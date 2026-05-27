import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 80, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text('يرجى تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 18)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AppButton(text: 'تسجيل الدخول', onPressed: () => context.go('/login')),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('حسابي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary,
              child: Text(user.name[0], style: const TextStyle(fontFamily: 'Cairo', fontSize: 32, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(user.email ?? user.phone ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            _InfoRow(label: 'الاسم', value: user.name),
            if (user.email != null) _InfoRow(label: 'البريد الإلكتروني', value: user.email!),
            if (user.phone != null) _InfoRow(label: 'رقم الجوال', value: user.phone!),
            const SizedBox(height: 32),
            AppButton(
              text: 'تسجيل الخروج',
              isOutlined: true,
              color: AppColors.error,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
