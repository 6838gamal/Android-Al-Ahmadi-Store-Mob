import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  ApiClient() {
    // Always use the configured base URL (Render.com API).
    // Never use Uri.base.origin — on Netlify/APK that resolves to the wrong
    // host (the frontend domain) and breaks every request.
    final String base = _resolveBase();

    _dio = Dio(BaseOptions(
      baseUrl: '$base${AppConstants.apiVersion}',
      connectTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {'Content-Type': 'application/json'},
    ));

    // ── Debug logging interceptor ──────────────────────────────────────────
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        logPrint: (obj) => print('[API] $obj'),
      ));
    }

    // ── Auth + 401 refresh interceptor ─────────────────────────────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await StorageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          print('[API] → ${options.method} ${options.uri}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          print('[API] ← ${response.statusCode} ${response.requestOptions.uri}');
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          print('[API] ✗ ${error.response?.statusCode} '
              '${error.requestOptions.uri} — ${error.message}');
          if (error.response?.data != null) {
            print('[API] ✗ body: ${error.response?.data}');
          }
        }
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          _isRefreshing = true;
          try {
            final refreshed = await _tryRefresh();
            if (refreshed) {
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

  /// Resolve the correct base URL.
  /// On web: use the same origin as the page so the server.js proxy
  /// routes /api/* to the local backend (works on Replit and self-hosted).
  /// A compile-time --dart-define=API_BASE_URL=... override takes priority.
  /// On mobile: always use the configured AppConstants.baseUrl.
  static String _resolveBase() {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return Uri.base.origin;
    return AppConstants.baseUrl;
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

  /// Expose the configured base API URL (used for image URL construction etc.)
  String get baseUrl => _dio.options.baseUrl;

  /// The API origin (without /api suffix) for direct asset URLs
  String get origin => AppConstants.baseUrl;
}
