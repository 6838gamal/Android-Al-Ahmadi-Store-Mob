import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/admin_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            leading: Builder(builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            )),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref.read(adminProvider.notifier).loadStats(),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF1A73E8)]),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text('لوحة التحكم', style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(AppConstants.appName, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.isLoading)
            const SliverFillRemaining(child: LoadingWidget(message: 'جاري التحميل...'))
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Grid
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(label: 'إجمالي الإيرادات', value: AppUtils.formatPrice(state.stats['total_revenue']?.toDouble() ?? 0), icon: Icons.attach_money, gradient: AppColors.primaryGradient),
                      _StatCard(label: 'الطلبات النشطة', value: '${state.stats['active_orders'] ?? 0}', icon: Icons.receipt_long_outlined, gradient: const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E63)])),
                      _StatCard(label: 'إجمالي الطلبات', value: '${state.stats['total_orders'] ?? 0}', icon: Icons.shopping_bag_outlined, gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)])),
                      _StatCard(label: 'المنتجات', value: '${state.stats['total_products'] ?? 0}', icon: Icons.inventory_2_outlined, gradient: const LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)])),
                      _StatCard(label: 'العملاء', value: '${state.stats['total_customers'] ?? 0}', icon: Icons.people_outline, gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF2196F3)])),
                      _StatCard(label: 'الصيانة', value: '${state.stats['maintenance_count'] ?? 0}', icon: Icons.build_outlined, gradient: const LinearGradient(colors: [Color(0xFF880E4F), Color(0xFFF48FB1)])),
                    ],
                  ).animate().fadeIn(),
                  const SizedBox(height: 20),
                  // Quick Actions
                  const Text('إجراءات سريعة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _QuickAction(icon: Icons.add_box_outlined, label: 'إضافة منتج', onTap: () => context.push('/admin/products/add'))),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickAction(icon: Icons.receipt_outlined, label: 'إدارة الطلبات', onTap: () => context.go('/admin/orders'))),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickAction(icon: Icons.build_outlined, label: 'صيانة جديدة', onTap: () => context.go('/admin/maintenance'))),
                    ],
                  ).animate(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 24),
                  // Alerts
                  if ((state.stats['low_stock_count'] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            '${state.stats['low_stock_count']} منتجات بمخزون منخفض!',
                            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.warning, fontWeight: FontWeight.w700),
                          )),
                        ],
                      ),
                    ).animate(delay: 300.ms).fadeIn(),
                  const SizedBox(height: 20),
                  // Recent Orders
                  const Text('آخر الطلبات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (state.recentOrders.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا توجد طلبات حتى الآن', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted)),
                    ))
                  else
                    ...state.recentOrders.asMap().entries.map((e) => _RecentOrderRow(order: e.value, index: e.key)),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Gradient gradient;

  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  final int index;
  const _RecentOrderRow({required this.order, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order['order_number'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                Text(order['customer_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(AppUtils.formatPrice((order['total'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppUtils.getOrderStatusColor(order['status'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppConstants.orderStatusAr[order['status']] ?? order['status'] ?? '',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.w700, color: AppUtils.getOrderStatusColor(order['status'] ?? '')),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideX(begin: 0.1, end: 0);
  }
}
