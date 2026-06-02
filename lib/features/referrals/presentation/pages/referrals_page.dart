import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../providers/referrals_provider.dart';

class ReferralsPage extends ConsumerStatefulWidget {
  const ReferralsPage({super.key});

  @override
  ConsumerState<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends ConsumerState<ReferralsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(referralsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralsProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الإحالات',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(referralsProvider.notifier).load(),
          ),
        ],
      ),
      body: state.isLoading
          ? const LoadingWidget(message: 'جاري تحميل بيانات الإحالة...')
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(state.error!,
                          style: const TextStyle(
                              fontFamily: 'Cairo', color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(referralsProvider.notifier).load(),
                        child: const Text('إعادة المحاولة',
                            style: TextStyle(fontFamily: 'Cairo')),
                      ),
                    ],
                  ),
                )
              : state.stats == null
                  ? const LoadingWidget()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      backgroundColor: AppColors.darkCard,
                      onRefresh: () => ref.read(referralsProvider.notifier).load(),
                      child: _ReferralsBody(stats: state.stats!),
                    ),
    );
  }
}

class _ReferralsBody extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ReferralsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    final code = stats['referral_code'] as String? ?? '';
    final link = stats['referral_link'] as String? ?? '';
    final total = stats['total_referrals'] as int? ?? 0;
    final verified = stats['verified_referrals'] as int? ?? 0;
    final target = stats['target'] as int? ?? 50;
    final level = stats['current_level'] as int? ?? 1;
    final progress = stats['progress_to_next'] as int? ?? 0;
    final level1Locked = stats['level1_locked'] as bool? ?? false;
    final level1Count = stats['level1_count'] as int? ?? 0;
    final level2Count = stats['level2_count'] as int? ?? 0;

    final progressPct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Level Badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: level >= 2
                ? const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                level >= 2 ? Icons.workspace_premium : Icons.star_outline,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'المستوى $level',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                level1Locked ? 'تم الترقية للمستوى الثاني 🎉' : 'أحل إلى المستوى التالي',
                style: const TextStyle(
                    fontFamily: 'Cairo', color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.1, end: 0),

        const SizedBox(height: 20),

        // Stats Row
        Row(
          children: [
            Expanded(child: _StatCard(label: 'إجمالي الإحالات', value: '$total', icon: Icons.people_outline, color: AppColors.info)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'إحالات مؤكدة', value: '$verified', icon: Icons.check_circle_outline, color: AppColors.success)),
          ],
        ).animate(delay: 100.ms).fadeIn(),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(child: _StatCard(label: 'مستوى 1', value: '$level1Count', icon: Icons.looks_one_outlined, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'مستوى 2', value: '$level2Count', icon: Icons.looks_two_outlined, color: const Color(0xFFAB47BC))),
          ],
        ).animate(delay: 160.ms).fadeIn(),

        const SizedBox(height: 20),

        // Progress Bar (Level 1 only)
        if (!level1Locked) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('التقدم نحو المستوى 2',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14)),
                    Text('$progress / $target',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    backgroundColor: AppColors.darkBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تحتاج ${target - progress} إحالة إضافية للوصول للمستوى 2',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 12),
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 20),
        ],

        // Referral Code Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رمز الإحالة الخاص بك',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 15)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        code,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 3),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        AppUtils.showSnackBar(
                            context, 'تم نسخ رمز الإحالة');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: link));
                    AppUtils.showSnackBar(context, 'تم نسخ رابط الإحالة');
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('نسخ رابط الإحالة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: 240.ms).fadeIn(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontSize: 18)),
                Text(label,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textMuted,
                        fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
