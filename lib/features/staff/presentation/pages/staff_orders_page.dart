import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../pages/staff_shell.dart';

final _staffOrdersProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/orders', queryParameters: {'limit': 100});
  final data = res.data;
  if (data is List) return data;
  if (data is Map) return (data['items'] as List?) ?? [];
  return [];
});

class StaffOrdersPage extends ConsumerStatefulWidget {
  const StaffOrdersPage({super.key});

  @override
  ConsumerState<StaffOrdersPage> createState() => _StaffOrdersPageState();
}

class _StaffOrdersPageState extends ConsumerState<StaffOrdersPage> {
  String _statusFilter = '';

  static const _statusLabels = {
    '': 'الكل',
    'received': 'مستلم',
    'reviewing': 'قيد المراجعة',
    'confirmed': 'مؤكد',
    'preparing': 'جاري التحضير',
    'shipped': 'تم الشحن',
    'on_the_way': 'في الطريق',
    'delivered': 'تم التسليم',
    'cancelled': 'ملغي',
  };

  static const _statusColors = {
    'received': Color(0xFF6B7280),
    'reviewing': Color(0xFFF59E0B),
    'confirmed': Color(0xFF3B82F6),
    'preparing': Color(0xFF8B5CF6),
    'shipped': Color(0xFF06B6D4),
    'on_the_way': Color(0xFF10B981),
    'delivered': Color(0xFF22C55E),
    'cancelled': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(_staffOrdersProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => StaffShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('إدارة الطلبات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(_staffOrdersProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: ordersAsync.when(
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
                      onPressed: () => ref.invalidate(_staffOrdersProvider),
                      child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              ),
              data: (orders) {
                final filtered = _statusFilter.isEmpty
                    ? orders
                    : orders.where((o) => o['status'] == _statusFilter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 56),
                        const SizedBox(height: 12),
                        const Text('لا توجد طلبات', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _OrderCard(
                    order: filtered[i],
                    statusColors: _statusColors,
                    statusLabels: _statusLabels,
                    onStatusUpdate: (orderId, newStatus) => _updateOrderStatus(orderId, newStatus),
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

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/orders/$orderId/status', data: {'status': newStatus});
      ref.invalidate(_staffOrdersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث حالة الطلب', style: TextStyle(fontFamily: 'Cairo')),
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
            content: Text('فشل التحديث: $e', style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, Color> statusColors;
  final Map<String, String> statusLabels;
  final void Function(int, String) onStatusUpdate;

  const _OrderCard({
    required this.order,
    required this.statusColors,
    required this.statusLabels,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'received';
    final statusColor = statusColors[status] ?? AppColors.textMuted;
    final statusLabel = statusLabels[status] ?? status;
    final orderType = order['order_type'] as String? ?? 'product';

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
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.darkCardAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order['order_number'] ?? '#',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                      Text(order['customer_name'] ?? '',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
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
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(order['customer_phone'] ?? '',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: orderType == 'maintenance' ? const Color(0xFF8B5CF6).withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        orderType == 'maintenance' ? 'صيانة' : 'طلب منتج',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: orderType == 'maintenance' ? const Color(0xFF8B5CF6) : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order['total'] != null) ...[
                  const SizedBox(height: 8),
                  Text('المجموع: ${order['total']} ريال',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ],
            ),
          ),
          // Action Buttons
          if (!['delivered', 'cancelled'].contains(status))
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

    return Row(
      children: nextStatuses.map((s) {
        final color = statusColors[s] ?? AppColors.primary;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: () => onStatusUpdate(order['id'], s),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withOpacity(0.6)),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(statusLabels[s] ?? s,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<String> _getNextStatuses(String current) {
    const flow = {
      'received': ['reviewing', 'cancelled'],
      'reviewing': ['confirmed', 'cancelled'],
      'confirmed': ['preparing'],
      'preparing': ['shipped'],
      'shipped': ['on_the_way'],
      'on_the_way': ['delivered'],
    };
    return flow[current] ?? [];
  }
}
