import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/admin_login_dialog.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', route: '/products'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'المنتجات', route: '/products'),
    _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'طلباتي', route: '/orders'),
    _TabItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'الإشعارات', route: '/notifications'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'حسابي', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: MainShell.scaffoldKey,
      backgroundColor: AppColors.darkBg,
      drawer: _buildDrawer(context),
      body: widget.child,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBottomNav(),
          _buildStoreBranding(context),
        ],
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
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

    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Info (double tap for admin)
                GestureDetector(
                  onDoubleTap: () => _showAdminLogin(context),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.phone_android, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(AppConstants.appName,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text(AppConstants.ownerName,
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                // User Info
                if (user != null) ...[
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(user.name[0], style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Text(user.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(user.email ?? user.phone ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                ] else ...[
                  TextButton.icon(
                    onPressed: () { Navigator.pop(context); context.go('/login'); },
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(icon: Icons.home_outlined, label: 'الرئيسية', onTap: () { Navigator.pop(context); context.go('/products'); }),
                _DrawerItem(icon: Icons.inventory_2_outlined, label: 'المنتجات', onTap: () { Navigator.pop(context); context.go('/products'); }),
                _DrawerItem(icon: Icons.receipt_long_outlined, label: 'طلباتي', onTap: () { Navigator.pop(context); context.go('/orders'); }),
                _DrawerItem(icon: Icons.track_changes_rounded, label: 'تتبع الطلبات', onTap: () { Navigator.pop(context); context.go('/orders'); }),
                _DrawerItem(icon: Icons.bookmark_outline, label: 'الحجوزات', onTap: () { Navigator.pop(context); context.go('/reservations'); }),
                _DrawerItem(icon: Icons.build_outlined, label: 'الصيانة', onTap: () { Navigator.pop(context); context.go('/maintenance'); }),
                _DrawerItem(icon: Icons.notifications_outlined, label: 'الإشعارات', onTap: () { Navigator.pop(context); context.go('/notifications'); }),
                const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
                _DrawerItem(icon: Icons.person_outline, label: 'الملف الشخصي', onTap: () { Navigator.pop(context); context.go('/profile'); }),
                _DrawerItem(icon: Icons.settings_outlined, label: 'الإعدادات', onTap: () { Navigator.pop(context); }),
                _DrawerItem(icon: Icons.support_agent_outlined, label: 'تواصل معنا', onTap: () { Navigator.pop(context); }),
                const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
                // Shop Info Section
                _ShopInfoSection(),
                if (user != null) ...[
                  const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: 'تسجيل الخروج',
                    color: AppColors.error,
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreBranding(BuildContext context) {
    return GestureDetector(
      onDoubleTap: () => _showAdminLogin(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          border: const Border(top: BorderSide(color: AppColors.darkBorder, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminLogin(BuildContext context) {
    showDialog(context: context, builder: (_) => AdminLoginDialog(
      onSuccess: () {
        if (context.mounted) context.go('/admin');
      },
    ));
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _TabItem({required this.icon, required this.activeIcon, required this.label, required this.route});
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(fontFamily: 'Cairo', color: c, fontSize: 14, fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: AppColors.darkCard,
    );
  }
}

class _ShopInfoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('معلومات المحل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
          const SizedBox(height: 12),
          _infoRow(Icons.phone_outlined, AppConstants.shopPhone),
          _infoRow(Icons.location_on_outlined, AppConstants.shopAddress),
          _infoRow(Icons.access_time_outlined, 'س-أ: 10ص-10م | خ: 10ص-11م'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
