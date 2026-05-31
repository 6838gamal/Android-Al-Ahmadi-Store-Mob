import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';

final _customerReservationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/reservations/', queryParameters: {'limit': '50'});
    final all = List<Map<String, dynamic>>.from(res.data);
    return all.where((r) => r['user_id'] == userId).toList();
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
      ),
      body: user == null
          ? _GuestView()
          : _ReservationsList(userId: user.id),
    );
  }
}

class _GuestView extends StatelessWidget {
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
  final int userId;
  const _ReservationsList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_customerReservationsProvider(userId));
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
              itemBuilder: (ctx, i) =>
                  _ReservationCard(reservation: reservations[i], index: i),
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

class _ReservationCard extends StatelessWidget {
  final Map<String, dynamic> reservation;
  final int index;
  const _ReservationCard(
      {required this.reservation, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = reservation['status'] as String? ?? 'pending';
    final statusAr = {
          'pending': 'في الانتظار',
          'confirmed': 'مؤكد',
          'cancelled': 'ملغي',
          'completed': 'مكتمل',
        }[status] ??
        status;
    final statusColor = {
          'pending': AppColors.warning,
          'confirmed': AppColors.success,
          'cancelled': AppColors.error,
          'completed': AppColors.textMuted,
        }[status] ??
        AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.phone_android,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reservation['product_name'] ?? 'منتج محجوز',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  reservation['reservation_number'] ??
                      '#${reservation['id'] ?? ''}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusAr,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor),
            ),
          ),
        ],
      ),
    ).animate(
        delay: Duration(milliseconds: index * 70)).fadeIn().slideX(begin: 0.1, end: 0);
  }
}
