import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/pages/phone_otp_page.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: 'تعديل البيانات',
            onPressed: () => _showEditSheet(context, ref, user),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          children: [
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
                          border: Border.all(
                            color: user.isVerified ? AppColors.success : AppColors.darkBorder,
                            width: user.isVerified ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          user.isVerified ? Icons.verified : Icons.verified_outlined,
                          size: 16,
                          color: user.isVerified ? AppColors.success : AppColors.textMuted,
                        ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                      if (user.isVerified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withOpacity(0.35)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: AppColors.success),
                              SizedBox(width: 4),
                              Text('موثّق', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 20),

            _SectionTitle(title: 'المعلومات الشخصية'),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person_outline, label: 'الاسم', value: user.name),
            if (user.phone != null)
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'رقم الجوال',
                  value: user.phone!),
            if (user.phone != null && !user.isVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhoneOtpPage(
                        mode: 'verify',
                        prefilledPhone: user.phone,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.warning, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.verified_user_outlined,
                      color: AppColors.warning, size: 17),
                  label: const Text('تحقق من رقم جوالك',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            if (user.email != null)
              _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'البريد الإلكتروني',
                  value: user.email!),

            const SizedBox(height: 20),
            _SectionTitle(title: 'إعدادات الحساب'),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'تعديل البيانات الشخصية',
              color: AppColors.primary,
              onTap: () => _showEditSheet(context, ref, user),
            ),
            _ActionTile(
              icon: Icons.lock_outline,
              label: 'تغيير كلمة المرور',
              color: AppColors.warning,
              onTap: () => _showChangePasswordDialog(context, ref),
            ),

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

  void _showEditSheet(BuildContext context, WidgetRef ref, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email ?? '');
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final originalPhone = user.phone ?? '';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('تعديل البيانات الشخصية',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 17)),
              const SizedBox(height: 20),
              _buildField('الاسم الكامل', nameCtrl, Icons.person_outline),
              const SizedBox(height: 12),
              _buildField('رقم الجوال', phoneCtrl, Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildField('البريد الإلكتروني', emailCtrl, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () async {
                    final newPhone = phoneCtrl.text.trim();
                    setState(() => saving = true);
                    final result = await ref.read(authProvider.notifier).updateProfile(
                      name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : null,
                      email: emailCtrl.text.trim(),
                      phone: newPhone,
                    );
                    setState(() => saving = false);
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (result['success'] == true) {
                      // If phone changed, backend sets is_verified=false → redirect to OTP
                      final updatedUser = ref.read(authProvider).user;
                      final phoneChanged = newPhone.isNotEmpty && newPhone != originalPhone;
                      if (phoneChanged && updatedUser != null && !updatedUser.isVerified) {
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhoneOtpPage(
                                mode: 'verify',
                                prefilledPhone: updatedUser.phone,
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('تم تحديث البيانات بنجاح', style: TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(result['error'] ?? 'حدث خطأ', style: const TextStyle(fontFamily: 'Cairo')),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ التغييرات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool saving = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تغيير كلمة المرور',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField('كلمة المرور الحالية', currentCtrl, showCurrent,
                  () => setState(() => showCurrent = !showCurrent)),
              const SizedBox(height: 12),
              _buildPasswordField('كلمة المرور الجديدة', newCtrl, showNew,
                  () => setState(() => showNew = !showNew)),
              const SizedBox(height: 12),
              _buildPasswordField('تأكيد كلمة المرور الجديدة', confirmCtrl, showConfirm,
                  () => setState(() => showConfirm = !showConfirm)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: saving ? null : () async {
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('كلمتا المرور غير متطابقتين', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.error,
                  ));
                  return;
                }
                setState(() => saving = true);
                final result = await ref.read(authProvider.notifier).updateProfile(
                  currentPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                setState(() => saving = false);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      result['success'] == true ? 'تم تغيير كلمة المرور بنجاح' : (result['error'] ?? 'حدث خطأ'),
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: result['success'] == true ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تغيير', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.darkBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController ctrl, bool show, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility, color: AppColors.textMuted, size: 20),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: AppColors.darkBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

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
                width: 38, height: 38,
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
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
            ],
          ),
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
                width: 38, height: 38,
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
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
            ],
          ),
        ),
      );
}
