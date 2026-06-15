import 'dart:async';
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

class _SplashPageState extends ConsumerState<SplashPage> {
  _ConnState _connState = _ConnState.connecting;
  int _attempt = 0;
  static const int _maxAttempts = 20;
  static const Duration _retryDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    // Wait for logo animation then start health check
    Future.delayed(const Duration(milliseconds: 900), _checkServer);
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
      // Brief "connected" flash then navigate
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await _navigate();
    } on DioException catch (e) {
      if (!mounted) return;
      // Keep retrying on connection errors; stop on server errors (5xx)
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
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo ──────────────────────────────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.phone_android,
                    size: 64, color: Colors.white),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              const Text(
                'اندرويد الاحمدي',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 8),

              const Text(
                'متخصصون في الجوالات وقطع الغيار',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 64),

              // ── Connection status ─────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildStatusWidget(),
              ).animate(delay: 800.ms).fadeIn(duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusWidget() {
    switch (_connState) {
      case _ConnState.connecting:
        return _ConnectingWidget(attempt: _attempt, maxAttempts: _maxAttempts);
      case _ConnState.connected:
        return const _ConnectedWidget();
      case _ConnState.failed:
        return _FailedWidget(onRetry: () {
          setState(() => _attempt = 0);
          _checkServer();
        });
    }
  }
}

// ── Connecting indicator ──────────────────────────────────────────────────────

class _ConnectingWidget extends StatelessWidget {
  final int attempt;
  final int maxAttempts;

  const _ConnectingWidget({required this.attempt, required this.maxAttempts});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('connecting'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'جاري الاتصال بالخادم...',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (attempt > 1) ...[
          const SizedBox(height: 6),
          Text(
            'المحاولة $attempt من $maxAttempts',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Connected ─────────────────────────────────────────────────────────────────

class _ConnectedWidget extends StatelessWidget {
  const _ConnectedWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('connected'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.success.withOpacity(0.5), width: 1.5),
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 24),
        ).animate().scale(duration: 350.ms, curve: Curves.elasticOut),
        const SizedBox(height: 12),
        const Text(
          'تم الاتصال بنجاح ✓',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 14,
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn(duration: 250.ms),
      ],
    );
  }
}

// ── Failed ────────────────────────────────────────────────────────────────────

class _FailedWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const _FailedWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('failed'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: AppColors.error.withOpacity(0.8), size: 32),
              const SizedBox(height: 10),
              const Text(
                'تعذّر الاتصال بالخادم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تحقق من اتصالك بالإنترنت\nأو حاول مرة أخرى لاحقاً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
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
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'إعادة المحاولة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
