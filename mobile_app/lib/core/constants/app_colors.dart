import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ==========================================================
  // BRAND COLORS
  // ==========================================================

  /// Blood Red (Primary)
  static const Color primary = Color(0xFFC62828);

  /// Darker Primary
  static const Color primaryDark = Color(0xFFB71C1C);

  /// Light Primary
  static const Color primaryLight = Color(0xFFFFEBEE);

  /// Medical Blue
  static const Color secondary = Color(0xFF1565C0);

  /// AI Accent Blue
  static const Color accent = Color(0xFF42A5F5);

  /// Success Green
  static const Color success = Color(0xFF2E7D32);

  /// Warning
  static const Color warning = Color(0xFFF9A825);

  /// Error
  static const Color error = Color(0xFFD32F2F);

  /// Information
  static const Color info = Color(0xFF0288D1);

  // ==========================================================
  // LIGHT THEME
  // ==========================================================

  static const Color lightBackground = Color(0xFFF8FAFC);

  static const Color lightSurface = Colors.white;

  static const Color lightCard = Colors.white;

  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color lightDivider = Color(0xFFE5E7EB);

  static const Color lightTextPrimary = Color(0xFF1E293B);

  static const Color lightTextSecondary = Color(0xFF64748B);

  static const Color lightHint = Color(0xFF94A3B8);

  // ==========================================================
  // DARK THEME
  // ==========================================================

  static const Color darkBackground = Color(0xFF0F172A);

  static const Color darkSurface = Color(0xFF1E293B);

  static const Color darkCard = Color(0xFF1E293B);

  static const Color darkBorder = Color(0xFF334155);

  static const Color darkDivider = Color(0xFF334155);

  static const Color darkTextPrimary = Colors.white;

  static const Color darkTextSecondary = Color(0xFFCBD5E1);

  static const Color darkHint = Color(0xFF94A3B8);

  // ==========================================================
  // BLOOD STATUS
  // ==========================================================

  static const Color bloodAvailable = Color(0xFF16A34A);

  static const Color bloodLow = Color(0xFFF59E0B);

  static const Color bloodCritical = Color(0xFFDC2626);

  // ==========================================================
  // MAP COLORS
  // ==========================================================

  static const Color hospitalMarker = primary;

  static const Color bloodBankMarker = secondary;

  static const Color donorMarker = success;

  static const Color emergencyMarker = error;

  // ==========================================================
  // EMERGENCY
  // ==========================================================

  static const Color emergencyBackground = Color(0xFFFFEBEE);

  static const Color emergencyPulse = Color(0xFFFF1744);

  // ==========================================================
  // COMMON
  // ==========================================================

  static const Color white = Colors.white;

  static const Color black = Colors.black;

  static const Color transparent = Colors.transparent;

  static const Color disabled = Color(0xFFCBD5E1);

  static const Color shadow = Color(0x14000000);

  // ==========================================================
  // GRADIENTS
  // ==========================================================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFD32F2F),
      Color(0xFFC62828),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [
      Color(0xFF42A5F5),
      Color(0xFF1565C0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [
      Color(0xFF43A047),
      Color(0xFF2E7D32),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}