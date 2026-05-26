import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class AdminState {
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> maintenanceOrders;
  final List<Map<String, dynamic>> reservations;
  final List<Map<String, dynamic>> customers;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.stats = const {},
    this.recentOrders = const [],
    this.orders = const [],
    this.products = const [],
    this.maintenanceOrders = const [],
    this.reservations = const [],
    this.customers = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? recentOrders,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? products,
    List<Map<String, dynamic>>? maintenanceOrders,
    List<Map<String, dynamic>>? reservations,
    List<Map<String, dynamic>>? customers,
    bool? isLoading,
    String? error,
  }) => AdminState(
    stats: stats ?? this.stats,
    recentOrders: recentOrders ?? this.recentOrders,
    orders: orders ?? this.orders,
    products: products ?? this.products,
    maintenanceOrders: maintenanceOrders ?? this.maintenanceOrders,
    reservations: reservations ?? this.reservations,
    customers: customers ?? this.customers,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class AdminNotifier extends StateNotifier<AdminState> {
  final ApiClient _api;
  AdminNotifier(this._api) : super(const AdminState());

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('/dashboard/stats');
      final data = Map<String, dynamic>.from(res.data);
      final recent = List<Map<String, dynamic>>.from(data['recent_orders'] ?? []);
      data.remove('recent_orders');
      state = state.copyWith(stats: data, recentOrders: recent, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل الإحصائيات');
    }
  }

  Future<void> loadOrders({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      final res = await _api.get('/orders', params: params);
      state = state.copyWith(orders: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadProducts({String? search, String? category}) async {
    state = state.copyWith(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (category != null) params['category'] = category;
      final res = await _api.get('/products', params: params);
      state = state.copyWith(products: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMaintenance() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('/maintenance');
      state = state.copyWith(maintenanceOrders: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadReservations() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('/reservations');
      state = state.copyWith(reservations: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.get('/customers');
      state = state.copyWith(customers: List<Map<String, dynamic>>.from(res.data), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> updateOrderStatus(int orderId, String status, {String? note, String? employeeName}) async {
    try {
      await _api.put('/orders/$orderId/status', data: {
        'status': status,
        if (note != null) 'note': note,
        if (employeeName != null) 'employee_name': employeeName,
      });
      await loadOrders();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await _api.delete('/products/$id');
      await loadProducts();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createProduct(Map<String, dynamic> data) async {
    try {
      await _api.post('/products', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
    try {
      await _api.put('/products/$id', data: data);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref.read(apiClientProvider));
});
