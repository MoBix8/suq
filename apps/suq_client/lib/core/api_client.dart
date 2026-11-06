import 'dart:async';

import 'package:dio/dio.dart';
import 'config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 60),
            headers: const {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;
  String? _token;

  void setToken(String? token) {
    _token = token;
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  String? get token => _token;

  /// The server mounts every route under `/api`. Callers use short paths such
  /// as `/auth/login`, so normalise them here.
  String _path(String path) =>
      path.startsWith('/api/') || path == '/api' ? path : '/api$path';

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        _path(path),
        queryParameters: query,
        options: timeout == null ? null : Options(receiveTimeout: timeout),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        _path(path),
        data: body,
        options: timeout == null ? null : Options(receiveTimeout: timeout),
      );
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    try {
      final response = await _dio.patch<dynamic>(_path(path), data: body);
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final response = await _dio.delete<dynamic>(_path(path));
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{'data': data};
  }

  ApiException _toApiException(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? message;
    if (data is Map && data['error'] is String) {
      message = data['error'] as String;
    }
    if (message == null) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          message = 'Cannot reach the SUQ server. Check your internet connection.';
          break;
        case DioExceptionType.badResponse:
          message = status == 401
              ? 'Your session expired. Please log in again.'
              : 'The server rejected this request.';
          break;
        default:
          message = 'Something went wrong. Please try again.';
      }
    }
    return ApiException(message, statusCode: status);
  }
}

/// Fire-and-forget helper for sync calls after a sale.
void background(Future<void> future) {
  unawaited(future.catchError((_) {}));
}
