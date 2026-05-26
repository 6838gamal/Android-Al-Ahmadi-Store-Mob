import 'package:flutter/material.dart';

class AppColors {
  // Primary Brand
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF4FC3F7);
  static const Color accent = Color(0xFF00BCD4);

  // Dark Theme
  static const Color darkBg = Color(0xFF0A0E1A);
  static const Color darkSurface = Color(0xFF131929);
  static const Color darkCard = Color(0xFF1A2035);
  static const Color darkCardAlt = Color(0xFF1E2740);
  static const Color darkBorder = Color(0xFF2A3450);
  static const Color darkDivider = Color(0xFF1F2D45);

  // Light Theme
  static const Color lightBg = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E7EF);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF607D8B);
  static const Color textDark = Color(0xFF1A2035);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFF81C784);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFCC02);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFEF9A9A);
  static const Color info = Color(0xFF2196F3);
  static const Color grey = Color(0xFF9E9E9E);

  // Product Status
  static const Color available = Color(0xFF4CAF50);
  static const Color reserved = Color(0xFFFF9800);
  static const Color sold = Color(0xFFF44336);
  static const Color unavailable = Color(0xFF9E9E9E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A73E8), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0E1A), Color(0xFF131929)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A2035), Color(0xFF1E2740)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFEF6C00), Color(0xFFFF9800)],
  );
}
