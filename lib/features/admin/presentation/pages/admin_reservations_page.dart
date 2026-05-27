import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/admin_provider.dart';

class AdminReservationsPage extends ConsumerStatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  ConsumerState<AdminReservationsPage> createState() => _AdminReservationsPageState();
}

class _AdminReservationsPageState extends ConsumerState<AdminReservationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadReservations());
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
        title: const Text('الحجوزات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => ref.read(adminProvider.notifier).loadReservations())],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : state.reservations.isEmpty
              ? const EmptyState(title: 'لا توجد حجوزات', icon: Icons.bookmark_outline)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.reservations.length,
                  itemBuilder: (ctx, i) {
                    final r = state.reservations[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r['reservation_number'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text('${r['customer_name'] ?? ''} | ${r['customer_phone'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(r['product_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(AppUtils.formatPrice((r['price'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ).animate(delay: Duration(milliseconds: i * 50)).fadeIn();
                  },
                ),
    );
  }
}
