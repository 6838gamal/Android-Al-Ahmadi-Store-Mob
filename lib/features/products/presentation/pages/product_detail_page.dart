import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/products_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  final int productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  Map<String, dynamic>? _product;
  bool _loading = true;
  bool _requestingSrestock = false;

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
    final qty = (p['quantity'] as num?)?.toInt() ?? 0;
    final canOrder = status == 'available' && qty > 0;
    final isSoldOut = status == 'sold' || status == 'unavailable' || (status == 'available' && qty == 0);

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
            background: Stack(
              fit: StackFit.expand,
              children: [
                p['image_url'] != null
                    ? GestureDetector(
                        onTap: () => _showImageZoom(context, ApiClient.img(p['image_url'] as String?)),
                        child: Hero(
                          tag: 'product_img_${widget.productId}',
                          child: CachedNetworkImage(
                              imageUrl: ApiClient.img(p['image_url'] as String?),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _imagePlaceholder(),
                              errorWidget: (_, __, ___) => _imagePlaceholder()),
                        ),
                      )
                    : _imagePlaceholder(),
                // Sold-out overlay
                if (isSoldOut)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: status == 'sold' ? Colors.red.shade800 : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          status == 'sold' ? 'تم البيع' : qty == 0 ? 'نفذت الكمية' : 'غير متوفر',
                          style: const TextStyle(
                            fontFamily: 'Cairo', color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
              // Series badge
              if (p['series'] != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                  ),
                  child: Text(
                    p['series'] == 's_series' ? 'فئة S Series' : p['series'] == 'note_series' ? 'فئة Note Series' : p['series'],
                    style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    AppUtils.formatPrice((p['price'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const Spacer(),
                  // Quantity / availability chip
                  _AvailabilityChip(status: status, qty: qty),
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
              _SpecRow(label: 'الفئة', value: AppConstants.categoryAr[p['category']] ?? p['category'] ?? ''),
              if (p['brand'] != null) _SpecRow(label: 'الماركة', value: p['brand']),
              if (p['model'] != null) _SpecRow(label: 'الموديل', value: p['model']),
              const SizedBox(height: 32),
              // Action buttons
              if (canOrder)
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'حجز',
                        isOutlined: true,
                        icon: Icons.bookmark_outline,
                        onPressed: () => _reserve(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'طلب الآن',
                        icon: Icons.shopping_cart_outlined,
                        onPressed: () => context.push('/orders/create'),
                      ),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0)
              else
                _RestockButton(
                  productId: widget.productId,
                  status: status,
                  isRequesting: _requestingSrestock,
                  onRequest: _handleRestockRequest,
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3, end: 0),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRestockRequest() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'يجب تسجيل الدخول أولاً لطلب إعادة التوفير');
      context.push('/login');
      return;
    }
    setState(() => _requestingSrestock = true);
    final msg = await ref.read(productsProvider.notifier).requestRestock(widget.productId);
    if (!mounted) return;
    setState(() => _requestingSrestock = false);
    AppUtils.showSnackBar(
      context,
      msg ?? 'تم إرسال طلب إعادة التوفير',
      isError: msg == null,
    );
  }

  Widget _imagePlaceholder() => Container(
    color: AppColors.darkCardAlt,
    child: const Center(child: Icon(Icons.phone_android, size: 80, color: AppColors.textMuted)),
  );

  void _showImageZoom(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Hero(
                  tag: 'product_img_${widget.productId}',
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => _imagePlaceholder(),
                    errorWidget: (_, __, ___) => _imagePlaceholder(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 44, right: 16,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: const Text('اسحب للتكبير/التصغير',
                    style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reserve(BuildContext context) {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) {
      AppUtils.showSnackBar(context, 'يجب تسجيل الدخول أولاً لحجز المنتج');
      context.push('/login');
      return;
    }
    final p = _product!;
    context.push(
      '/reservations/create',
      extra: {
        'productId': p['id'] as int,
        'productName': p['name'] as String,
        'price': (p['price'] as num?)?.toDouble() ?? 0.0,
      },
    );
  }
}

// ── Availability chip ──────────────────────────────────────────────────────────

class _AvailabilityChip extends StatelessWidget {
  final String status;
  final int qty;
  const _AvailabilityChip({required this.status, required this.qty});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (status == 'available' && qty > 0) {
      bg = AppColors.success.withOpacity(0.15);
      fg = AppColors.success;
      icon = Icons.check_circle_outline;
      label = 'متوفر ($qty)';
    } else if (status == 'available' && qty == 0) {
      bg = Colors.orange.withOpacity(0.15);
      fg = Colors.orange;
      icon = Icons.inventory_2_outlined;
      label = 'نفذت الكمية';
    } else if (status == 'sold') {
      bg = Colors.red.withOpacity(0.15);
      fg = Colors.red;
      icon = Icons.sell_outlined;
      label = 'تم البيع';
    } else if (status == 'reserved') {
      bg = AppColors.info.withOpacity(0.15);
      fg = AppColors.info;
      icon = Icons.bookmark_outlined;
      label = 'محجوز';
    } else {
      bg = AppColors.darkCard;
      fg = AppColors.textMuted;
      icon = Icons.block_outlined;
      label = 'غير متوفر';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: fg.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 15),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'Cairo', color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Restock request button ─────────────────────────────────────────────────────

class _RestockButton extends StatelessWidget {
  final int productId;
  final String status;
  final bool isRequesting;
  final VoidCallback onRequest;

  const _RestockButton({
    required this.productId,
    required this.status,
    required this.isRequesting,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Column(children: [
            Icon(
              status == 'sold' ? Icons.sell_outlined : Icons.inventory_2_outlined,
              color: Colors.orange, size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              status == 'sold' ? 'هذا المنتج تم بيعه' : 'هذا المنتج غير متوفر حالياً',
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'يمكنك طلب إعادة توفيره وسيتم إشعارك عند توفّره',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isRequesting ? null : onRequest,
            icon: isRequesting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.notifications_active_outlined, size: 20),
            label: Text(
              isRequesting ? 'جارٍ الإرسال...' : 'طلب إعادة التوفير',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Spec row ───────────────────────────────────────────────────────────────────

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
