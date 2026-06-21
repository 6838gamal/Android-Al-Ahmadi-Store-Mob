import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../utils/storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  /// Resolved API origin computed once at first instantiation.
  static final String _staticOrigin = _resolveBase();

  /// Build a full image/media URL from a relative path or absolute URL.
  ///
  /// - Already-absolute URLs (http/https) are returned as-is.
  /// - Relative paths like `/api/uploads/image/uuid` or `/uploads/filename`
  ///   are prefixed with the runtime-resolved origin so they work on both
  ///   Replit dev (through the server.js proxy) and production (Render.com).
  static String img(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$_staticOrigin$path';
  }

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
  ///
  /// - Production (Netlify / custom domain): returns AppConstants.baseUrl
  ///   (Render.com API), because the frontend and backend are on different domains.
  /// - Dev on Replit / localhost: returns Uri.base.origin so all /api/* requests
  ///   go through the server.js proxy → localhost:8000.
  /// - Mobile (non-web): always returns AppConstants.baseUrl.
  /// - Override at build time with --dart-define=API_BASE_URL=https://your-api.com
  static const String _fallbackApi = 'https://android-al-ahmadi-store-api.onrender.com';

  static String _resolveBase() {
    const override = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (override.isNotEmpty) return override;

    if (kIsWeb) {
      final host = Uri.base.host;
      // On production domains (Netlify, Render.com hosted frontend, custom domain)
      // the backend is on a different origin — use the full Render.com URL.
      if (host.contains('netlify.app') ||
          host.endsWith('.onrender.com') ||
          host.contains('alahmadi.')) {
        final url = AppConstants.baseUrl;
        return url.isNotEmpty ? url : _fallbackApi;
      }
      // On Replit dev, localhost, or any other dev host, use the current origin.
      // server.js proxies /api/* → localhost:8000 so this routes correctly.
      return Uri.base.origin;
    }

    // Mobile (Android / iOS) — always use direct Render.com URL.
    final url = AppConstants.baseUrl;
    return url.isNotEmpty ? url : _fallbackApi;
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

  /// The API origin (without /api suffix) for direct asset URLs.
  /// Uses the runtime-resolved base (Replit proxy or Render.com) — not AppConstants.baseUrl.
  String get origin => _staticOrigin;
}
