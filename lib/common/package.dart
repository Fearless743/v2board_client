import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
        "FlClash X/v$version",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");

  String uaWithCoreVersion(String? coreVersion) {
    final cv = coreVersion ?? '';
    return [
      "clash.meta",
      if (cv.isNotEmpty) "v$cv",
      "FlClash X/v$version",
      "Platform/${Platform.operatingSystem}",
    ].join(" ");
  }
}
