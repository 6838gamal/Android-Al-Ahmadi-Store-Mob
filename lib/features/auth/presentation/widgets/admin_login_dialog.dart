import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class AdminLoginDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const AdminLoginDialog({super.key, required this.onSuccess});

  @override
  ConsumerState<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends ConsumerState<AdminLoginDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _error;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _error = null);
    final ok = await ref.read(authProvider.notifier).adminLogin(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      setState(() => _error = ref.read(authProvider).error ?? 'بيانات الإدارة غير صحيحة');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
            ],
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                const Text('دخول الإدارة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('للمصرح لهم فقط',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.error.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Text(_error!, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  label: 'البريد الإلكتروني',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'كلمة المرور',
                  controller: _passCtrl,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                  validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'إلغاء',
                        isOutlined: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'دخول',
                        isLoading: auth.isLoading,
                        onPressed: _login,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate().scale(begin: const Offset(0.9, 0.9), duration: 300.ms, curve: Curves.easeOut).fadeIn(),
    );
  }
}
