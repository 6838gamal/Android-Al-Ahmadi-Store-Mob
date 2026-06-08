import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/storage_service.dart';
import '../providers/auth_provider.dart';

// ─── OTP step enum ────────────────────────────────────────────────────────────

enum _OtpStep { enterPhone, enterCode }

class _OtpState {
  final _OtpStep step;
  final bool loading;
  final String? error;
  final String? phone;
  final int resendSeconds;

  const _OtpState({
    this.step = _OtpStep.enterPhone,
    this.loading = false,
    this.error,
    this.phone,
    this.resendSeconds = 0,
  });

  _OtpState copyWith({
    _OtpStep? step,
    bool? loading,
    String? error,
    String? phone,
    int? resendSeconds,
    bool clearError = false,
  }) =>
      _OtpState(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        phone: phone ?? this.phone,
        resendSeconds: resendSeconds ?? this.resendSeconds,
      );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

/// PhoneOtpPage — dual-purpose:
///   mode='verify'  → verifies current user's phone after registration
///   mode='login'   → login via OTP without password
///
/// Firebase is temporarily disabled. Uses backend /auth/send-otp and
/// /auth/verify-otp instead. The OTP code is printed to the server console.
class PhoneOtpPage extends ConsumerStatefulWidget {
  final String mode;
  final String? prefilledPhone;
  final String? redirectTo;

  const PhoneOtpPage({
    super.key,
    this.mode = 'verify',
    this.prefilledPhone,
    this.redirectTo,
  });

  @override
  ConsumerState<PhoneOtpPage> createState() => _PhoneOtpPageState();
}

class _PhoneOtpPageState extends ConsumerState<PhoneOtpPage> {
  _OtpState _s = const _OtpState();

  final _phoneCtrl = TextEditingController();
  final List<TextEditingController> _digitCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledPhone != null) {
      _phoneCtrl.text = widget.prefilledPhone!;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    for (final c in _digitCtrls) c.dispose();
    for (final f in _foci) f.dispose();
    super.dispose();
  }

  String get _fullCode => _digitCtrls.map((c) => c.text).join();

  String _formatPhone(String raw) {
    raw = raw.trim().replaceAll(' ', '').replaceAll('-', '');
    if (raw.startsWith('+')) return raw;
    if (raw.startsWith('00')) return '+${raw.substring(2)}';
    if (raw.startsWith('967')) return '+$raw';
    if (raw.startsWith('7') && raw.length == 9) return '+967$raw';
    if (raw.startsWith('0') && raw.length == 10) return '+967${raw.substring(1)}';
    return '+967$raw';
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _s = _s.copyWith(resendSeconds: 60));
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        final r = _s.resendSeconds - 1;
        if (r <= 0) {
          t.cancel();
          _s = _s.copyWith(resendSeconds: 0);
        } else {
          _s = _s.copyWith(resendSeconds: r);
        }
      });
    });
  }

  String? _extractDetail(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        final d = data['detail'];
        if (d is String && d.isNotEmpty) return d;
      }
      if (data is String && data.isNotEmpty && !data.trimLeft().startsWith('<')) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _s = _s.copyWith(error: 'أدخل رقم الجوال'));
      return;
    }
    final phone = _formatPhone(raw);
    setState(() => _s = _s.copyWith(loading: true, clearError: true));

    final api = ref.read(apiClientProvider);
    try {
      await api.post('/auth/send-otp', data: {'phone': phone});
      if (!mounted) return;
      for (final c in _digitCtrls) c.clear();
      setState(() => _s = _s.copyWith(
            loading: false,
            step: _OtpStep.enterCode,
            phone: phone,
            clearError: true,
          ));
      _startTimer();
      Future.delayed(const Duration(milliseconds: 300),
          () { if (mounted) _foci[0].requestFocus(); });
    } catch (e) {
      final msg = _extractDetail(e) ?? 'تعذر إرسال الرمز — تحقق من رقم الجوال';
      if (!mounted) return;
      setState(() => _s = _s.copyWith(loading: false, error: msg));
    }
  }

  Future<void> _verifyOtp() async {
    final code = _fullCode;
    if (code.length < 6) {
      setState(() => _s = _s.copyWith(error: 'أدخل الرمز المكوّن من 6 أرقام'));
      return;
    }
    setState(() => _s = _s.copyWith(loading: true, clearError: true));

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.post('/auth/verify-otp', data: {
        'phone': _s.phone ?? _phoneCtrl.text.trim(),
        'code': code,
      });

      final token = res.data['access_token'] as String;
      final user = UserModel.fromJson(
          Map<String, dynamic>.from(res.data['user'] as Map));
      await StorageService.saveToken(token);
      if (res.data['refresh_token'] != null) {
        await StorageService.saveRefreshToken(res.data['refresh_token'] as String);
      }
      await StorageService.saveUser(jsonEncode(user.toJson()));
      ref.read(authProvider.notifier).setUserFromData(user, token);

      if (!mounted) return;

      if (widget.mode == 'login') {
        context.go(user.isStaffOrAbove ? '/staff' : '/products');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ تم التحقق من رقم الهاتف بنجاح',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        if (widget.redirectTo != null) {
          context.go(widget.redirectTo!);
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      final msg = _extractDetail(e) ?? 'الرمز غير صحيح أو انتهت صلاحيته — أعد المحاولة';
      if (!mounted) return;
      setState(() => _s = _s.copyWith(loading: false, error: msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            if (_s.step == _OtpStep.enterCode) {
              setState(() => _s = _s.copyWith(
                    step: _OtpStep.enterPhone,
                    clearError: true,
                  ));
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.mode == 'login' ? 'الدخول برقم الجوال' : 'التحقق من رقم الجوال',
          style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _s.step == _OtpStep.enterPhone
                ? _PhoneStep(
                    ctrl: _phoneCtrl,
                    loading: _s.loading,
                    error: _s.error,
                    mode: widget.mode,
                    onSend: _sendOtp,
                  )
                : _CodeStep(
                    phone: _s.phone ?? '',
                    ctrls: _digitCtrls,
                    foci: _foci,
                    loading: _s.loading,
                    error: _s.error,
                    resendSeconds: _s.resendSeconds,
                    onVerify: _verifyOtp,
                    onResend: _sendOtp,
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Phone input ──────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final String mode;
  final VoidCallback onSend;

  const _PhoneStep({
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.mode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 3)
            ],
          ),
          child: const Icon(Icons.phone_android, color: Colors.white, size: 38),
        ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),
        Text(
          mode == 'login' ? 'الدخول برقم الجوال' : 'تحقق من رقم جوالك',
          style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white),
        ).animate(delay: 80.ms).fadeIn(),

        const SizedBox(height: 8),
        Text(
          mode == 'login'
              ? 'أدخل رقمك لتصلك رسالة رمز التحقق للدخول بدون كلمة مرور'
              : 'سنرسل رمز التحقق المكوّن من 6 أرقام',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Cairo',
              color: AppColors.textSecondary,
              fontSize: 13),
        ).animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 32),

        Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: const BoxDecoration(
                  border:
                      Border(right: BorderSide(color: AppColors.darkBorder)),
                ),
                child: const Text('+967',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '77XXXXXXX',
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.textMuted,
                        fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ],
          ),
        ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.2, end: 0),

        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error!),
        ],

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onSend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white, size: 18),
            label: Text(
              loading ? 'جارٍ الإرسال...' : 'إرسال رمز التحقق',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.white),
            ),
          ),
        ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.3, end: 0),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ستصلك رسالة برمز التحقق\nتأكد من إدخال رقم الجوال بشكل صحيح',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ).animate(delay: 300.ms).fadeIn(),
      ],
    );
  }
}

// ─── Step 2: Code input ───────────────────────────────────────────────────────

class _CodeStep extends StatelessWidget {
  final String phone;
  final List<TextEditingController> ctrls;
  final List<FocusNode> foci;
  final bool loading;
  final String? error;
  final int resendSeconds;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _CodeStep({
    required this.phone,
    required this.ctrls,
    required this.foci,
    required this.loading,
    required this.error,
    required this.resendSeconds,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: AppColors.success.withOpacity(0.3), width: 1.5),
          ),
          child: const Icon(Icons.mark_chat_read_outlined,
              color: AppColors.success, size: 38),
        ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),
        const Text('أدخل رمز التحقق',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white))
            .animate(delay: 60.ms)
            .fadeIn(),

        const SizedBox(height: 8),
        Text('تم إرسال رمز التحقق إلى\n$phone',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                    fontSize: 13))
            .animate(delay: 100.ms)
            .fadeIn(),

        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              6,
              (i) => _OtpBox(
                    ctrl: ctrls[i],
                    focus: foci[i],
                    nextFocus: i < 5 ? foci[i + 1] : null,
                    prevFocus: i > 0 ? foci[i - 1] : null,
                    isLast: i == 5,
                    onComplete: i == 5 ? onVerify : null,
                  )),
        ).animate(delay: 140.ms).fadeIn(),

        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(error!),
        ],

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined,
                    color: Colors.white, size: 18),
            label: Text(
                loading ? 'جارٍ التحقق...' : 'تأكيد الرمز',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white)),
          ),
        ).animate(delay: 200.ms).fadeIn(),

        const SizedBox(height: 18),

        resendSeconds > 0
            ? Text('إعادة الإرسال بعد ${resendSeconds}ث',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textMuted,
                    fontSize: 13))
            : TextButton.icon(
                onPressed: onResend,
                icon: const Icon(Icons.refresh,
                    color: AppColors.primary, size: 16),
                label: const Text('إعادة إرسال الرمز',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.error,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final FocusNode? nextFocus;
  final FocusNode? prevFocus;
  final bool isLast;
  final VoidCallback? onComplete;

  const _OtpBox({
    required this.ctrl,
    required this.focus,
    this.nextFocus,
    this.prevFocus,
    this.isLast = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder, width: 1.5),
      ),
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        onChanged: (v) {
          if (v.length == 1) {
            if (nextFocus != null) {
              nextFocus!.requestFocus();
            } else if (isLast && onComplete != null) {
              onComplete!();
            }
          } else if (v.isEmpty && prevFocus != null) {
            prevFocus!.requestFocus();
          }
        },
      ),
    );
  }
}
