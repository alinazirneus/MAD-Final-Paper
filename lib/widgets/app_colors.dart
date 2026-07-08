import 'package:flutter/material.dart';

class AppColors {
  // Primary dark blue color requested by the user: #0b0a2e
  static const Color primaryBlue = Color(0xFF0B0A2E);
  
  // Secondary white color
  static const Color white = Colors.white;

  // Additional helper theme colors derived/aligned with theme
  static final Color primaryBlueLight = const Color(0xFF0B0A2E).withValues(alpha: 0.85);
  static final Color primaryBlueAccent = const Color(0xFF0B0A2E).withValues(alpha: 0.1);
  static final Color backgroundLight = Colors.grey.shade50;
  static final Color borderLight = Colors.grey.shade200;
  static final Color inputFill = Colors.grey.shade50;
}
