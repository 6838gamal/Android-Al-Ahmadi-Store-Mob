import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';

// ─── Data & Provider ──────────────────────────────────────────────────────────

final _galleryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products/', queryParameters: {'limit': '200'});
    final all = List<Map<String, dynamic>>.from(res.data);
    return all.where((p) {
      final url = p['image_url'] as String?;
      return url != null && url.isNotEmpty;
    }).toList();
  } catch (_) {
    return [];
  }
});

// ─── Category Model ───────────────────────────────────────────────────────────

class _Category {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _Category({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const _kCategories = [
  _Category(key: 'all',        label: 'الكل',        icon: Icons.apps_rounded,          color: AppColors.primary),
  _Category(key: 'screen',     label: 'شاشات',       icon: Icons.phone_android,          color: Color(0xFF42A5F5)),
  _Category(key: 'battery',    label: 'بطاريات',     icon: Icons.battery_charging_full,  color: Color(0xFF66BB6A)),
  _Category(key: 'device',     label: 'أجهزة',       icon: Icons.devices,                color: Color(0xFFAB47BC)),
  _Category(key: 'camera',     label: 'كاميرات',     icon: Icons.camera_alt_outlined,    color: Color(0xFFEF5350)),
  _Category(key: 'speaker',    label: 'سماعات',      icon: Icons.speaker_outlined,       color: Color(0xFF26C6DA)),
  _Category(key: 'charger',    label: 'شواحن',       icon: Icons.power_outlined,         color: Color(0xFFFFCA28)),
  _Category(key: 'spare_part', label: 'قطع غيار',    icon: Icons.settings_outlined,      color: Color(0xFFFF7043)),
  _Category(key: 'other',      label: 'أخرى',        icon: Icons.category_outlined,      color: AppColors.textMuted),
];

// ─── Page ─────────────────────────────────────────────────────────────────────

class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_galleryProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('معرض الصور',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(_galleryProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category tabs
          _CategoryBar(
            selected: _selectedCategory,
            onSelect: (k) => setState(() => _selectedCategory = k),
          ),
          // Grid
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    const Text('تعذر تحميل الصور',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(_galleryProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
              data: (products) {
                final filtered = _selectedCategory == 'all'
                    ? products
                    : products
                        .where((p) => p['category'] == _selectedCategory)
                        .toList();

                if (filtered.isEmpty) {
                  return _EmptyCategory(
                    category: _kCategories.firstWhere(
                      (c) => c.key == _selectedCategory,
                      orElse: () => _kCategories.first,
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _GalleryItem(
                    product: filtered[i],
                    index: i,
                    onTap: () => _showFullScreen(ctx, filtered, i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(
      BuildContext context, List<Map<String, dynamic>> items, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenViewer(items: items, initialIndex: startIndex),
      ),
    );
  }
}

// ─── Category Bar ─────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _kCategories.length,
        itemBuilder: (ctx, i) {
          final cat = _kCategories[i];
          final isSelected = selected == cat.key;
          return GestureDetector(
            onTap: () => onSelect(cat.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? cat.color.withOpacity(0.2)
                    : AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? cat.color : AppColors.darkBorder,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon,
                      size: 15,
                      color: isSelected ? cat.color : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: isSelected ? cat.color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Grid Item ────────────────────────────────────────────────────────────────

class _GalleryItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final VoidCallback onTap;
  const _GalleryItem(
      {required this.product, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image_url'] as String? ?? '';
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConstants.baseUrl}$imageUrl';
    final name = product['name'] as String? ?? '';
    final category = product['category'] as String? ?? '';
    final catLabel = AppConstants.categoryAr[category] ?? category;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: CachedNetworkImage(
                  imageUrl: fullUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
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
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.darkSurface,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.textMuted, size: 28),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (catLabel.isNotEmpty)
                    Text(
                      catLabel,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textMuted,
                          fontSize: 9),
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: (index % 12) * 40))
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyCategory extends StatelessWidget {
  final _Category category;
  const _EmptyCategory({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(category.icon, color: category.color, size: 38),
          ),
          const SizedBox(height: 16),
          Text('لا توجد صور في ${category.label}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('سيتم إضافة صور لهذه الفئة قريباً',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Full-Screen Viewer ───────────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;
  const _FullScreenViewer(
      {required this.items, required this.initialIndex});

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
    final product = widget.items[_current];
    final name = product['name'] as String? ?? '';
    final category = product['category'] as String? ?? '';
    final catLabel = AppConstants.categoryAr[category] ?? category;
    final price = product['price'];
    final status = product['status'] as String? ?? '';
    final statusLabel = AppConstants.productStatusAr[status] ?? status;

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
            Text(name,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('${_current + 1} / ${widget.items.length}  •  $catLabel',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white60,
                    fontSize: 11)),
          ],
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              final p = widget.items[i];
              final imgUrl = p['image_url'] as String? ?? '';
              final fullUrl = imgUrl.startsWith('http')
                  ? imgUrl
                  : '${AppConstants.baseUrl}$imgUrl';
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CircularProgressIndicator(
                        color: AppColors.primary),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white38,
                        size: 64),
                  ),
                ),
              );
            },
          ),

          // Info bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        if (catLabel.isNotEmpty)
                          Text(catLabel,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white60,
                                  fontSize: 12)),
                      ],
                    ),
                  ),
                  if (price != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${price.toString()} ر.ي',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        if (statusLabel.isNotEmpty)
                          Text(statusLabel,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white54,
                                  fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Dots indicator
          if (widget.items.length > 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length.clamp(0, 8),
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _current % 8 ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _current % 8
                          ? AppColors.primary
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
