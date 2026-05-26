import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isProduct;
  final bool isOrder;

  const StatusBadge({
    super.key,
    required this.status,
    this.isProduct = false,
    this.isOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (isProduct) {
      label = AppConstants.productStatusAr[status] ?? status;
      color = AppUtils.getProductStatusColor(status);
    } else {
      label = AppConstants.orderStatusAr[status] ??
          AppConstants.maintenanceStatusAr[status] ??
          status;
      color = AppUtils.getOrderStatusColor(status);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
