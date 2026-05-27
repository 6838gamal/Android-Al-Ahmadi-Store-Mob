import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/loading_widget.dart';

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('الصيانة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      ),
      body: const EmptyState(
        title: 'لا توجد طلبات صيانة',
        subtitle: 'تواصل مع المحل لتسجيل طلب صيانة',
        icon: Icons.build_outlined,
      ),
    );
  }
}
