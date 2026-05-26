import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class OrdersState {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;

  const OrdersState({this.orders = const [], this.isLoading = false, this.error});

  OrdersState copyWith({List<Map<String, dynamic>>? orders, bool? isLoading, String? error}) =>
      OrdersState(orders: orders ?? this.orders, isLoading: isLoading ?? this.isLoading, error: error);
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiClient _api;
  OrdersNotifier(this._api) : super(const OrdersState());

  Future<void> loadMyOrders(String phone) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('/orders/my/$phone');
      state = state.copyWith(orders: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل الطلبات');
    }
  }

  Future<Map<String, dynamic>?> trackOrder(String orderNumber) async {
    try {
      final res = await _api.get('/orders/track/$orderNumber');
      return Map<String, dynamic>.from(res.data);
    } catch (_) {
      return null;
    }
  }

  Future<bool> createOrder(Map<String, dynamic> data) async {
    try {
      await _api.post('/orders', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref.read(apiClientProvider));
});
