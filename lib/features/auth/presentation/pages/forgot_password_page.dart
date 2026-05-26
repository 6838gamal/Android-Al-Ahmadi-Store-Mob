import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _ctrl = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => context.pop()),
        title: const Text('استعادة كلمة المرور', style: TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.lock_reset, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              if (!_sent) ...[
                const Text('أدخل بريدك الإلكتروني أو رقم جوالك لاستعادة كلمة المرور',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
                const SizedBox(height: 32),
                AppTextField(label: 'البريد الإلكتروني أو رقم الجوال', controller: _ctrl, prefixIcon: Icons.contact_mail_outlined),
                const SizedBox(height: 24),
                AppButton(text: 'إرسال رابط الاستعادة', onPressed: () => setState(() => _sent = true)),
              ] else ...[
                const Text('تم إرسال رابط الاستعادة!',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 12),
                const Text('تحقق من بريدك الإلكتروني أو رسائل الجوال',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                AppButton(text: 'العودة لتسجيل الدخول', onPressed: () => context.go('/login')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
