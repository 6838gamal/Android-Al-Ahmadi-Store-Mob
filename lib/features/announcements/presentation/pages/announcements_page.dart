import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../providers/announcements_provider.dart';

class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(announcementsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementsProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الإعلانات والعروض',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(announcementsProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading && state.announcements.isEmpty
          ? const LoadingWidget(message: 'جاري تحميل الإعلانات...')
          : state.error != null && state.announcements.isEmpty
              ? _ErrorView(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(announcementsProvider.notifier).load(),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  onRefresh: () =>
                      ref.read(announcementsProvider.notifier).load(),
                  child: state.announcements.isEmpty
                      ? const Center(
                          child: EmptyState(
                            title: 'لا توجد إعلانات حالياً',
                            subtitle: 'تابعنا لمعرفة أحدث العروض والأخبار',
                            icon: Icons.campaign_outlined,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: state.announcements.length,
                          itemBuilder: (ctx, i) => _AnnouncementCard(
                            item: state.announcements[i],
                            index: i,
                          ),
                        ),
                ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  const _AnnouncementCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final type = item['type'] as String? ?? 'general';
    final imageUrl = item['image_url'] as String?;
    final createdAtStr = item['created_at'] as String?;

    DateTime? createdAt;
    if (createdAtStr != null) {
      try { createdAt = DateTime.parse(createdAtStr); } catch (_) {}
    }

    Color typeColor;
    String typeLabel;
    IconData typeIcon;

    switch (type) {
      case 'offer':
        typeColor = AppColors.success;
        typeLabel = 'عرض';
        typeIcon = Icons.local_offer_outlined;
        break;
      case 'alert':
        typeColor = AppColors.error;
        typeLabel = 'تنبيه';
        typeIcon = Icons.warning_amber_outlined;
        break;
      case 'event':
        typeColor = AppColors.warning;
        typeLabel = 'حدث';
        typeIcon = Icons.event_outlined;
        break;
      default:
        typeColor = AppColors.primary;
        typeLabel = 'إعلان';
        typeIcon = Icons.campaign_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: CachedNetworkImage(
                  imageUrl: ApiClient.img(imageUrl),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.darkSurface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.darkSurface,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted, size: 32),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, color: typeColor, size: 14),
                          const SizedBox(width: 4),
                          Text(typeLabel,
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: typeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(AppUtils.formatDate(createdAt),
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.textMuted,
                              fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 16)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(body,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn().slideY(begin: 0.05, end: 0);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}
