import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/session_storage.dart';

/// Pembungkus Dio: base URL, timeout, dan penyisipan token otomatis.
class ApiClient {
  ApiClient(SessionStorage storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConstants.baseUrl,
            connectTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.receiveTimeout,
            headers: {'Accept': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response<dynamic>> post(String path, {Object? body}) =>
      _dio.post(path, data: body);

  Future<Response<dynamic>> put(String path, {Object? body}) =>
      _dio.put(path, data: body);

  Future<Response<dynamic>> delete(String path) => _dio.delete(path);
}
