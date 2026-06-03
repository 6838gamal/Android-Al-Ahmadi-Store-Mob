import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/inspection_provider.dart';

class InspectionPage extends ConsumerStatefulWidget {
  const InspectionPage({super.key});

  @override
  ConsumerState<InspectionPage> createState() => _InspectionPageState();
}

class _InspectionPageState extends ConsumerState<InspectionPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inspectionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inspectionProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('عيادة الفحص',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => ref.read(inspectionProvider.notifier).load(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: () => _showSubmitDialog(context),
          ),
        ],
      ),
      body: state.isLoading && state.requests.isEmpty
          ? const LoadingWidget(message: 'جاري تحميل طلبات الفحص...')
          : state.error != null && state.requests.isEmpty
              ? _ErrorView(
                  message: state.error!,
                  onRetry: () => ref.read(inspectionProvider.notifier).load(),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.darkCard,
                  onRefresh: () => ref.read(inspectionProvider.notifier).load(),
                  child: state.requests.isEmpty
                      ? _EmptyInspection(
                          onTap: () => _showSubmitDialog(context))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          itemCount: state.requests.length,
                          itemBuilder: (ctx, i) => _InspectionCard(
                            request: state.requests[i],
                            index: i,
                          ),
                        ),
                ),
    );
  }

  void _showSubmitDialog(BuildContext context) {
    final auth = ref.read(authProvider);
    final user = auth.user;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    final modelCtrl = TextEditingController();
    final probCtrl = TextEditingController();
    final List<XFile> selectedImages = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('طلب فحص جهاز',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'اسمك', Icons.person_outline),
                const SizedBox(height: 10),
                _field(phoneCtrl, 'رقم جوالك', Icons.phone_outlined,
                    keyboard: TextInputType.phone),
                const SizedBox(height: 10),
                _field(modelCtrl, 'موديل الجهاز (مثال: Samsung A55)',
                    Icons.phone_android_outlined),
                const SizedBox(height: 10),
                _field(probCtrl, 'وصف المشكلة بالتفصيل',
                    Icons.report_problem_outlined,
                    maxLines: 3),
                const SizedBox(height: 14),
                // Image picker section
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickMultiImage(imageQuality: 70);
                    if (picked.isNotEmpty) {
                      setDialogState(() {
                        selectedImages.clear();
                        selectedImages.addAll(picked.take(4));
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedImages.isEmpty
                            ? AppColors.darkBorder
                            : AppColors.primary.withOpacity(0.5),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        selectedImages.isEmpty ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline,
                        color: selectedImages.isEmpty ? AppColors.textMuted : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        selectedImages.isEmpty
                            ? 'إضافة صور للجهاز (اختياري)'
                            : 'تم اختيار ${selectedImages.length} صورة ✓',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: selectedImages.isEmpty ? AppColors.textMuted : AppColors.primary,
                            fontSize: 13),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(
                      fontFamily: 'Cairo', color: AppColors.textMuted)),
            ),
            Consumer(builder: (_, ref2, __) {
              final isSubmitting =
                  ref2.watch(inspectionProvider).isSubmitting;
              return ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            phoneCtrl.text.trim().isEmpty ||
                            modelCtrl.text.trim().isEmpty ||
                            probCtrl.text.trim().isEmpty) {
                          AppUtils.showSnackBar(
                              ctx, 'يرجى ملء جميع الحقول',
                              isError: true);
                          return;
                        }
                        final ok = await ref2
                            .read(inspectionProvider.notifier)
                            .submit(
                              customerName: nameCtrl.text.trim(),
                              customerPhone: phoneCtrl.text.trim(),
                              deviceModel: modelCtrl.text.trim(),
                              problemDescription: probCtrl.text.trim(),
                              images: selectedImages,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          AppUtils.showSnackBar(
                            context,
                            ok
                                ? 'تم إرسال طلب الفحص بنجاح ✓'
                                : 'فشل إرسال الطلب',
                            isError: !ok,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('إرسال الطلب',
                        style: TextStyle(fontFamily: 'Cairo')),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: AppColors.textMuted,
            fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }
}

class _EmptyInspection extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyInspection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.medical_services_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('لا توجد طلبات فحص',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'اضغط على + لتقديم طلب فحص جهازك\nوسيرد عليك فني متخصص',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: const Text('طلب فحص جديد',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final int index;
  const _InspectionCard({required this.request, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String? ?? 'pending';
    final deviceModel = request['device_model'] as String? ?? '';
    final problem = request['problem_description'] as String? ?? '';
    final diagnosis = request['diagnosis'] as String?;
    final estimatedPrice = request['estimated_price'];
    final createdAtStr = request['created_at'] as String?;

    DateTime? createdAt;
    if (createdAtStr != null) {
      try { createdAt = DateTime.parse(createdAtStr); } catch (_) {}
    }

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'in_progress':
        statusColor = AppColors.warning;
        statusLabel = 'قيد الفحص';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusLabel = 'مكتمل';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'مرفوض';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = AppColors.primary;
        statusLabel = 'قيد الانتظار';
        statusIcon = Icons.schedule_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deviceModel,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 15)),
                      if (createdAt != null)
                        Text(AppUtils.formatDate(createdAt),
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textMuted,
                                fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.darkBorder, height: 1),
            const SizedBox(height: 12),
            Text('المشكلة: $problem',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            if (diagnosis != null && diagnosis.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رد الفني:',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(diagnosis,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 13)),
                    if (estimatedPrice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'التكلفة التقديرية: ${estimatedPrice.toString()} ر.ي',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 80)).fadeIn().slideY(begin: 0.05, end: 0);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }
}
