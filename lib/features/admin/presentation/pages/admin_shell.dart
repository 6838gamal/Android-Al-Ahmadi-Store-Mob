import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminShell extends ConsumerStatefulWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'لوحة التحكم', route: '/admin'),
    _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'الطلبات', route: '/admin/orders'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'المنتجات', route: '/admin/products'),
    _TabItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: 'الصيانة', route: '/admin/maintenance'),
    _TabItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'العملاء', route: '/admin/customers'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AdminShell.scaffoldKey,
      backgroundColor: AppColors.darkBg,
      drawer: _buildDrawer(context),
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final selected = _selectedIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  context.go(tab.route);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(selected ? tab.activeIcon : tab.icon,
                        color: selected ? AppColors.primary : AppColors.textMuted, size: 22),
                      const SizedBox(height: 3),
                      Text(tab.label, style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 9,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                        color: selected ? AppColors.primary : AppColors.textMuted,
                      )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFF1A73E8)]),
            ),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('لوحة الإدارة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
                    Text(AppConstants.appName, style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _item(Icons.dashboard_outlined, 'لوحة التحكم', () { Navigator.pop(context); context.go('/admin'); }),
          _item(Icons.receipt_long_outlined, 'إدارة الطلبات', () { Navigator.pop(context); context.go('/admin/orders'); }),
          _item(Icons.inventory_2_outlined, 'إدارة المنتجات', () { Navigator.pop(context); context.go('/admin/products'); }),
          _item(Icons.build_outlined, 'الصيانة', () { Navigator.pop(context); context.go('/admin/maintenance'); }),
          _item(Icons.bookmark_outline, 'الحجوزات', () { Navigator.pop(context); context.go('/admin/reservations'); }),
          _item(Icons.people_outline, 'العملاء', () { Navigator.pop(context); context.go('/admin/customers'); }),
          const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
          _item(Icons.exit_to_app, 'العودة لتطبيق العميل', () { Navigator.pop(context); context.go('/products'); }, color: AppColors.warning),
          _item(Icons.logout, 'تسجيل الخروج', () async {
            Navigator.pop(context);
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          }, color: AppColors.error),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
    leading: Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
    title: Text(label, style: TextStyle(fontFamily: 'Cairo', color: color ?? AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

class _TabItem {
  final IconData icon, activeIcon;
  final String label, route;
  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.route});
}
