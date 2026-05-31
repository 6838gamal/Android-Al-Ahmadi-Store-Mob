import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'staff_shell.dart';

final _staffStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final results = await Future.wait([
      api.get('/orders/', queryParameters: {'limit': '200'}),
      api.get('/maintenance/', queryParameters: {'limit': '200'}),
      api.get('/inventory/', queryParameters: {'limit': '200'}),
    ]);

    final orders = List<Map<String, dynamic>>.from(results[0].data);
    final maintenance = List<Map<String, dynamic>>.from(results[1].data);
    final inventory = List<Map<String, dynamic>>.from(results[2].data);

    final pendingOrders = orders
        .where((o) =>
            o['status'] != 'delivered' &&
            o['status'] != 'cancelled' &&
            o['order_type'] != 'maintenance')
        .length;
    final pendingMaint = maintenance
        .where((m) =>
            m['maintenance_status'] != 'delivered' &&
            m['maintenance_status'] != null)
        .length;
    final availableItems =
        inventory.where((i) => i['status'] == 'available').length;
    final soldToday = inventory.where((i) => i['status'] == 'sold').length;

    return {
      'pending_orders': pendingOrders,
      'pending_maintenance': pendingMaint,
      'available_inventory': availableItems,
      'sold_today': soldToday,
    };
  } catch (_) {
    return {
      'pending_orders': 0,
      'pending_maintenance': 0,
      'available_inventory': 0,
      'sold_today': 0,
    };
  }
});

class StaffHomePage extends ConsumerWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final statsAsync = ref.watch(_staffStatsProvider);
    final roleLabel = auth.isBranchManager ? 'مدير الفرع' : 'موظف';
    final roleColor = auth.isBranchManager ? AppColors.warning : AppColors.info;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_staffStatsProvider),
        color: AppColors.primary,
        backgroundColor: AppColors.darkCard,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            StaffShell.scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: roleColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: roleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'مرحباً، ${user?.name ?? ''}',
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ).animate().fadeIn().slideX(begin: -0.1, end: 0),
                    const SizedBox(height: 4),
                    const Text(
                      'إليك ملخص مهام اليوم',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white70,
                          fontSize: 14),
                    ).animate(delay: 100.ms).fadeIn(),
                  ],
                ),
              ),
            ),

            // Stats cards
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: statsAsync.when(
                loading: () => SliverToBoxAdapter(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _StatCardSkeleton(),
                      _StatCardSkeleton(),
                      _StatCardSkeleton(),
                      _StatCardSkeleton(),
                    ],
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
                data: (stats) => SliverToBoxAdapter(
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(
                        label: 'طلبات قيد التنفيذ',
                        value: stats['pending_orders']!,
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.primary,
                        index: 0,
                        onTap: () => context.go('/staff/orders'),
                      ),
                      _StatCard(
                        label: 'أجهزة للصيانة',
                        value: stats['pending_maintenance']!,
                        icon: Icons.build_outlined,
                        color: AppColors.warning,
                        index: 1,
                        onTap: () => context.go('/staff/maintenance'),
                      ),
                      _StatCard(
                        label: 'شاشات متاحة',
                        value: stats['available_inventory']!,
                        icon: Icons.inventory_2_outlined,
                        color: AppColors.success,
                        index: 2,
                        onTap: () => context.go('/staff/inventory'),
                      ),
                      _StatCard(
                        label: 'إجمالي مباع',
                        value: stats['sold_today']!,
                        icon: Icons.sell_outlined,
                        color: AppColors.info,
                        index: 3,
                        onTap: () => context.go('/staff/inventory'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Quick Actions
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الوصول السريع',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ).animate(delay: 300.ms).fadeIn(),
                    const SizedBox(height: 12),
                    _QuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'إدارة الطلبات',
                      subtitle: 'تحديث حالات الطلبات',
                      color: AppColors.primary,
                      index: 0,
                      onTap: () => context.go('/staff/orders'),
                    ),
                    _QuickAction(
                      icon: Icons.build_circle_outlined,
                      label: 'طلبات الصيانة',
                      subtitle: 'متابعة وتحديث حالة الصيانة',
                      color: AppColors.warning,
                      index: 1,
                      onTap: () => context.go('/staff/maintenance'),
                    ),
                    _QuickAction(
                      icon: Icons.inventory_2_outlined,
                      label: 'المخزون والشاشات',
                      subtitle: 'تسجيل المبيعات وإدارة المخزون',
                      color: AppColors.success,
                      index: 2,
                      onTap: () => context.go('/staff/inventory'),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: AppColors.textSecondary),
                  maxLines: 2,
                ),
              ],
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: 100 + index * 80))
          .fadeIn()
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
          duration: 1200.ms,
          color: Colors.white.withOpacity(0.05),
        );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textSecondary,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: 350 + index * 80))
          .fadeIn()
          .slideX(begin: 0.1, end: 0),
    );
  }
}
