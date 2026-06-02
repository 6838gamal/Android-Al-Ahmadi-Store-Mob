import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

const _cacheKey = 'cache_announcements_v1';

class AnnouncementsState {
  final List<Map<String, dynamic>> announcements;
  final bool isLoading;
  final String? error;

  const AnnouncementsState({
    this.announcements = const [],
    this.isLoading = false,
    this.error,
  });

  AnnouncementsState copyWith({
    List<Map<String, dynamic>>? announcements,
    bool? isLoading,
    String? error,
  }) =>
      AnnouncementsState(
        announcements: announcements ?? this.announcements,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AnnouncementsNotifier extends StateNotifier<AnnouncementsState> {
  final ApiClient _api;
  AnnouncementsNotifier(this._api) : super(const AnnouncementsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    final cached = await _loadCache();
    if (cached.isNotEmpty) {
      state = state.copyWith(announcements: cached);
    }
    try {
      final res = await _api.get('/announcements/', params: {'active_only': 'true'});
      final list = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(announcements: list, isLoading: false, error: null);
      await _saveCache(list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.announcements.isEmpty ? 'فشل تحميل الإعلانات' : null,
      );
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

final announcementsProvider =
    StateNotifierProvider<AnnouncementsNotifier, AnnouncementsState>((ref) {
  return AnnouncementsNotifier(ref.read(apiClientProvider));
});
