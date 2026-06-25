import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/server_health_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../products/presentation/providers/products_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  bool _wasOffline = false;
  Timer? _productRefreshTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(notificationsProvider.notifier).startPolling());
    // Real-time product refresh: poll every 60 seconds for new product data
    _productRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.read(productsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    ref.read(notificationsProvider.notifier).stopPolling();
    _productRefreshTimer?.cancel();
    super.dispose();
  }

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', route: '/products'),
    _TabItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'المنتجات', route: '/products'),
    _TabItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'طلباتي', route: '/orders'),
    _TabItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'الإشعارات', route: '/notifications'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'حسابي', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);
    final serverHealth = ref.watch(serverHealthProvider);

    // Auto-sync: when coming back online, reload all providers
    ref.listen<bool>(connectivityProvider, (prev, next) {
      if (prev == false && next == true) {
        ref.read(productsProvider.notifier).load();
        ref.read(notificationsProvider.notifier).load();
        ref.read(serverHealthProvider.notifier).retryNow();
      }
    });

    ref.listen<ServerHealthState>(serverHealthProvider, (prev, next) {
      if (prev?.isOffline == true && next.isOnline) {
        ref.read(productsProvider.notifier).load();
        ref.read(notificationsProvider.notifier).load();
      }
    });

    final showBanner = !isOnline || serverHealth.isOffline || serverHealth.isSlow ||
        (serverHealth.isChecking && serverHealth.retryCount > 0);

    return Scaffold(
      key: MainShell.scaffoldKey,
      backgroundColor: AppColors.darkBg,
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            child: showBanner
                ? _ServerStatusBanner(
                    isNetworkOff: !isOnline,
                    serverHealth: serverHealth,
                    onRetry: () =>
                        ref.read(serverHealthProvider.notifier).retryNow(),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final unread = ref.watch(notificationsProvider).unreadCount;
    // notifications tab is index 3
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
              final showBadge = i == 3 && unread > 0;
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            selected ? tab.activeIcon : tab.icon,
                            color: selected ? AppColors.primary : AppColors.textMuted,
                            size: 24,
                          ),
                          if (showBadge)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
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
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                if (user != null) ...[
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(user.name[0],
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Text(user.name,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(user.email ?? user.phone ?? '',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70)),
                ] else ...[
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/login');
                    },
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text('تسجيل الدخول',
                        style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          // Menu Items
          const SizedBox(height: 8),
          _DrawerItem(icon: Icons.home_outlined, label: 'الرئيسية', onTap: () { Navigator.pop(context); context.go('/products'); }),
          _DrawerItem(icon: Icons.inventory_2_outlined, label: 'المنتجات', onTap: () { Navigator.pop(context); context.go('/products'); }),
          _DrawerItem(icon: Icons.receipt_long_outlined, label: 'طلباتي', onTap: () { Navigator.pop(context); context.go('/orders'); }),
          _DrawerItem(icon: Icons.track_changes_rounded, label: 'تتبع الطلبات', onTap: () { Navigator.pop(context); context.go('/orders'); }),
          _DrawerItem(icon: Icons.bookmark_outline, label: 'الحجوزات', onTap: () { Navigator.pop(context); context.go('/reservations'); }),
          _DrawerItem(icon: Icons.build_outlined, label: 'الصيانة', onTap: () { Navigator.pop(context); context.go('/maintenance'); }),
          _DrawerItem(icon: Icons.verified_user_outlined, label: 'الضمان', onTap: () { Navigator.pop(context); context.go('/warranty'); }),
          _DrawerItem(icon: Icons.account_balance_wallet_outlined, label: 'محفظتي', onTap: () { Navigator.pop(context); context.go('/wallet'); }),
          _DrawerItem(icon: Icons.people_outline, label: 'الإحالات', onTap: () { Navigator.pop(context); context.go('/referrals'); }),
          _DrawerItem(icon: Icons.medical_services_outlined, label: 'عيادة الفحص', onTap: () { Navigator.pop(context); context.go('/inspection'); }),
          _DrawerItem(icon: Icons.photo_library_outlined, label: 'معرض الصور', onTap: () { Navigator.pop(context); context.go('/gallery'); }),
          _DrawerItem(icon: Icons.campaign_outlined, label: 'الإعلانات والعروض', onTap: () { Navigator.pop(context); context.go('/announcements'); }),
          _DrawerItem(icon: Icons.notifications_outlined, label: 'الإشعارات', onTap: () { Navigator.pop(context); context.go('/notifications'); }),
          const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
          _DrawerItem(icon: Icons.person_outline, label: 'الملف الشخصي', onTap: () { Navigator.pop(context); context.go('/profile'); }),
          _DrawerItem(icon: Icons.settings_outlined, label: 'الإعدادات', onTap: () { Navigator.pop(context); context.go('/settings'); }),
          _DrawerItem(icon: Icons.support_agent_outlined, label: 'تواصل معنا', onTap: () { Navigator.pop(context); context.go('/contact'); }),
          const Divider(color: AppColors.darkDivider, indent: 16, endIndent: 16),
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
          const SizedBox(height: 16),
        ],
      ),
    );
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
      title: Text(label,
          style: TextStyle(fontFamily: 'Cairo', color: c, fontSize: 14, fontWeight: FontWeight.w600)),
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
          const Text('معلومات المحل',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
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
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

// ── Server Status Banner ───────────────────────────────────────────────────────

class _ServerStatusBanner extends StatefulWidget {
  final bool isNetworkOff;
  final ServerHealthState serverHealth;
  final VoidCallback onRetry;

  const _ServerStatusBanner({
    required this.isNetworkOff,
    required this.serverHealth,
    required this.onRetry,
  });

  @override
  State<_ServerStatusBanner> createState() => _ServerStatusBannerState();
}

class _ServerStatusBannerState extends State<_ServerStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChecking = widget.serverHealth.isChecking &&
        widget.serverHealth.retryCount > 0;
    final isOffline =
        widget.isNetworkOff || widget.serverHealth.isOffline;
    final isSlow = widget.serverHealth.isSlow;
    final retryCount = widget.serverHealth.retryCount;
    final responseMs = widget.serverHealth.lastResponseMs ?? 0;

    // Colors
    final Color bannerColor = widget.isNetworkOff
        ? const Color(0xFF6D1B00)
        : isChecking
            ? const Color(0xFF1A3A5C)
            : isSlow
                ? const Color(0xFF3D2800)
                : const Color(0xFF7B1500);

    final Color borderColor = widget.isNetworkOff
        ? const Color(0xFFFF5722)
        : isChecking
            ? AppColors.primary
            : isSlow
                ? const Color(0xFFFF9800)
                : const Color(0xFFFF3D00);

    final IconData bannerIcon = widget.isNetworkOff
        ? Icons.wifi_off_rounded
        : isChecking
            ? Icons.autorenew_rounded
            : isSlow
                ? Icons.speed_rounded
                : Icons.cloud_off_rounded;

    final String mainText = widget.isNetworkOff
        ? 'لا يوجد اتصال بالإنترنت'
        : isChecking
            ? 'جاري إعادة الاتصال بالخادم...'
            : isSlow
                ? 'الخادم بطيء — اتصال ضعيف'
                : 'الخادم غير متاح حالياً';

    final String subText = widget.isNetworkOff
        ? 'تحقق من إعدادات الشبكة'
        : isChecking
            ? 'المحاولة $retryCount — يُعاد تلقائياً'
            : isSlow
                ? 'وقت الاستجابة ${responseMs ~/ 1000}s — قد تكون بعض البيانات بطيئة'
                : 'يُعاد الاتصال تلقائياً كل ٨ ثوانٍ';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = isOffline
            ? 0.85 + 0.15 * math.sin(_pulseCtrl.value * math.pi)
            : 1.0;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bannerColor,
            border: Border(
              bottom: BorderSide(color: borderColor.withOpacity(0.6), width: 1),
            ),
          ),
          child: Opacity(
            opacity: pulse,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    // Icon (spinning if checking)
                    isChecking
                        ? RotationTransition(
                            turns: _pulseCtrl,
                            child: Icon(bannerIcon,
                                color: AppColors.primaryLight, size: 18),
                          )
                        : Icon(bannerIcon, color: borderColor, size: 18),

                    const SizedBox(width: 10),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mainText,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isChecking
                                  ? Colors.white70
                                  : Colors.white,
                            ),
                          ),
                          Text(
                            subText,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Retry button (only when offline, not checking)
                    if (isOffline && !isChecking)
                      GestureDetector(
                        onTap: widget.onRetry,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: borderColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: borderColor.withOpacity(0.5), width: 1),
                          ),
                          child: const Text(
                            'إعادة',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
