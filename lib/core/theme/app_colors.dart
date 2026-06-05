import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color deepAquiferBlue = Color(0xFF5B5CFF);
  static const Color tealStart = Color(0xFF7C3AED);
  static const Color tealEnd = Color(0xFF22D3EE);

  // Agricultural Context
  static const Color fieldGreen = Color(0xFF8B5CF6);
  static const Color earthBrown = Color(0xFF795548);

  // Alerts & Indicators
  static const Color warningOrange = Color(0xFFFF8800);
  static const Color criticalRed = Color(0xFFD03F2F);
  static const Color safeBlue = Color(0xFF2196F3);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color lightGrey = Color(0xFFF8FAFC);
  static const Color mediumGrey = Color(0xFF94A3B8);
  static const Color darkGrey = Color(0xFF0F172A);

  // Gradients
  static const LinearGradient aquaFlowGradient = LinearGradient(
    colors: [tealStart, tealEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}