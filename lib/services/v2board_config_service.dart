import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flclashx/common/custom_base64.dart';
import 'package:flclashx/common/retry_interceptor.dart';

/// Fetches the V2Board config from an object storage direct link.
///
/// The remote file must contain a custom-base64-encoded JSON string with
/// the structure: `{ "baseUrl": ["https://...", ...] }`.
class V2boardConfigService {
  V2boardConfigService()
      : _dio = Dio()
          ..interceptors.add(RetryInterceptor());

  final Dio _dio;

  /// Returns the list of base URLs decoded from the remote config file.
  Future<List<String>> fetchBaseUrls(String configUrl) async {
    final response = await _dio.get<String>(
      configUrl,
      options: Options(responseType: ResponseType.plain),
    );

    final body = response.data;
    if (body == null || body.trim().isEmpty) {
      throw const V2boardConfigException('配置文件内容为空。');
    }

    final String jsonString;
    try {
      jsonString = CustomBase64.decodeToString(body.trim());
    } catch (e) {
      throw V2boardConfigException('配置文件解码失败：$e');
    }

    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonString);
    } catch (e) {
      throw V2boardConfigException('配置文件 JSON 解析失败：$e');
    }

    if (parsed is! Map<String, dynamic>) {
      throw const V2boardConfigException('配置文件格式不正确，期望 JSON 对象。');
    }

    final raw = parsed['baseUrl'];
    if (raw is! List || raw.isEmpty) {
      throw const V2boardConfigException('配置文件中未找到 baseUrl 列表。');
    }

    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}

class V2boardConfigException implements Exception {
  const V2boardConfigException(this.message);
  final String message;

  @override
  String toString() => message;
}
