import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class WarrantyState {
  final List<Map<String, dynamic>> warranties;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  const WarrantyState({
    this.warranties = const [],
    this.isLoading = false,
    this.error,
    this.isSubmitting = false,
  });

  WarrantyState copyWith({
    List<Map<String, dynamic>>? warranties,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) =>
      WarrantyState(
        warranties: warranties ?? this.warranties,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

class WarrantyNotifier extends StateNotifier<WarrantyState> {
  final ApiClient _api;
  WarrantyNotifier(this._api) : super(const WarrantyState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get('/warranty/my');
      state = state.copyWith(
        warranties: List<Map<String, dynamic>>.from(res.data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل بيانات الضمان');
    }
  }

  Future<bool> requestReturn({
    required int warrantyId,
    required String reason,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _api.post('/warranty/$warrantyId/request-return', data: {'return_reason': reason});
      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'فشل تقديم طلب الإرجاع');
      return false;
    }
  }
}

final warrantyProvider = StateNotifierProvider<WarrantyNotifier, WarrantyState>((ref) {
  return WarrantyNotifier(ref.read(apiClientProvider));
});
