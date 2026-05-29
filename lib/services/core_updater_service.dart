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
  });

  final String tagName;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
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

  Future<CoreUpdateInfo?> checkForCoreUpdate({bool force = false}) async {
    try {
      if (!force && !await _shouldCheck()) return null;

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

      final globPattern = await _resolveAssetName();
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
      );
    } catch (e) {
      commonPrint.log('Core update check failed: $e');
      return null;
    }
  }

  Future<bool> downloadAndInstall(
    CoreUpdateInfo info, {
    Function(double progress, String status)? onProgress,
  }) async {
    final tempDirPath = await appPath.tempPath;
    final downloadFile = p.join(tempDirPath, info.fileName);
    final extractedFile = p.join(
      tempDirPath,
      info.fileName.replaceAll('.gz', ''),
    );

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

      // Extract gzip
      final compressedBytes = await File(downloadFile).readAsBytes();
      final gzipBytes = GZipDecoder().decodeBytes(compressedBytes);

      // Install
      onProgress?.call(1.0, '正在安装内核...');

      if (Platform.isAndroid) {
        await _installAndroid(gzipBytes);
      } else {
        await _installDesktop(gzipBytes);
      }

      await _saveInstalledVersion(info.tagName);

      onProgress?.call(1.0, '内核更新完成');

      return true;
    } catch (e) {
      commonPrint.log('Core install failed: $e');
      return false;
    } finally {
      // Cleanup temp files
      try {
        final dlFile = File(downloadFile);
        if (await dlFile.exists()) await dlFile.delete();
        final exFile = File(extractedFile);
        if (await exFile.exists()) await exFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _installDesktop(List<int> binaryBytes) async {
    final targetPath = appPath.corePath;
    final targetFile = File(targetPath);

    // Write to temp file first for atomic replacement
    final tempPath = '$targetPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(binaryBytes, flush: true);

    // Set executable permission
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tempPath]);
    }

    // Atomic rename
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetPath);
  }

  static const _channel = MethodChannel('com.follow.clashx/core_updater');

  Future<void> _installAndroid(List<int> binaryBytes) async {
    final coresDir = await appPath.coresDirPath;
    final coresDirectory = Directory(coresDir);
    if (!await coresDirectory.exists()) {
      await coresDirectory.create(recursive: true);
    }

    final targetPath = p.join(coresDir, 'mihomo');

    // Write to temp file first
    final tempDirPath = await appPath.tempPath;
    final tempPath = p.join(tempDirPath, 'mihomo_download.tmp');
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(binaryBytes, flush: true);

    // Use Kotlin to copy and set executable permission
    // (Java File API handles permissions more reliably on Android)
    try {
      await _channel.invokeMethod('installCoreBinary', {
        'srcPath': tempPath,
        'destPath': targetPath,
      });
    } on MissingPluginException {
      // Fallback for when channel isn't available (e.g., unit tests)
      final targetFile = File(targetPath);
      if (await targetFile.exists()) await targetFile.delete();
      await tempFile.copy(targetPath);
      await Process.run('chmod', ['755', targetPath]);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  Future<String?> _resolveAssetName() async {
    if (Platform.isAndroid) {
      return _resolveAndroidAssetName();
    } else if (Platform.isLinux) {
      return _resolveLinuxAssetName();
    } else if (Platform.isMacOS) {
      return _resolveDarwinAssetName();
    } else if (Platform.isWindows) {
      return _resolveWindowsAssetName();
    }
    return null;
  }

  Future<String> _resolveAndroidAssetName() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final abi = deviceInfo.supportedAbis.isNotEmpty
        ? deviceInfo.supportedAbis.first
        : 'arm64-v8a';

    final arch = switch (abi) {
      'arm64-v8a' => 'arm64-v8',
      'armeabi-v7a' => 'armv7',
      'x86_64' => 'amd64',
      'x86' => '386',
      _ => 'arm64-v8',
    };

    return 'mihomo-android-$arch-*.gz';
  }

  String? _resolveLinuxAssetName() {
    // Detect architecture
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
  }

  String? _resolveDarwinAssetName() {
    final result = Process.runSync('uname', ['-m']);
    final machine = result.stdout.toString().trim();

    final arch = switch (machine) {
      'arm64' => 'arm64',
      'x86_64' => 'amd64',
      _ => null,
    };

    if (arch == null) return null;
    return 'mihomo-darwin-$arch-*.gz';
  }

  String? _resolveWindowsAssetName() {
    // Windows is almost always amd64
    return 'mihomo-windows-amd64-*.gz';
  }

  /// Resolve the actual asset name from the glob pattern by matching
  /// against the release assets list
  static String? matchAsset(List<dynamic> assets, String globPattern) {
    final prefix = globPattern.split('*').first;
    final suffix = globPattern.split('*').last;

    String? bestMatch;
    for (final asset in assets) {
      final name = asset['name'] as String?;
      if (name == null) continue;
      if (name.startsWith(prefix) && name.endsWith(suffix)) {
        // Prefer the simplest variant (no v1/v2/v3/go suffixes)
        // The pattern is: mihomo-{os}-{arch}-v{version}.gz
        // Skip variants like: mihomo-{os}-{arch}-v1-v{version}.gz
        //                     mihomo-{os}-{arch}-go120-v{version}.gz
        final betweenPrefixAndSuffix =
            name.substring(prefix.length, name.length - suffix.length);
        // If there's only the version (like "v1.19.25"), it's the base variant
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
