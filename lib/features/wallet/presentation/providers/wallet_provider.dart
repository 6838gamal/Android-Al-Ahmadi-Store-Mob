import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class WalletState {
  final double balance;
  final String currency;
  final List<Map<String, dynamic>> transactions;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.balance = 0.0,
    this.currency = 'YER',
    this.transactions = const [],
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    double? balance,
    String? currency,
    List<Map<String, dynamic>>? transactions,
    bool? isLoading,
    String? error,
  }) =>
      WalletState(
        balance: balance ?? this.balance,
        currency: currency ?? this.currency,
        transactions: transactions ?? this.transactions,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiClient _api;
  WalletNotifier(this._api) : super(const WalletState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get('/wallet/my');
      final data = Map<String, dynamic>.from(res.data);
      state = state.copyWith(
        balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
        currency: data['currency'] as String? ?? 'YER',
        transactions: List<Map<String, dynamic>>.from(data['transactions'] ?? []),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل بيانات المحفظة');
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.read(apiClientProvider));
});
