import 'package:flutter/material.dart';

class AdminColors {
  static const seed = Color(0xFF1E4B8F);
  static const ink = Color(0xFF15202B);
  static const muted = Color(0xFF64748B);
  static const background = Color(0xFFF3F6FB);
  static const card = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF0E7A4F);
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFFB26A00);
  static const accent = Color(0xFFF2B233);
}

class AdminTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AdminColors.seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AdminColors.background,
      fontFamily: 'Segoe UI',
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AdminColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AdminColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AdminColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          side: const BorderSide(color: AdminColors.border),
          foregroundColor: AdminColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AdminColors.border, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AdminColors.border),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.seed,
        unselectedLabelColor: AdminColors.muted,
        indicatorColor: AdminColors.seed,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
