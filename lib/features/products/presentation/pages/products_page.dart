import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shared_filters_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
            ),
            actions: [
              if (!auth.isAuthenticated)
                TextButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                  label: const Text('دخول',
                      style: TextStyle(
                          fontFamily: 'Cairo', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () => _showSearch(context),
              ),
              IconButton(
                icon: const Icon(Icons.tune_outlined, color: Colors.white),
                onPressed: () => _showFilter(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(AppConstants.appName,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('اكتشف أحدث الجوالات وقطع الغيار',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: const Text(AppConstants.appName,
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white)),
          ),
          // Category Chips
          SliverToBoxAdapter(
            child: _CategoryChips(
              selected: _selectedCategory,
              onSelect: (cat) {
                setState(() => _selectedCategory = cat);
                ref.read(selectedProductCategoryProvider.notifier).state = cat;
                ref.read(productsProvider.notifier).load(category: cat);
              },
            ),
          ),
          // Products Grid
          if (state.isLoading)
            const SliverFillRemaining(child: ProductGridShimmer())
          else if (state.error != null)
            SliverFillRemaining(
                child: EmptyState(title: 'حدث خطأ', subtitle: state.error, icon: Icons.error_outline))
          else if (state.products.isEmpty)
            const SliverFillRemaining(
                child: EmptyState(title: 'لا توجد منتجات', icon: Icons.inventory_2_outlined))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ProductCard(product: state.products[i], index: i),
                  childCount: state.products.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('بحث في المنتجات',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              onChanged: (v) => ref.read(productsProvider.notifier).load(search: v),
              decoration: InputDecoration(
                hintText: 'اسم الجهاز، الماركة، الموديل...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.darkSurface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تصفية المنتجات',
                style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            const Text('الحالة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppConstants.productStatusAr.entries
                  .map((e) => FilterChip(
                        label: Text(e.value, style: const TextStyle(fontFamily: 'Cairo')),
                        selected: _selectedStatus == e.key,
                        onSelected: (v) {
                          Navigator.pop(ctx);
                          setState(() => _selectedStatus = v ? e.key : null);
                          ref.read(productsProvider.notifier).load(status: v ? e.key : null);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final String? selected;
  final void Function(String?) onSelect;

  const _CategoryChips({this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(label: 'الكل', selected: selected == null, onTap: () => onSelect(null)),
          ...AppConstants.categoryAr.entries.map((e) => _Chip(
                label: e.value,
                selected: selected == e.key,
                onTap: () => onSelect(selected == e.key ? null : e.key),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.darkBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;

  const _ProductCard({required this.product, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = product['status'] as String? ?? 'available';
    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: product['image_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: ApiClient.img(product['image_url'] as String?),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _loadingPlaceholder(),
                        errorWidget: (_, __, ___) => _noImagePlaceholder(),
                      )
                    : _noImagePlaceholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? '',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product['brand'] != null) ...[
                          const SizedBox(height: 2),
                          Text(product['brand'],
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            AppUtils.formatPrice((product['price'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        StatusBadge(status: status, isProduct: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      color: AppColors.darkCardAlt,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _noImagePlaceholder() {
    return Container(
      color: AppColors.darkCardAlt,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_not_supported_outlined, size: 36, color: AppColors.textMuted),
          SizedBox(height: 6),
          Text(
            'لا تتوفر صورة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
