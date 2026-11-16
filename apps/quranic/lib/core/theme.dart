import 'package:flutter/material.dart';

/// The Quranic palette: warm ivory paper, deep espresso ink and brushed gold.
///
/// [seed] is the deep antique gold used for text and primary controls; [accent]
/// is the brighter metallic gold used for highlights on dark surfaces.
class AppColors {
  static const seed = Color(0xFF8A6A1F);
  static const gold = Color(0xFFD4AF37);
  static const goldDeep = Color(0xFF8A6A1F);
  static const goldSoft = Color(0xFFF3E7C6);
  static const ink = Color(0xFF221B10);
  static const muted = Color(0xFF7B6F5B);
  static const background = Color(0xFFFBF7ED);
  static const card = Color(0xFFFFFDF8);
  static const border = Color(0xFFEDE2CC);
  static const profit = Color(0xFF2E7D5B);
  static const loss = Color(0xFFB3261E);
  static const warning = Color(0xFF9A6A00);
  static const accent = gold;
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: AppColors.goldDeep,
      onPrimary: Colors.white,
      primaryContainer: AppColors.goldSoft,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.goldSoft,
      onSecondaryContainer: AppColors.ink,
      surface: AppColors.background,
      onSurface: AppColors.ink,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: AppColors.goldDeep,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.goldSoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.border),
        selectedColor: AppColors.goldSoft,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.goldDeep,
        linearTrackColor: AppColors.border,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.gold,
        thumbColor: AppColors.gold,
      ),
    );
  }
}
