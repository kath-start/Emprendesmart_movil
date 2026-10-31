import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  /// Se dispara si el refresh también falla (sesión realmente vencida).
  void Function()? onSessionExpired;

  Future<String>? _refreshFuture;

  ApiClient({required this.tokenStorage})
    : dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isRefreshCall = error.requestOptions.path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 && !alreadyRetried && !isRefreshCall) {
            try {
              final newAccessToken = await _refreshAccessToken();
              final retryOptions = error.requestOptions..extra['retried'] = true;
              retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (_) {
              await tokenStorage.clear();
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<String> _refreshAccessToken() {
    return _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<String> _doRefresh() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw ApiException('Sesión expirada');
    }

    final refreshDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
    final response = await refreshDio.post('/app/auth/refresh', data: {'refreshToken': refreshToken});
    final data = response.data['data'] as Map<String, dynamic>;
    final newAccessToken = data['accessToken'] as String;
    final newRefreshToken = data['refreshToken'] as String;

    await tokenStorage.saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);
    return newAccessToken;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _unwrap(dio.get(path, queryParameters: query));

  /// [receiveTimeout] alarga la espera para peticiones lentas (p. ej. las que llaman a la IA).
  Future<Map<String, dynamic>> post(String path, {Object? data, Duration? receiveTimeout}) => _unwrap(
    dio.post(path, data: data, options: receiveTimeout == null ? null : Options(receiveTimeout: receiveTimeout)),
  );

  /// Envía bytes crudos (ej. una imagen) con su Content-Type.
  Future<Map<String, dynamic>> postBytes(String path, Uint8List bytes, {required String contentType}) => _unwrap(
    dio.post(
      path,
      data: bytes,
      options: Options(contentType: contentType),
    ),
  );

  Future<Map<String, dynamic>> patch(String path, {Object? data}) => _unwrap(dio.patch(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _unwrap(dio.delete(path));

  Future<Map<String, dynamic>> _unwrap(Future<Response> request) async {
    try {
      final response = await request;
      return response.data as Map<String, dynamic>;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] as String? ?? 'Ocurrió un error inesperado';
      final rawDetails = data['details'];
      final details = rawDetails is List ? rawDetails.cast<Map<String, dynamic>>() : null;
      return ApiException(message, details: details);
    }
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.connectionError) {
      return ApiException('No se pudo conectar con el servidor');
    }
    return ApiException('Ocurrió un error inesperado');
  }
}
