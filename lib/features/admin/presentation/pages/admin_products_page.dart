import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../providers/admin_provider.dart';

class AdminProductsPage extends ConsumerStatefulWidget {
  const AdminProductsPage({super.key});

  @override
  ConsumerState<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends ConsumerState<AdminProductsPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('إدارة المنتجات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () => context.push('/admin/products/add')),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(adminProvider.notifier).loadProducts()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              onChanged: (v) => ref.read(adminProvider.notifier).loadProducts(search: v),
              decoration: InputDecoration(
                hintText: 'بحث في المنتجات...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true, fillColor: AppColors.darkCard,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const LoadingWidget(message: 'جاري التحميل...')
                : state.products.isEmpty
                    ? EmptyState(title: 'لا توجد منتجات', icon: Icons.inventory_2_outlined, actionLabel: 'إضافة منتج', onAction: () => context.push('/admin/products/add'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: state.products.length,
                        itemBuilder: (ctx, i) => _ProductAdminCard(product: state.products[i], index: i),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ProductAdminCard extends ConsumerWidget {
  final Map<String, dynamic> product;
  final int index;
  const _ProductAdminCard({required this.product, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = product['status'] as String? ?? 'available';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56, height: 56,
              child: product['image_url'] != null
                  ? Image.network('${AppConstants.baseUrl}${product['image_url']}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(AppUtils.formatPrice((product['price'] as num?)?.toDouble() ?? 0),
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('ك: ${product['quantity'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                StatusBadge(status: status, isProduct: true),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                onPressed: () => context.push('/admin/products/edit/${product['id']}'),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                onPressed: () => _confirmDelete(context, ref),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _placeholder() => Container(color: AppColors.darkCardAlt, child: const Icon(Icons.phone_android, color: AppColors.textMuted, size: 24));

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المنتج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        content: Text('هل تريد حذف "${product['name']}"؟', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary))),
          TextButton(
            onPressed: () { Navigator.pop(ctx); ref.read(adminProvider.notifier).deleteProduct(product['id']); },
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
