import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';

// ─── State providers ──────────────────────────────────────────────────────────

final _selectedSeriesProvider = StateProvider.autoDispose<String?>((ref) => null);

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// رابط صالح = Supabase أو /api/uploads/image/ (ليس مساراً محلياً مؤقتاً)
bool _isValidImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('http') || url.startsWith('/api/uploads/image/');
}

// ─── Data providers ───────────────────────────────────────────────────────────

/// قائمة الفئات (series) مع مجلداتها
final _galleryMetaProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/gallery/folders');
    return List<Map<String, dynamic>>.from(res.data);
  } catch (_) {
    return [];
  }
});

/// صور المنتجات كاحتياطي عند فراغ المعرض
final _productImagesForGalleryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products', queryParameters: {'limit': 60});
    final raw = res.data;
    final List items = raw is List
        ? raw
        : (raw['items'] ?? raw['products'] ?? raw['results'] ?? []) as List;
    return items
        .where((p) => _isValidImageUrl(p['image_url'] as String?))
        .map<Map<String, dynamic>>((p) => {
              'id': 'product_${p["id"]}',
              'image_url': p['image_url'],
              'watermark_number': null,
              'title': p['name'] ?? p['name_ar'],
              'folder_label_ar': p['category'] ?? 'منتجات المتجر',
              'series_key': null,
              'model_key': null,
            })
        .toList();
  } catch (_) {
    return [];
  }
});

/// صور المعرض — مع احتياطي لصور المنتجات عند الفراغ
final _galleryImagesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final seriesKey = ref.watch(_selectedSeriesProvider);
  final api = ref.read(apiClientProvider);
  try {
    final params = <String, dynamic>{};
    if (seriesKey != null) params['series_key'] = seriesKey;
    final res = await api.get('/gallery/images',
        queryParameters: params.isNotEmpty ? params : null);

    final valid = List<Map<String, dynamic>>.from(res.data)
        .where((img) => _isValidImageUrl(img['image_url'] as String?))
        .toList();

    if (valid.isEmpty && seriesKey == null) {
      return await ref.read(_productImagesForGalleryProvider.future);
    }
    return valid;
  } catch (_) {
    if (ref.read(_selectedSeriesProvider) == null) {
      return await ref.read(_productImagesForGalleryProvider.future);
    }
    return [];
  }
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync   = ref.watch(_galleryMetaProvider);
    final imagesAsync = ref.watch(_galleryImagesProvider);
    final selSeries   = ref.watch(_selectedSeriesProvider);
    final seriesList  = metaAsync.valueOrNull ?? [];

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
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () {
                  ref.invalidate(_galleryMetaProvider);
                  ref.invalidate(_galleryImagesProvider);
                },
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
                          '🖼️ معرض الصور',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'صور الموديلات والشاشات',
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

          // ── تبويبات الفئات (مثل لوحة التحكم) ───────────────────────────────
          if (seriesList.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SeriesTabsDelegate(
                seriesList: seriesList,
                selected: selSeries,
                onSelect: (key) {
                  ref.read(_selectedSeriesProvider.notifier).state = key;
                  ref.invalidate(_galleryImagesProvider);
                },
              ),
            ),

          // ── محتوى الصور ─────────────────────────────────────────────────────
          imagesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, __) => SliverFillRemaining(
              child: _EmptyGallery(
                message: 'تعذّر تحميل الصور',
                onRetry: () => ref.invalidate(_galleryImagesProvider),
              ),
            ),
            data: (images) {
              if (images.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyGallery(
                    message: selSeries != null
                        ? 'لا توجد صور لهذه الفئة بعد'
                        : 'لا توجد صور في المعرض بعد',
                    onRetry: null,
                  ),
                );
              }

              return SliverMainAxisGroup(
                slivers: [
                  // شريط عدد الصور
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.photo_library_outlined,
                              color: AppColors.primary, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '${images.length} صورة',
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
                  // شبكة الصور
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ImageCard(
                          image: images[i],
                          index: i,
                          onTap: () => _showFullScreen(ctx, images, i),
                        ),
                        childCount: images.length,
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
            },
          ),
        ],
      ),
    );
  }

  void _showFullScreen(
      BuildContext context, List<Map<String, dynamic>> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenViewer(images: images, initialIndex: index),
      ),
    );
  }
}

// ─── Series Tabs (Persistent Header) ─────────────────────────────────────────

class _SeriesTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<Map<String, dynamic>> seriesList;
  final String? selected;
  final void Function(String?) onSelect;

  const _SeriesTabsDelegate({
    required this.seriesList,
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  bool shouldRebuild(_SeriesTabsDelegate old) =>
      old.selected != selected || old.seriesList.length != seriesList.length;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.darkBg,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF2D3748), width: 1),
          ),
        ),
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          scrollDirection: Axis.horizontal,
          children: [
            _TabPill(
              label: 'الكل',
              isSelected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...seriesList.map((s) {
              final key = s['series_key'] as String?;
              final label = s['label_ar'] as String? ?? key ?? '';
              final count = (s['folders'] as List?)?.length ?? 0;
              return _TabPill(
                label: label,
                badge: count > 0 ? '$count' : null,
                isSelected: selected == key,
                onTap: () => onSelect(selected == key ? null : key),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Pill ─────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFF2D3748),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Image Card ───────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final Map<String, dynamic> image;
  final int index;
  final VoidCallback onTap;

  const _ImageCard(
      {required this.image, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = image['image_url'] as String? ?? '';
    final fullUrl = ApiClient.img(url);
    final watermark = image['watermark_number'] as String?;
    final label = image['folder_label_ar'] as String?;
    final model = image['model_key'] as String?;

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
                    if (watermark != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            watermark,
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
                  if (label != null && label.isNotEmpty)
                    Text(
                      label,
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
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const _FullScreenViewer(
      {required this.images, required this.initialIndex});

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
    final img       = widget.images[_current];
    final watermark = img['watermark_number'] as String?;
    final label     = img['folder_label_ar'] as String?;
    final model     = img['model_key'] as String?;

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
              label ?? watermark ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_current + 1} / ${widget.images.length}  •  ${model ?? ""}',
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
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (ctx, i) {
              final p      = widget.images[i];
              final imgUrl = p['image_url'] as String? ?? '';
              final fullUrl = ApiClient.img(imgUrl);
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
          if (watermark != null)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    watermark,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty Gallery ────────────────────────────────────────────────────────────

class _EmptyGallery extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const _EmptyGallery({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            message ?? 'تعذّر تحميل المعرض',
            style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.textMuted,
                fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
