import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
        "FlClash X/v$version",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");

  /// UA for subscription fetching.
  /// Xboard matches "flclash" flag → ClashMeta YAML output.
  /// Includes mihomo core version for feature gating (ECH, xhttp, etc).
  String uaWithCoreVersion(String? coreVersion) {
    final cv = coreVersion ?? '';
    final parts = <String>[
      "FlClash/v$version",
      if (cv.isNotEmpty) "mihomo/$cv",
      "Platform/${Platform.operatingSystem}",
    ];
    return parts.join(" ");
  }
}
