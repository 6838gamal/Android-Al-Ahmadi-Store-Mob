import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class ProductsState {
  final List<Map<String, dynamic>> products;
  final bool isLoading;
  final String? error;

  const ProductsState({this.products = const [], this.isLoading = false, this.error});

  ProductsState copyWith({List<Map<String, dynamic>>? products, bool? isLoading, String? error}) =>
      ProductsState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ProductsNotifier extends StateNotifier<ProductsState> {
  final ApiClient _api;
  ProductsNotifier(this._api) : super(const ProductsState());

  Future<void> load({String? search, String? category, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final params = <String, dynamic>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (category != null) params['category'] = category;
      if (status != null) params['status'] = status;
      final res = await _api.get('/products', params: params);
      state = state.copyWith(
        products: List<Map<String, dynamic>>.from(res.data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'فشل تحميل المنتجات');
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
}

final productsProvider = StateNotifierProvider<ProductsNotifier, ProductsState>((ref) {
  return ProductsNotifier(ref.read(apiClientProvider));
});
