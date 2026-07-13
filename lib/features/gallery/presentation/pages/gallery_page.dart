import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../screens/presentation/pages/screens_gallery_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/add_product_page.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _galleryCatProvider = StateProvider.autoDispose<String?>((ref) => null);

final _galleryProductsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products', queryParameters: {'limit': 200, 'skip': 0});
    final raw = res.data;
    final List items = raw is List
        ? raw
        : ((raw['items'] ?? raw['products'] ?? raw['results'] ?? []) as List);

    // Expand: each extra image in image_urls becomes its own gallery entry
    final expanded = <Map<String, dynamic>>[];
    for (final p in items) {
      final base = Map<String, dynamic>.from(p as Map);
      final primary = base['image_url'] as String?;
      final extras = (base['image_urls'] as List?)?.cast<String>() ?? [];

      if (_validUrl(primary)) {
        expanded.add(base);
      }
      for (final url in extras) {
        if (_validUrl(url)) {
          expanded.add({...base, 'image_url': url, '_extra_image': true});
        }
      }
    }
    return expanded;
  } catch (_) {
    return [];
  }
});

bool _validUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('http') || url.startsWith('/api/uploads/image/');
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_galleryProductsProvider);
    final selectedCat  = ref.watch(_galleryCatProvider);
    final auth         = ref.watch(authProvider);
    final isStaff      = auth.isStaffOrAbove;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () =>
                  MainShell.scaffoldKey.currentState?.openDrawer(),
            ),
            actions: [
              if (isStaff)
                IconButton(
                  tooltip: 'إضافة منتج جديد',
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primary),
                  onPressed: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddProductPage()),
                    );
                    if (added == true) {
                      ref.invalidate(_galleryProductsProvider);
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => ref.invalidate(_galleryProductsProvider),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7B1FA2), AppColors.primary],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 40),
                        Text(
                          '🖼️ معرض صور المتجر',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'صور المنتجات حسب الفئة والموديل',
                          style: TextStyle(
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

          // ── تبويبات الفئات ───────────────────────────────────────────────
          productsAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (products) {
              final cats = _availableCategories(products);
              if (cats.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverPersistentHeader(
                pinned: true,
                delegate: _CatTabsDelegate(
                  categories: cats,
                  selected: selectedCat,
                  onSelect: (k, context) {
                    if (k == 'screen') {
                      showScreenGradePicker(context, fromGallery: true);
                      return;
                    }
                    ref.read(_galleryCatProvider.notifier).state = k;
                  },
                ),
              );
            },
          ),

          // ── المحتوى ──────────────────────────────────────────────────────
          productsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              child: _EmptyGallery(
                message: 'تعذّر تحميل المعرض',
                onRetry: () => ref.invalidate(_galleryProductsProvider),
              ),
            ),
            data: (products) {
              // تصفية حسب الفئة المحددة
              final filtered = selectedCat == null
                  ? products
                  : products
                      .where((p) => p['category'] == selectedCat)
                      .toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyGallery(
                    message: selectedCat != null
                        ? 'لا توجد صور لهذه الفئة بعد'
                        : 'لا توجد صور في المعرض بعد',
                    onRetry: null,
                  ),
                );
              }

              // تجميع حسب الموديل داخل كل فئة
              final groups = _groupByModel(filtered);

              return SliverMainAxisGroup(
                slivers: [
                  // عدد الصور
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${filtered.length} صورة',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // المجموعات حسب الموديل
                  ...groups.entries.map((entry) {
                    final model = entry.key;
                    final items = entry.value;
                    return SliverMainAxisGroup(
                      slivers: [
                        // عنوان الموديل
                        if (model.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    model,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${items.length})',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // شبكة الصور
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _ImageCard(
                                product: items[i],
                                index: i,
                                onTap: () => _showFullScreen(ctx, items, i),
                              ),
                              childCount: items.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.78,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // كل الفئات دائماً — بغض النظر عن وجود منتجات بها
  List<String> _availableCategories(List<Map<String, dynamic>> products) {
    return AppConstants.categoryAr.keys.toList();
  }

  // تجميع المنتجات حسب الموديل
  Map<String, List<Map<String, dynamic>>> _groupByModel(
      List<Map<String, dynamic>> products) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final p in products) {
      final model = (p['model'] as String?)?.trim() ?? '';
      grouped.putIfAbsent(model, () => []).add(p);
    }
    // الموديلات بدون اسم تأتي أخيراً
    final sorted = Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) {
          if (a.key.isEmpty) return 1;
          if (b.key.isEmpty) return -1;
          return a.key.compareTo(b.key);
        }),
    );
    return sorted;
  }

  void _showFullScreen(BuildContext context,
      List<Map<String, dynamic>> products, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(products: products, initialIndex: index),
      ),
    );
  }
}

// ─── Category Tabs ────────────────────────────────────────────────────────────

class _CatTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final String? selected;
  final void Function(String?, BuildContext) onSelect;

  const _CatTabsDelegate({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  bool shouldRebuild(_CatTabsDelegate old) =>
      old.selected != selected || old.categories.length != categories.length;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.darkBg,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          border: Border(
            bottom: BorderSide(color: Color(0xFF2D3748), width: 1),
          ),
        ),
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          scrollDirection: Axis.horizontal,
          children: [
            _TabChip(
              label: 'الكل',
              isSelected: selected == null,
              onTap: () => onSelect(null, context),
            ),
            ...categories.map((cat) {
              final label = AppConstants.categoryAr[cat] ?? cat;
              return _TabChip(
                label: label,
                isSelected: selected == cat,
                onTap: () => onSelect(selected == cat ? null : cat, context),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFF1C2230),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFF2D3748),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}

// ─── Image Card ───────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final VoidCallback onTap;

  const _ImageCard(
      {required this.product, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url     = product['image_url'] as String? ?? '';
    final fullUrl = ApiClient.img(url);
    final name    = product['name_ar'] as String? ??
                    product['name'] as String? ?? '';
    final model   = product['model'] as String?;
    final cat     = product['category'] as String?;
    final catAr   = cat != null ? (AppConstants.categoryAr[cat] ?? cat) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: fullUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.darkSurface,
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.darkSurface,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: AppColors.textMuted, size: 26),
                        ),
                      ),
                    ),
                    if (catAr != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            catAr,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (model != null && model.isNotEmpty)
                    Text(
                      model,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textMuted,
                          fontSize: 8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: (index % 12) * 35))
        .fadeIn(duration: 280.ms)
        .scale(begin: const Offset(0.93, 0.93));
  }
}

// ─── Full-Screen Viewer ───────────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final int initialIndex;

  const _FullScreenViewer(
      {required this.products, required this.initialIndex});

  @override
  State<_FullScreenViewer> createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<_FullScreenViewer> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p     = widget.products[_current];
    final name  = p['name_ar'] as String? ?? p['name'] as String? ?? '';
    final model = p['model'] as String?;
    final cat   = p['category'] as String?;
    final catAr = cat != null ? (AppConstants.categoryAr[cat] ?? cat) : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isNotEmpty ? name : (catAr ?? ''),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_current + 1} / ${widget.products.length}'
              '${model != null && model.isNotEmpty ? '  •  $model' : ''}',
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.products.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              final prod = widget.products[i];
              final imgUrl  = prod['image_url'] as String? ?? '';
              final fullUrl = ApiClient.img(imgUrl);
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white30, size: 60),
                    ),
                  ),
                ),
              );
            },
          ),
          // شريط المعلومات السفلي
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Builder(builder: (_) {
                final cur   = widget.products[_current];
                final cName = cur['name_ar'] as String? ?? cur['name'] as String? ?? '';
                final cMod  = cur['model'] as String?;
                final cCat  = cur['category'] as String?;
                final cAr   = cCat != null ? (AppConstants.categoryAr[cCat] ?? cCat) : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cName.isNotEmpty)
                      Text(cName,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    if (cMod != null && cMod.isNotEmpty)
                      Text(cMod,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white70,
                              fontSize: 12)),
                    if (cAr != null)
                      Text(cAr,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyGallery extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _EmptyGallery({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              color: AppColors.textMuted, size: 56),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
