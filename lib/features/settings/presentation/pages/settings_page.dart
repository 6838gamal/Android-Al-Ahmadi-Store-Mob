import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Account section
          _SectionHeader(title: 'الحساب'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'الملف الشخصي',
            subtitle: user?.name ?? 'غير مسجّل',
            onTap: () => context.go('/profile'),
          ),
          if (user == null)
            _SettingsTile(
              icon: Icons.login,
              title: 'تسجيل الدخول',
              subtitle: 'سجّل دخولك للوصول لجميع الميزات',
              onTap: () => context.go('/login'),
            ),
          if (user != null)
            _SettingsTile(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              subtitle: 'تسجيل خروج من الحساب الحالي',
              color: AppColors.error,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'التطبيق'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'الإشعارات',
            subtitle: 'إدارة إشعارات الطلبات والعروض',
            onTap: () => context.go('/notifications'),
          ),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'الوضع الداكن',
            subtitle: 'مفعّل دائماً',
            trailing: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            ),
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'اللغة',
            subtitle: 'العربية',
            trailing: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, color: AppColors.primary, size: 22),
            ),
            onTap: null,
          ),

          const SizedBox(height: 16),
          _SectionHeader(title: 'الدعم'),
          _SettingsTile(
            icon: Icons.support_agent_outlined,
            title: 'تواصل معنا',
            subtitle: 'الدعم الفني وخدمة العملاء',
            onTap: () => context.go('/contact'),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'عن التطبيق',
            subtitle: 'اندرويد الاحمدي - الإصدار 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('عن التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.phone_android, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('اندرويد الاحمدي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('الإصدار 1.0.0', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            const Text('متخصصون في بيع وصيانة الجوالات وقطع الغيار', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4, right: 4),
      child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListTile(
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? AppColors.primary, size: 22),
        ),
        title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: c, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
        trailing: trailing ?? (onTap != null ? Icon(Icons.chevron_left, color: AppColors.textMuted) : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
