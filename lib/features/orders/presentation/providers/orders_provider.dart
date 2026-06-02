import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

const _ordersCacheKey = 'cache_orders_v1';

class OrdersState {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;
  final bool fromCache;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.fromCache = false,
  });

  OrdersState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
    String? error,
    bool? fromCache,
  }) =>
      OrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        fromCache: fromCache ?? this.fromCache,
      );
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  final ApiClient _api;
  OrdersNotifier(this._api) : super(const OrdersState());

  Future<void> loadMyOrders(String phone) async {
    state = state.copyWith(isLoading: true);

    // Show cached orders instantly
    final cached = await _loadCache(phone);
    if (cached.isNotEmpty) {
      state = state.copyWith(orders: cached, fromCache: true);
    }

    try {
      final res = await _api.get('/orders/my/$phone');
      final list = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(orders: list, isLoading: false, fromCache: false, error: null);
      await _saveCache(phone, list);
    } catch (_) {
      if (state.orders.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: 'تعذّر الاتصال — يعرض بيانات محفوظة');
      } else {
        state = state.copyWith(isLoading: false, error: 'فشل تحميل الطلبات');
      }
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

  static Future<List<Map<String, dynamic>>> _loadCache(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_ordersCacheKey}_$phone');
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCache(
      String phone, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_ordersCacheKey}_$phone', jsonEncode(data));
    } catch (_) {}
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(ref.read(apiClientProvider));
});
