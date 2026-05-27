import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../providers/orders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _trackCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user?.phone != null) {
      Future.microtask(() => ref.read(ordersProvider.notifier).loadMyOrders(user!.phone!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('طلباتي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('طلب جديد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 13)),
            onPressed: () => context.push('/orders/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Track input
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تتبع طلبك', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _trackCtrl,
                        style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'ORD-2026-0001',
                          hintStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_trackCtrl.text.isNotEmpty) {
                          context.push('/orders/track/${_trackCtrl.text.trim()}');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('تتبع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Orders list
          Expanded(
            child: state.isLoading
                ? const LoadingWidget(message: 'جاري تحميل الطلبات...')
                : state.orders.isEmpty
                    ? EmptyState(
                        title: 'لا توجد طلبات',
                        subtitle: 'ابدأ بطلبك الأول',
                        icon: Icons.receipt_long_outlined,
                        actionLabel: 'طلب جديد',
                        onAction: () => context.push('/orders/create'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: state.orders.length,
                        itemBuilder: (ctx, i) => _OrderCard(order: state.orders[i], index: i),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final int index;

  const _OrderCard({required this.order, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'received';
    return GestureDetector(
      onTap: () => context.push('/orders/track/${order['order_number']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
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
            Text(
              AppUtils.formatDateTime(DateTime.parse(order['created_at'])),
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الإجمالي: ${AppUtils.formatPrice((order['total'] as num?)?.toDouble() ?? 0)}',
                  style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideX(begin: 0.1, end: 0),
    );
  }
}
