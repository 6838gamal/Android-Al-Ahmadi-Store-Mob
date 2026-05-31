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
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'customer';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).registerWithDetails(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim().isEmpty
              ? null
              : _emailCtrl.text.trim(),
          password: _passCtrl.text,
          role: _selectedRole,
        );
    if (!mounted) return;
    if (ok) {
      final auth = ref.read(authProvider);
      if (auth.isStaffOrAbove) {
        context.go('/staff');
      } else {
        context.go('/products');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ref.read(authProvider).error ?? 'فشل التسجيل، تحقق من البيانات',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isStaff = _selectedRole == 'staff';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'إنشاء حساب جديد',
          style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role Selector
                  const Text(
                    'نوع الحساب',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                        fontSize: 13),
                  ).animate().fadeIn(),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _RoleOption(
                          label: 'عميل',
                          subtitle: 'تسوق وتتبع طلباتك',
                          icon: Icons.person_outline,
                          selected: _selectedRole == 'customer',
                          onTap: () =>
                              setState(() => _selectedRole = 'customer'),
                        ),
                        _RoleOption(
                          label: 'موظف',
                          subtitle: 'إدارة الطلبات والصيانة',
                          icon: Icons.badge_outlined,
                          selected: _selectedRole == 'staff',
                          onTap: () =>
                              setState(() => _selectedRole = 'staff'),
                        ),
                      ],
                    ),
                  ).animate(delay: 40.ms).fadeIn().slideY(begin: 0.15, end: 0),

                  if (isStaff) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B1FA2).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF7B1FA2).withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 15,
                              color:
                                  const Color(0xFF9C4DCC).withOpacity(0.8)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'سيتطلب حساب الموظف موافقة الإدارة للوصول الكامل',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(),
                  ],

                  const SizedBox(height: 20),

                  // Account Info
                  const Text(
                    'معلومات الحساب',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                        fontSize: 13),
                  ).animate(delay: 80.ms).fadeIn(),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'الاسم الكامل *',
                    controller: _nameCtrl,
                    prefixIcon: Icons.person_outline,
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? 'الاسم مطلوب' : null,
                  ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'رقم الجوال *',
                    controller: _phoneCtrl,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'رقم الجوال مطلوب';
                      }
                      if (v.trim().length < 9) return 'رقم الجوال غير صحيح';
                      return null;
                    },
                  ).animate(delay: 140.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'البريد الإلكتروني (اختياري)',
                    controller: _emailCtrl,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null &&
                          v.trim().isNotEmpty &&
                          !v.contains('@')) {
                        return 'البريد الإلكتروني غير صحيح';
                      }
                      return null;
                    },
                  ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 20),
                  const Text(
                    'كلمة المرور',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textSecondary,
                        fontSize: 13),
                  ).animate(delay: 220.ms).fadeIn(),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'كلمة المرور *',
                    controller: _passCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'تأكيد كلمة المرور *',
                    controller: _confirmCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) {
                      if (v != _passCtrl.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 32),
                  AppButton(
                    text: isStaff ? 'إنشاء حساب موظف' : 'إنشاء الحساب',
                    isLoading: auth.isLoading,
                    onPressed: _register,
                    icon: isStaff
                        ? Icons.badge_outlined
                        : Icons.person_add_outlined,
                  ).animate(delay: 340.ms).fadeIn().slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('لديك حساب بالفعل؟',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('تسجيل الدخول',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ).animate(delay: 380.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF7B1FA2)],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? Colors.white : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  color: selected
                      ? Colors.white.withOpacity(0.75)
                      : AppColors.textMuted.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
