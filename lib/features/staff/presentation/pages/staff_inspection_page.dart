import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'staff_shell.dart';

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
    'responded': 'تم الرد',
    'closed': 'مغلق',
  };

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
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
                    onRespond: _respondToInspection,
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

  Future<void> _respondToInspection(int id, String diagnosis, String? price, String? notes) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/inspection/$id/respond', data: {
        'diagnosis': diagnosis,
        'estimated_price': price,
        'response_notes': notes,
      });
      ref.invalidate(_inspectionListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم إرسال الرد بنجاح', style: TextStyle(fontFamily: 'Cairo')),
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
            content: Text('فشل الإرسال: $e', style: const TextStyle(fontFamily: 'Cairo')),
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
  final void Function(int, String, String?, String?) onRespond;
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
            if (status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showRespondDialog(context),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('الرد على الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else if (status == 'responded') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onClose(item['id']),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('إغلاق الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.darkBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  void _showRespondDialog(BuildContext context) {
    final diagCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('الرد على طلب الفحص',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: diagCtrl,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'التشخيص *',
                labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.darkBorder)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'السعر التقديري',
                labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.darkBorder)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'ملاحظات إضافية',
                labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.darkBorder)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (diagCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              onRespond(item['id'], diagCtrl.text.trim(), priceCtrl.text.trim().isEmpty ? null : priceCtrl.text.trim(),
                  notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('إرسال الرد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
