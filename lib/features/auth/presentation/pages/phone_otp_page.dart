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

  // Single controller for the entire 6-digit OTP (enables autofill + paste)
  final _codeCtrl = TextEditingController();
  final _codeFocus = FocusNode();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledPhone != null) {
      _phoneCtrl.text = widget.prefilledPhone!;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _sendOtp();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _fullCode => _codeCtrl.text.trim();

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
      final res = await api.post('/auth/send-otp', data: {'phone': phone});
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() => _s = _s.copyWith(
            loading: false,
            step: _OtpStep.enterCode,
            phone: phone,
            clearError: true,
          ));
      _startTimer();
      Future.delayed(const Duration(milliseconds: 300),
          () { if (mounted) _codeFocus.requestFocus(); });

      // Dev mode: show OTP in a copyable popup
      final devCode = res.data['dev_code'];
      if (devCode != null && mounted) {
        _showDevOtpDialog(devCode.toString());
      }
    } catch (e) {
      final msg = _extractDetail(e) ?? 'تعذر إرسال الرمز — تحقق من رقم الجوال';
      if (!mounted) return;
      setState(() => _s = _s.copyWith(loading: false, error: msg));
    }
  }

  void _showDevOtpDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.developer_mode, color: Color(0xFFFFA000), size: 20),
            SizedBox(width: 8),
            Text('رمز التحقق — وضع التطوير',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الرمز المرسَل إلى رقمك:',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Color(0xFF90A4AE),
                    fontSize: 13)),
            const SizedBox(height: 14),
            SelectableText(
              code,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4FC3F7),
                  letterSpacing: 10),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4FC3F7),
                side: const BorderSide(color: Color(0xFF4FC3F7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ تم نسخ الرمز',
                      style: TextStyle(fontFamily: 'Cairo')),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('نسخ الرمز',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق',
                style: TextStyle(
                    fontFamily: 'Cairo', color: Color(0xFF90A4AE))),
          ),
        ],
      ),
    );
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
                    codeCtrl: _codeCtrl,
                    codeFocus: _codeFocus,
                    loading: _s.loading,
                    error: _s.error,
                    resendSeconds: _s.resendSeconds,
                    onVerify: _verifyOtp,
                    onResend: _sendOtp,
                    onCodeChanged: (v) {
                      // Keep only digits, max 6
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length > 6) {
                        _codeCtrl.text = digits.substring(0, 6);
                        _codeCtrl.selection = TextSelection.collapsed(
                            offset: _codeCtrl.text.length);
                      }
                      setState(() => _s = _s.copyWith(clearError: true));
                      // Auto-submit when 6 digits entered
                      if (digits.length == 6 && !_s.loading) {
                        Future.delayed(const Duration(milliseconds: 80),
                            () { if (mounted) _verifyOtp(); });
                      }
                    },
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

/// Uses a single hidden TextField (autofill-compatible) overlaid under 6
/// decorative display boxes. Supports SMS OTP autofill, paste, and
/// manual digit-by-digit entry.
class _CodeStep extends StatefulWidget {
  final String phone;
  final TextEditingController codeCtrl;
  final FocusNode codeFocus;
  final bool loading;
  final String? error;
  final int resendSeconds;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final ValueChanged<String> onCodeChanged;

  const _CodeStep({
    required this.phone,
    required this.codeCtrl,
    required this.codeFocus,
    required this.loading,
    required this.error,
    required this.resendSeconds,
    required this.onVerify,
    required this.onResend,
    required this.onCodeChanged,
  });

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.codeFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.codeFocus.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.codeFocus.hasFocus);
  }

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
        Text('تم إرسال رمز التحقق إلى\n${widget.phone}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                    fontSize: 13))
            .animate(delay: 100.ms)
            .fadeIn(),

        const SizedBox(height: 32),

        // ── OTP input: hidden field + 6 display boxes ──────────────────────
        GestureDetector(
          onTap: () => widget.codeFocus.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hidden TextField — captures input, enables autofill & paste
              SizedBox(
                width: 1,
                height: 1,
                child: Opacity(
                  opacity: 0,
                  child: AutofillGroup(
                    child: TextField(
                      controller: widget.codeCtrl,
                      focusNode: widget.codeFocus,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: widget.onCodeChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ),

              // 6 decorative display boxes — forced LTR so digit[0] is always leftmost
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.codeCtrl,
                builder: (ctx, value, _) {
                  final digits = value.text.padRight(6);
                  return Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) {
                        final char = digits[i] == ' ' ? '' : digits[i];
                        final isActive = _isFocused &&
                            (value.text.length == i ||
                                (i == 5 && value.text.length >= 5));
                        final isFilled = char.isNotEmpty;
                        return _OtpDigitBox(
                          digit: char,
                          isActive: isActive,
                          isFilled: isFilled,
                        );
                      }),
                    ),
                  );
                },
              ),
            ],
          ),
        ).animate(delay: 140.ms).fadeIn(),
        // ───────────────────────────────────────────────────────────────────

        if (widget.error != null) ...[
          const SizedBox(height: 14),
          _ErrorBox(widget.error!),
        ],

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.loading ? null : widget.onVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: widget.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_outlined,
                    color: Colors.white, size: 18),
            label: Text(
                widget.loading ? 'جارٍ التحقق...' : 'تأكيد الرمز',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white)),
          ),
        ).animate(delay: 200.ms).fadeIn(),

        const SizedBox(height: 18),

        widget.resendSeconds > 0
            ? Text('إعادة الإرسال بعد ${widget.resendSeconds}ث',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textMuted,
                    fontSize: 13))
            : TextButton.icon(
                onPressed: widget.onResend,
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

// ─── OTP digit display box ────────────────────────────────────────────────────

/// Pure display widget — no TextField inside.
/// Shows the digit (or a blinking cursor when active & empty).
class _OtpDigitBox extends StatelessWidget {
  final String digit;
  final bool isActive;
  final bool isFilled;

  const _OtpDigitBox({
    required this.digit,
    required this.isActive,
    required this.isFilled,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    if (isActive) {
      borderColor = AppColors.primary;
    } else if (isFilled) {
      borderColor = AppColors.success.withOpacity(0.7);
    } else {
      borderColor = AppColors.darkBorder;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isFilled
            ? AppColors.darkCard.withOpacity(0.95)
            : AppColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isActive ? 2.0 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Center(
        child: digit.isNotEmpty
            ? Text(
                digit,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              )
            : isActive
                ? _BlinkingCursor()
                : const SizedBox.shrink(),
      ),
    );
  }
}

// ─── Blinking cursor ──────────────────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 1, end: 0).animate(_ctrl);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
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
