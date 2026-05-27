import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/admin_provider.dart';

class AdminMaintenancePage extends ConsumerStatefulWidget {
  const AdminMaintenancePage({super.key});

  @override
  ConsumerState<AdminMaintenancePage> createState() => _AdminMaintenancePageState();
}

class _AdminMaintenancePageState extends ConsumerState<AdminMaintenancePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadMaintenance());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('إدارة الصيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.primary, size: 28), onPressed: () => _showAddDialog(context)),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => ref.read(adminProvider.notifier).loadMaintenance()),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : state.maintenanceOrders.isEmpty
              ? EmptyState(title: 'لا توجد طلبات صيانة', icon: Icons.build_outlined, actionLabel: 'إضافة طلب صيانة', onAction: () => _showAddDialog(context))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.maintenanceOrders.length,
                  itemBuilder: (ctx, i) => _MaintenanceCard(order: state.maintenanceOrders[i], index: i),
                ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final deviceCtrl = TextEditingController();
    final problemCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('إضافة طلب صيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            AppTextField(label: 'اسم العميل', controller: nameCtrl, prefixIcon: Icons.person_outline),
            const SizedBox(height: 10),
            AppTextField(label: 'رقم الجوال', controller: phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppTextField(label: 'نوع الجهاز', controller: deviceCtrl, prefixIcon: Icons.phone_android),
            const SizedBox(height: 10),
            AppTextField(label: 'وصف المشكلة', controller: problemCtrl, prefixIcon: Icons.description_outlined, maxLines: 2),
            const SizedBox(height: 10),
            AppTextField(label: 'السعر التقديري', controller: priceCtrl, prefixIcon: Icons.attach_money, keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            AppButton(
              text: 'حفظ',
              onPressed: () async {
                Navigator.pop(ctx);
                // Would call maintenance create API
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends ConsumerWidget {
  final Map<String, dynamic> order;
  final int index;
  const _MaintenanceCard({required this.order, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintStatus = order['maintenance_status'] as String? ?? 'received';
    final items = (order['items'] as List?) ?? [];
    final device = items.isNotEmpty ? (items[0] as Map)['device'] ?? '' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(order['order_number'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
              const Spacer(),
              StatusBadge(status: maintStatus, isOrder: true),
            ],
          ),
          const SizedBox(height: 8),
          Text('${order['customer_name'] ?? ''} | ${order['customer_phone'] ?? ''}',
            style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
          if (device.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_android, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(device, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text('الإجمالي: ${AppUtils.formatPrice((order['total'] as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              const Spacer(),
              if (order['created_at'] != null)
                Text(AppUtils.timeAgo(DateTime.parse(order['created_at'])),
                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 50)).fadeIn().slideY(begin: 0.05, end: 0);
  }
}
