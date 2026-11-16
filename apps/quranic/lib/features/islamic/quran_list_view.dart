import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quran_audio.dart';
import 'quran_meta.dart';
import 'quran_study.dart';
import 'quran_theme.dart';

/// A readable, scrolling list of a whole surah.
///
/// It opens at the verse printed on the current mushaf page, follows the verse
/// being recited so it stays in view, and keeps the active word highlighted.
class QuranPageListView extends ConsumerStatefulWidget {
  const QuranPageListView({
    super.key,
    required this.page,
    required this.translationId,
    required this.theme,
    required this.activeWord,
    required this.currentVerse,
    required this.onVerseTap,
    required this.onPlayVerse,
  });

  final int page;
  final int translationId;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final ValueListenable<String?> currentVerse;
  final ValueChanged<String> onVerseTap;
  final ValueChanged<String> onPlayVerse;

  @override
  ConsumerState<QuranPageListView> createState() => _QuranPageListViewState();
}

class _QuranPageListViewState extends ConsumerState<QuranPageListView> {
  final ScrollController _controller = ScrollController();
  final Map<String, GlobalKey> _verseKeys = {};

  late Future<QuranChapterStudy> _future;
  late int _chapter;
  QuranChapterStudy? _study;

  int? _scrolledChapter;
  int? _scrolledPage;

  @override
  void initState() {
    super.initState();
    _chapter = quranChapterForPage(widget.page).number;
    _future = _load();
    widget.currentVerse.addListener(_onActiveVerse);
  }

  @override
  void didUpdateWidget(covariant QuranPageListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentVerse != widget.currentVerse) {
      oldWidget.currentVerse.removeListener(_onActiveVerse);
      widget.currentVerse.addListener(_onActiveVerse);
    }

    final chapter = quranChapterForPage(widget.page).number;
    if (chapter != _chapter || oldWidget.translationId != widget.translationId) {
      _chapter = chapter;
      _verseKeys.clear();
      _scrolledChapter = null;
      _scrolledPage = null;
      _study = null;
      _future = _load();
      return;
    }

    if (oldWidget.page != widget.page) {
      // A page turn inside the same surah: bring the new page's first verse
      // into view once the list has laid out.
      _scrolledChapter = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final study = _study;
        if (!mounted || study == null) return;
        _scheduleInitialScroll(study);
      });
    }
  }

  @override
  void dispose() {
    widget.currentVerse.removeListener(_onActiveVerse);
    _controller.dispose();
    super.dispose();
  }

  Future<QuranChapterStudy> _load() {
    return ref
        .read(quranStudyProvider)
        .chapter(_chapter, widget.translationId);
  }

  void _retry() {
    setState(() {
      _verseKeys.clear();
      _scrolledChapter = null;
      _scrolledPage = null;
      _study = null;
      _future = _load();
    });
  }

  GlobalKey _keyFor(String verseKey) {
    return _verseKeys.putIfAbsent(verseKey, GlobalKey.new);
  }

  void _onActiveVerse() {
    final key = widget.currentVerse.value;
    if (key == null || !mounted) return;
    if (!key.startsWith('$_chapter:')) return;
    _scrollToVerse(key, animate: true);
  }

  String? _firstVerseOnPage(QuranChapterStudy study) {
    // A long verse can start on an earlier page and continue onto this one, so
    // the verse at the top of the page is the last one that starts on or before
    // it, not the first one that starts on it.
    String? candidate;
    for (final verse in study.verses) {
      final page = verse.pageNumber;
      if (page == null) continue;
      if (page > widget.page) break;
      candidate = verse.verseKey;
    }
    if (candidate != null) return candidate;
    return study.verses.isEmpty ? null : study.verses.first.verseKey;
  }

  void _scheduleInitialScroll(QuranChapterStudy study) {
    if (_scrolledChapter == _chapter && _scrolledPage == widget.page) return;
    _scrolledChapter = _chapter;
    _scrolledPage = widget.page;

    final key = _firstVerseOnPage(study);
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToVerse(key, animate: false);
    });
  }

  int _indexOf(String verseKey) {
    final verses = _study?.verses;
    if (verses == null) return -1;
    for (var index = 0; index < verses.length; index++) {
      if (verses[index].verseKey == verseKey) return index;
    }
    return -1;
  }

  void _scrollToVerse(String verseKey, {required bool animate}) {
    if (!mounted) return;

    final context = _verseKeys[verseKey]?.currentContext;
    if (context != null) {
      _reveal(context, animate: animate);
      return;
    }

    // The target has not been built yet (long surah, or the recitation jumped
    // ahead). Move to its approximate position first, then refine once the
    // item exists.
    final index = _indexOf(verseKey);
    final total = _study?.verses.length ?? 0;
    if (index < 0 || total == 0 || !_controller.hasClients) return;

    final position = _controller.position;
    final ratio = index / total;
    final target = (position.maxScrollExtent * ratio).clamp(
      0.0,
      position.maxScrollExtent,
    ).toDouble();
    if (animate) {
      unawaited(
        _controller
            .animateTo(
              target,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final refined = _verseKeys[verseKey]?.currentContext;
            if (refined != null) _reveal(refined, animate: false);
          });
        }),
      );
    } else {
      _controller.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final refined = _verseKeys[verseKey]?.currentContext;
        if (refined != null) _reveal(refined, animate: false);
      });
    }
  }

  void _reveal(BuildContext context, {required bool animate}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;

    final position = _controller.hasClients ? _controller.position : null;
    if (position != null) {
      final offset = viewport.getOffsetToReveal(box, 0.0).offset;
      final top = offset;
      final bottom = offset + box.size.height;
      final visibleTop = position.pixels + 24;
      final visibleBottom =
          position.pixels + position.viewportDimension - 24;
      // Do not move the list while the verse is comfortably in view; this
      // keeps manual scrolling from fighting the recitation.
      if (top >= visibleTop && bottom <= visibleBottom) return;
    }

    unawaited(
      Scrollable.ensureVisible(
        context,
        alignment: 0.28,
        duration: animate
            ? const Duration(milliseconds: 320)
            : Duration.zero,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuranChapterStudy>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ListMessage(
            theme: widget.theme,
            icon: Icons.cloud_off_rounded,
            title: 'This surah could not be loaded.',
            body: 'Check your connection, then try again. The page view stays '
                'available offline.',
            onRetry: _retry,
          );
        }

        final study = snapshot.data;
        if (study == null) {
          return _ListMessage(
            theme: widget.theme,
            icon: null,
            title: 'Loading ${quranChapterByNumber(_chapter).nameSimple}…',
          );
        }

        _study = study;
        _scheduleInitialScroll(study);

        return ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 28),
          itemCount: study.verses.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _ListHeader(
                theme: widget.theme,
                chapter: quranChapterByNumber(_chapter),
                page: widget.page,
                translationId: widget.translationId,
                verseCount: study.verses.length,
                onPlay: study.verses.isEmpty
                    ? null
                    : () => widget.onPlayVerse(study.verses.first.verseKey),
              );
            }
            final verse = study.verses[index - 1];
            return _VerseCard(
              key: _keyFor(verse.verseKey),
              verse: verse,
              translationId: widget.translationId,
              theme: widget.theme,
              activeWord: widget.activeWord,
              currentVerse: widget.currentVerse,
              onTap: () => widget.onVerseTap(verse.verseKey),
              onPlay: () => widget.onPlayVerse(verse.verseKey),
            );
          },
        );
      },
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.theme,
    required this.chapter,
    required this.page,
    required this.translationId,
    required this.verseCount,
    required this.onPlay,
  });

  final QuranTheme theme;
  final QuranChapter chapter;
  final int page;
  final int translationId;
  final int verseCount;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final translation = quranTranslations.firstWhere(
      (item) => item.id == translationId,
      orElse: () => quranTranslations.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.bandFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: Text(
              'Surah ${chapter.number}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: theme.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.nameSimple,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.ink,
                  ),
                ),
                Text(
                  'Whole surah · $verseCount verses · page $page · '
                  '${translation.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: theme.mutedInk),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Recite this surah',
            onPressed: onPlay,
            visualDensity: VisualDensity.compact,
            color: theme.accent,
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _VerseCard extends StatefulWidget {
  const _VerseCard({
    super.key,
    required this.verse,
    required this.translationId,
    required this.theme,
    required this.activeWord,
    required this.currentVerse,
    required this.onTap,
    required this.onPlay,
  });

  final QuranVerseStudy verse;
  final int translationId;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final ValueListenable<String?> currentVerse;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  State<_VerseCard> createState() => _VerseCardState();
}

class _VerseCardState extends State<_VerseCard> {
  bool _activeVerse = false;

  @override
  void initState() {
    super.initState();
    _activeVerse = _isActiveVerse();
    widget.currentVerse.addListener(_onVerseChanged);
    widget.activeWord.addListener(_onWordChanged);
  }

  @override
  void didUpdateWidget(covariant _VerseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentVerse != widget.currentVerse) {
      oldWidget.currentVerse.removeListener(_onVerseChanged);
      widget.currentVerse.addListener(_onVerseChanged);
    }
    if (oldWidget.activeWord != widget.activeWord) {
      oldWidget.activeWord.removeListener(_onWordChanged);
      widget.activeWord.addListener(_onWordChanged);
    }
    _activeVerse = _isActiveVerse();
  }

  @override
  void dispose() {
    widget.currentVerse.removeListener(_onVerseChanged);
    widget.activeWord.removeListener(_onWordChanged);
    super.dispose();
  }

  bool _isActiveVerse() {
    return widget.currentVerse.value == widget.verse.verseKey;
  }

  void _onVerseChanged() {
    final active = _isActiveVerse();
    if (active != _activeVerse) setState(() => _activeVerse = active);
  }

  void _onWordChanged() {
    // Repaint the active card whenever the recitation moves, including when it
    // stops (the word becomes null) so the old highlight is cleared.
    if (!_activeVerse || !mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final translation = widget.verse.translations[widget.translationId] ?? '';
    final chapter = quranChapterByNumber(
      int.tryParse(widget.verse.verseKey.split(':').first) ?? 1,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _activeVerse ? theme.selection : theme.paper,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _activeVerse ? theme.accent : theme.border,
                width: _activeVerse ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      widget.verse.verseKey,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chapter.nameSimple,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.mutedInk,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Recite from this verse',
                      onPressed: widget.onPlay,
                      visualDensity: VisualDensity.compact,
                      color: theme.accent,
                      icon: const Icon(Icons.play_circle_outline_rounded),
                    ),
                  ],
                ),
                _VerseText(
                  verse: widget.verse,
                  theme: theme,
                  activeWord: _activeVerse ? widget.activeWord.value : null,
                ),
                if (translation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: theme.border),
                  const SizedBox(height: 10),
                  Text(
                    translation,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.55,
                      color: theme.ink.withValues(alpha: 0.88),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Translation not available for this verse.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: theme.mutedInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the verse with the word being recited filled in a solid highlight.
class _VerseText extends StatelessWidget {
  const _VerseText({
    required this.verse,
    required this.theme,
    required this.activeWord,
  });

  final QuranVerseStudy verse;
  final QuranTheme theme;
  final QuranWordRef? activeWord;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontFamily: 'AmiriQuran',
      fontSize: 24,
      height: 1.55,
    );

    if (verse.words.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Text(
          verse.arabic,
          textAlign: TextAlign.right,
          textScaler: TextScaler.noScaling,
          style: base.copyWith(color: theme.ink),
        ),
      );
    }

    final spans = <InlineSpan>[];
    for (final word in verse.words) {
      if (word.isAyahEnd) {
        spans.add(
          TextSpan(
            text: ' ﴿${word.text}﴾ ',
            style: base.copyWith(
              fontSize: 15,
              color: theme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        continue;
      }

      final active = activeWord != null &&
          activeWord!.verseKey == verse.verseKey &&
          activeWord!.wordIndex == word.position;
      spans.add(
        TextSpan(
          text: '${word.text} ',
          style: base.copyWith(
            color: active ? theme.highlightInk : theme.ink,
            backgroundColor: active ? theme.highlight : null,
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.right,
        textScaler: TextScaler.noScaling,
        style: base.copyWith(color: theme.ink),
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.theme,
    required this.icon,
    required this.title,
    this.body,
    this.onRetry,
  });

  final QuranTheme theme;
  final IconData? icon;
  final String title;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconData == null)
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: theme.accent,
                ),
              )
            else
              Icon(iconData, size: 36, color: theme.mutedInk),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: theme.mutedInk,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
