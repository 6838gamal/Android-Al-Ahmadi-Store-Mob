import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _gallerySeriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/gallery/folders');
    return List<Map<String, dynamic>>.from(res.data);
  } catch (_) {
    return [];
  }
});

final _folderImagesProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, folderId) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/gallery/folders/$folderId');
    return Map<String, dynamic>.from(res.data);
  } catch (_) {
    return {'images': [], 'folder': {}};
  }
});

// ─── Page (Level 1 — series list) ────────────────────────────────────────────

class GalleryPage extends ConsumerWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(_gallerySeriesProvider);

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
            onPressed: () => ref.invalidate(_gallerySeriesProvider),
          ),
        ],
      ),
      body: seriesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _EmptyGallery(onRetry: () => ref.invalidate(_gallerySeriesProvider)),
        data: (seriesList) {
          if (seriesList.isEmpty) {
            return _EmptyGallery(onRetry: () => ref.invalidate(_gallerySeriesProvider));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: seriesList.length,
            itemBuilder: (ctx, si) {
              final series = seriesList[si];
              final folders =
                  List<Map<String, dynamic>>.from(series['folders'] as List? ?? []);
              return _SeriesSection(
                  series: series, folders: folders, seriesIndex: si);
            },
          );
        },
      ),
    );
  }
}

// ─── Series Section ────────────────────────────────────────────────────────────

class _SeriesSection extends StatelessWidget {
  final Map<String, dynamic> series;
  final List<Map<String, dynamic>> folders;
  final int seriesIndex;

  const _SeriesSection(
      {required this.series, required this.folders, required this.seriesIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Series header
        Container(
          margin: const EdgeInsets.only(bottom: 12, top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B1FA2), AppColors.primary],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_special, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series['label_ar'] as String? ?? '',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15),
                    ),
                    Text(
                      '${folders.length} موديل',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate(delay: Duration(milliseconds: seriesIndex * 80)).fadeIn().slideY(begin: -0.1),

        // Folder grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemCount: folders.length,
          itemBuilder: (ctx, fi) {
            final folder = folders[fi];
            return _FolderCard(
              folder: folder,
              index: fi,
              onTap: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => _FolderPage(folder: folder),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Folder Card ──────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final int index;
  final VoidCallback onTap;

  const _FolderCard(
      {required this.folder, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = folder['cover_image_url'] as String?;
    final fullCover = cover != null && cover.isNotEmpty
        ? ApiClient.img(cover)
        : null;
    final count = folder['image_count'] as int? ?? 0;

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
            // Cover
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (fullCover != null)
                      CachedNetworkImage(
                        imageUrl: fullCover,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.darkSurface,
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _emptyFolder(),
                      )
                    else
                      _emptyFolder(),
                    // Count badge
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder['label_ar'] as String? ?? '',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    folder['model_key'] as String? ?? '',
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
          .animate(delay: Duration(milliseconds: (index % 9) * 40))
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
    );
  }

  Widget _emptyFolder() => Container(
        color: AppColors.darkSurface,
        child: const Center(
          child: Icon(Icons.folder_open_outlined,
              color: AppColors.textMuted, size: 32),
        ),
      );
}

// ─── Folder Page (Level 2 — images in folder) ─────────────────────────────────

class _FolderPage extends ConsumerWidget {
  final Map<String, dynamic> folder;
  const _FolderPage({required this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderId = folder['id'] as int;
    final folderAsync = ref.watch(_folderImagesProvider(folderId));

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              folder['label_ar'] as String? ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
            Text(
              folder['label_en'] as String? ?? '',
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.invalidate(_folderImagesProvider(folderId)),
          ),
        ],
      ),
      body: folderAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _EmptyFolder(
          folderName: folder['label_ar'] as String? ?? '',
          onRetry: () => ref.invalidate(_folderImagesProvider(folderId)),
        ),
        data: (data) {
          final images =
              List<Map<String, dynamic>>.from(data['images'] as List? ?? []);

          if (images.isEmpty) {
            return _EmptyFolder(
              folderName: folder['label_ar'] as String? ?? '',
              onRetry: null,
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: images.length,
            itemBuilder: (ctx, i) => _GalleryImage(
              image: images[i],
              index: i,
              onTap: () => _showFullScreen(ctx, images, i),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreen(BuildContext context,
      List<Map<String, dynamic>> images, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullScreenViewer(images: images, initialIndex: startIndex, folderLabel: folder['label_ar'] as String? ?? ''),
      ),
    );
  }
}

// ─── Image card ───────────────────────────────────────────────────────────────

class _GalleryImage extends StatelessWidget {
  final Map<String, dynamic> image;
  final int index;
  final VoidCallback onTap;

  const _GalleryImage(
      {required this.image, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = image['image_url'] as String? ?? '';
    final fullUrl = ApiClient.img(url);
    final watermark = image['watermark_number'] as String?;
    final title = image['title'] as String?;

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
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textMuted, size: 28),
                      ),
                    ),
                    if (watermark != null)
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            watermark,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                child: Text(
                  title,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: (index % 12) * 40))
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
    );
  }
}

// ─── Full-Screen Viewer ───────────────────────────────────────────────────────

class _FullScreenViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final String folderLabel;

  const _FullScreenViewer(
      {required this.images,
      required this.initialIndex,
      required this.folderLabel});

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
    final img = widget.images[_current];
    final watermark = img['watermark_number'] as String?;
    final title = img['title'] as String?;
    final createdAt = (img['created_at'] as String? ?? '').replaceFirst('T', ' ');

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
              title ?? watermark ?? widget.folderLabel,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_current + 1} / ${widget.images.length}  •  ${widget.folderLabel}',
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
              final p = widget.images[i];
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

          // Bottom info bar
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (watermark != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              watermark,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (title != null && title.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt.length > 10
                                ? createdAt.substring(0, 16)
                                : createdAt,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white54,
                                fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dots indicator
          if (widget.images.length > 1)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length.clamp(0, 8),
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

// ─── Empty state — main gallery ───────────────────────────────────────────────

class _EmptyGallery extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyGallery({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'المعرض فارغ حالياً',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم إضافة صور المنتجات والعروض قريباً',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state — folder detail ─────────────────────────────────────────────

class _EmptyFolder extends StatelessWidget {
  final String folderName;
  final VoidCallback? onRetry;
  const _EmptyFolder({required this.folderName, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textMuted.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.folder_open_outlined,
                  color: AppColors.textMuted, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد صور في $folderName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم إضافة صور لهذا الموديل قريباً',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('تحديث', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
