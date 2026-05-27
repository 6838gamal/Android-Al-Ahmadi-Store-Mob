import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../home/presentation/pages/main_shell.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('تواصل معنا', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.phone_android, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(AppConstants.appName, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20)),
                const SizedBox(height: 4),
                const Text(AppConstants.shopBio, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionTitle('وسائل التواصل'),

          _ContactTile(
            icon: Icons.phone_outlined,
            color: AppColors.success,
            title: 'الهاتف',
            subtitle: AppConstants.shopPhone,
            onTap: () => _copyToClipboard(context, AppConstants.shopPhone, 'تم نسخ رقم الهاتف'),
            action: 'اتصال',
          ),
          _ContactTile(
            icon: Icons.chat_outlined,
            color: const Color(0xFF25D366),
            title: 'واتساب',
            subtitle: '+${AppConstants.shopWhatsApp}',
            onTap: () => _copyToClipboard(context, AppConstants.shopPhone, 'تم نسخ رقم الواتساب'),
            action: 'مراسلة',
          ),
          _ContactTile(
            icon: Icons.email_outlined,
            color: AppColors.info,
            title: 'البريد الإلكتروني',
            subtitle: AppConstants.shopEmail,
            onTap: () => _copyToClipboard(context, AppConstants.shopEmail, 'تم نسخ البريد الإلكتروني'),
            action: 'نسخ',
          ),

          const SizedBox(height: 20),
          _sectionTitle('الموقع'),

          _ContactTile(
            icon: Icons.location_on_outlined,
            color: AppColors.error,
            title: 'العنوان',
            subtitle: AppConstants.shopAddress,
            onTap: () => _copyToClipboard(context, AppConstants.shopAddress, 'تم نسخ العنوان'),
            action: 'نسخ',
          ),

          const SizedBox(height: 20),
          _sectionTitle('ساعات العمل'),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: AppConstants.workingHours.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
                    Text(e.value, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              )).toList(),
            ),
          ),

          const SizedBox(height: 20),
          _sectionTitle('اقتراحات وشكاوى'),

          _FeedbackSection(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 4),
      child: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String action;

  const _ContactTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: color.withOpacity(0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: TextStyle(fontFamily: 'Cairo', color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _FeedbackSection extends StatefulWidget {
  @override
  State<_FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<_FeedbackSection> {
  final _ctrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 40),
            SizedBox(height: 10),
            Text('شكراً لتواصلك معنا!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 16)),
            SizedBox(height: 4),
            Text('سنرد عليك في أقرب وقت ممكن', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'اكتب رسالتك هنا...',
              hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.darkBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_ctrl.text.trim().isNotEmpty) {
                  setState(() => _sent = true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إرسال', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
