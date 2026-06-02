import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../providers/warranty_provider.dart';

class WarrantyPage extends ConsumerStatefulWidget {
  const WarrantyPage({super.key});

  @override
  ConsumerState<WarrantyPage> createState() => _WarrantyPageState();
}

class _WarrantyPageState extends ConsumerState<WarrantyPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(warrantyProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warrantyProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الضمان',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(warrantyProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري تحميل بيانات الضمان...')
          : state.error != null
              ? _ErrorView(
                  message: state.error!,
                  onRetry: () => ref.read(warrantyProvider.notifier).load(),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  onRefresh: () => ref.read(warrantyProvider.notifier).load(),
                  child: state.warranties.isEmpty
                      ? const Center(
                          child: EmptyState(
                            title: 'لا توجد ضمانات',
                            subtitle: 'ستظهر هنا ضمانات المنتجات التي اشتريتها',
                            icon: Icons.verified_user_outlined,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: state.warranties.length,
                          itemBuilder: (ctx, i) => _WarrantyCard(
                            warranty: state.warranties[i],
                            index: i,
                            onRequestReturn: (id, reason) async {
                              final ok = await ref
                                  .read(warrantyProvider.notifier)
                                  .requestReturn(
                                      warrantyId: id, reason: reason);
                              if (context.mounted) {
                                AppUtils.showSnackBar(
                                  context,
                                  ok
                                      ? 'تم تقديم طلب الإرجاع بنجاح'
                                      : 'فشل تقديم الطلب',
                                  isError: !ok,
                                );
                              }
                            },
                          ),
                        ),
                ),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  final Map<String, dynamic> warranty;
  final int index;
  final void Function(int id, String reason) onRequestReturn;

  const _WarrantyCard({
    required this.warranty,
    required this.index,
    required this.onRequestReturn,
  });

  @override
  Widget build(BuildContext context) {
    final id = warranty['id'] as int? ?? 0;
    final productName = warranty['product_name'] as String? ?? 'منتج';
    final serial = warranty['product_serial'] as String? ?? '';
    final days = warranty['warranty_days'] as int? ?? 7;
    final isReturnRequested = warranty['is_return_requested'] as bool? ?? false;
    final returnResolved = warranty['return_resolved'] as bool? ?? false;
    final returnStatus = returnResolved
        ? 'approved'
        : isReturnRequested
            ? 'pending'
            : 'none';

    DateTime? endsAt;
    final endsAtStr = warranty['ends_at'] as String?;
    if (endsAtStr != null) {
      try {
        endsAt = DateTime.parse(endsAtStr);
      } catch (_) {}
    }

    final isExpired = endsAt != null && DateTime.now().isAfter(endsAt);
    final daysLeft = endsAt != null
        ? endsAt.difference(DateTime.now()).inDays
        : 0;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isExpired) {
      statusColor = AppColors.textMuted;
      statusLabel = 'منتهي';
      statusIcon = Icons.cancel_outlined;
    } else if (daysLeft <= 2) {
      statusColor = AppColors.error;
      statusLabel = 'ينتهي قريباً';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppColors.success;
      statusLabel = 'ساري';
      statusIcon = Icons.verified_user;
    }

    Color returnColor;
    String returnLabel;
    switch (returnStatus) {
      case 'pending':
        returnColor = AppColors.warning;
        returnLabel = 'طلب إرجاع قيد المراجعة';
        break;
      case 'approved':
        returnColor = AppColors.success;
        returnLabel = 'تم قبول الإرجاع';
        break;
      case 'rejected':
        returnColor = AppColors.error;
        returnLabel = 'تم رفض الإرجاع';
        break;
      default:
        returnColor = Colors.transparent;
        returnLabel = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 15),
                          ),
                          if (serial.isNotEmpty)
                            Text(
                              'S/N: $serial',
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.textMuted,
                                  fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.darkBorder, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: '$days يوم ضمان'),
                    const SizedBox(width: 8),
                    if (endsAt != null)
                      _InfoChip(
                        icon: isExpired
                            ? Icons.event_busy_outlined
                            : Icons.event_available_outlined,
                        label: isExpired
                            ? 'انتهى ${AppUtils.formatDate(endsAt)}'
                            : 'ينتهي ${AppUtils.formatDate(endsAt)}',
                        color: isExpired
                            ? AppColors.textMuted
                            : daysLeft <= 2
                                ? AppColors.error
                                : AppColors.success,
                      ),
                  ],
                ),
                if (returnStatus != 'none' && returnLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: returnColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: returnColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      returnLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: returnColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isExpired && returnStatus == 'none')
            InkWell(
              onTap: () => _showReturnDialog(context, id, productName),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_return_outlined,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'طلب إرجاع',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn().slideY(begin: 0.05, end: 0);
  }

  void _showReturnDialog(
      BuildContext context, int id, String productName) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('طلب إرجاع',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(
                  fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'سبب الإرجاع...',
                hintStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textMuted,
                    fontSize: 13),
                filled: true,
                fillColor: AppColors.darkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                onRequestReturn(id, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إرسال الطلب',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Cairo', color: c, fontSize: 12)),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}
