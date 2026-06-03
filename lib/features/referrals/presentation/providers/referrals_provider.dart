import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/device_service.dart';

class ReferralsState {
  final Map<String, dynamic>? stats;
  final List<Map<String, dynamic>> referredList;
  final bool isLoading;
  final bool isLoadingList;
  final String? error;
  final bool claimed;

  const ReferralsState({
    this.stats,
    this.referredList = const [],
    this.isLoading = false,
    this.isLoadingList = false,
    this.error,
    this.claimed = false,
  });

  ReferralsState copyWith({
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? referredList,
    bool? isLoading,
    bool? isLoadingList,
    String? error,
    bool? claimed,
  }) =>
      ReferralsState(
        stats: stats ?? this.stats,
        referredList: referredList ?? this.referredList,
        isLoading: isLoading ?? this.isLoading,
        isLoadingList: isLoadingList ?? this.isLoadingList,
        error: error,
        claimed: claimed ?? this.claimed,
      );
}

class ReferralsNotifier extends StateNotifier<ReferralsState> {
  final ApiClient _api;
  ReferralsNotifier(this._api) : super(const ReferralsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get('/referrals/my-stats');
      state = state.copyWith(
        stats: Map<String, dynamic>.from(res.data),
        isLoading: false,
      );
      // Also load the referred users list
      loadList();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل بيانات الإحالة');
    }
  }

  Future<void> loadList() async {
    state = state.copyWith(isLoadingList: true);
    try {
      final res = await _api.get('/referrals/my-list');
      final list = List<Map<String, dynamic>>.from(
          (res.data as List).map((e) => Map<String, dynamic>.from(e)));
      state = state.copyWith(referredList: list, isLoadingList: false);
    } catch (_) {
      state = state.copyWith(isLoadingList: false);
    }
  }

  /// Register a referral code use with anti-fraud device fingerprint
  Future<String?> applyReferralCode(String code) async {
    try {
      final fingerprint = await DeviceService.getFingerprint();
      final res = await _api.post('/referrals/apply', data: {
        'code': code.toUpperCase().trim(),
        'device_fingerprint': fingerprint,
      });
      state = state.copyWith(claimed: true);
      return null; // success
    } catch (e) {
      final msg = e.toString().contains('already') ||
              e.toString().contains('سبق')
          ? 'تم استخدام هذا الكود مسبقاً'
          : 'فشل تطبيق كود الإحالة';
      return msg;
    }
  }
}

final referralsProvider =
    StateNotifierProvider<ReferralsNotifier, ReferralsState>((ref) {
  return ReferralsNotifier(ref.read(apiClientProvider));
});
