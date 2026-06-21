import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../home/presentation/pages/main_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/loading_widget.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ─── Provider ────────────────────────────────────────────────────────────────

class _MaintenanceState {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  const _MaintenanceState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.isSubmitting = false,
  });

  _MaintenanceState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) =>
      _MaintenanceState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

class _MaintenanceNotifier extends StateNotifier<_MaintenanceState> {
  final ApiClient _api;
  _MaintenanceNotifier(this._api) : super(const _MaintenanceState());

  static const _cacheKey = 'cache_maintenance_my_v1';

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cached = await _loadCache();
      if (cached.isNotEmpty) state = state.copyWith(orders: cached);
    } catch (_) {}

    try {
      final res = await _api.get('/maintenance/my');
      final list = List<Map<String, dynamic>>.from(res.data);
      state = state.copyWith(orders: list, isLoading: false);
      await _saveCache(list);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: state.orders.isEmpty ? 'تعذر تحميل طلبات الصيانة' : null,
      );
    }
  }

  Future<bool> submitRequest({
    required String deviceType,
    required String problemDescription,
    required List<XFile> mediaFiles,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final List<String> mediaUrls = [];
      for (final file in mediaFiles) {
        try {
          final bytes = await file.readAsBytes();
          final contentType = _guessContentType(file.name);
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(
              bytes,
              filename: file.name,
              contentType: DioMediaType.parse(contentType),
            ),
          });
          final res = await _api.postForm('/uploads/media', formData);
          final url = res.data['url'] as String?;
          if (url != null) mediaUrls.add(url);
        } catch (_) {}
      }

      await _api.post('/maintenance/customer-request', data: {
        'device_type': deviceType,
        'problem_description': problemDescription,
        'media_urls': mediaUrls,
        'notes': notes,
      });

      state = state.copyWith(isSubmitting: false);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: 'فشل إرسال الطلب');
      return false;
    }
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.webm')) return 'video/webm';
    return 'application/octet-stream';
  }

  static Future<List<Map<String, dynamic>>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCache(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (_) {}
  }
}

final _maintenanceProvider =
    StateNotifierProvider<_MaintenanceNotifier, _MaintenanceState>((ref) {
  return _MaintenanceNotifier(ref.read(apiClientProvider));
});

// ─── Page ─────────────────────────────────────────────────────────────────────

class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final user = ref.read(authProvider).user;
      if (user != null) ref.read(_maintenanceProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => MainShell.scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('الصيانة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () => ref.read(_maintenanceProvider.notifier).load(),
            ),
        ],
      ),
      body: user == null ? _buildGuestView() : _buildLoggedInView(user),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showSubmitSheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('طلب صيانة جديد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: const Icon(Icons.build_outlined,
                  size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text('تتبع طلبات الصيانة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'سجّل دخولك لمتابعة طلبات الصيانة أو إرسال طلب جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textSecondary,
                  fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(AppConstants.shopPhone,
                      style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView(dynamic user) {
    final state = ref.watch(_maintenanceProvider);

    if (state.isLoading && state.orders.isEmpty) {
      return const LoadingWidget(message: 'جاري تحميل طلبات الصيانة...');
    }

    if (state.error != null && state.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(state.error!,
                style: const TextStyle(
                    fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(_maintenanceProvider.notifier).load(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
    }

    if (state.orders.isEmpty) {
      return _EmptyMaintenanceView(
          onSubmit: () => _showSubmitSheet(context));
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.darkCard,
      onRefresh: () => ref.read(_maintenanceProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.orders.length,
        itemBuilder: (ctx, i) =>
            _MaintenanceCard(order: state.orders[i], index: i),
      ),
    );
  }

  void _showSubmitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitMaintenanceSheet(
        onSubmitted: () => ref.read(_maintenanceProvider.notifier).load(),
      ),
    );
  }
}

// ─── Submit Sheet ─────────────────────────────────────────────────────────────

class _SubmitMaintenanceSheet extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _SubmitMaintenanceSheet({required this.onSubmitted});

  @override
  ConsumerState<_SubmitMaintenanceSheet> createState() =>
      _SubmitMaintenanceSheetState();
}

class _SubmitMaintenanceSheetState
    extends ConsumerState<_SubmitMaintenanceSheet> {
  final _deviceCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<XFile> _selectedMedia = [];
  XFile? _selectedVideo;

  @override
  void dispose() {
    _deviceCtrl.dispose();
    _problemCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        _selectedMedia.clear();
        _selectedMedia.addAll(picked.take(5));
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      setState(() => _selectedVideo = picked);
    }
  }

  Future<void> _submit() async {
    if (_deviceCtrl.text.trim().isEmpty || _problemCtrl.text.trim().isEmpty) {
      AppUtils.showSnackBar(
          context, 'يرجى تعبئة نوع الجهاز ووصف المشكلة',
          isError: true);
      return;
    }

    final allMedia = [
      ..._selectedMedia,
      if (_selectedVideo != null) _selectedVideo!,
    ];

    final ok = await ref.read(_maintenanceProvider.notifier).submitRequest(
          deviceType: _deviceCtrl.text.trim(),
          problemDescription: _problemCtrl.text.trim(),
          mediaFiles: allMedia,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

    if (mounted) Navigator.pop(context);
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        ok ? 'تم إرسال طلب الصيانة بنجاح ✓' : 'فشل إرسال الطلب',
        isError: !ok,
      );
    }
    if (ok) widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(_maintenanceProvider).isSubmitting;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('طلب صيانة جديد',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text(
              'سيتواصل معك فريقنا لتأكيد الطلب',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Device field
            _buildField(
              controller: _deviceCtrl,
              hint: 'نوع الجهاز (مثال: Samsung Galaxy A55)',
              icon: Icons.phone_android_outlined,
            ),
            const SizedBox(height: 12),

            // Problem field
            _buildField(
              controller: _problemCtrl,
              hint: 'وصف المشكلة بالتفصيل...',
              icon: Icons.report_problem_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 12),

            // Notes field
            _buildField(
              controller: _notesCtrl,
              hint: 'ملاحظات إضافية (اختياري)',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Media section header
            const Text('الصور والفيديو',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text(
              'أرفق صوراً أو فيديو يوضح المشكلة لمساعدة الفني',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),

            // Media buttons
            Row(
              children: [
                Expanded(
                  child: _MediaButton(
                    icon: Icons.add_photo_alternate_outlined,
                    label: _selectedMedia.isEmpty
                        ? 'إضافة صور'
                        : '${_selectedMedia.length} صور',
                    color: _selectedMedia.isEmpty
                        ? AppColors.primary
                        : AppColors.success,
                    onTap: _pickImages,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.videocam_outlined,
                    label: _selectedVideo == null ? 'إضافة فيديو' : 'فيديو ✓',
                    color: _selectedVideo == null
                        ? AppColors.info
                        : AppColors.success,
                    onTap: kIsWeb ? null : _pickVideo,
                    subtitle: kIsWeb ? 'غير متاح على الويب' : null,
                  ),
                ),
              ],
            ),

            // Image previews
            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length,
                  itemBuilder: (ctx, i) => _ImagePreview(
                    file: _selectedMedia[i],
                    onRemove: () => setState(() => _selectedMedia.removeAt(i)),
                  ),
                ),
              ),
            ],

            // Video preview
            if (_selectedVideo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedVideo!.name,
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selectedVideo = null),
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('إرسال طلب الصيانة',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'Cairo', color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.darkCard,
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

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Text(subtitle!,
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _ImagePreview({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 75,
          height: 75,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            image: kIsWeb
                ? null
                : DecorationImage(
                    image: FileImage(File(file.path)),
                    fit: BoxFit.cover,
                  ),
          ),
          child: kIsWeb
              ? const Icon(Icons.image, color: AppColors.primary)
              : null,
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty View ───────────────────────────────────────────────────────────────

class _EmptyMaintenanceView extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyMaintenanceView({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.build_outlined,
                  size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('لا توجد طلبات صيانة',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 8),
            const Text(
              'يمكنك إرسال طلب صيانة وإرفاق صور أو فيديو لتوضيح المشكلة',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.add),
              label: const Text('طلب صيانة جديد',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final int index;
  const _MaintenanceCard({required this.order, required this.index});

  @override
  Widget build(BuildContext context) {
    final maintStatus = order['maintenance_status'] as String? ?? 'received';
    final statusAr = AppConstants.maintenanceStatusAr[maintStatus] ?? maintStatus;
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final deviceName =
        items.isNotEmpty ? (items[0]['device'] ?? items[0]['name'] ?? 'جهاز') : 'جهاز';
    final problem = items.isNotEmpty ? (items[0]['problem'] ?? '') : '';
    final images = (order['images'] as List?)?.cast<String>() ?? [];
    final hasMedia = images.isNotEmpty;
    final videoUrls = images.where((u) =>
        u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.avi') ||
        u.endsWith('.webm')).toList();
    final photoUrls = images.where((u) => !videoUrls.contains(u)).toList();

    final statusColors = {
      'received': AppColors.info,
      'inspecting': AppColors.warning,
      'repairing': AppColors.primary,
      'waiting_part': AppColors.warning,
      'repaired': AppColors.success,
      'ready': AppColors.success,
      'delivered': AppColors.textMuted,
    };
    final color = statusColors[maintStatus] ?? AppColors.textMuted;

    final statusIcons = {
      'received': Icons.inbox_outlined,
      'inspecting': Icons.search_outlined,
      'repairing': Icons.build_outlined,
      'waiting_part': Icons.hourglass_bottom_outlined,
      'repaired': Icons.check_circle_outline,
      'ready': Icons.store_outlined,
      'delivered': Icons.done_all_outlined,
    };
    final statusIcon = statusIcons[maintStatus] ?? Icons.build_outlined;

    return GestureDetector(
      onTap: hasMedia
          ? () => _showMediaDialog(context, photoUrls, videoUrls)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon, color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order['order_number'] ?? '',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  fontSize: 13),
                            ),
                            Text(
                              deviceName,
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(statusAr,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                    ],
                  ),

                  if (problem.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(color: AppColors.darkBorder, height: 1),
                    const SizedBox(height: 10),
                    Text('المشكلة: $problem',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.textSecondary,
                            fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],

                  if (order['admin_notes'] != null &&
                      (order['admin_notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ملاحظات الفني:',
                              style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(order['admin_notes'],
                              style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  color: Colors.white,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],

                  if (order['estimated_time'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('وقت الجاهزية: ${order['estimated_time']}',
                            style: const TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textMuted,
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Media preview strip
            if (hasMedia)
              _MediaStrip(
                  photoUrls: photoUrls,
                  videoCount: videoUrls.length,
                  onTap: () =>
                      _showMediaDialog(context, photoUrls, videoUrls)),
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: index * 70)).fadeIn().slideX(begin: 0.08, end: 0);
  }

  void _showMediaDialog(BuildContext context, List<String> photos, List<String> videos) {
    showDialog(
      context: context,
      builder: (_) => _MediaViewDialog(photos: photos, videos: videos),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  final List<String> photoUrls;
  final int videoCount;
  final VoidCallback onTap;

  const _MediaStrip({
    required this.photoUrls,
    required this.videoCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.darkBorder)),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            ...photoUrls.take(4).map((url) => Container(
                  width: 54,
                  height: 54,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.darkSurface,
                    image: DecorationImage(
                      image: NetworkImage(
                          ApiClient.img(url)),
                      fit: BoxFit.cover,
                    ),
                  ),
                )),
            if (videoCount > 0)
              Container(
                width: 54,
                height: 54,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.info.withOpacity(0.15),
                  border: Border.all(color: AppColors.info.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam, color: AppColors.info, size: 18),
                    Text('$videoCount فيديو',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.info,
                            fontSize: 9)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaViewDialog extends StatefulWidget {
  final List<String> photos;
  final List<String> videos;
  const _MediaViewDialog({required this.photos, required this.videos});

  @override
  State<_MediaViewDialog> createState() => _MediaViewDialogState();
}

class _MediaViewDialogState extends State<_MediaViewDialog> {
  int _currentPage = 0;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMedia = [...widget.photos, ...widget.videos];
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: allMedia.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (ctx, i) {
              final url = allMedia[i];
              final isVideo = url.endsWith('.mp4') ||
                  url.endsWith('.mov') ||
                  url.endsWith('.avi') ||
                  url.endsWith('.webm');
              if (isVideo) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text('فيديو',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white,
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(url.split('/').last,
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.white54,
                              fontSize: 12)),
                    ],
                  ),
                );
              }
              return InteractiveViewer(
                child: Image.network(
                  ApiClient.img(url),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white38, size: 64),
                ),
              );
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
          if (allMedia.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  allMedia.length,
                  (i) => Container(
                    width: i == _currentPage ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.primary
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
