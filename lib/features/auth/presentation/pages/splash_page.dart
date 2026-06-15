import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/storage_service.dart';
import '../providers/auth_provider.dart';

enum _ConnState { connecting, connected, failed }

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  _ConnState _connState = _ConnState.connecting;
  int _attempt = 0;
  static const int _maxAttempts = 20;
  static const Duration _retryDelay = Duration(seconds: 3);

  late final AnimationController _pulseController;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1100), _checkServer);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    if (!mounted) return;
    setState(() {
      _connState = _ConnState.connecting;
      _attempt++;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.get('/health', queryParameters: {});
      if (!mounted) return;
      setState(() => _connState = _ConnState.connected);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await _navigate();
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode ?? 0;
      if (statusCode >= 500 || _attempt >= _maxAttempts) {
        setState(() => _connState = _ConnState.failed);
      } else {
        setState(() => _connState = _ConnState.connecting);
        await Future.delayed(_retryDelay);
        if (mounted) _checkServer();
      }
    } catch (_) {
      if (!mounted) return;
      if (_attempt >= _maxAttempts) {
        setState(() => _connState = _ConnState.failed);
      } else {
        await Future.delayed(_retryDelay);
        if (mounted) _checkServer();
      }
    }
  }

  Future<void> _navigate() async {
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      if (auth.isAdmin) {
        await ref.read(authProvider.notifier).logout();
        context.go('/welcome');
        return;
      }
      if (auth.isStaff || auth.isBranchManager) {
        context.go('/staff');
      } else {
        context.go('/products');
      }
      return;
    }
    final onboarded = await StorageService.isOnboardingDone();
    if (!mounted) return;
    if (onboarded) {
      context.go('/welcome');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Stack(
          children: [
            // ── Background radial glow ─────────────────────────────────
            Positioned(
              top: size.height * 0.15,
              left: size.width / 2 - 160,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Opacity(
                  opacity: 0.12 +
                      0.06 * math.sin(_pulseController.value * 2 * math.pi),
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Main content ───────────────────────────────────────────
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // ── Pulse rings + Logo ─────────────────────────────
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring
                        if (_connState == _ConnState.connecting)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) {
                              final v = _pulseController.value;
                              return Opacity(
                                opacity: (1 - v) * 0.4,
                                child: Transform.scale(
                                  scale: 0.7 + v * 0.6,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primary,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Middle pulse ring
                        if (_connState == _ConnState.connecting)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) {
                              final v = (_pulseController.value + 0.4) % 1.0;
                              return Opacity(
                                opacity: (1 - v) * 0.3,
                                child: Transform.scale(
                                  scale: 0.55 + v * 0.55,
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryLight,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Logo container
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: _connState == _ConnState.connected
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.success,
                                      Color(0xFF66BB6A)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : _connState == _ConnState.failed
                                    ? LinearGradient(colors: [
                                        AppColors.error,
                                        AppColors.error.withOpacity(0.7)
                                      ])
                                    : AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: (_connState == _ConnState.connected
                                        ? AppColors.success
                                        : _connState == _ConnState.failed
                                            ? AppColors.error
                                            : AppColors.primary)
                                    .withOpacity(0.45),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            _connState == _ConnState.connected
                                ? Icons.check_rounded
                                : _connState == _ConnState.failed
                                    ? Icons.wifi_off_rounded
                                    : Icons.phone_android,
                            size: 54,
                            color: Colors.white,
                          ),
                        )
                            .animate()
                            .scale(
                                duration: 600.ms,
                                curve: Curves.elasticOut)
                            .fadeIn(duration: 400.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── App name ───────────────────────────────────────
                  const Text(
                    'اندرويد الاحمدي',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  )
                      .animate(delay: 300.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 6),

                  const Text(
                    'متخصصون في الجوالات وقطع الغيار',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

                  const SizedBox(height: 56),

                  // ── Connection status area ─────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _buildStatusWidget(),
                  ).animate(delay: 900.ms).fadeIn(duration: 300.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget() {
    switch (_connState) {
      case _ConnState.connecting:
        return _ConnectingWidget(
          key: const ValueKey('connecting'),
          attempt: _attempt,
          maxAttempts: _maxAttempts,
          dotController: _dotController,
        );
      case _ConnState.connected:
        return const _ConnectedWidget(key: ValueKey('connected'));
      case _ConnState.failed:
        return _FailedWidget(
          key: const ValueKey('failed'),
          onRetry: () {
            setState(() => _attempt = 0);
            _checkServer();
          },
        );
    }
  }
}

// ── Animated dots ─────────────────────────────────────────────────────────────

class _AnimatedDots extends AnimatedWidget {
  const _AnimatedDots({required AnimationController controller})
      : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final controller = listenable as AnimationController;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i / 3.0;
        final anim = ((controller.value + delay) % 1.0);
        final opacity = 0.3 + 0.7 * math.sin(anim * math.pi).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(opacity),
          ),
        );
      }),
    );
  }
}

// ── Connecting indicator ──────────────────────────────────────────────────────

class _ConnectingWidget extends StatelessWidget {
  final int attempt;
  final int maxAttempts;
  final AnimationController dotController;

  const _ConnectingWidget({
    super.key,
    required this.attempt,
    required this.maxAttempts,
    required this.dotController,
  });

  @override
  Widget build(BuildContext context) {
    final progress = attempt / maxAttempts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated dots
        _AnimatedDots(controller: dotController),

        const SizedBox(height: 16),

        const Text(
          'جاري الاتصال بالخادم...',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          attempt <= 1
              ? 'نتحقق من الاتصال'
              : 'المحاولة $attempt من $maxAttempts',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),

        if (attempt > 1) ...[
          const SizedBox(height: 14),
          // Progress bar
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: progress.clamp(0.04, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            attempt > 5
                ? 'الخادم قد يكون في وضع السكون — يتم الإيقاظ...'
                : 'تأكد من اتصالك بالإنترنت',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ── Connected ─────────────────────────────────────────────────────────────────

class _ConnectedWidget extends StatelessWidget {
  const _ConnectedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.success.withOpacity(0.5), width: 1.5),
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 28),
        )
            .animate()
            .scale(duration: 400.ms, curve: Curves.elasticOut),

        const SizedBox(height: 14),

        const Text(
          'تم الاتصال بنجاح ✓',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 6),

        const Text(
          'جاري تحميل التطبيق...',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ).animate(delay: 200.ms).fadeIn(),
      ],
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────────

class _FailedWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const _FailedWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
                    color: AppColors.error.withOpacity(0.9), size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'تعذّر الاتصال بالخادم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تحقق من اتصالك بالإنترنت\nأو حاول مرة أخرى',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'إعادة المحاولة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
