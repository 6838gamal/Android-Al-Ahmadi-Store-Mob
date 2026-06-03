import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';

const _cacheKey = 'cache_products_v1';

class ProductsState {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;
  final bool fromCache;

  const ProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.fromCache = false,
  });

  ProductsState copyWith({
    List<Map<String, dynamic>>? products,
    bool? isLoading,
    String? error,
    bool? fromCache,
  }) =>
      ProductsState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        fromCache: fromCache ?? this.fromCache,
      );
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  final ApiClient _api;
  ProductsNotifier(this._api) : super(const ProductsState());

  Future<void> load({String? search, String? category, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    final isUnfiltered = search == null && category == null && status == null;

    // Show cached data instantly while fetching
    if (isUnfiltered) {
      final cached = await _loadCache();
      if (cached.isNotEmpty) {
        state = state.copyWith(products: cached, fromCache: true);
      }
    }

    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (category != null) params['category'] = category;
      if (status != null) params['status'] = status;
      final res = await _api.get('/products', params: params);
      final list = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(products: list, isLoading: false, fromCache: false, error: null);
      if (isUnfiltered) await _saveCache(list);
    } catch (e) {
      if (state.products.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: 'تعذّر الاتصال — يعرض بيانات محفوظة');
      } else {
        state = state.copyWith(isLoading: false, error: 'فشل تحميل المنتجات');
      }
    }
  }

  Future<Map<String, dynamic>?> getProduct(int id) async {
    try {
      final res = await _api.get('/products/$id');
      return Map<String, dynamic>.from(res.data);
    } catch (_) {
      return null;
    }
  }

  Future<String?> requestRestock(int productId) async {
    try {
      final res = await _api.post('/products/$productId/restock-request');
      return res.data['message'] as String?;
    } catch (e) {
      return null;
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

final productsProvider =
    StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier(ref.read(apiClientProvider));
});
