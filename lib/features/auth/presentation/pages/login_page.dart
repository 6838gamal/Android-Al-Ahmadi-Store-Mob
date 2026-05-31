import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(
          _idCtrl.text.trim(),
          _passCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      final auth = ref.read(authProvider);
      if (auth.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'حساب المدير يعمل عبر لوحة التحكم الويب فقط',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
        await ref.read(authProvider.notifier).logout();
        return;
      }
      if (auth.isStaff || auth.isBranchManager) {
        context.go('/staff');
      } else {
        context.go('/products');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authProvider).error ?? 'بيانات الدخول غير صحيحة',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5)
                      ],
                    ),
                    child: const Icon(Icons.phone_android,
                        size: 48, color: Colors.white),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  const Text(
                    'أهلاً بك في اندرويد الاحمدي',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                        fontSize: 14),
                  ).animate(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 40),
                  AppTextField(
                    label: 'البريد الإلكتروني أو رقم الجوال',
                    controller: _idCtrl,
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? 'هذا الحقل مطلوب' : null,
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'كلمة المرور',
                    controller: _passCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? 'هذا الحقل مطلوب' : null,
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('نسيت كلمة المرور؟',
                          style: TextStyle(
                              fontFamily: 'Cairo', color: AppColors.primary)),
                    ),
                  ).animate(delay: 450.ms).fadeIn(),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'دخول',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                  ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ليس لديك حساب؟',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text('إنشاء حساب',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ).animate(delay: 600.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
