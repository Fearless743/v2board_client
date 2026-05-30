import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flclashx/common/retry_interceptor.dart';
import 'package:flclashx/models/profile.dart';
import 'package:flclashx/models/shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

const v2boardSessionKey = 'v2board.session.v1';

class V2BoardException implements Exception {
  const V2BoardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class V2BoardSession {
  const V2BoardSession({
    required this.baseUrl,
    required this.token,
    required this.email,
    this.profileId,
    this.subscriptionUrl,
    this.updatedAt,
  });

  factory V2BoardSession.fromJson(Map<String, dynamic> json) => V2BoardSession(
        baseUrl: json['baseUrl']?.toString() ?? '',
        token: json['token']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        profileId: json['profileId']?.toString(),
        subscriptionUrl: json['subscriptionUrl']?.toString(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      );

  final String baseUrl;
  final String token;
  final String email;
  final String? profileId;
  final String? subscriptionUrl;
  final DateTime? updatedAt;

  bool get isValid => baseUrl.isNotEmpty && token.isNotEmpty;

  V2BoardSession copyWith({
    String? baseUrl,
    String? token,
    String? email,
    String? profileId,
    String? subscriptionUrl,
    DateTime? updatedAt,
  }) =>
      V2BoardSession(
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
        email: email ?? this.email,
        profileId: profileId ?? this.profileId,
        subscriptionUrl: subscriptionUrl ?? this.subscriptionUrl,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'token': token,
        'email': email,
        if (profileId != null) 'profileId': profileId,
        if (subscriptionUrl != null) 'subscriptionUrl': subscriptionUrl,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

class V2BoardSessionStore {
  static Future<V2BoardSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(v2boardSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final session = V2BoardSession.fromJson(json);
      return session.isValid ? session : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(V2BoardSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(v2boardSessionKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(v2boardSessionKey);
  }
}

class V2BoardApiConfig {
  const V2BoardApiConfig({
    this.loginPath = '/api/v1/passport/auth/login',
    this.checkLoginPath = '/api/v1/user/checkLogin',
    this.getSubscribePath = '/api/v1/user/getSubscribe',
    this.subscribePath = '/api/v1/client/subscribe',
    this.fetchPlansPath = '/api/v1/user/plan/fetch',
    this.saveOrderPath = '/api/v1/user/order/save',
    this.fetchOrdersPath = '/api/v1/user/order/fetch',
    this.fetchOrderDetailPath = '/api/v1/user/order/detail',
    this.checkoutOrderPath = '/api/v1/user/order/checkout',
    this.checkOrderPath = '/api/v1/user/order/check',
    this.cancelOrderPath = '/api/v1/user/order/cancel',
    this.paymentMethodsPath = '/api/v1/user/order/getPaymentMethod',
    this.checkCouponPath = '/api/v1/user/coupon/check',
    this.userBalancePath = '/api/v1/user/user/info',
  });

  final String loginPath;
  final String checkLoginPath;
  final String getSubscribePath;
  final String subscribePath;
  final String fetchPlansPath;
  final String saveOrderPath;
  final String fetchOrdersPath;
  final String fetchOrderDetailPath;
  final String checkoutOrderPath;
  final String checkOrderPath;
  final String cancelOrderPath;
  final String paymentMethodsPath;
  final String checkCouponPath;
  final String userBalancePath;

  String endpoint(String baseUrl, String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$baseUrl$path';
  }
}

class V2BoardCheckLoginResult {
  const V2BoardCheckLoginResult({
    required this.isLogin,
    this.isAdmin = false,
  });

  final bool isLogin;
  final bool isAdmin;
}

class V2BoardUserInfo {
  const V2BoardUserInfo({
    this.email,
    this.planName,
    this.upload = 0,
    this.download = 0,
    this.transferTotal = 0,
    this.expiredAt = 0,
    this.token,
    this.subscribeUrl,
    this.subscribeUrlEncrypted,
    this.resetDay = 0,
    this.speedLimit = 0,
  });

  factory V2BoardUserInfo.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'];
    final planName = switch (plan) {
      final Map<String, dynamic> value => value['name']?.toString(),
      _ => json['plan_name']?.toString(),
    };

    return V2BoardUserInfo(
      email: json['email']?.toString(),
      planName: planName,
      upload: _readInt(json['u']),
      download: _readInt(json['d']),
      transferTotal: _readInt(json['transfer_enable']),
      expiredAt: _readInt(json['expired_at']),
      token: json['token']?.toString(),
      subscribeUrl:
          (json['subscribe_url'] ?? json['subscribeUrl'] ?? json['url'])
              ?.toString(),
      subscribeUrlEncrypted:
          json['subscribe_url_encrypted']?.toString(),
      resetDay: _readInt(json['reset_day']),
      speedLimit: _readInt(json['speed_limit'] ??
          (plan is Map<String, dynamic> ? plan['speed_limit'] : null)),
    );
  }

  final String? email;
  final String? planName;
  final int upload;
  final int download;
  final int transferTotal;
  final int expiredAt;
  final String? token;
  final String? subscribeUrl;
  final String? subscribeUrlEncrypted;
  final int resetDay;
  final int speedLimit;

  bool get hasSubscriptionInfo =>
      upload > 0 || download > 0 || transferTotal > 0 || expiredAt > 0;

  SubscriptionInfo get subscriptionInfo => SubscriptionInfo(
        upload: upload,
        download: download,
        total: transferTotal,
        expire: expiredAt,
      );

  Map<String, String> providerHeaders(String baseUrl) => {
        'v2board-base-url': baseUrl,
        if (email != null && email!.isNotEmpty) 'v2board-email': email!,
        if (planName != null && planName!.isNotEmpty) ...{
          'v2board-plan-name': planName!,
          'flclashx-servicename': planName!,
        },
        if (subscribeUrlEncrypted != null && subscribeUrlEncrypted!.isNotEmpty)
          'v2board-subscribe-url': subscribeUrlEncrypted!,
        if (resetDay > 0) 'v2board-reset-day': resetDay.toString(),
        if (speedLimit > 0) 'v2board-speed-limit': speedLimit.toString(),
      };

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class V2BoardClient {
  V2BoardClient({
    required String baseUrl,
    String token = '',
    V2BoardApiConfig apiConfig = const V2BoardApiConfig(),
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _token = _rawToken(token),
        _apiConfig = apiConfig,
        _dio = Dio(BaseOptions(
          headers: {
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.userAgentHeader: 'clash-verge/2.0.0',
          },
        ))..interceptors.add(RetryInterceptor());

  final String baseUrl;
  final String _token;
  final V2BoardApiConfig _apiConfig;
  final Dio _dio;

  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _apiConfig.endpoint(baseUrl, _apiConfig.loginPath),
        data: {
          'email': email,
          'password': password,
        },
        options: Options(responseType: ResponseType.json),
      );
      final data = _unwrap(response.data);
      final token =
          data['auth_data']?.toString() ?? data['token']?.toString() ?? '';
      if (token.isEmpty) {
        throw const V2BoardException('V2Board 登录成功，但面板没有返回 token。');
      }
      return token;
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: 'V2Board 登录失败'));
    }
  }

  Future<V2BoardCheckLoginResult> checkLogin() async {
    if (_token.isEmpty) {
      return const V2BoardCheckLoginResult(isLogin: false);
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _apiConfig.endpoint(baseUrl, _apiConfig.checkLoginPath),
        options: Options(
          responseType: ResponseType.json,
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $_token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (_isUnauthorized(response)) {
        return const V2BoardCheckLoginResult(isLogin: false);
      }
      final data = _unwrap(response.data);
      if (!data.containsKey('is_login')) {
        throw const V2BoardException('V2Board checkLogin 返回格式不正确。');
      }
      return V2BoardCheckLoginResult(
        isLogin: _readBool(data['is_login']),
        isAdmin: _readBool(data['is_admin']),
      );
    } on DioException catch (e) {
      throw V2BoardException(
        _formatDioError(e, action: '检查 V2Board 登录状态失败'),
      );
    }
  }

  Future<V2BoardUserInfo> getSubscribe() async {
    try {
      final response = await _getWithAuthFallback(_apiConfig.getSubscribePath);
      return V2BoardUserInfo.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取 V2Board 订阅信息失败'));
    }
  }

  Future<String> subscriptionUrl([V2BoardUserInfo? userInfo]) async {
    try {
      final info = userInfo ?? await getSubscribe();
      final encryptedUrl = info.subscribeUrlEncrypted;
      if (encryptedUrl != null && encryptedUrl.isNotEmpty) {
        return encryptedUrl;
      }

      final token = info.token?.isNotEmpty == true ? info.token! : _token;
      if (token.isEmpty) {
        throw const V2BoardException('V2Board 没有返回可用订阅地址。');
      }
      return Uri.parse(_apiConfig.endpoint(baseUrl, _apiConfig.subscribePath))
          .replace(queryParameters: {'token': token}).toString();
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取 V2Board 订阅地址失败'));
    }
  }

  // --- Shop API ---

  Future<List<ShopPlan>> fetchPlans() async {
    try {
      final response = await _getWithAuthFallback(_apiConfig.fetchPlansPath);
      final list = _unwrapList(response.data);
      return list
          .map((e) => ShopPlan.fromJson((e as Map).cast<String, Object?>()))
          .toList();
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取套餐列表失败'));
    }
  }

  Future<List<ShopOrder>> fetchOrders({int? status}) async {
    try {
      var path = _apiConfig.fetchOrdersPath;
      if (status != null) path = '$path?status=$status';
      final response = await _getWithAuthFallback(path);
      final list = _unwrapList(response.data);
      return list
          .map((e) => ShopOrder.fromJson((e as Map).cast<String, Object?>()))
          .toList();
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取订单列表失败'));
    }
  }

  Future<ShopOrder> fetchOrderDetail(String tradeNo) async {
    try {
      final response = await _getWithAuthFallback(
        '${_apiConfig.fetchOrderDetailPath}?trade_no=$tradeNo',
      );
      return ShopOrder.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取订单详情失败'));
    }
  }

  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    try {
      final response = await _getWithAuthFallback(_apiConfig.paymentMethodsPath);
      final list = _unwrapList(response.data);
      return list
          .map((e) => PaymentMethod.fromJson((e as Map).cast<String, Object?>()))
          .toList();
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取支付方式失败'));
    }
  }

  Future<String> saveOrder({
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    try {
      final response = await _postWithAuth(_apiConfig.saveOrderPath, data: {
        'plan_id': planId,
        'period': period,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      });
      final data = _unwrapData(response.data);
      final tradeNo = data.toString();
      if (tradeNo.isEmpty) {
        throw const V2BoardException('创建订单失败，未返回订单号。');
      }
      return tradeNo;
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '创建订单失败'));
    }
  }

  Future<CheckoutResult> checkoutOrder({
    required String tradeNo,
    required int methodId,
  }) async {
    try {
      final response = await _postWithAuth(_apiConfig.checkoutOrderPath, data: {
        'trade_no': tradeNo,
        'method': methodId,
      });
      return CheckoutResult.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '支付订单失败'));
    }
  }

  Future<int> checkOrderStatus(String tradeNo) async {
    try {
      final response = await _getWithAuthFallback(
        '${_apiConfig.checkOrderPath}?trade_no=$tradeNo',
      );
      final body = response.data;
      if (body == null) return 0;
      final data = body['data'];
      if (data is int) return data;
      return int.tryParse(data?.toString() ?? '') ?? 0;
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '查询订单状态失败'));
    }
  }

  Future<bool> cancelOrder(String tradeNo) async {
    try {
      final response = await _postWithAuth(_apiConfig.cancelOrderPath, data: {
        'trade_no': tradeNo,
      });
      _unwrap(response.data);
      return true;
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '取消订单失败'));
    }
  }

  Future<CouponCheckResult> checkCoupon({
    required String code,
    int? planId,
    String? period,
  }) async {
    try {
      final response = await _postWithAuth(_apiConfig.checkCouponPath, data: {
        'code': code,
        if (planId != null) 'plan_id': planId,
        if (period != null) 'period': period,
      });
      return CouponCheckResult.fromJson(_unwrap(response.data));
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '验证优惠券失败'));
    }
  }

  Future<int> fetchUserBalance() async {
    try {
      final response = await _getWithAuthFallback(_apiConfig.userBalancePath);
      final data = _unwrap(response.data);
      final balance = data['balance'];
      return balance is int ? balance : (balance is num ? balance.toInt() : int.tryParse(balance?.toString() ?? '') ?? 0);
    } on DioException catch (e) {
      throw V2BoardException(_formatDioError(e, action: '获取用户余额失败'));
    }
  }

  Future<Response<Map<String, dynamic>>> _postWithAuth(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    Object? lastError;
    for (final headers in _authHeaders()) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          _apiConfig.endpoint(baseUrl, path),
          data: data,
          options: Options(
            responseType: ResponseType.json,
            headers: headers,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (!_isUnauthorized(response)) {
          return response;
        }
        lastError = DioException.badResponse(
          statusCode: response.statusCode ?? HttpStatus.unauthorized,
          requestOptions: response.requestOptions,
          response: response,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('V2Board request failed.');
  }

  Future<Response<Map<String, dynamic>>> _getWithAuthFallback(
      String path) async {
    Object? lastError;
    for (final headers in _authHeaders()) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          _apiConfig.endpoint(baseUrl, path),
          options: Options(
            responseType: ResponseType.json,
            headers: headers,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (!_isUnauthorized(response)) {
          return response;
        }
        lastError = DioException.badResponse(
          statusCode: response.statusCode ?? HttpStatus.unauthorized,
          requestOptions: response.requestOptions,
          response: response,
        );
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('V2Board request failed.');
  }

  List<Map<String, String>> _authHeaders() {
    if (_token.isEmpty) {
      return const [{}];
    }
    return [
      {HttpHeaders.authorizationHeader: _token},
      {HttpHeaders.authorizationHeader: 'Bearer $_token'},
    ];
  }

  bool _isUnauthorized(Response response) {
    final statusCode = response.statusCode;
    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return true;
    }
    final text = response.data?.toString().toLowerCase() ?? '';
    return text.contains('未登录') ||
        text.contains('过期') ||
        text.contains('unauth');
  }

  static bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const V2BoardException('V2Board 返回了空响应。');
    }
    final status = body['status']?.toString().toLowerCase();
    if (status == 'fail' || status == 'error') {
      throw V2BoardException(
        _extractMessage(body) ?? 'V2Board 请求失败。',
      );
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return body;
  }

  /// Extract data from response, preserving non-Map types (String, int, List, etc.)
  static dynamic _unwrapData(Map<String, dynamic>? body) {
    if (body == null) {
      throw const V2BoardException('V2Board 返回了空响应。');
    }
    final status = body['status']?.toString().toLowerCase();
    if (status == 'fail' || status == 'error') {
      throw V2BoardException(
        _extractMessage(body) ?? 'V2Board 请求失败。',
      );
    }
    return body['data'] ?? body;
  }

  static List<dynamic> _unwrapList(Map<String, dynamic>? body) {
    if (body == null) {
      throw const V2BoardException('V2Board 返回了空响应。');
    }
    final status = body['status']?.toString().toLowerCase();
    if (status == 'fail' || status == 'error') {
      throw V2BoardException(
        _extractMessage(body) ?? 'V2Board 请求失败。',
      );
    }
    final data = body['data'];
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return body.values.whereType<List>().firstOrNull ?? [];
  }

  static String _formatDioError(DioException error, {required String action}) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractMessageFromResponse(error.response?.data);
    final reason = switch (statusCode) {
      HttpStatus.badRequest => '请求参数不正确。',
      HttpStatus.unauthorized => '登录已失效或账号密码不正确。',
      HttpStatus.forbidden => '账号无权限访问该面板接口。',
      HttpStatus.notFound => '面板地址或 API 路径不正确。',
      422 => '面板校验失败，请检查账号密码或请求参数。',
      429 => '请求过于频繁，请稍后重试。',
      HttpStatus.internalServerError => '面板服务器内部错误。',
      HttpStatus.badGateway => '面板网关错误，请检查面板地址或稍后重试。',
      HttpStatus.serviceUnavailable => '面板服务暂不可用，请稍后重试。',
      HttpStatus.gatewayTimeout => '面板网关超时，请稍后重试。',
      _ => switch (error.type) {
          DioExceptionType.connectionTimeout => '连接面板超时。',
          DioExceptionType.sendTimeout => '发送请求超时。',
          DioExceptionType.receiveTimeout => '等待面板响应超时。',
          DioExceptionType.connectionError => '无法连接到面板，请检查网络或面板地址。',
          DioExceptionType.badCertificate => '面板 HTTPS 证书无效。',
          _ => error.message ?? '请求面板失败。',
        },
    };
    final details = serverMessage == null || serverMessage.isEmpty
        ? ''
        : ' 面板返回：$serverMessage';
    final code = statusCode == null ? '' : '（HTTP $statusCode）';
    return '$action$code：$reason$details';
  }

  static String? _extractMessageFromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return _extractMessage(data);
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      return trimmed.length > 200 ? '${trimmed.substring(0, 200)}...' : trimmed;
    }
    return data?.toString();
  }

  static String? _extractMessage(Map<String, dynamic> data) {
    final value = data['message'] ?? data['msg'];
    if (value != null && value.toString().isNotEmpty) {
      return value.toString();
    }
    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      final nestedMessage = _extractMessage(nested);
      if (nestedMessage != null && nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
    }
    final errors = data['errors'];
    if (errors != null && errors.toString().isNotEmpty) {
      return errors.toString();
    }
    return null;
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const V2BoardException('V2Board 面板地址不能为空。');
    }
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }

  static String _rawToken(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
}
