import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/products_provider.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final int productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final product = await ref.read(productsProvider.notifier).getProduct(widget.productId);
    if (mounted) setState(() { _product = product; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: _loading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : _product == null
              ? const EmptyState(title: 'المنتج غير موجود', icon: Icons.error_outline)
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final p = _product!;
    final status = p['status'] as String? ?? 'available';
    final canOrder = status == 'available';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.darkSurface,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => context.pop()),
          actions: [
            IconButton(icon: const Icon(Icons.favorite_border, color: Colors.white), onPressed: () {}),
            IconButton(icon: const Icon(Icons.share_outlined, color: Colors.white), onPressed: () {}),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: p['image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: '${AppConstants.baseUrl}${p['image_url']}',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _imagePlaceholder(),
                    errorWidget: (_, __, ___) => _imagePlaceholder())
                : _imagePlaceholder(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(p['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  StatusBadge(status: status, isProduct: true),
                ],
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              if (p['brand'] != null)
                Text('${p['brand']} ${p['model'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    AppUtils.formatPrice((p['price'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.darkBorder)),
                    child: Text('المتوفر: ${p['quantity'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.darkDivider),
              const SizedBox(height: 16),
              if (p['description'] != null) ...[
                const Text('الوصف', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(p['description'], style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, height: 1.7)),
                const SizedBox(height: 20),
              ],
              // Specs
              _SpecRow(label: 'الفئة', value: AppConstants.categoryAr[p['category']] ?? p['category'] ?? ''),
              if (p['brand'] != null) _SpecRow(label: 'الماركة', value: p['brand']),
              if (p['model'] != null) _SpecRow(label: 'الموديل', value: p['model']),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: 'حجز',
                      isOutlined: true,
                      icon: Icons.bookmark_outline,
                      onPressed: canOrder ? () => _reserve(context) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: 'طلب الآن',
                      icon: Icons.shopping_cart_outlined,
                      onPressed: canOrder ? () => context.push('/orders/create') : null,
                    ),
                  ),
                ],
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
    color: AppColors.darkCardAlt,
    child: const Center(child: Icon(Icons.phone_android, size: 80, color: AppColors.textMuted)),
  );

  void _reserve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم إضافة الحجز قريباً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.primary),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13))),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
