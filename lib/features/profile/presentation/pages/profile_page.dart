import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_button.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
          ),
          title: const Text('حسابي',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBorder, width: 2),
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 48, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                const Text('يرجى تسجيل الدخول',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'سجّل دخولك للوصول لطلباتك وحجوزاتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textSecondary,
                      fontSize: 13),
                ),
                const SizedBox(height: 32),
                AppButton(
                    text: 'تسجيل الدخول',
                    onPressed: () => context.go('/login')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text(
                    'ليس لديك حساب؟ سجّل الآن',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final roleLabel = user.isCustomer
        ? 'عميل'
        : user.isStaff
            ? 'موظف'
            : user.isBranchManager
                ? 'مدير الفرع'
                : 'مدير';
    final roleColor = user.isCustomer
        ? AppColors.primary
        : user.isStaff
            ? AppColors.info
            : user.isBranchManager
                ? AppColors.warning
                : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('حسابي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
            // Avatar + name + role
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Icon(Icons.verified, size: 16, color: roleColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: roleColor),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 20),

            // Info fields
            _SectionTitle(title: 'المعلومات الشخصية'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_outline, label: 'الاسم', value: user.name),
            if (user.phone != null)
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'رقم الجوال',
                  value: user.phone!),
            if (user.email != null)
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'البريد الإلكتروني',
                  value: user.email!),

            // Quick links (customers only)
            if (user.isCustomer) ...[
              const SizedBox(height: 20),
              _SectionTitle(title: 'الوصول السريع'),
              const SizedBox(height: 12),
              _QuickLink(
                icon: Icons.receipt_long_outlined,
                label: 'طلباتي',
                color: AppColors.primary,
                onTap: () => context.go('/orders'),
              ),
              _QuickLink(
                icon: Icons.bookmark_outline,
                label: 'حجوزاتي',
                color: AppColors.info,
                onTap: () => context.go('/reservations'),
              ),
              _QuickLink(
                icon: Icons.build_outlined,
                label: 'طلبات الصيانة',
                color: AppColors.warning,
                onTap: () => context.go('/maintenance'),
              ),
              _QuickLink(
                icon: Icons.notifications_outlined,
                label: 'الإشعارات',
                color: AppColors.success,
                onTap: () => context.go('/notifications'),
              ),
            ],

            const SizedBox(height: 28),
            AppButton(
              text: 'تسجيل الخروج',
              isOutlined: true,
              color: AppColors.error,
              icon: Icons.logout,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ).animate(delay: 200.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      );
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder)),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}
