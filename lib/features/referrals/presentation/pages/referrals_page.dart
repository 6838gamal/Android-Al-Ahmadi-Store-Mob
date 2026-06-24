import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _ReferralsPageState extends ConsumerState<ReferralsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(referralsProvider.notifier).load());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tab,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'إحصائياتي'),
            Tab(text: 'المُحالون'),
          ],
        ),
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
                  : TabBarView(
                      controller: _tab,
                      children: [
                        RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.darkCard,
                          onRefresh: () => ref.read(referralsProvider.notifier).load(),
                          child: _StatsBody(stats: state.stats!),
                        ),
                        RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.darkCard,
                          onRefresh: () => ref.read(referralsProvider.notifier).loadList(),
                          child: _ReferredListBody(
                            list: state.referredList,
                            isLoading: state.isLoadingList,
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ── Stats Tab ─────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsBody({required this.stats});

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

    // نص الدعوة — بدون رابط، مع تمييز الكود
    String _inviteText() =>
        '🎉 أهلاً! أدعوك للانضمام إلى متجر أندرويد الأحمدي\n'
        'متخصصون في الجوالات وقطع الغيار 📱\n\n'
        'عند التسجيل استخدم كود الدعوة الخاص بي:\n\n'
        '🔑  $code  🔑\n\n'
        'سجّل الآن واستمتع بمزايا حصرية!';

    Future<void> shareWhatsApp() async {
      final msg = _inviteText();
      final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        Clipboard.setData(ClipboardData(text: msg));
        if (context.mounted) AppUtils.showSnackBar(context, 'تم نسخ رسالة الدعوة');
      }
    }

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
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            Icon(level >= 2 ? Icons.workspace_premium : Icons.star_outline, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            Text('المستوى $level', style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(level1Locked ? 'تم الترقية للمستوى الثاني 🎉' : 'أحل إلى المستوى التالي',
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white70, fontSize: 13)),
          ]),
        ).animate().fadeIn().slideY(begin: -0.1, end: 0),

        const SizedBox(height: 20),

        Row(children: [
          Expanded(child: _StatCard(label: 'إجمالي الإحالات', value: '$total', icon: Icons.people_outline, color: AppColors.info)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'إحالات مؤكدة', value: '$verified', icon: Icons.check_circle_outline, color: AppColors.success)),
        ]).animate(delay: 100.ms).fadeIn(),

        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _StatCard(label: 'مستوى 1', value: '$level1Count', icon: Icons.looks_one_outlined, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'مستوى 2', value: '$level2Count', icon: Icons.looks_two_outlined, color: const Color(0xFFAB47BC))),
        ]).animate(delay: 160.ms).fadeIn(),

        const SizedBox(height: 20),

        if (!level1Locked) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('التقدم نحو المستوى 2', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
                Text('$progress / $target', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progressPct, backgroundColor: AppColors.darkBorder, valueColor: const AlwaysStoppedAnimation(AppColors.primary), minHeight: 10),
              ),
              const SizedBox(height: 8),
              Text('تحتاج ${target - progress} إحالة إضافية للوصول للمستوى 2',
                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
            ]),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 20),
        ],

        // Referral Code Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('رمز الإحالة الخاص بك',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(code,
                      style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 3),
                      textAlign: TextAlign.center),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: AppColors.primary, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    AppUtils.showSnackBar(context, 'تم نسخ رمز الإحالة');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _inviteText()));
                    AppUtils.showSnackBar(context, 'تم نسخ رسالة الدعوة');
                  },
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text('نسخ الدعوة', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: shareWhatsApp,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('واتساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ]),
        ).animate(delay: 240.ms).fadeIn(),
      ],
    );
  }
}

// ── Referred Users Tab ────────────────────────────────────────────────────────

class _ReferredListBody extends StatelessWidget {
  final List<Map<String, dynamic>> list;
  final bool isLoading;
  const _ReferredListBody({required this.list, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading && list.isEmpty) {
      return const LoadingWidget(message: 'جاري تحميل قائمة المُحالين...');
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.people_outline, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('لا أحد حتى الآن',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('شارك رمز الإحالة لتظهر أسماء الأشخاص هنا',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final r = list[i];
        final name = r['name'] as String? ?? 'مجهول';
        final phone = r['phone'] as String?;
        final level = r['level'] as int? ?? 1;
        final isVerified = r['is_verified'] as bool? ?? false;
        final createdAt = r['created_at'] as String?;
        DateTime? dt;
        if (createdAt != null) try { dt = DateTime.parse(createdAt); } catch (_) {}
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              child: Text(name[0].toUpperCase(),
                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              if (phone != null)
                Text(phone, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12)),
              if (dt != null)
                Text(AppUtils.formatDate(dt), style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 11)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('م$level', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
              const SizedBox(height: 4),
              Icon(
                isVerified ? Icons.verified : Icons.access_time_outlined,
                size: 16,
                color: isVerified ? AppColors.success : AppColors.textMuted,
              ),
            ]),
          ]),
        ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideX(begin: 0.05, end: 0);
      },
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
      decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 10)),
        ])),
      ]),
    );
  }
}
