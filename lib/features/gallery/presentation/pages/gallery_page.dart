import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shared_filters_provider.dart';
import '../../../home/presentation/pages/main_shell.dart';

// ─── Filter state ─────────────────────────────────────────────────────────────

final _selectedSeriesProvider = StateProvider.autoDispose<String?>((ref) => null);
final _selectedModelProvider  = StateProvider.autoDispose<String?>((ref) => null);

// ─── View mode ────────────────────────────────────────────────────────────────

enum _GalleryView { folders, images }
final _viewModeProvider = StateProvider.autoDispose<_GalleryView>(
    (ref) => _GalleryView.folders);

// ─── Data providers ───────────────────────────────────────────────────────────

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

/// رابط صالح = Supabase أو /api/uploads/image/ (ليس مساراً محلياً مؤقتاً)
bool _isValidImageUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('http') || url.startsWith('/api/uploads/image/');
}

/// صور المنتجات مُهيَّأة بتنسيق gallery
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
              'folder_id': null,
              'folder_label_ar': p['category'] ?? 'منتجات المتجر',
              'series_key': null,
              'model_key': null,
              'created_at': null,
            })
        .toList();
  } catch (_) {
    return [];
  }
});

final _galleryImagesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final seriesKey = ref.watch(_selectedSeriesProvider);
  final modelKey  = ref.watch(_selectedModelProvider);
  final api = ref.read(apiClientProvider);
  try {
    final params = <String, dynamic>{};
    if (seriesKey != null) params['series_key'] = seriesKey;
    if (modelKey  != null) params['model_key']  = modelKey;
    final res = await api.get('/gallery/images',
        queryParameters: params.isNotEmpty ? params : null);

    // تصفية الروابط المحلية المؤقتة غير الصالحة
    final valid = List<Map<String, dynamic>>.from(res.data)
        .where((img) => _isValidImageUrl(img['image_url'] as String?))
        .toList();

    // عند غياب صور معرض صالحة وبدون فلتر موديل محدد → استخدم صور المنتجات
    if (valid.isEmpty && seriesKey == null && modelKey == null) {
      return await ref.read(_productImagesForGalleryProvider.future);
    }

    return valid;
  } catch (_) {
    return [];
  }
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync     = ref.watch(_galleryMetaProvider);
    final imagesAsync   = ref.watch(_galleryImagesProvider);
    final selSeries     = ref.watch(_selectedSeriesProvider);
    final selModel      = ref.watch(_selectedModelProvider);
    final viewMode      = ref.watch(_viewModeProvider);
    final activeCategory = ref.watch(selectedProductCategoryProvider);

    final seriesList = metaAsync.valueOrNull ?? [];

    // النماذج الخاصة بالفئة المختارة
    List<Map<String, dynamic>> modelFolders = [];
    if (selSeries != null) {
      final seriesEntry = seriesList.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['series_key'] == selSeries,
        orElse: () => <String, dynamic>{},
      );
      modelFolders = List<Map<String, dynamic>>.from(
          seriesEntry['folders'] as List? ?? []);
    }

    // هل الفئة المختارة من المنتجات تدعم المعرض (شاشات فقط)؟
    final bool categorySupported =
        activeCategory == null || activeCategory == 'screen';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            leading: IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
            ),
            actions: [
              // زر تبديل عرض المجلدات / الصور
              if (categorySupported)
                IconButton(
                  icon: Icon(
                    viewMode == _GalleryView.folders
                        ? Icons.photo_library_outlined
                        : Icons.folder_outlined,
                    color: AppColors.primary,
                  ),
                  tooltip: viewMode == _GalleryView.folders
                      ? 'عرض الصور'
                      : 'عرض المجلدات',
                  onPressed: () {
                    ref.read(_viewModeProvider.notifier).state =
                        viewMode == _GalleryView.folders
                            ? _GalleryView.images
                            : _GalleryView.folders;
                  },
                ),
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
                    padding: EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('معرض الصور',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('اختر الفئة والموديل لعرض الشاشات',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
              title: const Text('معرض الصور',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white)),
            ),
          ),

          // ── شريط الفئة النشطة من المنتجات ──────────────────────────────────
          if (activeCategory != null)
            SliverToBoxAdapter(
              child: _ActiveCategoryBanner(
                categoryKey: activeCategory,
                onClear: () {
                  ref.read(selectedProductCategoryProvider.notifier).state =
                      null;
                  ref.read(_selectedSeriesProvider.notifier).state = null;
                  ref.read(_selectedModelProvider.notifier).state = null;
                },
              ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.3, end: 0),
            ),

          // ── إذا الفئة لا تدعم المعرض ─────────────────────────────────────
          if (!categorySupported)
            SliverFillRemaining(
              child: _UnsupportedCategory(
                categoryKey: activeCategory!,
                onShowAll: () {
                  ref.read(selectedProductCategoryProvider.notifier).state =
                      null;
                },
              ),
            )
          else ...[
            // ── Series chips (الفئة) ────────────────────────────────────────
            if (viewMode == _GalleryView.images)
              SliverToBoxAdapter(
                child: _SeriesChips(
                  seriesList: seriesList,
                  selected: selSeries,
                  onSelect: (key) {
                    ref.read(_selectedSeriesProvider.notifier).state = key;
                    ref.read(_selectedModelProvider.notifier).state = null;
                  },
                ),
              ),

            // ── Model chips (نوع الشاشة) ───────────────────────────────────
            if (viewMode == _GalleryView.images &&
                selSeries != null &&
                modelFolders.isNotEmpty)
              SliverToBoxAdapter(
                child: _ModelChips(
                  folders: modelFolders,
                  selected: selModel,
                  onSelect: (key) =>
                      ref.read(_selectedModelProvider.notifier).state = key,
                ),
              ),

            // ── عرض المجلدات ────────────────────────────────────────────────
            if (viewMode == _GalleryView.folders)
              metaAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (_, __) => SliverFillRemaining(
                  child: _EmptyGallery(
                      onRetry: () => ref.invalidate(_galleryMetaProvider)),
                ),
                data: (series) {
                  if (series.isEmpty) {
                    return const SliverFillRemaining(
                      child: _EmptyGallery(message: 'لا توجد مجلدات بعد'),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, si) {
                          final s = series[si];
                          final folders = List<Map<String, dynamic>>.from(
                              s['folders'] as List? ?? []);
                          if (folders.isEmpty) return const SizedBox.shrink();
                          return _SeriesSection(
                            seriesKey: s['series_key'] as String? ?? '',
                            labelAr: s['label_ar'] as String? ?? '',
                            folders: folders,
                            onFolderTap: (folderSeriesKey, modelKey) {
                              // الانتقال لعرض الصور وتصفيتها بهذا الموديل
                              ref.read(_viewModeProvider.notifier).state =
                                  _GalleryView.images;
                              ref
                                  .read(_selectedSeriesProvider.notifier)
                                  .state = folderSeriesKey;
                              ref.read(_selectedModelProvider.notifier).state =
                                  modelKey;
                            },
                          );
                        },
                        childCount: series.length,
                      ),
                    ),
                  );
                },
              ),

            // ── عرض الصور ──────────────────────────────────────────────────
            if (viewMode == _GalleryView.images) ...[
              // معلومات العدد
              SliverToBoxAdapter(
                child: imagesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (images) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            color: AppColors.textMuted, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          '${images.length} صورة'
                          '${selSeries != null ? " في ${_seriesLabel(seriesList, selSeries)}" : ""}'
                          '${selModel != null ? " · ${selModel}" : ""}',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textMuted,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // شبكة الصور
              imagesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                error: (_, __) => SliverFillRemaining(
                  child: _EmptyGallery(
                      onRetry: () => ref.invalidate(_galleryImagesProvider)),
                ),
                data: (images) {
                  if (images.isEmpty) {
                    return SliverFillRemaining(
                      child: _EmptyGallery(
                          message: selSeries != null
                              ? 'لا توجد صور لهذه الفئة بعد'
                              : 'لا توجد صور في المعرض بعد',
                          onRetry: null),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
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
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _seriesLabel(List seriesList, String? key) {
    if (key == null) return '';
    try {
      return (seriesList as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((s) => s['series_key'] == key,
              orElse: () => {'label_ar': key})['label_ar'] as String? ?? key;
    } catch (_) {
      return key;
    }
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

// ─── Active Category Banner ───────────────────────────────────────────────────

class _ActiveCategoryBanner extends StatelessWidget {
  final String categoryKey;
  final VoidCallback onClear;

  const _ActiveCategoryBanner(
      {required this.categoryKey, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final label =
        AppConstants.categoryAr[categoryKey] ?? categoryKey;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              color: Color(0xFF7B1FA2), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'تصفية من المنتجات: $label',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded,
                color: AppColors.textMuted, size: 16),
          ),
        ],
      ),
    );
  }
}

// ─── Unsupported Category ─────────────────────────────────────────────────────

class _UnsupportedCategory extends StatelessWidget {
  final String categoryKey;
  final VoidCallback onShowAll;

  const _UnsupportedCategory(
      {required this.categoryKey, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final label = AppConstants.categoryAr[categoryKey] ?? categoryKey;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text(
              'لا توجد صور لفئة "$label"',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'معرض الصور مخصص حالياً لشاشات سامسونج',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onShowAll,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('عرض كل الصور',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Series Section (folder view) ─────────────────────────────────────────────

class _SeriesSection extends StatelessWidget {
  final String seriesKey;
  final String labelAr;
  final List<Map<String, dynamic>> folders;
  final void Function(String seriesKey, String? modelKey) onFolderTap;

  const _SeriesSection({
    required this.seriesKey,
    required this.labelAr,
    required this.folders,
    required this.onFolderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان الفئة
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                labelAr,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                '${folders.length} موديل',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textMuted,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        // شبكة المجلدات
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.82,
          ),
          itemCount: folders.length,
          itemBuilder: (ctx, i) {
            final f = folders[i];
            // تجاهل روابط الـ filesystem المحلية المؤقتة
            final coverRaw = f['cover_image_url'] as String?;
            final cover = _isValidImageUrl(coverRaw) ? coverRaw : null;
            final modelKey = f['model_key'] as String?;
            final labelAr = f['label_ar'] as String? ?? modelKey ?? '';
            final count = f['image_count'] as int? ?? 0;

            return GestureDetector(
              onTap: () => onFolderTap(seriesKey, modelKey),
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
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(11)),
                        child: cover != null
                            ? CachedNetworkImage(
                                imageUrl: ApiClient.img(cover),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, __) => Container(
                                  color: AppColors.darkSurface,
                                  child: const Center(
                                    child: Icon(Icons.folder_outlined,
                                        color: Color(0xFF7B1FA2), size: 32),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.darkSurface,
                                  child: const Center(
                                    child: Icon(Icons.folder_outlined,
                                        color: Color(0xFF7B1FA2), size: 32),
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.darkSurface,
                                child: const Center(
                                  child: Icon(Icons.folder_outlined,
                                      color: Color(0xFF7B1FA2), size: 32),
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelAr,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$count صورة',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textMuted,
                                fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate(
                      delay: Duration(milliseconds: (i % 9) * 30))
                  .fadeIn(duration: 250.ms)
                  .scale(begin: const Offset(0.93, 0.93)),
            );
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ─── Series Chips ─────────────────────────────────────────────────────────────

class _SeriesChips extends StatelessWidget {
  final List<Map<String, dynamic>> seriesList;
  final String? selected;
  final void Function(String?) onSelect;

  const _SeriesChips(
      {required this.seriesList,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
              label: 'الكل',
              selected: selected == null,
              onTap: () => onSelect(null)),
          ...seriesList.map((s) => _Chip(
                label: s['label_ar'] as String? ?? '',
                selected: selected == s['series_key'],
                onTap: () => onSelect(
                    selected == s['series_key'] ? null : s['series_key'] as String?),
              )),
        ],
      ),
    );
  }
}

// ─── Model Chips ──────────────────────────────────────────────────────────────

class _ModelChips extends StatelessWidget {
  final List<Map<String, dynamic>> folders;
  final String? selected;
  final void Function(String?) onSelect;

  const _ModelChips(
      {required this.folders,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
              label: 'كل الموديلات',
              selected: selected == null,
              color: const Color(0xFF7B1FA2),
              onTap: () => onSelect(null)),
          ...folders.map((f) => _Chip(
                label: f['label_ar'] as String? ?? f['model_key'] as String? ?? '',
                selected: selected == f['model_key'],
                color: const Color(0xFF7B1FA2),
                onTap: () => onSelect(
                    selected == f['model_key'] ? null : f['model_key'] as String?),
              )),
        ],
      ),
    );
  }
}

// ─── Chip widget ──────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? activeColor : AppColors.darkBorder),
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

// ─── Image Card ───────────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final Map<String, dynamic> image;
  final int index;
  final VoidCallback onTap;

  const _ImageCard(
      {required this.image, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url       = image['image_url'] as String? ?? '';
    final fullUrl   = ApiClient.img(url);
    final watermark = image['watermark_number'] as String?;
    final label     = image['folder_label_ar'] as String?;
    final model     = image['model_key'] as String?;

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
      )
          .animate(delay: Duration(milliseconds: (index % 12) * 35))
          .fadeIn(duration: 280.ms)
          .scale(begin: const Offset(0.93, 0.93)),
    );
  }
}

// ─── Full-Screen Viewer ───────────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;

  const _FullScreenViewer({required this.images, required this.initialIndex});

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
