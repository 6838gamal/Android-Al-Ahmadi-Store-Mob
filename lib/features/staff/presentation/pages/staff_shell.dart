import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StaffShell extends ConsumerStatefulWidget {
  final Widget child;
  const StaffShell({super.key, required this.child});

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', route: '/staff/home'),
    _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'الطلبات', route: '/staff/orders'),
    _TabItem(icon: Icons.build_outlined, activeIcon: Icons.build, label: 'الصيانة', route: '/staff/maintenance'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'المخزون', route: '/staff/inventory'),
  ];

  void _onTabTap(int i) {
    setState(() => _selectedIndex = i);
    context.go(_tabs[i].route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: StaffShell.scaffoldKey,
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
                onTap: () => _onTabTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? tab.activeIcon : tab.icon,
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
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
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final roleLabel = auth.isBranchManager ? 'مدير الفرع' : 'موظف';
    final roleColor = auth.isBranchManager ? AppColors.warning : AppColors.info;

    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)]),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.badge_outlined, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: roleColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: roleColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(AppConstants.appName,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
                if (user != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(user.name,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(user.email ?? user.phone ?? '',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _item(Icons.home_outlined, 'الرئيسية', () { Navigator.pop(context); context.go('/staff/home'); }),
          _item(Icons.receipt_long_outlined, 'إدارة الطلبات', () { Navigator.pop(context); context.go('/staff/orders'); }),
          _item(Icons.build_outlined, 'طلبات الصيانة', () { Navigator.pop(context); context.go('/staff/maintenance'); }),
          _item(Icons.inventory_2_outlined, 'المخزون', () { Navigator.pop(context); context.go('/staff/inventory'); }),
          _item(Icons.bookmark_outlined, 'إدارة الحجوزات', () { Navigator.pop(context); context.go('/staff/reservations'); }),
          _item(Icons.search_outlined, 'طلبات الفحص', () { Navigator.pop(context); context.go('/staff/inspection'); }),
          const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
          if (user != null)
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
        title: Text(label,
            style: TextStyle(fontFamily: 'Cairo', color: color ?? AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: AppColors.darkCard,
      );
}

class _TabItem {
  final IconData icon, activeIcon;
  final String label, route;
  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.route});
}
