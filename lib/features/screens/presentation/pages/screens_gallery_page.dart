import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/status_badge.dart';

// ── Grade definitions ──────────────────────────────────────────────────────────

class ScreenGrade {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  final String description;

  const ScreenGrade({
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
  });
}

const _grades = [
  ScreenGrade(
    key: 'white',
    label: 'أبيض',
    color: Color(0xFFE5E7EB),
    icon: Icons.diamond_outlined,
    description: 'شاشات أصلية عالية الجودة',
  ),
  ScreenGrade(
    key: 'green',
    label: 'أخضر',
    color: Color(0xFF10B981),
    icon: Icons.verified_outlined,
    description: 'شاشات جيدة متوسطة الجودة',
  ),
  ScreenGrade(
    key: 'orange',
    label: 'برتقالي',
    color: Color(0xFFF97316),
    icon: Icons.layers_outlined,
    description: 'شاشات اقتصادية بديلة',
  ),
];

// ── Provider ───────────────────────────────────────────────────────────────────

final _screensGalleryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, grade) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products', queryParameters: {
      'limit': 200,
      'skip': 0,
      'category': 'screen',
      'series': grade,
    });
    final raw = res.data;
    final List items = raw is List
        ? raw
        : ((raw['items'] ?? raw['products'] ?? raw['results'] ?? []) as List);
    return items.map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p as Map)).toList();
  } catch (_) {
    return [];
  }
});

// ── Grade Picker Sheet ─────────────────────────────────────────────────────────

void showScreenGradePicker(BuildContext context, {bool fromGallery = false}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '🖥️ فئات الشاشات',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'اختر فئة الشاشة لعرض معرض الصور',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ..._grades.map((g) => _GradeCard(grade: g, ctx: ctx)),
        ],
      ),
    ),
  );
}

class _GradeCard extends StatelessWidget {
  final ScreenGrade grade;
  final BuildContext ctx;
  const _GradeCard({required this.grade, required this.ctx});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScreensGalleryPage(grade: grade),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: grade.color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: grade.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(grade.icon, color: grade.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(grade.label,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: grade.color)),
                  Text(grade.description,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: grade.color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

// ── Main Gallery Page ──────────────────────────────────────────────────────────

class ScreensGalleryPage extends ConsumerWidget {
  final ScreenGrade grade;
  const ScreensGalleryPage({super.key, required this.grade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_screensGalleryProvider(grade.key));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref.invalidate(_screensGalleryProvider(grade.key)),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [grade.color.withOpacity(0.8), AppColors.darkSurface],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Icon(grade.icon, color: grade.color, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'شاشات ${grade.label}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          grade.description,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          productsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (_, __) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    const Text('تعذّر تحميل الشاشات',
                        style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.invalidate(_screensGalleryProvider(grade.key)),
                      child: const Text('إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
            ),
            data: (products) {
              if (products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(grade.icon, color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 14),
                        Text(
                          'لا توجد شاشات ${grade.label} بعد',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        children: [
                          Icon(Icons.phone_android, color: grade.color, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${products.length} شاشة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textMuted,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ScreenCard(
                          product: products[i],
                          grade: grade,
                          index: i,
                        ),
                        childCount: products.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.65,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Screen Card (navigates to ProductDetailPage) ──────────────────────────────

class _ScreenCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final ScreenGrade grade;
  final int index;

  const _ScreenCard({required this.product, required this.grade, required this.index});

  @override
  Widget build(BuildContext context) {
    final imgUrl = ApiClient.img(product['image_url'] as String?);
    final name = product['name_ar'] as String? ?? product['name'] as String? ?? '';
    final model = product['model'] as String? ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0.0;
    final status = product['status'] as String? ?? 'available';

    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: grade.color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product['image_url'] != null
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.darkSurface,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _noImg(),
                          )
                        : _noImg(),
                    // Grade badge
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: grade.color.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(grade.label,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: grade.key == 'white' ? Colors.black87 : Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (model.isNotEmpty)
                          Text(model,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            AppUtils.formatPrice(price),
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: grade.color),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(status: status, isProduct: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: index * 45))
          .fadeIn(duration: 280.ms)
          .scale(begin: const Offset(0.94, 0.94)),
    );
  }

  Widget _noImg() => Container(
        color: AppColors.darkSurface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 36, color: grade.color.withOpacity(0.4)),
            const SizedBox(height: 4),
            const Text('لا تتوفر صورة',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      );
}
