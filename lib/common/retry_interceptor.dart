import 'dart:io';

import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    this.maxRetries = 3,
    this.delay = const Duration(seconds: 1),
  });

  final int maxRetries;
  final Duration delay;

  static const _retryKey = 'retry_count';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount = err.requestOptions.extra[_retryKey] as int? ?? 0;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    err.requestOptions.extra[_retryKey] = retryCount + 1;

    final wait = delay * (1 << retryCount);
    await Future<void>.delayed(wait);

    try {
      final dio = Dio();
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError ||
      (err.error is SocketException);
}
