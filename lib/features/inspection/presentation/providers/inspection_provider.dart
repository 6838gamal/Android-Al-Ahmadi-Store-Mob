import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _api.post('/inspection/', data: {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'device_model': deviceModel,
        'problem_description': problemDescription,
        'images': [],
      });
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'فشل إرسال طلب الفحص');
      return false;
    }
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
