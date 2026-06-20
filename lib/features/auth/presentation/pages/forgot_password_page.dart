import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';

// ─── Step enum ────────────────────────────────────────────────────────────────

enum _Step { enterPhone, enterCode, enterPassword }

class _State {
  final _Step step;
  final bool loading;
  final String? error;
  final String phone;
  final String otpCode;
  final int resendSeconds;

  const _State({
    this.step = _Step.enterPhone,
    this.loading = false,
    this.error,
    this.phone = '',
    this.otpCode = '',
    this.resendSeconds = 0,
  });

  _State copyWith({
    _Step? step,
    bool? loading,
    String? error,
    String? phone,
    String? otpCode,
    int? resendSeconds,
    bool clearError = false,
  }) =>
      _State(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        phone: phone ?? this.phone,
        otpCode: otpCode ?? this.otpCode,
        resendSeconds: resendSeconds ?? this.resendSeconds,
      );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  _State _s = const _State();

  final _phoneCtrl = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _codeFocus = FocusNode();

  bool _sendingGuard = false;
  bool _pass1Visible = false;
  bool _pass2Visible = false;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

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
      if (data is String && data.isNotEmpty && !data.trimLeft().startsWith('<')) return data;
    } catch (_) {}
    return null;
  }

  // ── Step 1: Send OTP ─────────────────────────────────────────────────────

  Future<void> _sendOtp({bool isResend = false}) async {
    if (_sendingGuard || _s.loading) return;
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _s = _s.copyWith(error: 'أدخل رقم الجوال'));
      return;
    }
    _sendingGuard = true;
    final phone = _formatPhone(raw);
    setState(() => _s = _s.copyWith(loading: true, clearError: true));

    final api = ref.read(apiClientProvider);
    try {
      final res = await api.post('/auth/send-otp', data: {
        'phone': phone,
        'resend': isResend,
      });
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() => _s = _s.copyWith(
            loading: false,
            step: _Step.enterCode,
            phone: phone,
            clearError: true,
          ));
      _startTimer();
      Future.delayed(const Duration(milliseconds: 300),
          () { if (mounted) _codeFocus.requestFocus(); });

      if (isResend && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ تم إرسال رمز تحقق جديد',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }

      // Dev mode popup
      final devCode = res.data['dev_code'];
      if (devCode != null && mounted) _showDevOtpDialog(devCode.toString());
    } catch (e) {
      final msg = _extractDetail(e) ?? 'تعذر إرسال الرمز — تحقق من رقم الجوال';
      if (!mounted) return;
      setState(() => _s = _s.copyWith(loading: false, error: msg));
    } finally {
      _sendingGuard = false;
    }
  }

  // ── Step 2: Confirm OTP ──────────────────────────────────────────────────

  void _confirmCode() {
    final code = _codeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _s = _s.copyWith(error: 'أدخل الرمز المكوّن من 6 أرقام'));
      return;
    }
    setState(() => _s = _s.copyWith(
          step: _Step.enterPassword,
          otpCode: code,
          clearError: true,
        ));
  }

  // ── Step 3: Reset Password ───────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final pass1 = _pass1Ctrl.text;
    final pass2 = _pass2Ctrl.text;

    if (pass1.isEmpty) {
      setState(() => _s = _s.copyWith(error: 'أدخل كلمة المرور الجديدة'));
      return;
    }
    if (pass1.length < 6) {
      setState(() => _s = _s.copyWith(error: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'));
      return;
    }
    if (pass1 != pass2) {
      setState(() => _s = _s.copyWith(error: 'كلمتا المرور غير متطابقتين'));
      return;
    }

    setState(() => _s = _s.copyWith(loading: true, clearError: true));
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.post('/auth/reset-password', data: {
        'phone': _s.phone,
        'code': _s.otpCode,
        'new_password': pass1,
      });
      if (!mounted) return;
      final isStaff = res.data['is_staff'] == true;
      _showSuccessAndNavigate(isStaff);
    } catch (e) {
      final msg = _extractDetail(e) ?? 'حدث خطأ — حاول مجدداً';
      if (!mounted) return;
      setState(() => _s = _s.copyWith(loading: false, error: msg));
    }
  }

  void _showSuccessAndNavigate(bool isStaff) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ تم تغيير كلمة المرور بنجاح — سجّل دخولك',
          style: TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      context.go('/login?staff=${isStaff ? 'true' : 'false'}');
    });
  }

  void _showDevOtpDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.developer_mode, color: Color(0xFFFFA000), size: 20),
          SizedBox(width: 8),
          Text('رمز التحقق — وضع التطوير',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14,
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('الرمز المرسَل إلى رقمك:',
                style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF90A4AE), fontSize: 13)),
            const SizedBox(height: 14),
            SelectableText(code,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 38, fontWeight: FontWeight.w900,
                    color: Color(0xFF4FC3F7), letterSpacing: 10),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4FC3F7),
                  side: const BorderSide(color: Color(0xFF4FC3F7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ تم نسخ الرمز', style: TextStyle(fontFamily: 'Cairo')),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating));
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
                  style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF90A4AE))))
        ],
      ),
    );
  }

  // ── Back button logic ─────────────────────────────────────────────────────

  void _handleBack() {
    switch (_s.step) {
      case _Step.enterPhone:
        context.pop();
      case _Step.enterCode:
        _timer?.cancel();
        setState(() => _s = _s.copyWith(step: _Step.enterPhone, clearError: true));
      case _Step.enterPassword:
        setState(() => _s = _s.copyWith(step: _Step.enterCode, clearError: true));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
          onPressed: _handleBack,
        ),
        title: const Text('استعادة كلمة المرور',
            style: TextStyle(
                fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_s.step) {
                _Step.enterPhone   => _PhoneStep(
                    key: const ValueKey('phone'),
                    ctrl: _phoneCtrl,
                    loading: _s.loading,
                    error: _s.error,
                    onSend: _sendOtp,
                  ),
                _Step.enterCode    => _CodeStep(
                    key: const ValueKey('code'),
                    phone: _s.phone,
                    codeCtrl: _codeCtrl,
                    codeFocus: _codeFocus,
                    loading: _s.loading,
                    error: _s.error,
                    resendSeconds: _s.resendSeconds,
                    onConfirm: _confirmCode,
                    onResend: () => _sendOtp(isResend: true),
                    onCodeChanged: (v) {
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      if (digits.length > 6) {
                        _codeCtrl.text = digits.substring(0, 6);
                        _codeCtrl.selection =
                            TextSelection.collapsed(offset: _codeCtrl.text.length);
                      }
                      setState(() => _s = _s.copyWith(clearError: true));
                      if (digits.length == 6 && !_s.loading) {
                        Future.delayed(const Duration(milliseconds: 80),
                            () { if (mounted) _confirmCode(); });
                      }
                    },
                  ),
                _Step.enterPassword => _PasswordStep(
                    key: const ValueKey('password'),
                    pass1Ctrl: _pass1Ctrl,
                    pass2Ctrl: _pass2Ctrl,
                    pass1Visible: _pass1Visible,
                    pass2Visible: _pass2Visible,
                    loading: _s.loading,
                    error: _s.error,
                    onTogglePass1: () => setState(() => _pass1Visible = !_pass1Visible),
                    onTogglePass2: () => setState(() => _pass2Visible = !_pass2Visible),
                    onReset: _resetPassword,
                  ),
              },
            ),
          ),
        ),
      ),
    ));
  }
}

// ─── Step 1: Phone ────────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onSend;

  const _PhoneStep({
    super.key,
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF7B1FA2)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 20, spreadRadius: 3)],
          ),
          child: const Icon(Icons.lock_reset, color: Colors.white, size: 38),
        ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),
        const Text('استعادة كلمة المرور',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                fontWeight: FontWeight.w800, color: Colors.white))
            .animate(delay: 80.ms).fadeIn(),
        const SizedBox(height: 8),
        const Text('أدخل رقم جوالك المسجّل وسنرسل لك رمز التحقق',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo',
                color: AppColors.textSecondary, fontSize: 13))
            .animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 32),

        Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.darkBorder))),
                child: const Text('+967',
                    style: TextStyle(fontFamily: 'Cairo',
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontFamily: 'Cairo', color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: '77XXXXXXX',
                    hintStyle: TextStyle(
                        fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ]),
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
                elevation: 0),
            icon: loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, color: Colors.white, size: 18),
            label: Text(loading ? 'جارٍ الإرسال...' : 'إرسال رمز التحقق',
                style: const TextStyle(fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          ),
        ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.3, end: 0),
      ],
    );
  }
}

// ─── Step 2: OTP Code ─────────────────────────────────────────────────────────

class _CodeStep extends StatefulWidget {
  final String phone;
  final TextEditingController codeCtrl;
  final FocusNode codeFocus;
  final bool loading;
  final String? error;
  final int resendSeconds;
  final VoidCallback onConfirm;
  final VoidCallback onResend;
  final ValueChanged<String> onCodeChanged;

  const _CodeStep({
    super.key,
    required this.phone,
    required this.codeCtrl,
    required this.codeFocus,
    required this.loading,
    required this.error,
    required this.resendSeconds,
    required this.onConfirm,
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
    widget.codeFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.codeFocus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() { if (mounted) setState(() => _isFocused = widget.codeFocus.hasFocus); }

  @override
  Widget build(BuildContext context) {
    final digits = widget.codeCtrl.text.replaceAll(RegExp(r'\D'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5)),
          child: const Icon(Icons.mark_chat_read_outlined,
              color: AppColors.success, size: 38),
        ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),
        const Text('أدخل رمز التحقق',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                fontWeight: FontWeight.w800, color: Colors.white))
            .animate(delay: 80.ms).fadeIn(),
        const SizedBox(height: 6),
        Text('تم إرسال رمز 6 أرقام إلى ${widget.phone}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo',
                color: AppColors.textSecondary, fontSize: 12))
            .animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 32),

        // 6-box OTP display
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                final filled = i < digits.length;
                final active = _isFocused && i == digits.length.clamp(0, 5);
                return Container(
                  width: 44, height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: filled
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? AppColors.primary
                          : filled
                              ? AppColors.primary.withOpacity(0.5)
                              : AppColors.darkBorder,
                      width: active ? 2 : 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: filled
                      ? Text(digits[i],
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 22,
                              fontWeight: FontWeight.w800, color: Colors.white))
                      : active
                          ? Container(width: 2, height: 24,
                              color: AppColors.primary)
                          : null,
                );
              }),
            ),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.codeCtrl,
                focusNode: widget.codeFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                decoration: const InputDecoration(counterText: ''),
                onChanged: widget.onCodeChanged,
              ),
            ),
          ],
        ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.2, end: 0),

        const SizedBox(height: 8),
        TextButton(
          onPressed: () => widget.codeFocus.requestFocus(),
          child: const Text('اضغط هنا لإدخال الرمز',
              style: TextStyle(fontFamily: 'Cairo',
                  color: AppColors.textMuted, fontSize: 12)),
        ),

        if (widget.error != null) ...[
          const SizedBox(height: 8),
          _ErrorBox(widget.error!),
        ],
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.loading ? null : widget.onConfirm,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            child: widget.loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('التالي',
                    style: TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          ),
        ).animate(delay: 220.ms).fadeIn(),

        const SizedBox(height: 20),

        widget.resendSeconds > 0
            ? Text('إعادة الإرسال بعد ${widget.resendSeconds} ثانية',
                style: const TextStyle(fontFamily: 'Cairo',
                    color: AppColors.textMuted, fontSize: 13))
            : TextButton(
                onPressed: widget.onResend,
                child: const Text('لم تصلك الرسالة؟ إعادة إرسال الرمز',
                    style: TextStyle(fontFamily: 'Cairo',
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
      ],
    );
  }
}

// ─── Step 3: New Password ─────────────────────────────────────────────────────

class _PasswordStep extends StatelessWidget {
  final TextEditingController pass1Ctrl;
  final TextEditingController pass2Ctrl;
  final bool pass1Visible;
  final bool pass2Visible;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePass1;
  final VoidCallback onTogglePass2;
  final VoidCallback onReset;

  const _PasswordStep({
    super.key,
    required this.pass1Ctrl,
    required this.pass2Ctrl,
    required this.pass1Visible,
    required this.pass2Visible,
    required this.loading,
    required this.error,
    required this.onTogglePass1,
    required this.onTogglePass2,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF1A73E8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
                color: AppColors.success.withOpacity(0.35),
                blurRadius: 20, spreadRadius: 3)],
          ),
          child: const Icon(Icons.lock_outline, color: Colors.white, size: 38),
        ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),

        const SizedBox(height: 20),
        const Text('كلمة المرور الجديدة',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                fontWeight: FontWeight.w800, color: Colors.white))
            .animate(delay: 80.ms).fadeIn(),
        const SizedBox(height: 8),
        const Text('أدخل كلمة المرور الجديدة وتأكيدها',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo',
                color: AppColors.textSecondary, fontSize: 13))
            .animate(delay: 120.ms).fadeIn(),

        const SizedBox(height: 32),

        _PasswordField(
          ctrl: pass1Ctrl,
          label: 'كلمة المرور الجديدة',
          visible: pass1Visible,
          onToggle: onTogglePass1,
          hint: '6 أحرف على الأقل',
        ).animate(delay: 160.ms).fadeIn().slideY(begin: 0.2, end: 0),

        const SizedBox(height: 16),

        _PasswordField(
          ctrl: pass2Ctrl,
          label: 'تأكيد كلمة المرور',
          visible: pass2Visible,
          onToggle: onTogglePass2,
          hint: 'أعد إدخال كلمة المرور',
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(error!),
        ],
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading ? null : onReset,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            icon: loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            label: Text(loading ? 'جارٍ التغيير...' : 'تغيير كلمة المرور',
                style: const TextStyle(fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          ),
        ).animate(delay: 240.ms).fadeIn().slideY(begin: 0.3, end: 0),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder)),
      child: TextField(
        controller: ctrl,
        obscureText: !visible,
        style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
          hintText: hint,
          hintStyle: const TextStyle(fontFamily: 'Cairo',
              color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textMuted, size: 20),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.4))),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontFamily: 'Cairo',
                  fontSize: 13, color: Color(0xFFFF6B6B), height: 1.4)),
        ),
      ]),
    ).animate().fadeIn().shake(hz: 2, offset: const Offset(4, 0));
  }
}
