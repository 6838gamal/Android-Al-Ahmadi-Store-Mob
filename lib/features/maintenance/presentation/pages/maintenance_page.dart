import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';

final _customerMaintenanceProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, phone) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/maintenance/',
        queryParameters: {'customer_phone': phone, 'limit': '50'});
    final all = List<Map<String, dynamic>>.from(res.data);
    return all.where((m) => m['customer_phone'] == phone).toList();
  } catch (_) {
    return [];
  }
});

class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});

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
        title: const Text('الصيانة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: user?.phone == null
          ? _buildGuestView(context)
          : _buildMaintenanceList(ref, user!.phone!),
    );
  }

  Widget _buildGuestView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: const Icon(Icons.build_outlined,
                  size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'تتبع طلبات الصيانة',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'سجّل دخولك باستخدام رقم الجوال لمتابعة طلبات الصيانة',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13),
            ),
            const SizedBox(height: 24),
            const Text(
              'للتواصل مع المحل',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppConstants.shopPhone,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceList(WidgetRef ref, String phone) {
    final state = ref.watch(_customerMaintenanceProvider(phone));
    return state.when(
      loading: () =>
          const LoadingWidget(message: 'جاري تحميل طلبات الصيانة...'),
      error: (_, __) => const EmptyState(
        title: 'تعذر تحميل البيانات',
        subtitle: 'تحقق من الاتصال وحاول مجدداً',
        icon: Icons.error_outline,
      ),
      data: (orders) => orders.isEmpty
          ? const EmptyState(
              title: 'لا توجد طلبات صيانة',
              subtitle: 'تواصل مع المحل لتسجيل طلب صيانة جديد',
              icon: Icons.build_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: orders.length,
              itemBuilder: (ctx, i) =>
                  _MaintenanceCard(order: orders[i], index: i),
            ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final int index;
  const _MaintenanceCard({required this.order, required this.index});

  @override
  Widget build(BuildContext context) {
    final maintStatus = order['maintenance_status'] as String? ?? 'received';
    final statusAr = AppConstants.maintenanceStatusAr[maintStatus] ?? maintStatus;
    final items = (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final deviceName = items.isNotEmpty
        ? (items[0]['device'] ?? items[0]['name'] ?? 'جهاز')
        : 'جهاز';
    final problem = items.isNotEmpty ? (items[0]['problem'] ?? '') : '';

    final statusColors = {
      'received': AppColors.info,
      'inspecting': AppColors.warning,
      'repairing': AppColors.primary,
      'waiting_part': AppColors.warning,
      'repaired': AppColors.success,
      'ready': AppColors.success,
      'delivered': AppColors.textMuted,
    };
    final color = statusColors[maintStatus] ?? AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order['order_number'] ?? '',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusAr,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_android, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                deviceName,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ],
          ),
          if (problem.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              problem,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (order['estimated_time'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'وقت الجاهزية: ${order['estimated_time']}',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 70)).fadeIn().slideX(begin: 0.1, end: 0);
  }
}
