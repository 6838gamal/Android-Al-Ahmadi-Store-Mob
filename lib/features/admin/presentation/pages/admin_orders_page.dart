import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../providers/admin_provider.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() => ref.read(adminProvider.notifier).loadOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    final allOrders = state.orders.where((o) => o['order_type'] == 'product').toList();
    final activeOrders = allOrders.where((o) => !['delivered', 'cancelled'].contains(o['status'])).toList();
    final deliveredOrders = allOrders.where((o) => o['status'] == 'delivered').toList();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('إدارة الطلبات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.read(adminProvider.notifier).loadOrders()),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'الكل (${allOrders.length})'),
            Tab(text: 'نشطة (${activeOrders.length})'),
            Tab(text: 'مكتملة (${deliveredOrders.length})'),
          ],
        ),
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : TabBarView(
              controller: _tabController,
              children: [
                _OrdersList(orders: allOrders),
                _OrdersList(orders: activeOrders),
                _OrdersList(orders: deliveredOrders),
              ],
            ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  final List<Map<String, dynamic>> orders;
  const _OrdersList({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const EmptyState(title: 'لا توجد طلبات', icon: Icons.receipt_long_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (ctx, i) => _AdminOrderCard(order: orders[i], index: i, ref: ref),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final int index;
  final WidgetRef ref;

  const _AdminOrderCard({required this.order, required this.index, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'received';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(order['order_number'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14)),
                    const Spacer(),
                    StatusBadge(status: status, isOrder: true),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(order['customer_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
                    const Spacer(),
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(order['customer_phone'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('الإجمالي: ${AppUtils.formatPrice((order['total'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    if (order['created_at'] != null)
                      Text(AppUtils.timeAgo(DateTime.parse(order['created_at'])),
                        style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons
          if (status != 'delivered' && status != 'cancelled')
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
              child: Row(
                children: [
                  Expanded(child: TextButton.icon(
                    icon: const Icon(Icons.update, size: 16, color: AppColors.primary),
                    label: const Text('تحديث الحالة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 12)),
                    onPressed: () => _showUpdateDialog(context, order),
                  )),
                  Container(width: 1, height: 36, color: AppColors.darkBorder),
                  Expanded(child: TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                    label: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12)),
                    onPressed: () => ref.read(adminProvider.notifier).updateOrderStatus(order['id'], 'cancelled'),
                  )),
                ],
              ),
            ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideY(begin: 0.05, end: 0);
  }

  void _showUpdateDialog(BuildContext context, Map<String, dynamic> order) {
    final statuses = AppConstants.orderStatusAr.keys.toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تحديث حالة الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((s) => ListTile(
            title: Text(AppConstants.orderStatusAr[s] ?? s, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            leading: Radio<String>(
              value: s,
              groupValue: order['status'],
              onChanged: (v) {
                Navigator.pop(ctx);
                if (v != null) {
                  ref.read(adminProvider.notifier).updateOrderStatus(order['id'], v, note: 'تم تحديث الحالة');
                }
              },
              activeColor: AppColors.primary,
            ),
          )).toList(),
        ),
      ),
    );
  }
}
