// ignore_for_file: invalid_annotation_target
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flclashx/clash/core.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/services/crypto_service.dart';
import 'package:flclashx/utils/device_info_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'clash_config.dart';

part 'generated/profile.freezed.dart';
part 'generated/profile.g.dart';

typedef SelectedMap = Map<String, String>;

@freezed
class SubscriptionInfo with _$SubscriptionInfo {
  const factory SubscriptionInfo({
    @Default(0) int upload,
    @Default(0) int download,
    @Default(0) int total,
    @Default(0) int expire,
  }) = _SubscriptionInfo;

  factory SubscriptionInfo.fromJson(Map<String, Object?> json) =>
      _$SubscriptionInfoFromJson(json);

  factory SubscriptionInfo.formHString(String? info) {
    if (info == null || info.trim().isEmpty) return const SubscriptionInfo();
    final list = info.split(";");
    final map = <String, int?>{};
    for (final i in list) {
      final keyValue = i.trim().split("=");
      if (keyValue.length < 2) continue;
      final key = keyValue.first.trim();
      final value = keyValue.sublist(1).join("=").trim();
      if (key.isEmpty) continue;
      map[key] = int.tryParse(value);
    }
    return SubscriptionInfo(
      upload: map["upload"] ?? 0,
      download: map["download"] ?? 0,
      total: map["total"] ?? 0,
      expire: map["expire"] ?? 0,
    );
  }
}

extension SubscriptionInfoExt on SubscriptionInfo {
  bool get isNotEmpty => upload > 0 || download > 0 || total > 0 || expire > 0;
}

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String id,
    String? label,
    String? currentGroupName,
    @Default("") String url,
    DateTime? lastUpdateDate,
    required Duration autoUpdateDuration,
    SubscriptionInfo? subscriptionInfo,
    @Default(true) bool autoUpdate,
    @Default({}) SelectedMap selectedMap,
    @Default({}) Set<String> unfoldSet,
    @Default(OverrideData()) OverrideData overrideData,
    @JsonKey(includeToJson: false, includeFromJson: false)
    @Default(false)
    bool isUpdating,
    @Default(false) bool isEncrypted,
    String? encryptedUrl,
    @Default({}) Map<String, String> providerHeaders,
  }) = _Profile;

  factory Profile.fromJson(Map<String, Object?> json) =>
      _$ProfileFromJson(json);

  factory Profile.normal({
    String? label,
    String url = '',
  }) =>
      Profile(
        label: label,
        url: url,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        autoUpdateDuration: defaultUpdateDuration,
      );
}

@freezed
class OverrideData with _$OverrideData {
  const factory OverrideData({
    @Default(false) bool enable,
    @Default(OverrideRule()) OverrideRule rule,
  }) = _OverrideData;

  factory OverrideData.fromJson(Map<String, Object?> json) =>
      _$OverrideDataFromJson(json);
}

extension OverrideDataExt on OverrideData {
  List<String> get runningRule {
    if (!enable) {
      return [];
    }
    return rule.rules.map((item) => item.value).toList();
  }
}

@freezed
class OverrideRule with _$OverrideRule {
  const factory OverrideRule({
    @Default(OverrideRuleType.added) OverrideRuleType type,
    @Default([]) List<Rule> overrideRules,
    @Default([]) List<Rule> addedRules,
  }) = _OverrideRule;

  factory OverrideRule.fromJson(Map<String, Object?> json) =>
      _$OverrideRuleFromJson(json);
}

extension OverrideRuleExt on OverrideRule {
  List<Rule> get rules => switch (type == OverrideRuleType.override) {
        true => overrideRules,
        false => addedRules,
      };

  OverrideRule updateRules(List<Rule> Function(List<Rule> rules) builder) {
    if (type == OverrideRuleType.added) {
      return copyWith(addedRules: builder(addedRules));
    }
    return copyWith(overrideRules: builder(overrideRules));
  }
}

extension ProfilesExt on List<Profile> {
  Profile? getProfile(String? profileId) {
    final index = indexWhere((profile) => profile.id == profileId);
    return index == -1 ? null : this[index];
  }
}

extension ProfileExtension on Profile {
  ProfileType get type =>
      url.isEmpty == true ? ProfileType.file : ProfileType.url;

  bool get realAutoUpdate => url.isEmpty == true ? false : autoUpdate;

  Future<void> checkAndUpdate() async {
    final isExists = await check();
    if (!isExists) {
      if (url.isNotEmpty && realAutoUpdate) {
        await update();
      }
    }
  }

  Future<bool> check() async {
    final profilePath = await appPath.getProfilePath(id);
    if (await File(profilePath).exists()) return true;
    final encPath = await appPath.getEncryptedProfilePath(id);
    return File(encPath).exists();
  }

  Future<File> getFile() async {
    final path = await appPath.getProfilePath(id);
    final file = File(path);
    final isExists = await file.exists();
    if (!isExists) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<int> get profileLastModified async {
    final file = await getFile();
    return (await file.lastModified()).microsecondsSinceEpoch;
  }

  Future<Profile> update({bool shouldSendHeaders = true}) async {
    final headers = <String, dynamic>{};

    if (shouldSendHeaders) {
      final deviceInfoService = DeviceInfoService();
      final details = await deviceInfoService.getDeviceDetails();

      if (details.hwid != null) headers['x-hwid'] = details.hwid;
      if (details.os != null) headers['x-device-os'] = details.os;
      if (details.osVersion != null) headers['x-ver-os'] = details.osVersion;
      if (details.model != null) headers['x-device-model'] = details.model;
    }

    if (!await CryptoService.hasKeyPair()) {
      await CryptoService.generateKeyPair();
    }
    final publicKeyBase64 = await CryptoService.getPublicKeyBase64();
    headers['x-public-key'] = publicKeyBase64;

    final requestUrl = encryptedUrl ?? url;
    final response = await request.getFileResponseForUrl(
      requestUrl,
      headers: headers.isNotEmpty ? headers : null,
    );

    if (response.statusCode == 403) {
      await CryptoService.clearKeyPair();
      throw Exception("Encryption key rejected by server. Keys have been reset, please retry.");
    }

    final disposition = response.headers.value("content-disposition");
    final userinfo = response.headers.value('subscription-userinfo');

    final responseData = response.data;
    if (responseData == null) {
      throw Exception("Failed to get profile data from response.");
    }

    Uint8List plaintextBytes;
    final isResponseEncrypted =
        response.headers.value('x-encrypted') == 'true';

    // Debug: log response info
    final respLen = responseData.length;
    final contentType = response.headers.value('content-type') ?? '';
    final firstBytes = responseData.length >= 4
        ? responseData.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
        : 'short';
    print('[EncryptDebug] status=${response.statusCode} encrypted=$isResponseEncrypted '
        'content-type=$contentType len=$respLen firstBytes=$firstBytes '
        'url=$requestUrl');

    if (isResponseEncrypted) {
      plaintextBytes = await CryptoService.decryptHybrid(responseData);
    } else {
      plaintextBytes = responseData;
    }

    final providerHeaders = <String, String>{};

    final headersToCollect = [
      'announce',
      'support-url',
      'profile-update-interval',
      'profile-web-page-url',
      'subscription-title',
      'x-hwid-limit',
    ];

    for (final headerName in headersToCollect) {
      final value = response.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        providerHeaders[headerName] = value;
      }
    }

    response.headers.forEach((name, values) {
      if (name.toLowerCase().startsWith('flclashx-') && values.isNotEmpty) {
        providerHeaders[name.toLowerCase()] = values.first;
      }
    });

    Duration? durationFromHeader;
    final updateIntervalHeader = providerHeaders['profile-update-interval'];
    if (updateIntervalHeader != null) {
      final hours = int.tryParse(updateIntervalHeader);
      if (hours != null && hours > 0) {
        durationFromHeader = Duration(hours: hours);
      }
    }

    return copyWith(
      label: label ?? utils.getFileNameForDisposition(disposition) ?? id,
      subscriptionInfo: SubscriptionInfo.formHString(userinfo),
      autoUpdateDuration: durationFromHeader ?? autoUpdateDuration,
      providerHeaders: providerHeaders,
      encryptedUrl: isResponseEncrypted ? requestUrl : encryptedUrl,
    ).saveFile(
      isResponseEncrypted ? responseData : plaintextBytes,
      isEncrypted: isResponseEncrypted,
      plaintextForValidation: isResponseEncrypted ? plaintextBytes : null,
    );
  }

  Future<Profile> saveFile(
    Uint8List bytes, {
    bool isEncrypted = false,
    Uint8List? plaintextForValidation,
  }) async {
    final validateBytes = plaintextForValidation ?? bytes;
    final first20 = validateBytes.length >= 20
        ? validateBytes.sublist(0, 20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
        : 'short';
    final first20str = utf8.decode(validateBytes.sublist(0, validateBytes.length >= 20 ? 20 : validateBytes.length), allowMalformed: true);
    print('[SaveDebug] isEncrypted=$isEncrypted validateLen=${validateBytes.length} first20hex=$first20 first20str=$first20str');
    final message = await clashCore.validateConfig(utf8.decode(validateBytes));
    if (message.isNotEmpty) {
      throw message;
    }
    if (isEncrypted) {
      final encPath = await appPath.getEncryptedProfilePath(id);
      await File(encPath).parent.create(recursive: true);
      await File(encPath).writeAsBytes(bytes);
      final plainPath = await appPath.getProfilePath(id);
      final plainFile = File(plainPath);
      if (await plainFile.exists()) {
        await plainFile.delete();
      }
    } else {
      final file = await getFile();
      await file.writeAsBytes(bytes);
      final encPath = await appPath.getEncryptedProfilePath(id);
      final encFile = File(encPath);
      if (await encFile.exists()) {
        await encFile.delete();
      }
    }
    return copyWith(lastUpdateDate: DateTime.now(), isEncrypted: isEncrypted);
  }

  Future<Profile> saveFileWithString(String value) async {
    final message = await clashCore.validateConfig(value);
    if (message.isNotEmpty) {
      throw message;
    }
    final file = await getFile();
    await file.writeAsString(value);
    return copyWith(lastUpdateDate: DateTime.now());
  }
}
