import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

const _cacheKey = 'cache_inspections_v1';

class InspectionState {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  const InspectionState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
    this.isSubmitting = false,
  });

  InspectionState copyWith({
    List<Map<String, dynamic>>? requests,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) =>
      InspectionState(
        requests: requests ?? this.requests,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

class InspectionNotifier extends StateNotifier<InspectionState> {
  final ApiClient _api;
  InspectionNotifier(this._api) : super(const InspectionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final cached = await _loadCache();
    if (cached.isNotEmpty) {
      state = state.copyWith(requests: cached);
    }
    try {
      final res = await _api.get('/inspection/my');
      final list = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(requests: list, isLoading: false, error: null);
      await _saveCache(list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.requests.isEmpty ? 'فشل تحميل طلبات الفحص' : null,
      );
    }
  }

  Future<bool> submit({
    required String customerName,
    required String customerPhone,
    required String deviceModel,
    required String problemDescription,
    List<XFile>? images,
    XFile? video,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      // Upload images (best-effort — failures don't block submission)
      final List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (final img in images) {
          try {
            final bytes = await img.readAsBytes();
            final contentType = _guessContentType(img.name);
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(bytes,
                  filename: img.name,
                  contentType: DioMediaType.parse(contentType)),
            });
            final uploadRes = await _api.postForm('/uploads/media', formData);
            final url = uploadRes.data['url'] as String?;
            if (url != null) imageUrls.add(url);
          } catch (_) {}
        }
      }

      // Upload video (best-effort)
      String? videoUrl;
      if (video != null) {
        try {
          final bytes = await video.readAsBytes();
          final contentType = _guessContentType(video.name);
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes,
                filename: video.name,
                contentType: DioMediaType.parse(contentType)),
          });
          final uploadRes = await _api.postForm('/uploads/media', formData);
          videoUrl = uploadRes.data['url'] as String?;
        } catch (_) {}
      }

      await _api.post('/inspection/', data: {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'device_model': deviceModel,
        'problem_description': problemDescription,
        'images': imageUrls,
        if (videoUrl != null) 'video_url': videoUrl,
      });
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'فشل إرسال طلب الفحص');
      return false;
    }
  }

  static String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  static Future<List<Map<String, dynamic>>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCache(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (_) {}
  }
}

final inspectionProvider =
    StateNotifierProvider<InspectionNotifier, InspectionState>((ref) {
  return InspectionNotifier(ref.read(apiClientProvider));
});
