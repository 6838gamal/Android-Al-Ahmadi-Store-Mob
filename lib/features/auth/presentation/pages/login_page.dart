import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import 'phone_otp_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isStaffMode = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;

    bool ok;
    if (_isStaffMode) {
      ok = await ref.read(authProvider.notifier).staffLogin(
            _idCtrl.text.trim(),
            _passCtrl.text,
          );
    } else {
      ok = await ref.read(authProvider.notifier).login(
            _idCtrl.text.trim(),
            _passCtrl.text,
          );
    }

    if (!mounted) return;

    if (ok) {
      final auth = ref.read(authProvider);
      if (auth.isStaffOrAbove) {
        context.go('/staff');
      } else {
        context.go('/products');
      }
    } else {
      final auth = ref.read(authProvider);
      // Phone not verified — redirect to OTP verification page
      if (auth.error == 'PHONE_NOT_VERIFIED') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhoneOtpPage(
              mode: 'verify',
              prefilledPhone: auth.unverifiedPhone ?? _idCtrl.text.trim(),
              redirectTo: '/products',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.error ?? 'بيانات الدخول غير صحيحة',
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
                  const SizedBox(height: 32),

                  // Logo
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: _isStaffMode
                          ? const LinearGradient(
                              colors: [Color(0xFF7B1FA2), Color(0xFF1A73E8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_isStaffMode
                                  ? const Color(0xFF7B1FA2)
                                  : AppColors.primary)
                              .withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                    child: Icon(
                      _isStaffMode ? Icons.badge_outlined : Icons.phone_android,
                      size: 44,
                      color: Colors.white,
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 20),
                  Text(
                    'تسجيل الدخول',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ).animate(delay: 80.ms).fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 6),
                  Text(
                    _isStaffMode
                        ? 'دخول الموظفين ومديري الفروع'
                        : 'أهلاً بك في اندرويد الاحمدي',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ).animate(delay: 140.ms).fadeIn(),

                  const SizedBox(height: 28),

                  // Role Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _RoleTab(
                          label: 'عميل',
                          icon: Icons.person_outline,
                          selected: !_isStaffMode,
                          onTap: () => setState(() => _isStaffMode = false),
                        ),
                        _RoleTab(
                          label: 'موظف',
                          icon: Icons.badge_outlined,
                          selected: _isStaffMode,
                          onTap: () => setState(() => _isStaffMode = true),
                        ),
                      ],
                    ),
                  ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.15, end: 0),

                  const SizedBox(height: 28),

                  AppTextField(
                    label: 'البريد الإلكتروني أو رقم الجوال',
                    controller: _idCtrl,
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? 'هذا الحقل مطلوب' : null,
                  ).animate(delay: 260.ms).fadeIn().slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 16),

                  AppTextField(
                    label: 'كلمة المرور',
                    controller: _passCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? 'هذا الحقل مطلوب' : null,
                  ).animate(delay: 320.ms).fadeIn().slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('نسيت كلمة المرور؟',
                          style: TextStyle(
                              fontFamily: 'Cairo', color: AppColors.primary)),
                    ),
                  ).animate(delay: 360.ms).fadeIn(),

                  const SizedBox(height: 4),

                  AppButton(
                    text: _isStaffMode ? 'دخول الموظف' : 'دخول',
                    isLoading: auth.isLoading,
                    onPressed: _login,
                    icon: _isStaffMode ? Icons.badge_outlined : Icons.login,
                  ).animate(delay: 420.ms).fadeIn().slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 24),

                  if (!_isStaffMode) ...[
                    // ── OTP login divider ──
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.darkBorder)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('أو',
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    color: AppColors.textMuted,
                                    fontSize: 12)),
                          ),
                          const Expanded(child: Divider(color: AppColors.darkBorder)),
                        ],
                      ),
                    ).animate(delay: 460.ms).fadeIn(),

                    // OTP login button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PhoneOtpPage(mode: 'login'),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.darkBorder),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.phone_android,
                            color: AppColors.primary, size: 18),
                        label: const Text('الدخول برمز SMS',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                    ).animate(delay: 480.ms).fadeIn().slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 8),

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
                    ).animate(delay: 520.ms).fadeIn(),
                  ],

                  if (_isStaffMode)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B1FA2).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF7B1FA2).withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16,
                              color: const Color(0xFF9C4DCC).withOpacity(0.8)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'حسابات الموظفين يتم إنشاؤها من قِبل الإدارة أو يمكنك التسجيل كموظف جديد',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 480.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
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
          padding: const EdgeInsets.symmetric(vertical: 11),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
