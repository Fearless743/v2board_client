// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

enum Target {
  windows,
  linux,
  android,
  macos,
}

Target get currentHostTarget {
  if (Platform.isWindows) {
    return Target.windows;
  }
  if (Platform.isLinux) {
    return Target.linux;
  }
  if (Platform.isMacOS) {
    return Target.macos;
  }
  throw "Unsupported current platform";
}

extension TargetExt on Target {
  String get os {
    if (this == Target.macos) {
      return "darwin";
    }
    return name;
  }

  bool get same {
    if (this == Target.android) {
      return true;
    }
    if (Platform.isWindows && this == Target.windows) {
      return true;
    }
    if (Platform.isLinux && this == Target.linux) {
      return true;
    }
    if (Platform.isMacOS && this == Target.macos) {
      return true;
    }
    return false;
  }

  String get dynamicLibExtensionName {
    final String extensionName;
    switch (this) {
      case Target.android || Target.linux:
        extensionName = ".so";
        break;
      case Target.windows:
        extensionName = ".dll";
        break;
      case Target.macos:
        extensionName = ".dylib";
        break;
    }
    return extensionName;
  }

  String get executableExtensionName {
    final String extensionName;
    switch (this) {
      case Target.windows:
        extensionName = ".exe";
        break;
      default:
        extensionName = "";
        break;
    }
    return extensionName;
  }
}

enum Arch { amd64, arm64, arm }

class BuildItem {
  Target target;
  Arch? arch;
  String? archName;

  BuildItem({
    required this.target,
    this.arch,
    this.archName,
  });

  @override
  String toString() =>
      'BuildLibItem{target: $target, arch: $arch, archName: $archName}';
}

class Build {
  static List<BuildItem> get buildItems => [
        BuildItem(
          target: Target.macos,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.macos,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.linux,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.amd64,
        ),
        BuildItem(
          target: Target.windows,
          arch: Arch.arm64,
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.arm64,
          archName: 'arm64-v8a',
        ),
        BuildItem(
          target: Target.android,
          arch: Arch.amd64,
          archName: 'x86_64',
        ),
      ];

  static String get appName => "FlClashX";

  static String flutterTargetPlatform(String? archName) {
    const map = {
      'armeabi-v7a': 'android-arm',
      'arm64-v8a': 'android-arm64',
      'x86_64': 'android-x64',
    };
    return map[archName] ?? 'android-$archName';
  }

  static String get coreName => "FlClashCore";

  static String get libName => "libclash";

  static String get outDir => join(current, libName);

  static String get _servicesDir => join(current, "services", "helper");

  static String get distPath => join(current, "dist");

  static Future<void> exec(
    List<String> executable, {
    String? name,
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = true,
  }) async {
    if (name != null) print("run $name");
    final process = await Process.start(
      executable[0],
      executable.sublist(1),
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
    process.stdout.listen((data) {
      print(utf8.decode(data));
    });
    process.stderr.listen((data) {
      print(utf8.decode(data));
    });
    final exitCode = await process.exitCode;
    if (exitCode != 0 && name != null) throw "$name error";
  }

  static Future<String> calcSha256(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw "File not exists";
    }
    final stream = file.openRead();
    return sha256.convert(await stream.reduce((a, b) => a + b)).toString();
  }

  /// Fetches the latest mihomo core version from the Fearless743/mihomo_core release API.
  static Future<String> extractCoreVersion() async {
    const repo = "Fearless743/mihomo_core";
    const mirrors = [
      '',
      'https://v6.gh-proxy.org/',
      'https://gh-proxy.com/',
    ];
    for (final prefix in mirrors) {
      final url =
          '${prefix}https://api.github.com/repos/$repo/releases/latest';
      try {
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) continue;
        final data = json.decode(resp.body);
        final tag = data['tag_name'] as String?;
        if (tag != null && tag.isNotEmpty) {
          print("Core version from API: $tag");
          return tag;
        }
      } catch (_) {}
    }
    throw "Failed to fetch core version from $repo";
  }

  /// Writes [lib/core_version.dart] so Flutter can show the core version.
  static Future<void> syncCoreVersionDartFile() async {
    final v = await extractCoreVersion();
    final out = File(join(current, "lib", "core_version.dart"));
    await out.writeAsString(
      "// GENERATED by setup.dart from Fearless743/mihomo_core API — do not edit by hand\n"
      "// ignore_for_file: constant_identifier_names\n"
      "\n"
      "/// Latest mihomo version from Fearless743/mihomo_core releases.\n"
      "const String kCoreVersionFromSource = '$v';\n",
    );
  }

  static Future<Map<String, dynamic>> _fetchApiWithMirrors(String url) async {
    const mirrors = [
      '',
      'https://v6.gh-proxy.org/',
      'https://gh-proxy.com/',
    ];
    for (final prefix in mirrors) {
      try {
        final resp = await http.get(Uri.parse('$prefix$url'));
        if (resp.statusCode == 200) {
          return json.decode(resp.body);
        }
      } catch (_) {}
    }
    throw "Failed to fetch API: $url";
  }

  /// Downloads pre-built core binaries from Fearless743/mihomo_core releases.
  static Future<List<String>> downloadCore({
    required Target target,
    required String coreVersion,
    Arch? arch,
  }) async {
    const repo = "Fearless743/mihomo_core";
    final isLib = target == Target.android;

    // coreVersion is the tag name (e.g. "core-v1.19.26").
    // Asset names use the version without the "core-" prefix.
    final version = coreVersion.replaceFirst(RegExp(r'^core-'), '');

    final items = buildItems
        .where(
          (e) =>
              e.target == target && (arch == null ? true : e.arch == arch),
        )
        .toList();

    final targetOutDir = join(outDir, target.name);
    await Directory(targetOutDir).create(recursive: true);

    final List<String> corePaths = [];

    for (final item in items) {
      final archDir = join(targetOutDir, item.archName ?? '');
      await Directory(archDir).create(recursive: true);

      final expectedName =
          isLib ? '$libName${target.dynamicLibExtensionName}' : '$coreName${target.executableExtensionName}';
      final destPath = join(archDir, expectedName);

      // Asset name patterns from mihomo_core CI:
      //   Desktop: FlClashCore-{os}-{arch}-v{ver}.gz
      //   Android: libclash-android-{abi}-v{ver}.so.gz
      final assetName = isLib
          ? '$libName-${target.name}-${item.archName}-v${version}${target.dynamicLibExtensionName}.gz'
          : '$coreName-${target.name}-${item.arch!.name}-v${version}${target.executableExtensionName}.gz';

      final mirrors = [
        '',
        'https://v6.gh-proxy.org/',
        'https://gh-proxy.com/',
        'https://ghfast.top/',
      ];
      final url = 'https://github.com/$repo/releases/download/$coreVersion/$assetName';

      var downloaded = false;
      for (final mirror in mirrors) {
        try {
          print("Trying: $mirror$url");
          final resp = await http.get(Uri.parse('$mirror$url'));
          if (resp.statusCode != 200) continue;

          final decompressed = gzip.decode(resp.bodyBytes);
          File(destPath).writeAsBytesSync(decompressed);

          if (!isLib) {
            Process.runSync('chmod', ['+x', destPath]);
          }
          print("Downloaded: $destPath");
          corePaths.add(destPath);
          downloaded = true;
          break;
        } catch (e) {
          print("Failed ($mirror$url): $e");
        }
      }

      if (!downloaded) {
        throw "Failed to download $assetName for ${target.name}-${item.arch!.name}";
      }

      if (isLib) {
        final includesDir = join(targetOutDir, 'includes', item.archName!);
        await Directory(includesDir).create(recursive: true);
        final dir = Directory(archDir);
        for (final f in dir.listSync().whereType<File>()) {
          if (f.path.endsWith('.h')) {
            await f.copy(join(includesDir, basename(f.path)));
          }
        }
      }
    }

    return corePaths;
  }

  static buildHelper(Target target, String token, {Arch? arch}) async {
    final List<String> buildArgs = [
      "cargo",
      "build",
      "--release",
      "--features",
      "windows-service",
    ];

    // Add target for cross-compilation
    if (arch == Arch.arm64 && target == Target.windows) {
      buildArgs.addAll(["--target", "aarch64-pc-windows-msvc"]);
    }

    await exec(
      buildArgs,
      environment: {
        "TOKEN": token,
      },
      name: "build helper",
      workingDirectory: _servicesDir,
    );

    // Determine output path based on architecture
    final String releasePath;
    if (arch == Arch.arm64 && target == Target.windows) {
      releasePath =
          join(_servicesDir, "target", "aarch64-pc-windows-msvc", "release");
    } else {
      releasePath = join(_servicesDir, "target", "release");
    }

    final outPath = join(
      releasePath,
      "helper${target.executableExtensionName}",
    );
    final targetPath = join(
      outDir,
      target.name,
      "FlClashHelperService${target.executableExtensionName}",
    );
    await File(outPath).copy(targetPath);
  }

  static List<String> getExecutable(String command) => command.split(" ");

  static getDistributor() async {
    final distributorDir = join(
      current,
      "plugins",
      "flutter_distributor",
      "packages",
      "flutter_distributor",
    );

    await exec(
      name: "clean distributor",
      Build.getExecutable("flutter clean"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "upgrade distributor",
      Build.getExecutable("flutter pub upgrade"),
      workingDirectory: distributorDir,
    );
    await exec(
      name: "get distributor",
      Build.getExecutable("dart pub global activate -s path $distributorDir"),
    );
  }

  static copyFile(String sourceFilePath, String destinationFilePath) {
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      throw "SourceFilePath not exists";
    }
    final destinationFile = File(destinationFilePath);
    final destinationDirectory = destinationFile.parent;
    if (!destinationDirectory.existsSync()) {
      destinationDirectory.createSync(recursive: true);
    }
    try {
      sourceFile.copySync(destinationFilePath);
      print("File copied successfully!");
    } catch (e) {
      print("Failed to copy file: $e");
    }
  }

  static Future<Arch> resolveHostArch() async {
    final String? value;
    if (Platform.isWindows) {
      value = Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      value = result.stdout.toString().trim();
    } else {
      value = null;
    }

    final normalized = value?.toLowerCase();
    if (normalized == "x86_64" || normalized == "amd64") {
      return Arch.amd64;
    }
    if (normalized == "arm64" || normalized == "aarch64") {
      return Arch.arm64;
    }
    throw "Unsupported host arch: $value";
  }

  static Arch parseArch(String value) {
    return Arch.values.firstWhere(
      (arch) => arch.name == value,
      orElse: () => throw "Invalid arch parameter: $value",
    );
  }

  static Future<void> replaceIcons(String iconPath, String title) async {
    final bytes = File(iconPath).readAsBytesSync();
    final src = img.decodeImage(bytes);
    if (src == null) throw 'Failed to decode icon: $iconPath';

    _savePng(src, 'assets/images/icon.png', 1024);
    _savePng(_makeWhite(src), 'assets/images/icon_white.png', 1024);
    _savePng(_makeBlack(src), 'assets/images/icon_black.png', 1024);
    _savePng(_makeIco(src), 'assets/images/icon.ico', 256);
    _savePng(_makeWhite(src), 'assets/images/icon_white.ico', 256);

    final stopped = _makeStopped(src);
    _savePng(_makeWhite(stopped), 'assets/images/icon_stop_white.png', 256);
    _savePng(_makeBlack(stopped), 'assets/images/icon_stop_black.png', 256);

    final androidSizes = {
      'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192,
    };
    for (final e in androidSizes.entries) {
      _savePng(src, 'android/app/src/main/res/${e.key}/ic_launcher.png', e.value);
    }

    final drawableSizes = {
      'drawable-mdpi': 108, 'drawable-hdpi': 162, 'drawable-xhdpi': 216,
      'drawable-xxhdpi': 324, 'drawable-xxxhdpi': 432,
    };
    for (final e in drawableSizes.entries) {
      _savePng(src, 'android/app/src/main/res/${e.key}/ic_launcher_foreground.png', e.value);
      _savePng(_makeWhite(src), 'android/app/src/main/res/${e.key}/ic_launcher_monochrome.png', e.value);
    }

    _savePng(src, 'android/app/src/main/res/mipmap-xhdpi/ic_banner.png', 320, height: 180);

    final macSizes = [16, 32, 64, 128, 256, 512, 1024];
    for (final s in macSizes) {
      _savePng(src, 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$s.png', s);
    }

    _saveIco(src, 'windows/runner/resources/app_icon.ico');

    print('Icons replaced for all platforms.');
  }

  static Future<void> restoreIcons() async {
    print('Restoring original icons ...');
    await Process.run('git', ['checkout', '--',
      'assets/images/',
      'android/app/src/main/res/',
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/',
      'windows/runner/resources/app_icon.ico',
    ]);
  }

  static void _savePng(img.Image src, String path, int size, {int? height}) {
    final resized = img.copyResize(src, width: size, height: height ?? size,
        interpolation: img.Interpolation.cubic);
    File(path).writeAsBytesSync(img.encodePng(resized));
  }

  static void _saveIco(img.Image src, String path) {
    final resized = img.copyResize(src, width: 256, height: 256,
        interpolation: img.Interpolation.cubic);
    File(path).writeAsBytesSync(img.encodeIco(resized));
  }

  static img.Image _makeWhite(img.Image src) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 4);
    for (final p in out) {
      final s = src.getPixel(p.x, p.y);
      final a = s.a.toInt();
      if (a > 0) {
        p.setRgba(255, 255, 255, a);
      }
    }
    return out;
  }

  static img.Image _makeBlack(img.Image src) {
    final out = img.Image(width: src.width, height: src.height, numChannels: 4);
    for (final p in out) {
      final s = src.getPixel(p.x, p.y);
      final a = s.a.toInt();
      if (a > 0) {
        p.setRgba(0, 0, 0, a);
      }
    }
    return out;
  }

  static img.Image _makeStopped(img.Image src) {
    return img.adjustColor(src, saturation: -0.8, brightness: 0.1);
  }

  static img.Image _makeIco(img.Image src) => src;
}

class DevCommand extends Command {
  DevCommand() {
    argParser.addOption(
      "target",
      valueHelp: "android|linux|windows|macos|current|all",
      help: "Prepare one target for flutter run",
    );
    argParser.addOption(
      "targets",
      valueHelp: "android,linux",
      help: "Prepare multiple targets for flutter run",
    );
    argParser.addOption(
      "arch",
      valueHelp: "amd64|arm64|arm",
      help: "Desktop arch to prepare; Android defaults to all ABIs",
    );
    argParser.addOption(
      "env",
      defaultsTo: "pre",
      valueHelp: "pre|stable",
      help: "APP_ENV value used in printed flutter run commands",
    );
    argParser.addOption(
      "v2board-base-url",
      help: "Default V2Board panel base URL",
    );
    argParser.addFlag(
      "print-flutter-run",
      negatable: false,
      help: "Print suggested flutter run commands after preparing artifacts",
    );
  }

  @override
  String get description => "prepare native artifacts for flutter run";

  @override
  String get name => "dev";

  Future<List<Target>> _resolveTargets() async {
    final target = argResults?["target"] as String?;
    final targets = argResults?["targets"] as String?;

    if (target != null && targets != null) {
      throw "Use either --target or --targets, not both";
    }

    final values = (targets ?? target ?? "current")
        .split(",")
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);

    final resolved = <Target>[];
    for (final value in values) {
      if (value == "all") {
        resolved.addAll(Target.values);
        continue;
      }
      if (value == "current") {
        resolved.add(currentHostTarget);
        continue;
      }
      resolved.add(
        Target.values.firstWhere(
          (target) => target.name == value,
          orElse: () => throw "Invalid target parameter: $value",
        ),
      );
    }

    return resolved.toSet().toList();
  }

  Future<Arch?> _resolveArch(Target target) async {
    final archName = argResults?["arch"] as String?;
    if (target == Target.android) {
      return archName == null ? null : Build.parseArch(archName);
    }
    return archName == null
        ? await Build.resolveHostArch()
        : Build.parseArch(archName);
  }

  Future<String?> _prepareTarget(Target target, String coreVersion) async {
    final arch = await _resolveArch(target);
    final corePaths = await Build.downloadCore(
      target: target,
      arch: arch,
      coreVersion: coreVersion,
    );

    if (target != Target.windows) {
      return null;
    }

    final token = await Build.calcSha256(corePaths.first);
    await Build.buildHelper(target, token, arch: arch);
    return token;
  }

  String _v2boardRunDefine(String? v2boardBaseUrl) {
    final value = v2boardBaseUrl?.trim();
    if (value == null || value.isEmpty) return "";
    return " --dart-define=V2BOARD_BASE_URL=$value";
  }

  void _printFlutterRunHints(
    List<Target> targets,
    String env,
    String? windowsToken,
    String? v2boardBaseUrl,
  ) {
    final v2boardDefine = _v2boardRunDefine(v2boardBaseUrl);
    final deviceTargets = targets.map((target) => target.name).join(",");
    print("Prepared native artifacts for: $deviceTargets");
    print("");
    if (targets.contains(Target.windows) && windowsToken != null) {
      print(
        "flutter run -d windows --dart-define=APP_ENV=$env --dart-define=CORE_SHA256=$windowsToken$v2boardDefine",
      );
    }
    if (targets.length == 1 && !targets.contains(Target.windows)) {
      print(
        "flutter run -d ${targets.first.name} --dart-define=APP_ENV=$env$v2boardDefine",
      );
      return;
    }
    if (!targets.contains(Target.windows)) {
      print("flutter run -d all --dart-define=APP_ENV=$env$v2boardDefine");
    }
  }

  @override
  Future<void> run() async {
    final env = argResults?["env"] as String? ?? "pre";
    final v2boardBaseUrl = argResults?["v2board-base-url"] as String?;
    final printFlutterRun = argResults?["print-flutter-run"] as bool? ?? false;
    final targets = await _resolveTargets();

    await Build.syncCoreVersionDartFile();
    final coreVersion = await Build.extractCoreVersion();

    String? windowsToken;
    for (final target in targets) {
      final token = await _prepareTarget(target, coreVersion);
      windowsToken ??= token;
    }

    if (printFlutterRun) {
      _printFlutterRunHints(targets, env, windowsToken, v2boardBaseUrl);
    }
  }
}

class BuildCommand extends Command {
  Target target;

  BuildCommand({
    required this.target,
  }) {
    if (target == Target.android || target == Target.linux) {
      argParser.addOption(
        "arch",
        valueHelp: arches.map((e) => e.name).join(','),
        help: 'The $name build desc',
      );
    } else {
      argParser.addOption(
        "arch",
        help: 'The $name build archName',
      );
    }
    argParser.addOption(
      "out",
      valueHelp: [
        if (target.same) "app",
        "core",
      ].join(','),
      help: 'The $name build arch',
    );
    argParser.addOption(
      "env",
      valueHelp: [
        "pre",
        "stable",
      ].join(','),
      help: 'The $name build env',
    );
    argParser.addOption(
      "v2board-base-url",
      help: "Default V2Board panel base URL",
    );
    argParser.addOption(
      "app-title",
      help: "Application title (APP_TITLE)",
    );
    argParser.addOption(
      "primary-color",
      help: "PRIMARY_COLOR (e.g. 0xFF6750A4)",
    );
    argParser.addOption(
      "scheme-variant",
      help: "SCHEME_VARIANT (e.g. tonalSpot)",
    );
    argParser.addOption(
      "icon",
      help: "Path to 1024x1024 PNG icon to replace all platform icons",
    );
    // Android builds always create both split and universal APKs
    // No additional flags needed
  }

  @override
  String get description => "build $name application";

  @override
  String get name => target.name;

  List<Arch> get arches => Build.buildItems
      .where((element) => element.target == target && element.arch != null)
      .map((e) => e.arch!)
      .toList();

  _getLinuxDependencies(Arch arch) async {
    await Build.exec(
      Build.getExecutable("sudo apt update -y"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y ninja-build libgtk-3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y libayatana-appindicator3-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt-get install -y libkeybinder-3.0-dev"),
    );
    await Build.exec(
      Build.getExecutable("sudo apt install -y locate"),
    );
    if (arch == Arch.amd64) {
      await Build.exec(
        Build.getExecutable("sudo apt install -y rpm patchelf"),
      );
      await Build.exec(
        Build.getExecutable("sudo apt install -y libfuse2"),
      );

      final downloadName = arch == Arch.amd64 ? "x86_64" : "aarch64";
      await Build.exec(
        Build.getExecutable(
          "wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "chmod +x appimagetool",
        ),
      );
      await Build.exec(
        Build.getExecutable(
          "sudo mv appimagetool /usr/local/bin/",
        ),
      );
    }
  }

  _getMacosDependencies() async {
    await Build.exec(
      Build.getExecutable("npm install -g create-dmg"),
    );
  }

  String _v2boardBuildDefine(String? v2boardBaseUrl) {
    final value = v2boardBaseUrl?.trim();
    if (value == null || value.isEmpty) return "";
    return " --build-dart-define=V2BOARD_BASE_URL=$value";
  }

  String _extraBuildDefines({
    String? appTitle,
    String? primaryColor,
    String? schemeVariant,
  }) {
    final parts = <String>[];
    if (appTitle != null && appTitle.isNotEmpty) {
      parts.add("--build-dart-define=APP_TITLE=$appTitle");
    }
    if (primaryColor != null && primaryColor.isNotEmpty) {
      parts.add("--build-dart-define=PRIMARY_COLOR=$primaryColor");
    }
    if (schemeVariant != null && schemeVariant.isNotEmpty) {
      parts.add("--build-dart-define=SCHEME_VARIANT=$schemeVariant");
    }
    return parts.isEmpty ? "" : " ${parts.join(' ')}";
  }

  _buildMacosApp({
    required Arch arch,
    required String env,
    required String coreVersion,
    String? v2boardBaseUrl,
    String extraDefines = '',
  }) async {
    await Build.exec(
      name: "flutter build macos",
      [
        "flutter",
        "build",
        "macos",
        "--release",
        "--dart-define=APP_ENV=$env",
        "--dart-define=CORE_VERSION=$coreVersion",
        if (v2boardBaseUrl?.trim().isNotEmpty == true)
          "--dart-define=V2BOARD_BASE_URL=${v2boardBaseUrl!.trim()}",
        ...extraDefines
            .split(' ')
            .where((s) => s.startsWith('--build-dart-define='))
            .map((s) => s.replaceFirst('--build-dart-define=', '--dart-define=')),
      ],
    );

    final pubspecFile = File(join(current, "pubspec.yaml"));
    final pubspecContent = pubspecFile.readAsStringSync();
    final versionMatch = RegExp(r'version:\s*(.+)').firstMatch(pubspecContent);
    final version = versionMatch?.group(1)?.split('+').first ?? "0.0.0";

    final appName = Build.appName;
    final appPath = join(current, "build", "macos", "Build", "Products",
        "Release", "$appName.app");

    final distDir = Directory(Build.distPath);
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    print("Creating DMG with create-dmg...");

    await Build.exec(
      name: "create-dmg",
      [
        "create-dmg",
        "--overwrite",
        "--dmg-title",
        appName,
        appPath,
        Build.distPath,
      ],
    );

    final createdDmgName = "$appName $version.dmg";
    final createdDmgPath = join(Build.distPath, createdDmgName);
    final targetDmgName = "$appName-macos-${arch.name}.dmg";
    final targetDmgPath = join(Build.distPath, targetDmgName);

    final createdDmg = File(createdDmgPath);
    if (createdDmg.existsSync()) {
      final targetDmg = File(targetDmgPath);
      if (targetDmg.existsSync()) {
        targetDmg.deleteSync();
      }

      createdDmg.renameSync(targetDmgPath);
      print("✅ DMG created: $targetDmgPath");
    } else {
      throw "DMG file not created: $createdDmgPath";
    }
  }

  _buildDistributor({
    required Target target,
    required String targets,
    String args = '',
    required String env,
    String? v2boardBaseUrl,
  }) async {
    final v2boardDefine = _v2boardBuildDefine(v2boardBaseUrl);
    await Build.getDistributor();
    await Build.exec(
      name: name,
      Build.getExecutable(
        "dart pub global run flutter_distributor:main package --skip-clean --platform ${target.name} --targets $targets --flutter-build-args=verbose$args --build-dart-define=APP_ENV=$env$v2boardDefine",
      ),
    );
  }

  Future<String?> get systemArch async {
    if (Platform.isWindows) {
      return Platform.environment["PROCESSOR_ARCHITECTURE"];
    } else if (Platform.isLinux || Platform.isMacOS) {
      final result = await Process.run('uname', ['-m']);
      return result.stdout.toString().trim();
    }
    return null;
  }

  @override
  Future<void> run() async {
    final String out = argResults?["out"] ?? (target.same ? "app" : "core");
    final archName = argResults?["arch"];
    final env = argResults?["env"] ?? "pre";
    final v2boardBaseUrl = argResults?["v2board-base-url"] as String?;
    final appTitle = argResults?["app-title"] as String?;
    final primaryColor = argResults?["primary-color"] as String?;
    final schemeVariant = argResults?["scheme-variant"] as String?;
    final iconPath = argResults?["icon"] as String?;
    final extraDefines = _extraBuildDefines(
      appTitle: appTitle,
      primaryColor: primaryColor,
      schemeVariant: schemeVariant,
    );
    final currentArches =
        arches.where((element) => element.name == archName).toList();
    final arch = currentArches.isEmpty ? null : currentArches.first;

    if (arch == null && target != Target.android) {
      throw "Invalid arch parameter";
    }

    if (iconPath != null) {
      await Build.replaceIcons(iconPath, appTitle ?? Build.appName);
    }

    try {
      await Build.syncCoreVersionDartFile();
      final coreVersion = await Build.extractCoreVersion();

      final corePaths = await Build.downloadCore(
        target: target,
        arch: arch,
        coreVersion: coreVersion,
      );

      if (out != "app") {
        return;
      }

      switch (target) {
        case Target.windows:
        final token = target != Target.android
            ? await Build.calcSha256(corePaths.first)
            : null;
        Build.buildHelper(target, token!, arch: arch);
        _buildDistributor(
          target: target,
          targets: "exe,zip",
          args:
              " --description $archName --build-dart-define=CORE_SHA256=$token --build-dart-define=CORE_VERSION=$coreVersion$extraDefines",
          env: env,
          v2boardBaseUrl: v2boardBaseUrl,
        );
        return;
      case Target.linux:
        final targetMap = {
          Arch.arm64: "linux-arm64",
          Arch.amd64: "linux-x64",
        };
        final targets = [
          "deb",
          if (arch == Arch.amd64) "appimage",
          if (arch == Arch.amd64) "rpm",
        ].join(",");
        final defaultTarget = targetMap[arch];
        await _getLinuxDependencies(arch!);
        _buildDistributor(
          target: target,
          targets: targets,
          args:
              " --description $archName --build-target-platform $defaultTarget --build-dart-define=CORE_VERSION=$coreVersion$extraDefines",
          env: env,
          v2boardBaseUrl: v2boardBaseUrl,
        );
        return;
      case Target.android:
        // Build all architectures: arm64-v8a, x86_64
        final allTargets = Build.buildItems
            .where((b) => b.target == Target.android)
            .map((b) => Build.flutterTargetPlatform(b.archName))
            .join(',');

        // Build universal APK (all architectures in one file)
        await _buildDistributor(
          target: target,
          targets: "apk",
          args:
              " --build-target-platform $allTargets --build-dart-define=CORE_VERSION=$coreVersion$extraDefines",
          env: env,
          v2boardBaseUrl: v2boardBaseUrl,
        );

        return;
      case Target.macos:
        await _getMacosDependencies();
        await _buildMacosApp(
          arch: arch!,
          env: env,
          coreVersion: coreVersion,
          v2boardBaseUrl: v2boardBaseUrl,
          extraDefines: extraDefines,
        );
        return;
    }
    } finally {
      if (iconPath != null) {
        await Build.restoreIcons();
      }
    }
  }
}

class BuildAllCommand extends Command {
  BuildAllCommand() {
    argParser.addOption('icon', help: 'Path to 1024x1024 PNG icon');
    argParser.addOption('out', help: 'Output directory for built artifacts');
    argParser.addOption('title', defaultsTo: 'FlClashX', help: 'APP_TITLE');
    argParser.addOption('primary-color', help: 'PRIMARY_COLOR (e.g. 0xFF6750A4)');
    argParser.addOption('scheme-variant', help: 'SCHEME_VARIANT (e.g. tonalSpot)');
    argParser.addOption('env', defaultsTo: 'pre', help: 'APP_ENV (pre|stable)');
    argParser.addOption('v2board-base-url', help: 'V2BOARD_BASE_URL');
  }

  @override
  String get name => 'build-all';

  @override
  String get description => 'Build all platforms with custom icon and params';

  @override
  Future<void> run() async {
    final iconPath = argResults?['icon'] as String?;
    final outDir = argResults?['out'] as String?;
    final title = argResults?['title'] as String? ?? 'FlClashX';
    final primaryColor = argResults?['primary-color'] as String?;
    final schemeVariant = argResults?['scheme-variant'] as String?;
    final env = argResults?['env'] as String? ?? 'pre';
    final v2boardBaseUrl = argResults?['v2board-base-url'] as String?;

    if (outDir == null) {
      throw 'Missing required argument: --out';
    }

    // Replace icons if provided
    if (iconPath != null) {
      print('Replacing icons from $iconPath ...');
      await Build.replaceIcons(iconPath, title);
    }

    // Build dart-define args
    final defines = <String>[
      '--build-dart-define=APP_TITLE=$title',
      '--build-dart-define=APP_ENV=$env',
      if (primaryColor != null) '--build-dart-define=PRIMARY_COLOR=$primaryColor',
      if (schemeVariant != null) '--build-dart-define=SCHEME_VARIANT=$schemeVariant',
      if (v2boardBaseUrl != null) '--build-dart-define=V2BOARD_BASE_URL=$v2boardBaseUrl',
    ];
    final defineStr = defines.join(' ');

    // Set APP_TITLE env for Gradle
    final buildEnv = Map<String, String>.from(Platform.environment);
    buildEnv['APP_TITLE'] = title;

    await Build.syncCoreVersionDartFile();
    final coreVersion = await Build.extractCoreVersion();

    final out = Directory(outDir);
    if (!out.existsSync()) out.createSync(recursive: true);

    // Build Android
    print('\n=== Building Android ===');
    await _buildAndroid(coreVersion, defineStr, buildEnv);
    await _collectOutput(outDir, 'android', Build.distPath);

    // Build current-host desktop platform
    final hostTarget = currentHostTarget;
    if (hostTarget == Target.linux) {
      print('\n=== Building Linux ===');
      await _buildLinux(coreVersion, defineStr, buildEnv);
      await _collectOutput(outDir, 'linux', Build.distPath);
    } else if (hostTarget == Target.macos) {
      print('\n=== Building macOS ===');
      await _buildMacos(coreVersion, defineStr, buildEnv);
      await _collectOutput(outDir, 'macos', Build.distPath);
    } else if (hostTarget == Target.windows) {
      print('\n=== Building Windows ===');
      await _buildWindows(coreVersion, defineStr, buildEnv);
      await _collectOutput(outDir, 'windows', Build.distPath);
    }

    // Restore original icons
    if (iconPath != null) {
      await Build.restoreIcons();
    }

    print('\n=== Build complete. Output: $outDir ===');
  }

  // --- Platform builds ---

  Future<void> _buildAndroid(String coreVersion, String defines, Map<String, String> env) async {
    // Download core for all ABIs
    for (final bi in Build.buildItems.where((b) => b.target == Target.android)) {
      await Build.downloadCore(target: bi.target, arch: bi.arch, coreVersion: coreVersion);
    }
    // flutter_launcher_icons
    await Build.exec(name: 'icons', Build.getExecutable('dart run flutter_launcher_icons'));
    // Build APKs
    await Build.getDistributor();
    final allTargets = Build.buildItems
        .where((b) => b.target == Target.android)
        .map((b) => Build.flutterTargetPlatform(b.archName))
        .join(',');
    // Universal APK
    await Build.exec(
      name: 'android-universal',
      Build.getExecutable(
        'dart pub global run flutter_distributor:main package --skip-clean --platform android --targets apk --flutter-build-args=verbose --build-target-platform $allTargets --build-dart-define=CORE_VERSION=$coreVersion $defines',
      ),
      environment: env,
    );
  }

  Future<void> _buildLinux(String coreVersion, String defines, Map<String, String> env) async {
    final arch = _hostArch();
    if (arch == null) throw 'Cannot determine host architecture';
    await Build.downloadCore(target: Target.linux, arch: arch, coreVersion: coreVersion);
    final targetMap = {Arch.arm64: 'linux-arm64', Arch.amd64: 'linux-x64'};
    final targets = ['deb', if (arch == Arch.amd64) 'appimage', if (arch == Arch.amd64) 'rpm'].join(',');
    await Build.getDistributor();
    await Build.exec(
      name: 'linux',
      Build.getExecutable(
        'dart pub global run flutter_distributor:main package --skip-clean --platform linux --targets $targets --flutter-build-args=verbose --description ${arch.name} --build-target-platform ${targetMap[arch]} --build-dart-define=CORE_VERSION=$coreVersion $defines',
      ),
      environment: env,
    );
  }

  Future<void> _buildWindows(String coreVersion, String defines, Map<String, String> env) async {
    final arch = _hostArch();
    if (arch == null) throw 'Cannot determine host architecture';
    final corePaths = await Build.downloadCore(target: Target.windows, arch: arch, coreVersion: coreVersion);
    final token = await Build.calcSha256(corePaths.first);
    Build.buildHelper(Target.windows, token, arch: arch);
    await Build.getDistributor();
    await Build.exec(
      name: 'windows',
      Build.getExecutable(
        'dart pub global run flutter_distributor:main package --skip-clean --platform windows --targets exe,zip --flutter-build-args=verbose --description ${arch.name} --build-dart-define=CORE_SHA256=$token --build-dart-define=CORE_VERSION=$coreVersion $defines',
      ),
      environment: env,
    );
  }

  Future<void> _buildMacos(String coreVersion, String defines, Map<String, String> env) async {
    final arch = _hostArch();
    if (arch == null) throw 'Cannot determine host architecture';
    await Build.downloadCore(target: Target.macos, arch: arch, coreVersion: coreVersion);
    // macOS uses direct flutter build, not distributor
    final dartDefines = defines.replaceAll('--build-dart-define=', '--dart-define=');
    await Build.exec(
      name: 'macos',
      Build.getExecutable('flutter build macos --release $dartDefines --dart-define=CORE_VERSION=$coreVersion'),
      environment: env,
    );
    // Create DMG
    final archName = arch.name;
    final dmgPath = join(Build.distPath, '${Build.appName}-macos-$archName.dmg');
    await Process.run('create-dmg', [
      '--volname', '${Build.appName}',
      '--window-pos', '200', '120',
      '--window-size', '600', '400',
      '--icon-size', '100',
      '--icon', '${Build.appName}.app', '175', '190',
      '--hide-extension', '${Build.appName}.app',
      '--app-drop-link', '425', '190',
      dmgPath,
      'build/macos/Build/Products/Release/${Build.appName}.app',
    ]);
  }

  Arch? _hostArch() {
    final result = Process.runSync('uname', ['-m']);
    final machine = result.stdout.toString().trim();
    return switch (machine) {
      'x86_64' || 'amd64' => Arch.amd64,
      'aarch64' || 'arm64' => Arch.arm64,
      _ => null,
    };
  }

  Future<void> _collectOutput(String outDir, String platform, String distPath) async {
    final platDir = Directory(join(outDir, platform));
    if (!platDir.existsSync()) platDir.createSync(recursive: true);
    final dist = Directory(distPath);
    if (!dist.existsSync()) return;
    for (final f in dist.listSync().whereType<File>()) {
      final name = basename(f.path);
      f.copySync(join(platDir.path, name));
      print('  -> ${join(platform, name)}');
    }
  }
}

main(args) async {
  final runner = CommandRunner("setup", "build Application");
  runner.addCommand(DevCommand());
  runner.addCommand(BuildCommand(target: Target.android));
  runner.addCommand(BuildCommand(target: Target.linux));
  runner.addCommand(BuildCommand(target: Target.windows));
  runner.addCommand(BuildCommand(target: Target.macos));
  runner.addCommand(BuildAllCommand());
  runner.run(args);
}
