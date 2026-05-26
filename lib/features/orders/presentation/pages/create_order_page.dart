import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../providers/orders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CreateOrderPage extends ConsumerStatefulWidget {
  const CreateOrderPage({super.key});

  @override
  ConsumerState<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends ConsumerState<CreateOrderPage> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _orderType = 'product';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _phoneCtrl.text = user.phone ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Text('طلب جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order type toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.darkBorder)),
                child: Row(
                  children: [
                    _TypeBtn(label: 'منتج', selected: _orderType == 'product', onTap: () => setState(() => _orderType = 'product')),
                    _TypeBtn(label: 'صيانة', selected: _orderType == 'maintenance', onTap: () => setState(() => _orderType = 'maintenance')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('بيانات العميل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
              const SizedBox(height: 12),
              AppTextField(label: 'الاسم الكامل', controller: _nameCtrl, prefixIcon: Icons.person_outline, validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null),
              const SizedBox(height: 12),
              AppTextField(label: 'رقم الجوال', controller: _phoneCtrl, prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone, validator: (v) => (v?.isEmpty ?? true) ? 'مطلوب' : null),
              const SizedBox(height: 12),
              AppTextField(label: 'ملاحظات', controller: _notesCtrl, prefixIcon: Icons.notes_outlined, maxLines: 3),
              const SizedBox(height: 32),
              AppButton(
                text: 'إرسال الطلب',
                isLoading: _isLoading,
                icon: Icons.send_outlined,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final ok = await ref.read(ordersProvider.notifier).createOrder({
      'customer_name': _nameCtrl.text.trim(),
      'customer_phone': _phoneCtrl.text.trim(),
      'order_type': _orderType,
      'notes': _notesCtrl.text.trim(),
      'items': [],
      'payment_method': 'cash',
    });
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم إرسال الطلب بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
      ));
      context.go('/orders');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('فشل إرسال الطلب', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}
