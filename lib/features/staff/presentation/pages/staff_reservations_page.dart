import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import 'staff_shell.dart';

final _staffReservationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/reservations/', queryParameters: {'limit': '200'});
  return res.data is List ? res.data : [];
});

class StaffReservationsPage extends ConsumerStatefulWidget {
  const StaffReservationsPage({super.key});

  @override
  ConsumerState<StaffReservationsPage> createState() => _StaffReservationsPageState();
}

class _StaffReservationsPageState extends ConsumerState<StaffReservationsPage> {
  String _filter = '';

  static const _statusLabels = {
    '': 'الكل',
    'pending': 'قيد الانتظار',
    'confirmed': 'مؤكد',
    'completed': 'مكتمل',
    'cancelled': 'ملغي',
    'expired': 'منتهي',
  };

  static const _statusColors = {
    'pending': Color(0xFFF59E0B),
    'confirmed': Color(0xFF1A73E8),
    'completed': Color(0xFF10B981),
    'cancelled': Color(0xFFEF4444),
    'expired': Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_staffReservationsProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => StaffShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('إدارة الحجوزات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(_staffReservationsProvider),
          ),
        ],
      ),
      body: Column(children: [
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
                    onPressed: () => ref.invalidate(_staffReservationsProvider),
                    child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo'))),
              ]),
            ),
            data: (items) {
              final filtered = _filter.isEmpty
                  ? items
                  : items.where((r) => (r['status'] ?? '') == _filter).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 56),
                    const SizedBox(height: 12),
                    const Text('لا توجد حجوزات',
                        style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16)),
                  ]),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _ReservationCard(
                  reservation: filtered[i],
                  statusColors: _statusColors,
                  statusLabels: _statusLabels,
                  onComplete: _completeReservation,
                  onExtend: _extendReservation,
                  onCancel: (id) => _showCancelDialog(ctx, id),
                ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideY(begin: 0.05, end: 0),
              );
            },
          ),
        ),
      ]),
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

  Future<void> _completeReservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('استكمال الحجز', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('هل تأكد أن العميل استلم المنتج وتم البيع؟',
            style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('تأكيد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/reservations/$id/complete');
      ref.invalidate(_staffReservationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم استكمال الحجز وتسجيل البيع', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل: $e', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _extendReservation(int id) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.put('/reservations/$id/extend');
      ref.invalidate(_staffReservationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.data['message'] ?? 'تم التمديد', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التمديد: $e', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context, int id) {
    String cancelType = 'full_return';
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('اختر نوع الإلغاء:',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          _cancelOption(ctx, setS, cancelType, 'full_return', 'إرجاع المبلغ كاملاً للمحفظة',
              Icons.account_balance_wallet_outlined, AppColors.success,
              (v) => cancelType = v),
          const SizedBox(height: 6),
          _cancelOption(ctx, setS, cancelType, 'cash_return', 'صرف المبلغ كاش للعميل مباشرة',
              Icons.payments_outlined, AppColors.info,
              (v) => cancelType = v),
          const SizedBox(height: 6),
          _cancelOption(ctx, setS, cancelType, 'with_penalty', 'إلغاء مع خصم غرامة 2000 ريال',
              Icons.money_off, AppColors.error,
              (v) => cancelType = v),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'سبب الإلغاء (اختياري)',
              labelStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.darkBorder)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final res = await api.put('/reservations/$id/cancel', data: {
                  'cancellation_type': cancelType,
                  'reason': reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                });
                ref.invalidate(_staffReservationsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res.data['message'] ?? 'تم الإلغاء',
                          style: const TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل: $e', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      )),
    );
  }

  Widget _cancelOption(BuildContext ctx, StateSetter setS, String current, String value,
      String label, IconData icon, Color color, void Function(String) onSelect) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => setS(() => onSelect(value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? color.withOpacity(0.12) : AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? color : AppColors.darkBorder),
        ),
        child: Row(children: [
          Icon(icon, color: sel ? color : AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: sel ? color : AppColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal))),
          if (sel) Icon(Icons.check_circle, color: color, size: 16),
        ]),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final Map<String, dynamic> reservation;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final void Function(int) onComplete;
  final void Function(int) onExtend;
  final void Function(int) onCancel;

  const _ReservationCard({
    required this.reservation,
    required this.statusColors,
    required this.statusLabels,
    required this.onComplete,
    required this.onExtend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = (reservation['status'] ?? 'pending') as String;
    final statusColor = statusColors[status] ?? AppColors.textMuted;
    final statusLabel = statusLabels[status] ?? status;
    final canExtend =
        (status == 'pending' || status == 'confirmed') && (reservation['extension_count'] ?? 0) < 1;
    final canAct = status == 'pending' || status == 'confirmed';

    final expiresAt = reservation['expires_at'] as String?;
    final depositPaid = reservation['deposit_paid'] as bool? ?? false;
    final depositAmount = (reservation['deposit_amount'] as num?)?.toDouble() ?? 0;
    final remainingAmount = (reservation['remaining_amount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.darkCardAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.bookmark_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reservation['reservation_number'] ?? '#',
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                Text(reservation['product_name'] ?? '',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
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
              Text(reservation['customer_name'] ?? '',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(reservation['customer_phone'] ?? '',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 10),
            // Financial summary
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('السعر الكلي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                  Text('${(reservation['price'] as num?)?.toStringAsFixed(0) ?? '—'} ريال',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('العربون', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: depositPaid ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(depositPaid ? 'مدفوع' : 'غير مدفوع',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                              color: depositPaid ? AppColors.success : AppColors.error)),
                    ),
                    const SizedBox(width: 6),
                    Text('${depositAmount.toStringAsFixed(0)} ريال',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white)),
                  ]),
                ]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('المتبقي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                  Text('${remainingAmount.toStringAsFixed(0)} ريال',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w700)),
                ]),
                if (expiresAt != null) ...[
                  const Divider(color: AppColors.darkBorder, height: 12),
                  Row(children: [
                    const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text('ينتهي: ${expiresAt.substring(0, 10)}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                    if ((reservation['extension_count'] ?? 0) > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.info.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: const Text('تم التمديد',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.info)),
                      ),
                    ],
                  ]),
                ],
              ]),
            ),
            if (canAct) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onComplete(reservation['id']),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('استكمال البيع',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (canExtend) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onExtend(reservation['id']),
                      icon: const Icon(Icons.more_time, size: 16),
                      label: const Text('تمديد',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: BorderSide(color: AppColors.info.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => onCancel(reservation['id']),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('إلغاء',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
