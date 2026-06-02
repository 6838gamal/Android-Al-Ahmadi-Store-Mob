import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../providers/notifications_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            const Text('الإشعارات',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${state.unreadCount}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('قراءة الكل',
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(notificationsProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري تحميل الإشعارات...')
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(state.error!,
                          style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(notificationsProvider.notifier).load(),
                        child: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  onRefresh: () => ref.read(notificationsProvider.notifier).load(),
                  child: state.notifications.isEmpty
                      ? const Center(
                          child: EmptyState(
                            title: 'لا توجد إشعارات',
                            subtitle: 'ستظهر هنا جميع الإشعارات المتعلقة بحسابك',
                            icon: Icons.notifications_none_outlined,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: state.notifications.length,
                          itemBuilder: (ctx, i) => _NotifCard(
                            notif: state.notifications[i],
                            index: i,
                            onTap: () {
                              final id = state.notifications[i]['id'] as int?;
                              if (id != null && state.notifications[i]['is_read'] == false) {
                                ref.read(notificationsProvider.notifier).markRead(id);
                              }
                            },
                          ),
                        ),
                ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final int index;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notif['is_read'] as bool? ?? true;
    final isImportant = notif['is_important'] as bool? ?? false;
    final type = notif['notification_type'] as String? ?? 'system';
    final title = notif['title'] as String? ?? '';
    final body = notif['body'] as String? ?? '';
    final createdAt = notif['created_at'] as String?;

    DateTime? date;
    if (createdAt != null) {
      try { date = DateTime.parse(createdAt); } catch (_) {}
    }

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'order':      typeColor = AppColors.info;    typeIcon = Icons.receipt_long_outlined;           break;
      case 'warranty':   typeColor = AppColors.success; typeIcon = Icons.verified_user_outlined;           break;
      case 'referral':   typeColor = AppColors.warning; typeIcon = Icons.people_outline;                   break;
      case 'maintenance':typeColor = AppColors.warning; typeIcon = Icons.build_outlined;                   break;
      case 'wallet':     typeColor = AppColors.primary; typeIcon = Icons.account_balance_wallet_outlined;  break;
      default:           typeColor = AppColors.textSecondary; typeIcon = Icons.notifications_outlined;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? AppColors.darkCard : AppColors.darkCardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRead ? AppColors.darkBorder : AppColors.primary.withOpacity(0.4),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                if (!isRead)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                color: Colors.white,
                                fontSize: 14)),
                      ),
                      if (isImportant)
                        const Icon(Icons.star, color: AppColors.warning, size: 14),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                          fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(AppUtils.timeAgo(date),
                        style: const TextStyle(
                            fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ).animate(delay: Duration(milliseconds: index * 60)).fadeIn().slideX(begin: 0.08, end: 0),
    );
  }
}
