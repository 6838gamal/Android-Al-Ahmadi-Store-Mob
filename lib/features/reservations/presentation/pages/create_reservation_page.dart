import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';

class CreateReservationPage extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  final double price;

  const CreateReservationPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.price,
  });

  @override
  ConsumerState<CreateReservationPage> createState() =>
      _CreateReservationPageState();
}

class _CreateReservationPageState extends ConsumerState<CreateReservationPage> {
  final _form = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/reservations/request', data: {
        'product_id': widget.productId,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'deposit_amount': 0.0,
      });
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'تم إرسال طلب الحجز بنجاح! سيتواصل معك فريقنا قريباً');
      context.go('/reservations');
    } catch (e) {
      if (!mounted) return;
      final msg = _parseError(e.toString());
      AppUtils.showSnackBar(context, msg, isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String raw) {
    if (raw.contains('غير متوفر')) return 'هذا المنتج لم يعد متوفراً للحجز';
    if (raw.contains('نشط بالفعل')) return 'لديك حجز نشط بالفعل لهذا المنتج';
    if (raw.contains('401')) return 'انتهت جلستك — أعد تسجيل الدخول';
    return 'فشل إرسال طلب الحجز — أعد المحاولة';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'حجز المنتج',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product summary card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_android,
                        color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.productName,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppUtils.formatPrice(widget.price),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ]),
                  ),
                ]),
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // ── Reservation info box ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.info.withOpacity(0.25)),
                ),
                child: Column(children: [
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'مدة الحجز',
                    value: '14 يوماً',
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.bookmark_add_outlined,
                    label: 'حالة الحجز',
                    value: 'في انتظار التأكيد من المتجر',
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'ملاحظة',
                    value: 'سيتواصل معك فريقنا لتأكيد الحجز ومناقشة العربون',
                    color: AppColors.textSecondary,
                  ),
                ]),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 24),

              // ── Notes field ───────────────────────────────────────────
              const Text(
                'ملاحظات (اختياري)',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                label: 'أي ملاحظات أو متطلبات خاصة',
                controller: _notesCtrl,
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // ── Submit ────────────────────────────────────────────────
              AppButton(
                text: 'إرسال طلب الحجز',
                icon: Icons.bookmark_add_outlined,
                isLoading: _isLoading,
                onPressed: _submit,
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 8),
      Expanded(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
              TextSpan(text: value, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    ]);
  }
}
