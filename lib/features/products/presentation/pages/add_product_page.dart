import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';

class AddProductPage extends ConsumerStatefulWidget {
  /// Pre-fill category and series when opened from the screens gallery.
  final String? preCategory;
  final String? preSeries;

  const AddProductPage({super.key, this.preCategory, this.preSeries});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();

  String _category = 'screen';
  String? _series;
  String _status = 'available';

  // Images state
  final List<_ImageEntry> _images = [];
  bool _submitting = false;

  static const _categoryOptions = {
    'screen': 'شاشات',
    'battery': 'بطاريات',
    'camera': 'كاميرات',
    'speaker': 'سماعات',
    'charger': 'شواحن',
    'device': 'أجهزة',
    'spare_part': 'قطع غيار',
    'other': 'أخرى',
  };

  static const _seriesOptions = {
    'white': 'أبيض — جودة أصلية',
    'green': 'أخضر — جودة متوسطة',
    'orange': 'برتقالي — اقتصادي',
  };

  static const _statusOptions = {
    'available': 'متوفر',
    'unavailable': 'غير متوفر',
  };

  @override
  void initState() {
    super.initState();
    if (widget.preCategory != null) _category = widget.preCategory!;
    if (widget.preSeries != null) _series = widget.preSeries!;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameArCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85, limit: 10);
    if (picked.isEmpty) return;
    setState(() {
      for (final xf in picked) {
        _images.add(_ImageEntry(file: File(xf.path)));
      }
    });
  }

  Future<void> _pickCamera() async {
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xf == null) return;
    setState(() => _images.add(_ImageEntry(file: File(xf.path))));
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  // ── Upload one image to backend ────────────────────────────────────────────

  Future<String?> _uploadImage(_ImageEntry entry) async {
    if (entry.uploadedUrl != null) return entry.uploadedUrl;
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await entry.file!.readAsBytes();
      final ext = entry.file!.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes,
            filename: 'product_$ext', contentType: DioMediaType.parse(mime)),
      });
      final res = await api.post('/uploads/image', data: formData);
      return res.data['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      _snack('أضف صورة واحدة على الأقل', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      // Upload all images
      final urls = <String>[];
      for (var i = 0; i < _images.length; i++) {
        final url = await _uploadImage(_images[i]);
        if (url != null) {
          _images[i].uploadedUrl = url;
          urls.add(url);
        }
      }

      if (urls.isEmpty) {
        _snack('فشل رفع الصور. تحقق من الاتصال.', isError: true);
        setState(() => _submitting = false);
        return;
      }

      final api = ref.read(apiClientProvider);
      await api.post('/products/', data: {
        'name': _nameCtrl.text.trim(),
        if (_nameArCtrl.text.trim().isNotEmpty) 'name_ar': _nameArCtrl.text.trim(),
        'category': _category,
        if (_series != null) 'series': _series,
        if (_brandCtrl.text.trim().isNotEmpty) 'brand': _brandCtrl.text.trim(),
        if (_modelCtrl.text.trim().isNotEmpty) 'model': _modelCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'quantity': int.tryParse(_quantityCtrl.text.trim()) ?? 0,
        'status': _status,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'image_url': urls.first,
        'image_urls': urls.length > 1 ? urls.sublist(1) : [],
      });

      if (mounted) {
        _snack('✅ تم إضافة المنتج بنجاح');
        Navigator.pop(context, true); // return true = refresh needed
      }
    } catch (e) {
      if (mounted) _snack('فشل الإرسال: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('إضافة منتج جديد',
            style: TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white)),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5)),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('حفظ',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // ── Images section ───────────────────────────────────────────
            _Section(title: '📷 الصور (${_images.length})'),
            const SizedBox(height: 10),
            _buildImageGrid(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.photo_library_outlined,
                    label: 'من المعرض',
                    onTap: _submitting ? null : _pickImages,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    icon: Icons.camera_alt_outlined,
                    label: 'الكاميرا',
                    onTap: _submitting ? null : _pickCamera,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Basic info ───────────────────────────────────────────────
            _Section(title: '📝 المعلومات الأساسية'),
            const SizedBox(height: 12),
            _field(
              controller: _nameCtrl,
              label: 'الاسم بالإنجليزية *',
              hint: 'Samsung Galaxy S24 Screen',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _nameArCtrl,
              label: 'الاسم بالعربية',
              hint: 'شاشة سامسونج S24',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _brandCtrl,
                    label: 'الماركة',
                    hint: 'Samsung',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _modelCtrl,
                    label: 'الموديل',
                    hint: 'S24 Ultra',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Category & series ────────────────────────────────────────
            _Section(title: '🏷️ التصنيف'),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'الفئة',
              value: _category,
              items: _categoryOptions,
              onChanged: (v) => setState(() {
                _category = v!;
                if (_category != 'screen') _series = null;
              }),
            ),
            if (_category == 'screen') ...[
              const SizedBox(height: 12),
              _DropdownField(
                label: 'نوع الشاشة',
                value: _series,
                items: _seriesOptions,
                onChanged: (v) => setState(() => _series = v),
                hint: 'اختر نوع الشاشة',
              ),
            ],
            const SizedBox(height: 22),

            // ── Price & quantity ─────────────────────────────────────────
            _Section(title: '💰 السعر والكمية'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _priceCtrl,
                    label: 'السعر (ريال) *',
                    hint: '0',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      if (double.tryParse(v.trim()) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _quantityCtrl,
                    label: 'الكمية',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DropdownField(
              label: 'الحالة',
              value: _status,
              items: _statusOptions,
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 22),

            // ── Description ──────────────────────────────────────────────
            _Section(title: '📄 الوصف (اختياري)'),
            const SizedBox(height: 12),
            _field(
              controller: _descCtrl,
              label: 'الوصف',
              hint: 'تفاصيل المنتج...',
              maxLines: 3,
            ),
            const SizedBox(height: 32),

            // ── Submit ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('إضافة المنتج',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Image Grid ─────────────────────────────────────────────────────────────

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.darkBorder, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.textMuted, size: 32),
              SizedBox(height: 6),
              Text('لا توجد صور بعد',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.textMuted,
                      fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        itemBuilder: (ctx, i) {
          final entry = _images[i];
          final isFirst = i == 0;
          return Stack(
            children: [
              Container(
                width: 95,
                height: 95,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isFirst
                          ? AppColors.primary
                          : AppColors.darkBorder,
                      width: isFirst ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(entry.file!, fit: BoxFit.cover),
                      if (isFirst)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: AppColors.primary.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Text('رئيسية',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 10,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 12),
                  ),
                ),
              ),
              if (entry.uploadedUrl != null)
                Positioned(
                  bottom: 4,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 10),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.error)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.darkBorder)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final Map<String, String> items;
  final void Function(String?) onChanged;
  final String? hint;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 13),
      dropdownColor: AppColors.darkCard,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.darkBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      hint: hint != null
          ? Text(hint!,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: AppColors.textMuted,
                  fontSize: 12))
          : null,
      items: items.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value,
                    style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
              ))
          .toList(),
    );
  }
}

// ── Image entry model ────────────────────────────────────────────────────────

class _ImageEntry {
  final File? file;
  String? uploadedUrl;

  _ImageEntry({this.file, this.uploadedUrl});
}
