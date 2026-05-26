import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
      _nameCtrl.text.trim(),
      _idCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) context.go('/products');
    else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(authProvider).error ?? 'فشل التسجيل', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => context.go('/login')),
        title: const Text('إنشاء حساب جديد', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'الاسم الكامل',
                    controller: _nameCtrl,
                    prefixIcon: Icons.person_outline,
                    validator: (v) => (v?.isEmpty ?? true) ? 'الاسم مطلوب' : null,
                  ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'البريد الإلكتروني أو رقم الجوال',
                    controller: _idCtrl,
                    prefixIcon: Icons.contact_mail_outlined,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'هذا الحقل مطلوب';
                      return null;
                    },
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'كلمة المرور',
                    controller: _passCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) {
                      if (v == null || v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      return null;
                    },
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'تأكيد كلمة المرور',
                    controller: _confirmCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) {
                      if (v != _passCtrl.text) return 'كلمتا المرور غير متطابقتين';
                      return null;
                    },
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 32),
                  AppButton(
                    text: 'إنشاء الحساب',
                    isLoading: auth.isLoading,
                    onPressed: _register,
                  ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('لديك حساب بالفعل؟', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('تسجيل الدخول', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700)),
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
