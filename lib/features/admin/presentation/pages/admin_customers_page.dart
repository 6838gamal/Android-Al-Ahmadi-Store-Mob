import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import 'admin_shell.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../providers/admin_provider.dart';

class AdminCustomersPage extends ConsumerStatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  ConsumerState<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends ConsumerState<AdminCustomersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadCustomers());
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
          onPressed: () => AdminShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text('العملاء (${state.customers.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => ref.read(adminProvider.notifier).loadCustomers())],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري التحميل...')
          : state.customers.isEmpty
              ? const EmptyState(title: 'لا يوجد عملاء', icon: Icons.people_outline)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.customers.length,
                  itemBuilder: (ctx, i) {
                    final c = state.customers[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22, backgroundColor: AppColors.primary.withOpacity(0.2),
                            child: Text((c['name'] as String? ?? '?')[0], style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                            Text(c['email'] ?? c['phone'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
                          ])),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                        ],
                      ),
                    ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideX(begin: 0.1, end: 0);
                  },
                ),
    );
  }
}
