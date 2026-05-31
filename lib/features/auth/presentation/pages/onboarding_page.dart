import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _current = 0;

  final List<_OnboardData> _pages = const [
    _OnboardData(
      icon: Icons.phone_android,
      title: 'مرحباً بك في\nاندرويد الاحمدي',
      subtitle: 'متجرك المتخصص في بيع الجوالات وقطع الغيار والصيانة الاحترافية',
      gradient: AppColors.primaryGradient,
    ),
    _OnboardData(
      icon: Icons.build_circle_outlined,
      title: 'خدمات صيانة\naحترافية',
      subtitle: 'تتبع طلبات الصيانة لجهازك خطوة بخطوة مع تحديثات فورية',
      gradient: LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFE91E63)]),
    ),
    _OnboardData(
      icon: Icons.track_changes_rounded,
      title: 'تتبع طلباتك\nفي الوقت الفعلي',
      subtitle: 'اعرف أين وصل طلبك في أي لحظة مع إشعارات لحظية',
      gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
    ),
    _OnboardData(
      icon: Icons.inventory_2_outlined,
      title: 'أوسع مخزون\nمن قطع الغيار',
      subtitle: 'شاشات، بطاريات، كاميرات وأكثر من أفضل الماركات العالمية',
      gradient: LinearGradient(colors: [Color(0xFFE65100), Color(0xFFFF9800)]),
    ),
  ];

  void _next() {
    if (_current == _pages.length - 1) {
      _done();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _done() async {
    await StorageService.setOnboardingDone();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.darkGradient),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: _pages.length,
                  itemBuilder: (ctx, i) => _OnboardPage(data: _pages[i]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: 300.ms,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _current ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _current ? AppColors.primary : AppColors.textMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: isLast
                    ? Column(
                        children: [
                          ElevatedButton(
                            onPressed: () => context.go('/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'إنشاء حساب جديد',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _done,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              minimumSize: const Size(double.infinity, 52),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          TextButton(
                            onPressed: _done,
                            child: const Text(
                              'تخطي',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.textSecondary),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              'التالي',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final _OnboardData data;
  const _OnboardPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: data.gradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 10)),
              ],
            ),
            child: Icon(data.icon, size: 70, color: Colors.white),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.3,
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.7,
            ),
          ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
}

class _OnboardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  const _OnboardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
