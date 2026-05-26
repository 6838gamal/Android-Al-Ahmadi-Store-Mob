import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/admin_provider.dart';

class AddProductPage extends ConsumerStatefulWidget {
  final int? productId;
  const AddProductPage({super.key, this.productId});

  @override
  ConsumerState<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends ConsumerState<AddProductPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'screen';
  String _status = 'available';
  bool _isFeatured = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: Text(widget.productId != null ? 'تعديل المنتج' : 'إضافة منتج', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder, style: BorderStyle.solid)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
                      SizedBox(height: 4),
                      Text('رفع صورة', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 11)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(label: 'اسم المنتج *', controller: _nameCtrl, prefixIcon: Icons.label_outline, validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null),
              const SizedBox(height: 14),
              // Category Dropdown
              _buildDropdown('الفئة *', _category, AppConstants.categoryAr, (v) => setState(() => _category = v!)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: AppTextField(label: 'الماركة', controller: _brandCtrl, prefixIcon: Icons.business_outlined)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(label: 'الموديل', controller: _modelCtrl, prefixIcon: Icons.phone_outlined)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: AppTextField(label: 'السعر (د.ك) *', controller: _priceCtrl, prefixIcon: Icons.attach_money, keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null)),
                const SizedBox(width: 12),
                Expanded(child: AppTextField(label: 'الكمية *', controller: _qtyCtrl, prefixIcon: Icons.inventory_outlined, keyboardType: TextInputType.number, validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null)),
              ]),
              const SizedBox(height: 14),
              _buildDropdown('الحالة', _status, AppConstants.productStatusAr, (v) => setState(() => _status = v!)),
              const SizedBox(height: 14),
              AppTextField(label: 'الوصف', controller: _descCtrl, prefixIcon: Icons.description_outlined, maxLines: 3),
              const SizedBox(height: 14),
              AppTextField(label: 'ملاحظات', controller: _notesCtrl, prefixIcon: Icons.notes_outlined, maxLines: 2),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
                child: Row(
                  children: [
                    const Icon(Icons.star_outline, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    const Text('منتج مميز', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                    const Spacer(),
                    Switch(value: _isFeatured, onChanged: (v) => setState(() => _isFeatured = v), activeColor: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: widget.productId != null ? 'حفظ التعديلات' : 'إضافة المنتج',
                isLoading: _isLoading,
                icon: Icons.save_outlined,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, Map<String, String> options, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
      dropdownColor: AppColors.darkCard,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
        filled: true, fillColor: AppColors.darkCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.darkBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.darkBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
      items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)))).toList(),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'name': _nameCtrl.text.trim(),
      'category': _category,
      'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      'model': _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text) ?? 0,
      'quantity': int.tryParse(_qtyCtrl.text) ?? 0,
      'status': _status,
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'is_featured': _isFeatured,
    };

    bool ok;
    if (widget.productId != null) {
      ok = await ref.read(adminProvider.notifier).updateProduct(widget.productId!, data);
    } else {
      ok = await ref.read(adminProvider.notifier).createProduct(data);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.productId != null ? 'تم تحديث المنتج' : 'تمت إضافة المنتج بنجاح', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
      ));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فشلت العملية، يرجى المحاولة مرة أخرى', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ));
    }
  }
}
