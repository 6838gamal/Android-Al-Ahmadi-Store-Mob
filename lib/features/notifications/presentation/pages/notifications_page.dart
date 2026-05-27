import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../../shared/widgets/loading_widget.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static final _demoNotifications = [
    _Notif(icon: Icons.check_circle_outline, color: AppColors.success, title: 'تم تأكيد طلبك', body: 'طلبك ORD-2026-0001 تم تأكيده وجاري التجهيز', time: 'منذ 10 دقائق'),
    _Notif(icon: Icons.local_shipping_outlined, color: AppColors.info, title: 'طلبك في الطريق', body: 'طلبك ORD-2026-0001 تم شحنه وهو في الطريق إليك', time: 'منذ ساعة'),
    _Notif(icon: Icons.build_outlined, color: AppColors.warning, title: 'جهازك جاهز للاستلام', body: 'تم الانتهاء من صيانة جهازك يمكنك الاستلام', time: 'منذ يوم'),
  ];

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
        title: const Text('الإشعارات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [TextButton(onPressed: () {}, child: const Text('مسح الكل', style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 12)))],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _demoNotifications.length,
        itemBuilder: (ctx, i) {
          final n = _demoNotifications[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: n.color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(n.icon, color: n.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(n.body, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(n.time, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: Duration(milliseconds: i * 80)).fadeIn().slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _Notif {
  final IconData icon;
  final Color color;
  final String title, body, time;
  const _Notif({required this.icon, required this.color, required this.title, required this.body, required this.time});
}
