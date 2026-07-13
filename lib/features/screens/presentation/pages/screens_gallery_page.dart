import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../products/presentation/pages/add_product_page.dart';

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

// ── Samsung catalog (model list) ────────────────────────────────────────────────
//
// Fetched from the backend so the admin panel and the app always share the
// exact same model list (backend/core/samsung_catalog.py).

final samsungCatalogProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/products/catalog/samsung');
  final raw = res.data as List;
  return raw.cast<Map<String, dynamic>>();
});

// ── Cover images provider ──────────────────────────────────────────────────────
//
// Fetches all screen products once and returns a map of modelKey → first image URL.
// Used by the model picker to show cover thumbnails without N separate API calls.

final _screenCoversProvider = FutureProvider<Map<String, String?>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products', queryParameters: {
      'limit': 500,
      'skip': 0,
    });
    final raw = res.data;
    final List items = raw is List
        ? raw
        : ((raw['items'] ?? raw['products'] ?? raw['results'] ?? []) as List);
    final map = <String, String?>{};
    for (final p in items) {
      final model = p['model'] as String? ?? '';
      if (model.isEmpty) continue;
      if (!map.containsKey(model)) {
        final img = p['image_url'] as String?;
        if (img != null && img.isNotEmpty) {
          map[model] = img;
        }
      }
    }
    return map;
  } catch (_) {
    return {};
  }
});

// ── Provider ───────────────────────────────────────────────────────────────────
//
// Key is "modelKey|grade" — a screen gallery is always scoped to one specific
// model AND one color grade (white/green/orange).

final _screensGalleryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, key) async {
  final parts = key.split('|');
  final modelKey = parts[0];
  final grade = parts[1];
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/products', queryParameters: {
      'limit': 200,
      'skip': 0,
      'model': modelKey,
      'grade': grade,
    });
    final raw = res.data;
    final List items = raw is List
        ? raw
        : ((raw['items'] ?? raw['products'] ?? raw['results'] ?? []) as List);

    // Expand multi-image products: each image_url becomes its own gallery entry.
    // Every entry gets a unique _uid (productId_imageIndex) so the grid can key
    // each tile independently. We also deduplicate by image_url so the same
    // photo never appears twice in the same grade folder.
    final expanded = <Map<String, dynamic>>[];
    final seenUrls = <String>{};
    int imgIdx = 0;

    for (final p in items) {
      final base = Map<String, dynamic>.from(p as Map);
      final productId = base['id'];
      final primary = base['image_url'] as String?;
      final extras = (base['image_urls'] as List?)?.cast<String>() ?? [];

      void addEntry(Map<String, dynamic> entry, String url) {
        if (url.isEmpty || seenUrls.contains(url)) return;
        seenUrls.add(url);
        expanded.add({...entry, '_uid': '${productId}_$imgIdx'});
        imgIdx++;
      }

      if (primary != null) {
        addEntry(base, primary);
      }
      for (final url in extras) {
        addEntry({...base, 'image_url': url, '_extra_image': true}, url);
      }
    }
    return expanded;
  } catch (_) {
    return [];
  }
});

// ── Step 1: Model Picker Page ───────────────────────────────────────────────────
//
// Shown when the customer taps the "شاشة" category from the products page.
// Lists every Samsung model from the shared catalog (same list used in the
// admin panel), grouped by series, even if no product exists for it yet.
// Tapping a model moves to step 2 (color folders).

void showScreenGradePicker(BuildContext context, {bool fromGallery = false}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ScreenModelPickerPage()),
  );
}

class ScreenModelPickerPage extends ConsumerStatefulWidget {
  const ScreenModelPickerPage({super.key});

  @override
  ConsumerState<ScreenModelPickerPage> createState() => _ScreenModelPickerPageState();
}

class _ScreenModelPickerPageState extends ConsumerState<ScreenModelPickerPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(samsungCatalogProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('موديل الشاشة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر موديل الشاشة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ثم اختر اللون بعد ذلك',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث عن موديل...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: AppColors.darkCard,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: catalogAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                      const SizedBox(height: 10),
                      const Text('تعذّر تحميل قائمة الموديلات',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => ref.invalidate(samsungCatalogProvider),
                        child: const Text('إعادة المحاولة',
                            style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                data: (series) {
                  final q = _query.toLowerCase();
                  final sections = series.map((s) {
                    final models = (s['models'] as List).cast<Map<String, dynamic>>().where((m) {
                      if (q.isEmpty) return true;
                      final label = (m['label_ar'] as String? ?? '').toLowerCase();
                      final key = (m['key'] as String? ?? '').toLowerCase();
                      return label.contains(q) || key.contains(q);
                    }).toList();
                    return {'series': s, 'models': models};
                  }).where((s) => (s['models'] as List).isNotEmpty).toList();

                  if (sections.isEmpty) {
                    return const Center(
                      child: Text('لا توجد نتائج',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    );
                  }

                  // Load cover images alongside the catalog
                  final coversAsync = ref.watch(_screenCoversProvider);
                  final covers = coversAsync.maybeWhen(
                    data: (m) => m,
                    orElse: () => <String, String?>{},
                  );

                  // Flatten models into a single global list for correct index alternation
                  int globalIndex = 0;

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: sections.length,
                    itemBuilder: (ctx, si) {
                      final s = sections[si];
                      final seriesInfo = s['series'] as Map<String, dynamic>;
                      final models = s['models'] as List<Map<String, dynamic>>;
                      final startIndex = globalIndex;
                      globalIndex += models.length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(seriesInfo['label_ar'] as String? ?? '',
                                style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: models.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemBuilder: (ctx, i) => _ModelFolderTile(
                                modelKey: models[i]['key'] as String,
                                modelLabel: models[i]['label_ar'] as String,
                                index: startIndex + i,
                                imageUrl: covers[models[i]['key'] as String],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelFolderTile extends StatelessWidget {
  final String modelKey;
  final String modelLabel;
  final int index;
  final String? imageUrl;
  const _ModelFolderTile({
    required this.modelKey,
    required this.modelLabel,
    required this.index,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Alternate label colour: even → white, odd → green
    final labelColor = index % 2 == 0 ? Colors.white : const Color(0xFF10B981);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScreenGradeFoldersPage(modelKey: modelKey, modelLabel: modelLabel),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: ApiClient.img(imageUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _noImgPlaceholder(),
                    )
                  : _noImgPlaceholder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            modelLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: labelColor),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 220.ms)
        .scale(begin: const Offset(0.9, 0.9));
  }

  Widget _noImgPlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.image_not_supported_outlined,
              size: 28, color: AppColors.textMuted),
          SizedBox(height: 4),
          Text('لا توجد صور حالياً',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 9,
                  color: AppColors.textMuted)),
        ],
      );
}

// ── Step 2: Grade (color) Folders Page ──────────────────────────────────────────
//
// Scoped to the model chosen in step 1. Presents the three grades
// (أبيض / أخضر / برتقالي) as folder tiles, labeled "{الموديل} {اللون}".
// Tapping a folder opens ScreensGalleryPage — the image gallery for that
// exact model + color combination.

class ScreenGradeFoldersPage extends StatelessWidget {
  final String modelKey;
  final String modelLabel;
  const ScreenGradeFoldersPage({super.key, required this.modelKey, required this.modelLabel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(modelLabel,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر لون الشاشة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'كل لون يعرض معرض صور $modelLabel الخاص به',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: _grades.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (ctx, i) => _GradeFolderTile(
                  grade: _grades[i],
                  modelKey: modelKey,
                  modelLabel: modelLabel,
                  index: i,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeFolderTile extends StatelessWidget {
  final ScreenGrade grade;
  final String modelKey;
  final String modelLabel;
  final int index;
  const _GradeFolderTile({
    required this.grade,
    required this.modelKey,
    required this.modelLabel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScreensGalleryPage(
              grade: grade,
              modelKey: modelKey,
              modelLabel: modelLabel,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: grade.color.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.folder_rounded, size: 56, color: grade.color),
                  Icon(grade.icon, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$modelLabel ${grade.label}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: index % 2 == 0 ? Colors.white : const Color(0xFF10B981))),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 260.ms)
        .scale(begin: const Offset(0.9, 0.9));
  }
}

// ── Main Gallery Page ──────────────────────────────────────────────────────────

class ScreensGalleryPage extends ConsumerWidget {
  final ScreenGrade grade;
  final String modelKey;
  final String modelLabel;
  const ScreensGalleryPage({
    super.key,
    required this.grade,
    required this.modelKey,
    required this.modelLabel,
  });

  String get _providerKey => '$modelKey|${grade.key}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_screensGalleryProvider(_providerKey));
    final auth = ref.watch(authProvider);
    final isStaff = auth.isStaffOrAbove;

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
              if (isStaff)
                IconButton(
                  tooltip: 'إضافة منتج جديد',
                  icon: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.primary),
                  onPressed: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddProductPage(
                          preCategory: 'screen',
                          preGrade: grade.key,
                          preModel: modelKey,
                        ),
                      ),
                    );
                    if (added == true) {
                      ref.invalidate(_screensGalleryProvider(_providerKey));
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref.invalidate(_screensGalleryProvider(_providerKey)),
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
                              '$modelLabel ${grade.label}',
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
                      onPressed: () => ref.invalidate(_screensGalleryProvider(_providerKey)),
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
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _ScreenImageTile(
                          product: products[i],
                          grade: grade,
                          index: i,
                        ),
                        childCount: products.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                        childAspectRatio: 1.0,
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

// ── Screen Image Tile (4-column photo grid) ───────────────────────────────────

class _ScreenImageTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final ScreenGrade grade;
  final int index;

  const _ScreenImageTile({required this.product, required this.grade, required this.index});

  @override
  Widget build(BuildContext context) {
    final imgUrl = ApiClient.img(product['image_url'] as String?);

    return GestureDetector(
      onTap: () => context.push('/products/${product['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: product['image_url'] != null
            ? CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.darkCard,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => _noImg(),
              )
            : _noImg(),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 30))
        .fadeIn(duration: 200.ms);
  }

  Widget _noImg() => Container(
        color: AppColors.darkCard,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 20, color: grade.color.withOpacity(0.4)),
            const SizedBox(height: 2),
            const Text('لا تتوفر\nصورة',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 8,
                    color: AppColors.textMuted)),
          ],
        ),
      );
}

