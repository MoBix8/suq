import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'quran_meta.dart';
import 'quran_study.dart';
import 'quran_theme.dart';

/// Shows translations and tafsir for one ayah, plus a shortcut to recite from
/// that verse.
class QuranVerseSheet extends ConsumerStatefulWidget {
  const QuranVerseSheet({
    super.key,
    required this.verseKey,
    required this.theme,
    required this.onPlay,
  });

  final String verseKey;
  final QuranTheme theme;
  final VoidCallback onPlay;

  @override
  ConsumerState<QuranVerseSheet> createState() => _QuranVerseSheetState();
}

class _QuranVerseSheetState extends ConsumerState<QuranVerseSheet> {
  late final QuranStudyService _study;
  late Future<QuranVerseStudy> _verse;
  late Future<String> _tafsir;
  late int _translationId;
  late int _tafsirId;

  @override
  void initState() {
    super.initState();
    _study = ref.read(quranStudyProvider);
    final prefs = ref.read(prefsProvider);
    _translationId = _knownTranslation(
      prefs.getInt(quranTranslationKey) ?? quranTranslations.first.id,
    );
    _tafsirId = _knownTafsir(
      prefs.getInt(quranTafsirKey) ?? quranTafsirs.first.id,
    );
    _verse = _study.verse(widget.verseKey);
    _tafsir = _study.tafsir(_tafsirId, widget.verseKey);
  }

  int _knownTranslation(int id) {
    for (final item in quranTranslations) {
      if (item.id == id) return id;
    }
    return quranTranslations.first.id;
  }

  int _knownTafsir(int id) {
    for (final item in quranTafsirs) {
      if (item.id == id) return id;
    }
    return quranTafsirs.first.id;
  }

  void _selectTranslation(int id) {
    if (id == _translationId) return;
    setState(() => _translationId = id);
    unawaited(ref.read(prefsProvider).setInt(quranTranslationKey, id));
  }

  void _selectTafsir(int id) {
    if (id == _tafsirId) return;
    setState(() {
      _tafsirId = id;
      _tafsir = _study.tafsir(id, widget.verseKey);
    });
    unawaited(ref.read(prefsProvider).setInt(quranTafsirKey, id));
  }

  void _retry() {
    setState(() {
      _verse = _study.verse(widget.verseKey);
      _tafsir = _study.tafsir(_tafsirId, widget.verseKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final chapter = quranChapterByNumber(
      int.tryParse(widget.verseKey.split(':').first) ?? 1,
    );
    final height = MediaQuery.sizeOf(context).height * 0.9;
    final tafsir = quranTafsirs.firstWhere(
      (item) => item.id == _tafsirId,
      orElse: () => quranTafsirs.first,
    );

    return Theme(
      data: ThemeData(
        brightness: theme.brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accent,
          brightness: theme.brightness,
        ),
      ),
      child: Material(
        color: theme.paper,
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${chapter.nameSimple} · ${widget.verseKey}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.ink,
                            ),
                          ),
                          Text(
                            '${chapter.nameArabic} · ${chapter.meaning}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      color: theme.ink,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    FutureBuilder<QuranVerseStudy>(
                      future: _verse,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _StudyError(theme: theme, onRetry: _retry);
                        }
                        final study = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ArabicVerse(
                              text: study?.arabic ?? '…',
                              theme: theme,
                            ),
                            const SizedBox(height: 16),
                            _TranslationChips(
                              theme: theme,
                              selected: _translationId,
                              onSelected: _selectTranslation,
                            ),
                            const SizedBox(height: 10),
                            _TranslationText(
                              theme: theme,
                              text: study == null
                                  ? null
                                  : study.translations[_translationId] ??
                                      'This translation is not available for '
                                          'this verse.',
                              loading: study == null,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Divider(height: 1, color: theme.border),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 19,
                          color: theme.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Explanation (tafsir)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: theme.ink,
                                ),
                              ),
                              Text(
                                '${tafsir.language} · ${tafsir.author}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: theme.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _TafsirPicker(
                          theme: theme,
                          selected: _tafsirId,
                          onSelected: _selectTafsir,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<String>(
                      future: _tafsir,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _StudyError(theme: theme, onRetry: _retry);
                        }
                        final text = snapshot.data;
                        if (text == null) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: theme.accent,
                                ),
                              ),
                            ),
                          );
                        }
                        return Directionality(
                          textDirection: tafsir.language == 'Arabic'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: Text(
                            text,
                            textAlign: tafsir.language == 'Arabic'
                                ? TextAlign.justify
                                : TextAlign.start,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.8,
                              color: theme.ink,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Translations and tafsir from the Qur’an.com API. English '
                      'and Arabic tafsir are published there; Amharic, Oromo, '
                      'Somali and Swahili tafsir are not. Tigrinya translation '
                      'is not published yet.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: theme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accent,
                        foregroundColor: theme.accentInk,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onPlay();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Recite from this verse'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArabicVerse extends StatelessWidget {
  const _ArabicVerse({required this.text, required this.theme});

  final String text;
  final QuranTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.bandFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          text,
          textAlign: TextAlign.right,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: 'AmiriQuran',
            fontSize: 25,
            height: 1.7,
            color: theme.ink,
          ),
        ),
      ),
    );
  }
}

class _TranslationChips extends StatelessWidget {
  const _TranslationChips({
    required this.theme,
    required this.selected,
    required this.onSelected,
  });

  final QuranTheme theme;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in quranTranslations)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: item.id == selected,
                onSelected: (_) => onSelected(item.id),
                showCheckmark: false,
                selectedColor: theme.accent,
                backgroundColor: theme.paper,
                side: BorderSide(
                  color: item.id == selected ? theme.accent : theme.border,
                ),
                label: Text(
                  item.nativeLabel == item.label
                      ? item.label
                      : '${item.nativeLabel} · ${item.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.id == selected ? theme.accentInk : theme.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TranslationText extends StatelessWidget {
  const _TranslationText({
    required this.theme,
    required this.text,
    required this.loading,
  });

  final QuranTheme theme;
  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: theme.accent,
            ),
          ),
        ),
      );
    }
    return Text(
      text ?? '',
      style: TextStyle(
        fontSize: 15,
        height: 1.65,
        color: theme.ink,
      ),
    );
  }
}

class _TafsirPicker extends StatelessWidget {
  const _TafsirPicker({
    required this.theme,
    required this.selected,
    required this.onSelected,
  });

  final QuranTheme theme;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = quranTafsirs.firstWhere(
      (item) => item.id == selected,
      orElse: () => quranTafsirs.first,
    );

    return PopupMenuButton<int>(
      tooltip: 'Choose tafsir',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final item in quranTafsirs)
          PopupMenuItem<int>(
            value: item.id,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: item.id == selected
                      ? Icon(Icons.check_rounded, size: 16, color: theme.accent)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.author,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.bandFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: theme.ink),
          ],
        ),
      ),
    );
  }
}

class _StudyError extends StatelessWidget {
  const _StudyError({required this.theme, required this.onRetry});

  final QuranTheme theme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: theme.mutedInk),
          const SizedBox(height: 8),
          Text(
            'Could not load this verse. Check your connection.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: theme.mutedInk),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
