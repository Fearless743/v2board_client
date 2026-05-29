import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
        "FlClash X/v$version",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");

  /// UA for subscription fetching.
  /// Xboard regex extracts first name/version pair as clientVersion.
  /// Putting mihomo first ensures clientVersion = mihomo version,
  /// which Xboard uses for xhttp (>= 1.19.24) and other feature checks.
  /// Phase 2 substring match finds "flclash" → ClashMeta protocol output.
  String uaWithCoreVersion(String? coreVersion) {
    final cv = coreVersion ?? '';
    final parts = <String>[
      if (cv.isNotEmpty) "mihomo/$cv",
      "FlClash/v$version",
      "Platform/${Platform.operatingSystem}",
    ];
    return parts.join(" ");
  }
}
