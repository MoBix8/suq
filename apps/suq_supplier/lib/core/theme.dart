import 'package:flutter/material.dart';

class SupplierColors {
  static const seed = Color(0xFF54258A);
  static const ink = Color(0xFF21182D);
  static const muted = Color(0xFF6B6478);
  static const border = Color(0xFFE2DCE8);
  static const danger = Color(0xFFDC2626);
  static const profit = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const surface = Color(0xFFF8F6FB);
}

ThemeData buildSupplierTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: SupplierColors.seed),
      scaffoldBackgroundColor: SupplierColors.surface,
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        margin: EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SupplierColors.surface,
        foregroundColor: SupplierColors.ink,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SupplierColors.seed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
