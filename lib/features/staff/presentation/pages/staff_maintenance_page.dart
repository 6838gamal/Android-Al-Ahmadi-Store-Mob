import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/media_pick_btn.dart';
import '../pages/staff_shell.dart';

final _staffMaintenanceProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/maintenance', queryParameters: {'limit': 100});
  final data = res.data;
  if (data is List) return data;
  if (data is Map) return (data['items'] as List?) ?? [];
  return [];
});

class StaffMaintenancePage extends ConsumerStatefulWidget {
  const StaffMaintenancePage({super.key});

  @override
  ConsumerState<StaffMaintenancePage> createState() => _StaffMaintenancePageState();
}

class _StaffMaintenancePageState extends ConsumerState<StaffMaintenancePage> {
  String _statusFilter = '';

  static const _statusLabels = {
    '': 'الكل',
    'received': 'مستلم',
    'inspecting': 'قيد الفحص',
    'repairing': 'جاري الإصلاح',
    'waiting_part': 'انتظار قطعة',
    'repaired': 'تم الإصلاح',
    'ready': 'جاهز للاستلام',
    'delivered': 'تم التسليم',
    'unrepairable_visit': 'غير قابل - زيارة',
    'unrepairable_other': 'غير قابل - أخرى',
  };

  static const _statusColors = {
    'received': Color(0xFF6B7280),
    'inspecting': Color(0xFFF59E0B),
    'repairing': Color(0xFF8B5CF6),
    'waiting_part': Color(0xFFEF4444),
    'repaired': Color(0xFF06B6D4),
    'ready': Color(0xFF10B981),
    'delivered': Color(0xFF22C55E),
    'unrepairable_visit': Color(0xFFDC2626),
    'unrepairable_other': Color(0xFF991B1B),
  };

  @override
  Widget build(BuildContext context) {
    final maintenanceAsync = ref.watch(_staffMaintenanceProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => StaffShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('طلبات الصيانة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(_staffMaintenanceProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: maintenanceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text('حدث خطأ: $e',
                        style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(_staffMaintenanceProvider),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final filtered = _statusFilter.isEmpty
                    ? items
                    : items.where((o) => (o['maintenance_status'] ?? o['status']) == _statusFilter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.build_outlined, color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 12),
                        const Text('لا توجد طلبات صيانة',
                            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _MaintenanceCard(
                    order: filtered[i],
                    statusColors: _statusColors,
                    statusLabels: _statusLabels,
                    onStatusUpdate: _promptStatusUpdate,
                  ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 48,
      color: AppColors.darkSurface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        children: _statusLabels.entries.map((e) {
          final sel = _statusFilter == e.key;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = e.key),
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

  /// Shows a dialog asking for note + optional images/video before confirming the status change.
  Future<void> _promptStatusUpdate(int orderId, String newStatus) async {
    final notesCtrl = TextEditingController();
    final label = _statusLabels[newStatus] ?? newStatus;
    final color = _statusColors[newStatus] ?? AppColors.primary;
    final List<XFile> selectedImages = [];
    XFile? selectedVideo;
    bool isUploading = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Notes
              const Text('تعليق / ملاحظة (اختياري)',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقاً للعميل أو للسجل...',
                  hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.darkSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.darkBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.darkBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: color.withOpacity(0.6))),
                ),
              ),
              const SizedBox(height: 14),
              // Media buttons row
              const Text('وسائط (اختياري)',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: MediaPickBtn(
                    icon: selectedImages.isEmpty
                        ? Icons.add_photo_alternate_outlined
                        : Icons.check_circle_outline,
                    label: selectedImages.isEmpty ? 'صور' : '${selectedImages.length} صور ✓',
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
                    color: selectedVideo == null ? const Color(0xFF06B6D4) : AppColors.success,
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
                        width: 58, height: 58,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                          image: kIsWeb ? null : DecorationImage(
                            image: FileImage(File(selectedImages[i].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: kIsWeb
                            ? const Icon(Icons.image, color: AppColors.primary, size: 22)
                            : null,
                      ),
                      Positioned(
                        top: 0, right: 8,
                        child: GestureDetector(
                          onTap: () => setSt(() => selectedImages.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, color: Colors.white, size: 10),
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
                  const Icon(Icons.videocam, color: Color(0xFF06B6D4), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(selectedVideo!.name,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                            color: Color(0xFF06B6D4)),
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => setSt(() => selectedVideo = null),
                    child: const Icon(Icons.close, color: AppColors.textMuted, size: 14),
                  ),
                ]),
              ],
              if (isUploading) ...[
                const SizedBox(height: 12),
                const Row(children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 10),
                  Text('جاري رفع الوسائط...',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                ]),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isUploading ? null : () => Navigator.pop(ctx, true),
              child: const Text('تأكيد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      // Upload media before status update
      final api = ref.read(apiClientProvider);
      final List<String> mediaUrls = [];
      for (final img in selectedImages) {
        final url = await _uploadFile(api, img);
        if (url != null) mediaUrls.add(url);
      }
      if (selectedVideo != null) {
        final url = await _uploadFile(api, selectedVideo!);
        if (url != null) mediaUrls.add(url);
      }
      await _updateMaintenanceStatus(
        orderId, newStatus,
        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        mediaUrls,
      );
    }
    notesCtrl.dispose();
  }

  Future<void> _updateMaintenanceStatus(
      int orderId, String newStatus, String? note, List<String> mediaUrls) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/maintenance/$orderId/status', data: {
        'maintenance_status': newStatus,
        if (note != null) 'note': note,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      });
      ref.invalidate(_staffMaintenanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث حالة الصيانة',
                style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التحديث: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final Future<void> Function(int, String) onStatusUpdate;

  const _MaintenanceCard({
    required this.order,
    required this.statusColors,
    required this.statusLabels,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final rawStatus = order['maintenance_status'] ?? order['status'] ?? 'received';
    final status = rawStatus as String;
    final statusColor = statusColors[status] ?? AppColors.textMuted;
    final statusLabel = statusLabels[status] ?? status;
    final items = order['items'] as List<dynamic>? ?? [];
    final deviceInfo = items.isNotEmpty
        ? '${items[0]['device'] ?? ''} — ${items[0]['problem'] ?? ''}'
        : '';

    // Show staff notes if present
    final adminNotes = order['admin_notes'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.darkCardAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Color(0xFF8B5CF6), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(order['order_number'] ?? '#',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(order['customer_name'] ?? '',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(order['customer_phone'] ?? '',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                if (deviceInfo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                    ),
                    child: Text(deviceInfo,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
                // Staff notes
                if (adminNotes != null && adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(adminNotes,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Color(0xFFF59E0B))),
                        ),
                      ],
                    ),
                  ),
                ],
                // Customer-uploaded media (photos/video)
                _buildMediaStrip(order['images']),
                if (order['total'] != null && order['total'] != 0) ...[
                  const SizedBox(height: 8),
                  Text('التكلفة: ${order['total']} ريال',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ],
            ),
          ),
          if (!['delivered', 'unrepairable_visit', 'unrepairable_other'].contains(status))
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _buildActionButtons(context, status),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    final nextStatuses = _getNextStatuses(status);
    if (nextStatuses.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: nextStatuses.map((s) {
        final color = statusColors[s] ?? AppColors.primary;
        final isUnrepairable = s.startsWith('unrepairable');
        return OutlinedButton(
          onPressed: () => onStatusUpdate(order['id'], s),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.6)),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUnrepairable)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.cancel_outlined, size: 13, color: color),
                ),
              Text(statusLabels[s] ?? s,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaStrip(dynamic images) {
    if (images == null) return const SizedBox.shrink();
    final list = images is List ? images.cast<String>() : <String>[];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Text('وسائط العميل (${list.length})',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final url = list[i];
              final isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('.webm') || url.contains('.avi');
              return GestureDetector(
                onTap: () => _showMediaDialog(ctx, list, i),
                child: Container(
                  width: 70,
                  height: 70,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: isVideo
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_outline, color: AppColors.primary, size: 28),
                            Text('فيديو', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.textMuted)),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(url, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.textMuted)),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMediaDialog(BuildContext context, List<String> urls, int initial) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 400,
          child: PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: urls.length,
            itemBuilder: (ctx, i) {
              final url = urls[i];
              final isVideo = url.contains('.mp4') || url.contains('.mov') || url.contains('.webm');
              return isVideo
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam, color: Colors.white, size: 60),
                          const SizedBox(height: 12),
                          const Text('فيديو — افتح الرابط للمشاهدة',
                              style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 12),
                          SelectableText(url,
                              style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                        ],
                      ),
                    )
                  : InteractiveViewer(
                      child: Image.network(url, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white)),
                    );
            },
          ),
        ),
      ),
    );
  }

  List<String> _getNextStatuses(String current) {
    const all = [
      'received', 'inspecting', 'repairing', 'waiting_part',
      'repaired', 'ready', 'delivered',
      'unrepairable_visit', 'unrepairable_other',
    ];
    return all.where((s) => s != current).toList();
  }
}
