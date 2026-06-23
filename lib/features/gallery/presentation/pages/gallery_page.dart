import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';

// ─── Filter state ─────────────────────────────────────────────────────────────

final _selectedSeriesProvider = StateProvider.autoDispose<String?>((ref) => null);
final _selectedModelProvider  = StateProvider.autoDispose<String?>((ref) => null);

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
    return List<Map<String, dynamic>>.from(res.data);
  } catch (_) {
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
    final selModel    = ref.watch(_selectedModelProvider);

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

          // ── Series chips (الفئة) ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SeriesChips(
              seriesList: seriesList,
              selected: selSeries,
              onSelect: (key) {
                ref.read(_selectedSeriesProvider.notifier).state = key;
                ref.read(_selectedModelProvider.notifier).state  = null;
              },
            ),
          ),

          // ── Model chips (نوع الشاشة) ────────────────────────────────────────
          if (selSeries != null && modelFolders.isNotEmpty)
            SliverToBoxAdapter(
              child: _ModelChips(
                folders: modelFolders,
                selected: selModel,
                onSelect: (key) =>
                    ref.read(_selectedModelProvider.notifier).state = key,
              ),
            ),

          // ── Divider / info ──────────────────────────────────────────────────
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
                      '${selModel  != null ? " · ${selModel}" : ""}',
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

          // ── Images grid ─────────────────────────────────────────────────────
          imagesAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
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
                      onTap: () =>
                          _showFullScreen(ctx, images, i),
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
                        fontSize: 12,
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyGallery extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const _EmptyGallery({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            message ?? 'المعرض فارغ',
            style: const TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'سيتم عرض الصور هنا بعد إضافتها من لوحة التحكم',
            style: TextStyle(
                fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}
