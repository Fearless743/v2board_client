import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/core_version.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class CoreUpdateInfo {
  CoreUpdateInfo({
    required this.tagName,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.isApk,
  });

  final String tagName;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final bool isApk;
}

class CoreUpdaterService {
  factory CoreUpdaterService() => _instance ??= CoreUpdaterService._internal();

  CoreUpdaterService._internal();

  static CoreUpdaterService? _instance;

  static const _kInstalledVersion = 'core_installed_version';
  static const _kLastCheckTime = 'core_last_check_time';

  late final Dio _dio = Dio(
    BaseOptions(
      headers: {'User-Agent': browserUa},
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  Future<String> getInstalledCoreVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kInstalledVersion) ?? kCoreVersionFromSource;
  }

  Future<void> _saveInstalledVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kInstalledVersion, version);
  }

  Future<bool> _shouldCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_kLastCheckTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return now - lastCheck > coreCheckIntervalHours * 3600 * 1000;
  }

  Future<void> _markChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastCheckTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Check for core update. On Android, checks FlClashX releases for split
  /// APK containing updated libclash.so. On desktop, checks mihomo releases.
  Future<CoreUpdateInfo?> checkForCoreUpdate({bool force = false}) async {
    try {
      if (!force && !await _shouldCheck()) return null;

      if (Platform.isAndroid) {
        return _checkFlClashXRelease(force: force);
      }
      return _checkMihomoRelease(force: force);
    } catch (e) {
      commonPrint.log('Core update check failed: $e');
      return null;
    }
  }

  /// Check FlClashX releases for Android split APK with updated core.
  /// The split APK contains libclash.so which we extract via ZIP.
  Future<CoreUpdateInfo?> _checkFlClashXRelease({bool force = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$repository/releases/latest',
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode != 200 || response.data == null) return null;
    final data = response.data!;
    final remoteTag = data['tag_name'] as String?;
    if (remoteTag == null) return null;

    final remoteVersion = remoteTag.replaceAll('v', '');
    final installedVersion = await getInstalledCoreVersion();
    final hasUpdate = utils.compareVersions(
            remoteVersion, installedVersion.replaceAll('v', '')) >
        0;

    await _markChecked();
    if (!hasUpdate) return null;

    final assets = data['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) return null;

    // Find the split APK for the device's primary ABI
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final abi = deviceInfo.supportedAbis.isNotEmpty
        ? deviceInfo.supportedAbis.first
        : 'arm64-v8a';

    // Map Android ABI to flutter_distributor target name
    final targetArch = switch (abi) {
      'arm64-v8a' => 'arm64',
      'armeabi-v7a' => 'arm',
      'x86_64' => 'x64',
      _ => 'arm64',
    };

    final apkPattern = 'FlClashX-android-$targetArch-*.apk';

    final matchedName = matchAsset(assets, apkPattern);
    if (matchedName == null) return null;

    Map<String, dynamic>? matchedAsset;
    for (final asset in assets) {
      if ((asset as Map<String, dynamic>)['name'] == matchedName) {
        matchedAsset = asset;
        break;
      }
    }
    if (matchedAsset == null) return null;

    return CoreUpdateInfo(
      tagName: remoteTag,
      downloadUrl: matchedAsset['browser_download_url'] as String,
      fileName: matchedName,
      fileSize: matchedAsset['size'] as int? ?? 0,
      isApk: true,
    );
  }

  /// Check mihomo releases for desktop core binary.
  Future<CoreUpdateInfo?> _checkMihomoRelease({bool force = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      mihomoGitHubApiUrl,
      options: Options(responseType: ResponseType.json),
    );

    if (response.statusCode != 200 || response.data == null) return null;
    final data = response.data!;
    final remoteTag = data['tag_name'] as String?;
    if (remoteTag == null) return null;

    final remoteVersion = remoteTag.replaceAll('v', '');
    final installedVersion = await getInstalledCoreVersion();
    final hasUpdate = utils.compareVersions(
            remoteVersion, installedVersion.replaceAll('v', '')) >
        0;

    await _markChecked();
    if (!hasUpdate) return null;

    final assets = data['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) return null;

    final globPattern = _resolveDesktopAssetName();
    if (globPattern == null) return null;

    final matchedName = matchAsset(assets, globPattern);
    if (matchedName == null) return null;

    Map<String, dynamic>? matchedAsset;
    for (final asset in assets) {
      if ((asset as Map<String, dynamic>)['name'] == matchedName) {
        matchedAsset = asset;
        break;
      }
    }
    if (matchedAsset == null) return null;

    return CoreUpdateInfo(
      tagName: remoteTag,
      downloadUrl: matchedAsset['browser_download_url'] as String,
      fileName: matchedName,
      fileSize: matchedAsset['size'] as int? ?? 0,
      isApk: false,
    );
  }

  Future<bool> downloadAndInstall(
    CoreUpdateInfo info, {
    Function(double progress, String status)? onProgress,
  }) async {
    final tempDirPath = await appPath.tempPath;
    final downloadFile = p.join(tempDirPath, info.fileName);

    try {
      // Try mirrors in order
      bool downloaded = false;
      final errors = <String>[];

      for (final mirror in mihomoMirrorPrefixes) {
        final url = '$mirror${info.downloadUrl}';
        try {
          onProgress?.call(0, '正在从 $url 下载...');
          await _dio.download(
            url,
            downloadFile,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                final progress = received / total;
                onProgress?.call(
                  progress.clamp(0.0, 1.0),
                  '正在下载 ${info.tagName}...',
                );
              }
            },
            options: Options(
              followRedirects: true,
              maxRedirects: 5,
            ),
          );
          downloaded = true;
          break;
        } catch (e) {
          errors.add('$mirror: $e');
          continue;
        }
      }

      if (!downloaded) {
        throw Exception('所有下载源均失败:\n${errors.join('\n')}');
      }

      onProgress?.call(1.0, '正在解压...');

      if (info.isApk) {
        await _extractAndInstallFromApk(downloadFile);
      } else {
        await _extractAndInstallGzip(downloadFile);
      }

      await _saveInstalledVersion(info.tagName);
      onProgress?.call(1.0, '内核更新完成');
      return true;
    } catch (e) {
      commonPrint.log('Core install failed: $e');
      return false;
    } finally {
      try {
        final dlFile = File(downloadFile);
        if (await dlFile.exists()) await dlFile.delete();
      } catch (_) {}
    }
  }

  /// Extract libclash.so from a split APK (ZIP archive) and install it.
  Future<void> _extractAndInstallFromApk(String apkPath) async {
    final apkBytes = await File(apkPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(apkBytes);

    // Find libclash.so in the APK
    // Path format: lib/{abi}/libclash.so (e.g., lib/arm64-v8a/libclash.so)
    ArchiveFile? soFile;
    for (final file in archive) {
      if (file.name.endsWith('libclash.so') && file.name.startsWith('lib/')) {
        soFile = file;
        break;
      }
    }

    if (soFile == null) {
      throw Exception('APK 中未找到 libclash.so');
    }

    final soBytes = soFile.content as List<int>;
    await _installSoFile(soBytes);
  }

  /// Extract a gzip-compressed binary and install it (desktop).
  Future<void> _extractAndInstallGzip(String filePath) async {
    final compressedBytes = await File(filePath).readAsBytes();
    final binaryBytes = GZipDecoder().decodeBytes(compressedBytes);

    if (Platform.isAndroid) {
      await _installSoFile(binaryBytes);
    } else {
      await _installDesktop(binaryBytes);
    }
  }

  Future<void> _installDesktop(List<int> binaryBytes) async {
    final targetPath = appPath.corePath;
    final targetFile = File(targetPath);

    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(binaryBytes, flush: true);

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tempPath]);
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
  }

  static const _channel = MethodChannel('com.follow.clashx/core_updater');

  Future<void> _installSoFile(List<int> soBytes) async {
    final coresDir = await appPath.coresDirPath;
    final coresDirectory = Directory(coresDir);
    if (!await coresDirectory.exists()) {
      await coresDirectory.create(recursive: true);
    }

    final targetPath = p.join(coresDir, 'libclash.so');
    final tempDirPath = await appPath.tempPath;
    final tempPath = p.join(tempDirPath, 'libclash_download.tmp');
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(soBytes, flush: true);

    try {
      await _channel.invokeMethod('installCoreBinary', {
        'srcPath': tempPath,
        'destPath': targetPath,
      });
    } on MissingPluginException {
      final targetFile = File(targetPath);
      if (await targetFile.exists()) await targetFile.delete();
      await tempFile.copy(targetPath);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  String? _resolveDesktopAssetName() {
    if (Platform.isLinux) {
      final result = Process.runSync('uname', ['-m']);
      final machine = result.stdout.toString().trim();
      final arch = switch (machine) {
        'x86_64' || 'amd64' => 'amd64',
        'aarch64' || 'arm64' => 'arm64',
        'armv7l' => 'armv7',
        'i686' || 'i386' => '386',
        _ => null,
      };
      if (arch == null) return null;
      return 'mihomo-linux-$arch-*.gz';
    } else if (Platform.isMacOS) {
      final result = Process.runSync('uname', ['-m']);
      final machine = result.stdout.toString().trim();
      final arch = switch (machine) {
        'arm64' => 'arm64',
        'x86_64' => 'amd64',
        _ => null,
      };
      if (arch == null) return null;
      return 'mihomo-darwin-$arch-*.gz';
    } else if (Platform.isWindows) {
      return 'mihomo-windows-amd64-*.gz';
    }
    return null;
  }

  /// Resolve the actual asset name from the glob pattern by matching
  /// against the release assets list.
  static String? matchAsset(List<dynamic> assets, String globPattern) {
    final prefix = globPattern.split('*').first;
    final suffix = globPattern.split('*').last;

    String? bestMatch;
    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name == null) continue;
      if (name.startsWith(prefix) && name.endsWith(suffix)) {
        final betweenPrefixAndSuffix =
            name.substring(prefix.length, name.length - suffix.length);
        if (!betweenPrefixAndSuffix.contains('-go') &&
            !betweenPrefixAndSuffix.contains('-v1-') &&
            !betweenPrefixAndSuffix.contains('-v2-') &&
            !betweenPrefixAndSuffix.contains('-v3-') &&
            !betweenPrefixAndSuffix.contains('-compatible')) {
          return name;
        }
        bestMatch ??= name;
      }
    }
    return bestMatch;
  }
}

final coreUpdater = CoreUpdaterService();
