import 'package:flutter_riverpod/flutter_riverpod.dart';

/// الفئة المختارة حالياً من شاشة المنتجات — مشتركة بين المنتجات والمعرض
final selectedProductCategoryProvider = StateProvider<String?>((ref) => null);
