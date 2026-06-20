import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';

final _customerReservationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/reservations/my');
    return List<Map<String, dynamic>>.from(res.data);
  } catch (_) {
    return [];
  }
});

class ReservationsPage extends ConsumerWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('حجوزاتي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => ref.invalidate(_customerReservationsProvider),
            ),
        ],
      ),
      body: user == null ? const _GuestView() : const _ReservationsList(),
    );
  }
}

class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(Icons.bookmark_border,
                  size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'حجوزاتي',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل دخولك لعرض حجوزاتك',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              child: const Text('تسجيل الدخول',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationsList extends ConsumerWidget {
  const _ReservationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_customerReservationsProvider);
    return state.when(
      loading: () => const LoadingWidget(message: 'جاري تحميل الحجوزات...'),
      error: (_, __) => const EmptyState(
        title: 'لا توجد حجوزات',
        subtitle: 'يمكنك حجز المنتجات من صفحة المنتجات',
        icon: Icons.bookmark_border,
      ),
      data: (reservations) => reservations.isEmpty
          ? _EmptyReservations()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: reservations.length,
              itemBuilder: (ctx, i) => _ReservationCard(
                reservation: reservations[i],
                index: i,
                onCancelled: () => ref.invalidate(_customerReservationsProvider),
              ),
            ),
    );
  }
}

class _EmptyReservations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(Icons.bookmark_border,
                  size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد حجوزات',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'يمكنك حجز المنتجات من صفحة المنتجات',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => context.go('/products'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('تصفح المنتجات',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> reservation;
  final int index;
  final VoidCallback onCancelled;

  const _ReservationCard({
    required this.reservation,
    required this.index,
    required this.onCancelled,
  });

  @override
  ConsumerState<_ReservationCard> createState() => _ReservationCardState();
}

class _ReservationCardState extends ConsumerState<_ReservationCard> {
  bool _cancelling = false;

  static const _statusColors = {
    'pending': AppColors.warning,
    'confirmed': AppColors.success,
    'cancelled': AppColors.error,
    'completed': AppColors.textMuted,
    'expired': AppColors.textMuted,
  };

  static const _statusLabels = {
    'pending': 'في الانتظار',
    'confirmed': 'مؤكد',
    'cancelled': 'ملغي',
    'completed': 'مكتمل',
    'expired': 'منتهي',
  };

  String _daysRemaining(String? expiresAtStr) {
    if (expiresAtStr == null) return '';
    try {
      final expires = DateTime.parse(expiresAtStr).toLocal();
      final diff = expires.difference(DateTime.now());
      if (diff.isNegative) return 'انتهت المهلة';
      if (diff.inDays == 0) return 'ينتهي اليوم!';
      return 'ينتهي خلال ${diff.inDays} يوم';
    } catch (_) {
      return '';
    }
  }

  Color _expiryColor(String? expiresAtStr) {
    if (expiresAtStr == null) return AppColors.textMuted;
    try {
      final expires = DateTime.parse(expiresAtStr).toLocal();
      final diff = expires.difference(DateTime.now());
      if (diff.isNegative) return AppColors.error;
      if (diff.inDays <= 2) return AppColors.error;
      if (diff.inDays <= 5) return AppColors.warning;
      return AppColors.success;
    } catch (_) {
      return AppColors.textMuted;
    }
  }

  Future<void> _cancelReservation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إلغاء الحجز',
            style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.white,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا الحجز؟\nسيعود المنتج للمخزون.',
          style: TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textSecondary,
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع',
                style:
                    TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('إلغاء الحجز',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/reservations/my/${widget.reservation['id']}/cancel');
      if (mounted) {
        AppUtils.showSnackBar(context, 'تم إلغاء الحجز بنجاح');
        widget.onCancelled();
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'فشل الإلغاء — تواصل مع المتجر لإلغاء الحجز',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final status = r['status'] as String? ?? 'pending';
    final statusColor = _statusColors[status] ?? AppColors.textMuted;
    final statusLabel = _statusLabels[status] ?? status;
    final expiresAt = r['expires_at'] as String?;
    final depositAmount = (r['deposit_amount'] as num?)?.toDouble() ?? 0;
    final depositPaid = r['deposit_paid'] as bool? ?? false;
    final remainingAmount = (r['remaining_amount'] as num?)?.toDouble() ?? 0;
    final price = (r['price'] as num?)?.toDouble() ?? 0;
    final extensionCount = (r['extension_count'] as num?)?.toInt() ?? 0;
    final canCancel = status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.darkCardAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_android,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['product_name'] ?? 'منتج محجوز',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      r['reservation_number'] ?? '#${r['id']}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textMuted,
                          fontSize: 11),
                    ),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.35)),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor),
              ),
            ),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Financial summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(children: [
                _FinRow(
                  label: 'السعر الكلي',
                  value: AppUtils.formatPrice(price),
                  valueStyle: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
                const SizedBox(height: 6),
                _FinRow(
                  label: 'العربون',
                  value: AppUtils.formatPrice(depositAmount),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: depositPaid
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      depositPaid ? 'مدفوع' : 'غير مدفوع',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: depositPaid
                              ? AppColors.success
                              : AppColors.warning),
                    ),
                  ),
                  valueStyle: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontSize: 13),
                ),
                if (remainingAmount > 0) ...[
                  const SizedBox(height: 6),
                  _FinRow(
                    label: 'المتبقي',
                    value: AppUtils.formatPrice(remainingAmount),
                    valueStyle: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ],
              ]),
            ),

            // Expiry countdown
            if (expiresAt != null &&
                (status == 'pending' || status == 'confirmed')) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _expiryColor(expiresAt).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _expiryColor(expiresAt).withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: _expiryColor(expiresAt)),
                  const SizedBox(width: 6),
                  Text(
                    _daysRemaining(expiresAt),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _expiryColor(expiresAt)),
                  ),
                  if (extensionCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('تم التمديد',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 9,
                              color: AppColors.info)),
                    ),
                  ],
                ]),
              ),
            ],

            // Cancel button for pending reservations
            if (canCancel) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelReservation,
                  icon: _cancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error))
                      : const Icon(Icons.cancel_outlined, size: 16),
                  label: Text(
                    _cancelling ? 'جارٍ الإلغاء...' : 'إلغاء الحجز',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withOpacity(0.5), width: 1),
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
    ).animate(
        delay: Duration(milliseconds: widget.index * 60)).fadeIn().slideX(begin: 0.05, end: 0);
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final TextStyle valueStyle;

  const _FinRow({
    required this.label,
    required this.value,
    this.trailing,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textMuted)),
        Row(children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Text(value, style: valueStyle),
        ]),
      ],
    );
  }
}
