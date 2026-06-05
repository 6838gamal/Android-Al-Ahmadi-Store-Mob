import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  ApiClient() {
    // On web, use relative origin so the proxied Replit server routes correctly.
    // On native (mobile), fall back to the configured base URL.
    final String base = kIsWeb
        ? Uri.base.origin
        : AppConstants.baseUrl;

    _dio = Dio(BaseOptions(
      baseUrl: '$base${AppConstants.apiVersion}',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              // Retry original request with new token
              final token = await StorageService.getToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              final resp = await _dio.fetch(opts);
              _isRefreshing = false;
              return handler.resolve(resp);
            }
          } catch (_) {}
          _isRefreshing = false;
          await StorageService.clearToken();
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final resp = await Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      )).post('/auth/refresh', data: {'refresh_token': refreshToken});
      final newAccess = resp.data['access_token'] as String?;
      final newRefresh = resp.data['refresh_token'] as String?;
      if (newAccess != null) {
        await StorageService.saveToken(newAccess);
        if (newRefresh != null) {
          await StorageService.saveRefreshToken(newRefresh);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Response> get(String path,
          {Map<String, dynamic>? params,
          Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters ?? params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> postForm(String path, FormData data) => _dio.post(path,
      data: data, options: Options(contentType: 'multipart/form-data'));
}
