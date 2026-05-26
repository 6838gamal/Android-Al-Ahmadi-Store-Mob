import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

class AppUtils {
  static String formatPrice(double price) {
    final formatter = NumberFormat('#,##0.000', 'ar');
    return '${formatter.format(price)} د.ك';
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd', 'ar').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(date);
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return formatDate(date);
  }

  static Color getProductStatusColor(String status) {
    switch (status) {
      case 'available': return AppColors.available;
      case 'reserved': return AppColors.reserved;
      case 'sold': return AppColors.sold;
      default: return AppColors.unavailable;
    }
  }

  static Color getOrderStatusColor(String status) {
    switch (status) {
      case 'delivered': return AppColors.success;
      case 'cancelled': return AppColors.error;
      case 'on_the_way':
      case 'shipped': return AppColors.info;
      case 'confirmed':
      case 'preparing': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
