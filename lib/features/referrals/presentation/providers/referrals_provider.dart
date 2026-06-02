import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/device_service.dart';

class ReferralsState {
  final Map<String, dynamic>? stats;
  final bool isLoading;
  final String? error;
  final bool claimed;

  const ReferralsState({
    this.stats,
    this.isLoading = false,
    this.error,
    this.claimed = false,
  });

  ReferralsState copyWith({
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
    bool? claimed,
  }) =>
      ReferralsState(
        stats: stats ?? this.stats,
        isLoading: isLoading ?? this.isLoading,
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل بيانات الإحالة');
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
