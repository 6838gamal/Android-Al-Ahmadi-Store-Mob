import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Logo + Brand
                  Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 32,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(Icons.phone_android,
                            size: 52, color: Colors.white),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 20),
                      const Text(
                        'اندرويد الاحمدي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 6),
                      const Text(
                        'متخصصون في الجوالات وقطع الغيار',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ).animate(delay: 250.ms).fadeIn(),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Section title
                  const Text(
                    'كيف تريد الدخول؟',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 20),

                  // ── Customer Card ────────────────────────────────────────
                  _RoleCard(
                    title: 'عميل',
                    subtitle: 'تصفح المنتجات واطلب وتتبع طلباتك',
                    icon: Icons.person_outline,
                    gradient: AppColors.primaryGradient,
                    features: const [
                      _Feature(icon: Icons.inventory_2_outlined, label: 'تصفح المنتجات'),
                      _Feature(icon: Icons.receipt_long_outlined, label: 'متابعة الطلبات'),
                      _Feature(icon: Icons.build_outlined, label: 'طلبات الصيانة'),
                      _Feature(icon: Icons.bookmark_outline, label: 'الحجوزات'),
                    ],
                    onLogin: () => context.go('/login'),
                    onRegister: () => context.go('/register'),
                    loginLabel: 'دخول كعميل',
                    registerLabel: 'إنشاء حساب',
                    index: 0,
                  ),

                  const SizedBox(height: 16),

                  // ── Staff Card ───────────────────────────────────────────
                  _RoleCard(
                    title: 'موظف / مدير فرع',
                    subtitle: 'إدارة الطلبات والصيانة والمخزون',
                    icon: Icons.badge_outlined,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    ),
                    features: const [
                      _Feature(icon: Icons.receipt_long_outlined, label: 'إدارة الطلبات'),
                      _Feature(icon: Icons.build_circle_outlined, label: 'طلبات الصيانة'),
                      _Feature(icon: Icons.inventory_2_outlined, label: 'المخزون'),
                    ],
                    onLogin: () => context.go('/login'),
                    onRegister: null,
                    loginLabel: 'دخول للموظفين',
                    registerLabel: '',
                    index: 1,
                  ),

                  const SizedBox(height: 24),

                  // Guest browse
                  TextButton(
                    onPressed: () => context.go('/products'),
                    child: const Text(
                      'تصفح بدون حساب',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ).animate(delay: 700.ms).fadeIn(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final List<_Feature> features;
  final VoidCallback onLogin;
  final VoidCallback? onRegister;
  final String loginLabel;
  final String registerLabel;
  final int index;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.features,
    required this.onLogin,
    required this.onRegister,
    required this.loginLabel,
    required this.registerLabel,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: features.map((f) => _FeatureChip(feature: f)).toList(),
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      loginLabel,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
                if (onRegister != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRegister,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        registerLabel,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 350 + index * 120))
        .fadeIn()
        .slideY(begin: 0.15, end: 0);
  }
}

class _FeatureChip extends StatelessWidget {
  final _Feature feature;
  const _FeatureChip({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(feature.icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            feature.label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});
}
