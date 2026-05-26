import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/orders_provider.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  final String orderNumber;
  const OrderTrackingPage({super.key, required this.orderNumber});

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final order = await ref.read(ordersProvider.notifier).trackOrder(widget.orderNumber);
    if (mounted) setState(() { _order = order; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('تتبع الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: const BackButton(color: Colors.white),
      ),
      body: _loading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : _order == null
              ? const EmptyState(title: 'الطلب غير موجود', icon: Icons.error_outline)
              : _buildTracking(),
    );
  }

  Widget _buildTracking() {
    final o = _order!;
    final updates = (o['updates'] as List?) ?? [];
    final status = o['status'] as String? ?? 'received';
    final isMaint = o['order_type'] == 'maintenance';
    final allStatuses = isMaint
        ? AppConstants.maintenanceStatusAr.keys.toList()
        : AppConstants.orderStatusAr.keys.where((s) => s != 'cancelled').toList();
    final currentIdx = allStatuses.indexOf(status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(o['order_number'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(o['customer_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                Text(o['customer_phone'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
                if (o['estimated_time'] != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.access_time, color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text('الوقت المتوقع: ${o['estimated_time']}', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                  ]),
                ],
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),
          const SizedBox(height: 24),

          // Progress Steps
          const Text('مراحل الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          ...allStatuses.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isDone = idx <= currentIdx;
            final isCurrent = idx == currentIdx;
            final label = isMaint
                ? AppConstants.maintenanceStatusAr[s] ?? s
                : AppConstants.orderStatusAr[s] ?? s;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.primary : AppColors.darkCard,
                        border: Border.all(color: isDone ? AppColors.primary : AppColors.darkBorder, width: 2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : Text('${idx + 1}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                      ),
                    ),
                    if (idx < allStatuses.length - 1)
                      Container(
                        width: 2,
                        height: 36,
                        color: isDone ? AppColors.primary.withOpacity(0.5) : AppColors.darkBorder,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                            color: isDone ? Colors.white : AppColors.textMuted,
                            fontSize: isCurrent ? 15 : 14,
                          )),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('الحالة الحالية',
                              style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate(delay: Duration(milliseconds: idx * 80)).fadeIn().slideX(begin: -0.1, end: 0);
          }),

          // Updates Timeline
          if (updates.isNotEmpty) ...[
            const Divider(color: AppColors.darkDivider),
            const SizedBox(height: 16),
            const Text('سجل التحديثات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            ...updates.reversed.map((upd) {
              final updMap = upd as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.update, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          AppConstants.orderStatusAr[updMap['status']] ??
                          AppConstants.maintenanceStatusAr[updMap['status']] ??
                          updMap['status'] ?? '',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13),
                        ),
                        const Spacer(),
                        if (updMap['created_at'] != null)
                          Text(AppUtils.timeAgo(DateTime.parse(updMap['created_at'])),
                            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                    if (updMap['note'] != null) ...[
                      const SizedBox(height: 6),
                      Text(updMap['note'], style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
                    ],
                    if (updMap['employee_name'] != null) ...[
                      const SizedBox(height: 4),
                      Text('بواسطة: ${updMap['employee_name']}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ],
                ),
              ).animate().fadeIn();
            }),
          ],
        ],
      ),
    );
  }
}
