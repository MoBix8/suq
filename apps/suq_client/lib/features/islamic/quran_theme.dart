import 'package:flutter/material.dart';

/// A colour scheme for the Qur'an reader.
///
/// A theme colours the page itself and the chrome around it, so the header,
/// footer and backdrop always match the page instead of using the app's green
/// accent. The recitation highlight is a solid (opaque) colour that contrasts
/// with the page.
@immutable
class QuranTheme {
  const QuranTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.background,
    required this.paper,
    required this.ink,
    required this.mutedInk,
    required this.accent,
    required this.accentInk,
    required this.bandFill,
    required this.selection,
    required this.highlight,
    required this.highlightInk,
    required this.chrome,
    required this.chromeInk,
    required this.border,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;

  /// Backdrop behind the page.
  final Color background;

  /// The page surface.
  final Color paper;

  /// Arabic text.
  final Color ink;

  /// Secondary text, notes and captions.
  final Color mutedInk;

  /// Page number, ayah outlines and small accents.
  final Color accent;

  /// Text and icons drawn on top of [accent].
  final Color accentInk;

  /// Surah band and ayah badge fill.
  final Color bandFill;

  /// Tint behind the selected verse.
  final Color selection;

  /// Solid colour behind the word being recited.
  final Color highlight;

  /// Text colour on top of [highlight].
  final Color highlightInk;

  /// App bar and footer.
  final Color chrome;

  /// Text and icons on [chrome].
  final Color chromeInk;

  /// Hairline borders.
  final Color border;

  bool get _isDark => brightness == Brightness.dark;

  /// Rule-based Tajweed palette, following the colour-coded mushaf convention
  /// used by international Islamic printers:
  ///
  /// * red — madd (elongation) markers
  /// * green — ghunnah (noon/meem with shadda)
  /// * blue — qalqalah letters
  /// * orange — noon sakinah and tanween rules (ikhfa, idgham, iqlab)
  /// * grey — silent letters
  /// * gold — the majesty name Allah
  Color get tajweedMadd =>
      _isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828);

  Color get tajweedGhunnah =>
      _isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

  Color get tajweedQalqalah =>
      _isDark ? const Color(0xFF82B1FF) : const Color(0xFF1565C0);

  Color get tajweedNoon =>
      _isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);

  Color get tajweedSilent =>
      _isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

  Color get tajweedDivine =>
      _isDark ? const Color(0xFFFFD54F) : const Color(0xFF8D6E00);
}

/// SharedPreferences key for the chosen page theme.
const quranThemeKey = 'quran.themeId';

/// Theme used when the shop has not chosen one yet.
const quranDefaultThemeId = 'paper';

const quranThemes = <QuranTheme>[
  QuranTheme(
    id: 'paper',
    name: 'Paper',
    description: 'Warm cream page with a deep blue recitation highlight',
    brightness: Brightness.light,
    background: Color(0xFFE6DAC1),
    paper: Color(0xFFFBF5E6),
    ink: Color(0xFF2A2118),
    mutedInk: Color(0xFF6F6352),
    accent: Color(0xFF8A6A3C),
    accentInk: Color(0xFFFFFBF2),
    bandFill: Color(0xFFF0E2C2),
    selection: Color(0xFFEDE1C8),
    highlight: Color(0xFF3D5A80),
    highlightInk: Color(0xFFFFFBF2),
    chrome: Color(0xFFF3EBD8),
    chromeInk: Color(0xFF2A2118),
    border: Color(0xFFD8C7A5),
  ),
  QuranTheme(
    id: 'ivory',
    name: 'Ivory',
    description: 'Clean white page with a slate blue highlight',
    brightness: Brightness.light,
    background: Color(0xFFDCDDD7),
    paper: Color(0xFFFFFFFF),
    ink: Color(0xFF1C1C1C),
    mutedInk: Color(0xFF646A6E),
    accent: Color(0xFF4F6070),
    accentInk: Color(0xFFFFFFFF),
    bandFill: Color(0xFFEDF1F4),
    selection: Color(0xFFE9EFF4),
    highlight: Color(0xFF2F5D8A),
    highlightInk: Color(0xFFFFFFFF),
    chrome: Color(0xFFF2F3F4),
    chromeInk: Color(0xFF1C1C1C),
    border: Color(0xFFD4D9DD),
  ),
  QuranTheme(
    id: 'sepia',
    name: 'Sepia',
    description: 'Antique paper with a terracotta highlight',
    brightness: Brightness.light,
    background: Color(0xFFD2BC96),
    paper: Color(0xFFF3E3C3),
    ink: Color(0xFF3A2B1D),
    mutedInk: Color(0xFF7A644A),
    accent: Color(0xFF8A5A2B),
    accentInk: Color(0xFFFFF6E8),
    bandFill: Color(0xFFE8D3AC),
    selection: Color(0xFFE4CDA6),
    highlight: Color(0xFF7A3E2A),
    highlightInk: Color(0xFFFFF6E8),
    chrome: Color(0xFFE9D8B6),
    chromeInk: Color(0xFF3A2B1D),
    border: Color(0xFFC9AE82),
  ),
  QuranTheme(
    id: 'night',
    name: 'Night',
    description: 'Dark page with a muted blue highlight',
    brightness: Brightness.dark,
    background: Color(0xFF0E1214),
    paper: Color(0xFF171C1E),
    ink: Color(0xFFE9E2D2),
    mutedInk: Color(0xFF9C978A),
    accent: Color(0xFFC9A96A),
    accentInk: Color(0xFF1B1A16),
    bandFill: Color(0xFF232A2D),
    selection: Color(0xFF263236),
    highlight: Color(0xFF3E5C82),
    highlightInk: Color(0xFFF7F3E8),
    chrome: Color(0xFF12171A),
    chromeInk: Color(0xFFE9E2D2),
    border: Color(0xFF2C3538),
  ),
  QuranTheme(
    id: 'sand',
    name: 'Sand',
    description: 'Desert tan page with a deep teal highlight',
    brightness: Brightness.light,
    background: Color(0xFFD9C9A8),
    paper: Color(0xFFF6EDD8),
    ink: Color(0xFF33291C),
    mutedInk: Color(0xFF74644C),
    accent: Color(0xFF6B5A2E),
    accentInk: Color(0xFFFFF9EC),
    bandFill: Color(0xFFEADCB8),
    selection: Color(0xFFE3D2AE),
    highlight: Color(0xFF1F6F63),
    highlightInk: Color(0xFFF2FBF7),
    chrome: Color(0xFFEFE4C8),
    chromeInk: Color(0xFF33291C),
    border: Color(0xFFCCB88C),
  ),
  QuranTheme(
    id: 'mint',
    name: 'Mint',
    description: 'Soft green page with a forest highlight',
    brightness: Brightness.light,
    background: Color(0xFFCFDDD3),
    paper: Color(0xFFF4FAF4),
    ink: Color(0xFF1E2B24),
    mutedInk: Color(0xFF5F7266),
    accent: Color(0xFF2F6B4F),
    accentInk: Color(0xFFF4FAF4),
    bandFill: Color(0xFFE1EFE4),
    selection: Color(0xFFDCEBDD),
    highlight: Color(0xFF2E6B4F),
    highlightInk: Color(0xFFF4FAF4),
    chrome: Color(0xFFE9F2EA),
    chromeInk: Color(0xFF1E2B24),
    border: Color(0xFFC3D6C7),
  ),
  QuranTheme(
    id: 'midnight',
    name: 'Midnight',
    description: 'Deep navy page with a gold accent and blue highlight',
    brightness: Brightness.dark,
    background: Color(0xFF0A1020),
    paper: Color(0xFF121A2C),
    ink: Color(0xFFE7E3D6),
    mutedInk: Color(0xFF9AA3B5),
    accent: Color(0xFFD2B36A),
    accentInk: Color(0xFF1A1508),
    bandFill: Color(0xFF1B2740),
    selection: Color(0xFF20304C),
    highlight: Color(0xFF3E6C9A),
    highlightInk: Color(0xFFF4F8FF),
    chrome: Color(0xFF0E1626),
    chromeInk: Color(0xFFE7E3D6),
    border: Color(0xFF243352),
  ),
  QuranTheme(
    id: 'graphite',
    name: 'Graphite',
    description: 'Charcoal page with a slate highlight',
    brightness: Brightness.dark,
    background: Color(0xFF101112),
    paper: Color(0xFF1A1C1E),
    ink: Color(0xFFE8E4DA),
    mutedInk: Color(0xFF9B9A94),
    accent: Color(0xFFB9A27A),
    accentInk: Color(0xFF1A1C1E),
    bandFill: Color(0xFF26292C),
    selection: Color(0xFF2A2F33),
    highlight: Color(0xFF5A6B7A),
    highlightInk: Color(0xFFF7F5EF),
    chrome: Color(0xFF151719),
    chromeInk: Color(0xFFE8E4DA),
    border: Color(0xFF303438),
  ),
];

/// Resolves a saved theme id, falling back to the default theme.
QuranTheme quranThemeById(String? id) {
  for (final theme in quranThemes) {
    if (theme.id == id) return theme;
  }
  return quranThemes.first;
}
