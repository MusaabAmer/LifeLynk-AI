import 'package:dio/dio.dart';

import 'dio_client.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = DioClient.dio;

  static Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
    );
  }

  static Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
  }

  static Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
    );
  }

  static Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
    );
  }
}
