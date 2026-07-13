import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'staff_shell.dart';
import '../../../../shared/widgets/media_pick_btn.dart';

final _inspectionListProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/inspection/', queryParameters: {'limit': '100'});
  return res.data is List ? res.data : [];
});

class StaffInspectionPage extends ConsumerStatefulWidget {
  const StaffInspectionPage({super.key});

  @override
  ConsumerState<StaffInspectionPage> createState() => _StaffInspectionPageState();
}

class _StaffInspectionPageState extends ConsumerState<StaffInspectionPage> {
  String _filter = '';

  static const _statusLabels = {
    '': 'الكل',
    'pending': 'قيد الانتظار',
    'under_review': 'قيد الفحص',
    'responded': 'تم الرد',
    'closed': 'مغلق',
  };

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'under_review': Color(0xFF8B5CF6),
    'responded': Color(0xFF10B981),
    'closed': Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_inspectionListProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => StaffShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('طلبات الفحص',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(_inspectionListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilter(),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text('حدث خطأ: $e',
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: () => ref.invalidate(_inspectionListProvider),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo'))),
                ]),
              ),
              data: (items) {
                final filtered = _filter.isEmpty
                    ? items
                    : items.where((i) => (i['status'] ?? 'pending') == _filter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.search_off, color: AppColors.textMuted, size: 56),
                      const SizedBox(height: 12),
                      const Text('لا توجد طلبات فحص',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _InspectionCard(
                    item: filtered[i],
                    statusColors: _statusColors,
                    statusLabels: _statusLabels,
                    onRespond: _showRespondDialog,
                    onClose: _closeInspection,
                  ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      height: 48,
      color: AppColors.darkSurface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: _statusLabels.entries.map((e) {
          final sel = _filter == e.key;
          return GestureDetector(
            onTap: () => setState(() => _filter = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.primary : AppColors.darkBorder),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  Future<String?> _uploadFile(ApiClient api, XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final ct = _guessContentType(file.name);
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes,
            filename: file.name, contentType: DioMediaType.parse(ct)),
      });
      final res = await api.postForm('/uploads/media', form);
      return res.data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Shows the respond dialog — runs in page state so it can upload via ApiClient.
  void _showRespondDialog(int id) {
    final diagCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final List<XFile> selectedImages = [];
    XFile? selectedVideo;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('الرد على طلب الفحص',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Diagnosis
              TextField(
                controller: diagCtrl,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'التشخيص *',
                  labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.darkBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 10),
              // Price
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'السعر التقديري (ر.ي)',
                  labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.darkBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 10),
              // Notes
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.darkBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 14),
              // Media header
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('وسائط الرد (صور / فيديو — اختياري)',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 8),
              // Media buttons
              Row(children: [
                Expanded(
                  child: MediaPickBtn(
                    icon: selectedImages.isEmpty
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle_outline,
                    label: selectedImages.isEmpty
                        ? 'صور'
                        : '${selectedImages.length} صور ✓',
                    color: selectedImages.isEmpty ? AppColors.primary : AppColors.success,
                    onTap: () async {
                      final picked =
                          await ImagePicker().pickMultiImage(imageQuality: 80);
                      if (picked.isNotEmpty) {
                        setSt(() {
                          selectedImages.clear();
                          selectedImages.addAll(picked.take(5));
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MediaPickBtn(
                    icon: selectedVideo == null
                        ? Icons.videocam_outlined
                        : Icons.videocam,
                    label: selectedVideo == null ? 'فيديو' : 'فيديو ✓',
                    color: selectedVideo == null
                        ? const Color(0xFF06B6D4)
                        : AppColors.success,
                    subtitle: kIsWeb ? 'موبايل فقط' : null,
                    onTap: kIsWeb
                        ? null
                        : () async {
                            final v = await ImagePicker().pickVideo(
                              source: ImageSource.gallery,
                              maxDuration: const Duration(minutes: 3),
                            );
                            if (v != null) setSt(() => selectedVideo = v);
                          },
                  ),
                ),
              ]),
              // Image thumbs
              if (selectedImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    itemBuilder: (_, i) => Stack(children: [
                      Container(
                        width: 58,
                        height: 58,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.4)),
                          image: kIsWeb
                              ? null
                              : DecorationImage(
                                  image: FileImage(
                                      File(selectedImages[i].path)),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: kIsWeb
                            ? const Icon(Icons.image,
                                color: AppColors.primary, size: 22)
                            : null,
                      ),
                      Positioned(
                        top: 0,
                        right: 8,
                        child: GestureDetector(
                          onTap: () =>
                              setSt(() => selectedImages.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
              // Video chip
              if (selectedVideo != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.videocam,
                      color: Color(0xFF06B6D4), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(selectedVideo!.name,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Color(0xFF06B6D4)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => setSt(() => selectedVideo = null),
                    child: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 14),
                  ),
                ]),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (diagCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await _submitResponse(
                  id: id,
                  diagnosis: diagCtrl.text.trim(),
                  price: priceCtrl.text.trim().isEmpty
                      ? null
                      : priceCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  images: selectedImages,
                  video: selectedVideo,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('إرسال الرد',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitResponse({
    required int id,
    required String diagnosis,
    String? price,
    String? notes,
    List<XFile> images = const [],
    XFile? video,
  }) async {
    try {
      final api = ref.read(apiClientProvider);

      // Upload images + video (best-effort)
      final List<String> mediaUrls = [];
      for (final img in images) {
        final url = await _uploadFile(api, img);
        if (url != null) mediaUrls.add(url);
      }
      if (video != null) {
        final url = await _uploadFile(api, video);
        if (url != null) mediaUrls.add(url);
      }

      await api.post('/inspection/$id/respond', data: {
        'diagnosis': diagnosis,
        if (price != null) 'estimated_price': price,
        if (notes != null) 'response_notes': notes,
        if (mediaUrls.isNotEmpty) 'response_images': mediaUrls,
      });
      ref.invalidate(_inspectionListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال الرد بنجاح',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _closeInspection(int id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/inspection/$id/close');
      ref.invalidate(_inspectionListProvider);
    } catch (_) {}
  }
}

class _InspectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final void Function(int) onRespond;
  final void Function(int) onClose;

  const _InspectionCard({
    required this.item,
    required this.statusColors,
    required this.statusLabels,
    required this.onRespond,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'pending') as String;
    final statusColor = statusColors[status] ?? AppColors.textMuted;
    final statusLabel = statusLabels[status] ?? status;
    final images = item['images'] as List<dynamic>? ?? [];
    final videoUrl = item['video_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.darkCardAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.search, color: Color(0xFF06B6D4), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(item['device_model'] ?? 'جهاز غير محدد',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(item['customer_name'] ?? '',
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(item['customer_phone'] ?? '',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
              ),
              child: Text(item['problem_description'] ?? '',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            ),
            // Customer images
            if (images.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.photo_library_outlined, size: 13, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text('صور العميل (${images.length})',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (ctx, i) => Container(
                    width: 70, height: 70,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(images[i].toString(), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.textMuted)),
                    ),
                  ),
                ),
              ),
            ],
            // Customer video
            if (videoUrl != null && videoUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showVideoDialog(context, videoUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.play_circle_outline, color: Color(0xFF06B6D4), size: 20),
                    SizedBox(width: 8),
                    Text('فيديو مرفق — اضغط للمشاهدة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFF06B6D4))),
                  ]),
                ),
              ),
            ],
            // Staff response
            if (item['diagnosis'] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.25)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                    SizedBox(width: 5),
                    Text('تشخيص الموظف',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                  ]),
                  const SizedBox(height: 4),
                  Text(item['diagnosis'] ?? '',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                  if (item['estimated_price'] != null)
                    Text('السعر التقديري: ${item['estimated_price']}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            if (status == 'pending' || status == 'under_review') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onRespond(item['id']),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('الرد على الطلب',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (status == 'responded') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onClose(item['id']),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('إغلاق الطلب',
                      style: TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showVideoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam, color: Colors.white, size: 52),
              const SizedBox(height: 12),
              const Text('فيديو العميل',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 12),
              SelectableText(url,
                  style: const TextStyle(
                      color: Colors.blueAccent, fontSize: 12)),
              const SizedBox(height: 8),
              const Text('انسخ الرابط وافتحه في المتصفح لمشاهدة الفيديو',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white70,
                      fontSize: 11),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
