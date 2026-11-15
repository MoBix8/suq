import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

import 'quran_audio.dart';
import 'quran_audio_store.dart';
import 'quran_bookmarks.dart';
import 'quran_download_sheet.dart';
import 'quran_list_view.dart';
import 'quran_meta.dart';
import 'quran_page_cache.dart';
import 'quran_study.dart';
import 'quran_theme.dart';
import 'quran_verse_sheet.dart';

const _bismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

/// Reads the Qur'an page by page, laid out like the printed Madinah mushaf,
/// with synchronized recitation and verse translations.
class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key, this.initialPage});

  /// Page to open when set; otherwise the last page the shop read is used.
  final int? initialPage;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  late final PageController _controller;
  late final QuranAudioController _audio;
  late final QuranAudioStore _store;
  late final QuranBookmarks _bookmarks;
  late int _page;

  QuranPageData? _visibleData;
  String? _selectedVerse;
  String? _shownError;
  late QuranTheme _theme;
  late int _translationId;
  late QuranViewMode _viewMode;

  /// Whether turning to a page should start its recitation. Opening the reader
  /// never starts playback; pausing with the footer button clears this until
  /// the shop presses play.
  bool _autoPlay = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    final saved = widget.initialPage ?? prefs.getInt(quranLastPageKey) ?? 1;
    _page = saved.clamp(1, quranPageCount).toInt();
    _controller = PageController(initialPage: _page - 1);
    _theme = quranThemeById(prefs.getString(quranThemeKey));
    _translationId =
        prefs.getInt(quranTranslationKey) ?? quranTranslations.first.id;
    _viewMode = QuranViewMode.fromValue(prefs.getString(quranViewModeKey));

    _store = ref.read(quranAudioStoreProvider);
    _bookmarks = QuranBookmarks(prefs);
    _bookmarks.addListener(_onBookmarks);
    _audio = QuranAudioController(prefs: prefs, store: _store);
    _audio.addListener(_onAudioChanged);
    _audio.currentVerse.addListener(_onAudioVerse);

    _remember(_page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchAround(_page);
      // Opening the reader never starts the recitation; turning the page still
      // does, unless the shop has paused playback.
      unawaited(_syncPage(_page, autoplay: false));
    });
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    _audio.currentVerse.removeListener(_onAudioVerse);
    _audio.dispose();
    _bookmarks.removeListener(_onBookmarks);
    _bookmarks.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onBookmarks() {
    if (mounted) setState(() {});
  }

  void _remember(int page) {
    unawaited(ref.read(prefsProvider).setInt(quranLastPageKey, page));
  }

  void _prefetchAround(int page) {
    final cache = ref.read(quranPageCacheProvider);
    unawaited(cache.prefetch(page + 1));
    unawaited(cache.prefetch(page - 1));
  }

  void _onAudioChanged() {
    if (!mounted) return;
    final error = _audio.error;
    if (_audio.isPlaying) _shownError = null;
    setState(() {});
    if (error != null && error != _shownError) {
      _shownError = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _onAudioVerse() {
    final key = _audio.currentVerse.value;
    if (key == null || !mounted) return;
    // In list view the whole surah is already on screen and follows the
    // recitation itself, so only the page view needs to walk pages.
    if (_viewMode == QuranViewMode.page) unawaited(_followVerse(key));
  }

  /// Loads the page the recitation has reached, so playback can walk from one
  /// page to the next without the shop turning pages by hand.
  Future<void> _followVerse(String verseKey) async {
    final visible = _visibleData;
    if (visible != null && visible.verseKeys.contains(verseKey)) return;

    final cache = ref.read(quranPageCacheProvider);
    final last = math.min(_page + 4, quranPageCount);
    for (var page = _page + 1; page <= last; page++) {
      try {
        final data = await cache.page(page);
        if (!mounted) return;
        if (data.verseKeys.contains(verseKey)) {
          if (page != _page) _goToPage(page);
          return;
        }
      } catch (_) {
        return;
      }
    }
  }

  /// Makes the visible page the source for audio, starting its recitation when
  /// autoplay is on. If the recitation is already on this page (because it
  /// walked here on its own), playback is left untouched.
  Future<void> _syncPage(int page, {bool autoplay = true}) async {
    QuranPageData data;
    try {
      data = await ref.read(quranPageCacheProvider).page(page);
    } catch (_) {
      return;
    }
    if (!mounted || _page != page) return;
    _visibleData = data;

    if (!autoplay) return;

    final current = _audio.currentVerseKey;
    if (!_autoPlay) {
      if (current != null && !data.verseKeys.contains(current)) {
        unawaited(_audio.stop());
      }
      return;
    }
    if (current != null && data.verseKeys.contains(current)) return;
    if (data.verseKeys.isEmpty) return;
    unawaited(_audio.playFromVerse(data.verseKeys.first));
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() {
      _page = page;
      _visibleData = null;
      _selectedVerse = null;
    });
    _remember(page);
    _prefetchAround(page);
    unawaited(_syncPage(page));
  }

  void _goToPage(int page) {
    final target = page.clamp(1, quranPageCount).toInt();
    if (target == _page) return;

    if (_viewMode == QuranViewMode.page && _controller.hasClients) {
      _controller.animateToPage(
        target - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // In list view there is no PageView, so move the page directly.
    setState(() {
      _page = target;
      _visibleData = null;
      _selectedVerse = null;
    });
    _remember(target);
    _prefetchAround(target);
    unawaited(_syncPage(target));
  }

  // In an Arabic book the next page comes from the left, so the left arrow
  // (and the left key) moves forward.
  void _nextPage() => _goToPage(_page + 1);
  void _previousPage() => _goToPage(_page - 1);

  Future<void> _openJumpSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _theme.paper,
      builder: (_) => _QuranJumpSheet(
        currentPage: _page,
        theme: _theme,
        bookmarks: _bookmarks,
      ),
    );
    if (selected != null) _goToPage(selected);
  }

  Future<void> _toggleBookmark() async {
    final adding = !_bookmarks.contains(_page);
    await _bookmarks.toggle(_page);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          adding ? 'Page $_page bookmarked.' : 'Bookmark removed.',
        ),
      ),
    );
  }

  Future<void> _openDownloadSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _theme.paper,
      builder: (_) => QuranDownloadSheet(
        theme: _theme,
        reciterId: _audio.reciterId,
        page: _page,
      ),
    );
  }

  Future<void> _openVerseSheet(String verseKey) async {
    if (verseKey.isEmpty) return;
    setState(() => _selectedVerse = verseKey);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _theme.paper,
      builder: (_) => QuranVerseSheet(
        verseKey: verseKey,
        theme: _theme,
        onPlay: () => unawaited(_playVerse(verseKey)),
      ),
    );
    if (!mounted) return;
    final translation = ref.read(prefsProvider).getInt(quranTranslationKey);
    setState(() {
      _selectedVerse = null;
      if (translation != null) _translationId = translation;
    });
  }

  Future<void> _playVerse(String verseKey) async {
    _autoPlay = true;
    await _audio.playFromVerse(verseKey);
  }

  Future<void> _togglePlayback() async {
    if (_audio.isLoading) return;
    if (_audio.isPlaying) {
      _autoPlay = false;
      await _audio.pause();
      return;
    }

    _autoPlay = true;
    if (_audio.currentVerseKey != null) {
      await _audio.resume();
      return;
    }
    final data = _visibleData;
    if (data != null && data.verseKeys.isNotEmpty) {
      await _audio.playFromVerse(data.verseKeys.first);
    } else {
      unawaited(_syncPage(_page));
    }
  }

  Future<void> _selectReciter(int id) async {
    // The controller restarts the current verse when recitation was playing.
    // Choosing a reciter while paused never starts playback on its own.
    await _audio.setReciter(id);
  }

  void _selectTheme(QuranTheme theme) {
    if (theme.id == _theme.id) return;
    setState(() => _theme = theme);
    unawaited(ref.read(prefsProvider).setString(quranThemeKey, theme.id));
  }

  Future<void> _openThemeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _theme.paper,
      builder: (_) => _QuranThemeSheet(
        selected: _theme,
        onSelected: _selectTheme,
      ),
    );
  }

  void _toggleViewMode() {
    final next = _viewMode == QuranViewMode.page
        ? QuranViewMode.list
        : QuranViewMode.page;
    setState(() => _viewMode = next);
    unawaited(ref.read(prefsProvider).setString(quranViewModeKey, next.value));

    if (next == QuranViewMode.page) {
      // The PageView is rebuilt after being absent in list view, so put it
      // back on the page the shop is reading.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.jumpToPage(_page - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = ref.watch(quranPageCacheProvider);
    final chapter = quranChapterForPage(_page);
    final reciter = quranReciterById(_audio.reciterId);
    final theme = _theme;
    final chromeInk = theme.chromeInk;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _nextPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _previousPage,
        const SingleActivator(LogicalKeyboardKey.pageDown): _nextPage,
        const SingleActivator(LogicalKeyboardKey.pageUp): _previousPage,
        const SingleActivator(LogicalKeyboardKey.space):
            () => unawaited(_togglePlayback()),
      },
      child: Focus(
        autofocus: true,
        child: Theme(
          data: ThemeData(
            brightness: theme.brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.accent,
              brightness: theme.brightness,
            ),
            canvasColor: theme.paper,
            dividerColor: theme.border,
          ),
          child: Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            backgroundColor: theme.chrome,
            foregroundColor: chromeInk,
            iconTheme: IconThemeData(color: chromeInk),
            elevation: 0,
            titleSpacing: 4,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Qur'an",
                  style: TextStyle(
                    color: chromeInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${chapter.nameSimple} · Page $_page of $quranPageCount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: chromeInk.withValues(alpha: 0.66),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<int>(
                tooltip: 'Reciter',
                icon: const Icon(Icons.record_voice_over_rounded),
                constraints: const BoxConstraints(minWidth: 250),
                onSelected: (id) => unawaited(_selectReciter(id)),
                itemBuilder: (context) => [
                  for (final item in quranReciters)
                    PopupMenuItem<int>(
                      value: item.id,
                      child: Row(
                        children: [
                          Icon(
                            item.id == _audio.reciterId
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 18,
                            color: item.id == _audio.reciterId
                                ? theme.accent
                                : theme.mutedInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.style,
                                  style: TextStyle(
                                    fontSize: 11,
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
              ),
              IconButton(
                tooltip: _bookmarks.contains(_page)
                    ? 'Remove page bookmark'
                    : 'Bookmark this page',
                visualDensity: VisualDensity.compact,
                onPressed: () => unawaited(_toggleBookmark()),
                icon: Icon(
                  _bookmarks.contains(_page)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
              IconButton(
                tooltip: _viewMode == QuranViewMode.page
                    ? 'Switch to list view'
                    : 'Switch to page view',
                visualDensity: VisualDensity.compact,
                onPressed: _toggleViewMode,
                icon: Icon(
                  _viewMode == QuranViewMode.page
                      ? Icons.view_agenda_rounded
                      : Icons.menu_book_rounded,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'theme') unawaited(_openThemeSheet());
                  if (value == 'jump') unawaited(_openJumpSheet());
                  if (value == 'offline') unawaited(_openDownloadSheet());
                },
                itemBuilder: (context) => const [
                  PopupMenuItem<String>(
                    value: 'theme',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Page theme'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'jump',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.toc_rounded),
                      title: Text('Surah & page'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'offline',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.download_for_offline_outlined),
                      title: Text('Offline recitation'),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: _viewMode == QuranViewMode.page
              ? ScrollConfiguration(
                  // PageView ignores mouse drags on desktop by default; allow
                  // them so the mushaf can be turned with a mouse.
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PageView.builder(
                    controller: _controller,
                    reverse: true,
                    physics: const PageScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    itemCount: quranPageCount,
                    itemBuilder: (context, index) => _MushafPage(
                      page: index + 1,
                      cache: cache,
                      theme: theme,
                      activeWord: _audio.activeWord,
                      selectedVerse: _selectedVerse,
                      onWordTap: _playVerse,
                      onWordLongPress: _openVerseSheet,
                    ),
                  ),
                )
              : QuranPageListView(
                  page: _page,
                  translationId: _translationId,
                  theme: theme,
                  activeWord: _audio.activeWord,
                  currentVerse: _audio.currentVerse,
                  onVerseTap: _openVerseSheet,
                  onPlayVerse: (key) => unawaited(_playVerse(key)),
                ),
          bottomNavigationBar: _ReaderBar(
            page: _page,
            chapter: chapter,
            reciter: reciter,
            theme: theme,
            isPlaying: _audio.isPlaying,
            isLoading: _audio.isLoading,
            onPrevious: _page > 1 ? _previousPage : null,
            onNext: _page < quranPageCount ? _nextPage : null,
            onOpenJump: _openJumpSheet,
            onTogglePlay: () => unawaited(_togglePlayback()),
          ),
          ),
        ),
      ),
    );
  }
}

class _ReaderBar extends StatelessWidget {
  const _ReaderBar({
    required this.page,
    required this.chapter,
    required this.reciter,
    required this.theme,
    required this.isPlaying,
    required this.isLoading,
    required this.onPrevious,
    required this.onNext,
    required this.onOpenJump,
    required this.onTogglePlay,
  });

  final int page;
  final QuranChapter chapter;
  final QuranReciter reciter;
  final QuranTheme theme;
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpenJump;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context) {
    final ink = theme.chromeInk;
    return SafeArea(
      top: false,
      child: Material(
        color: theme.chrome,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
          child: Row(
            children: [
              // The next page sits to the left, as in an Arabic book.
              IconButton(
                tooltip: 'Next page',
                onPressed: onNext,
                color: ink,
                disabledColor: ink.withValues(alpha: 0.24),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onOpenJump,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _arabicNumber(page),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'AmiriQuran',
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Page $page of $quranPageCount · ${chapter.nameSimple}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          reciter.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: isPlaying ? 'Pause recitation' : 'Play recitation',
                onPressed: onTogglePlay,
                style: IconButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.accentInk,
                ),
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.accentInk,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: onPrevious,
                color: ink,
                disabledColor: ink.withValues(alpha: 0.24),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MushafPage extends StatefulWidget {
  const _MushafPage({
    required this.page,
    required this.cache,
    required this.theme,
    required this.activeWord,
    required this.selectedVerse,
    required this.onWordTap,
    this.onWordLongPress,
  });

  final int page;
  final QuranPageCache cache;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final String? selectedVerse;
  final ValueChanged<String> onWordTap;
  final ValueChanged<String>? onWordLongPress;

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  late Future<QuranPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache.page(widget.page);
  }

  @override
  void didUpdateWidget(covariant _MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      _future = widget.cache.page(widget.page);
    }
  }

  void _retry() {
    setState(() {
      _future = widget.cache.page(widget.page, refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: _PageFrame(
        theme: widget.theme,
        child: FutureBuilder<QuranPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _MushafTextPage(
                data: snapshot.data!,
                theme: widget.theme,
                activeWord: widget.activeWord,
                selectedVerse: widget.selectedVerse,
                onWordTap: widget.onWordTap,
                onWordLongPress: widget.onWordLongPress,
              );
            }
            if (snapshot.hasError) {
              return _PageError(
                page: widget.page,
                theme: widget.theme,
                onRetry: _retry,
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: widget.theme.accent,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Loading page ${widget.page}…',
                  style: TextStyle(
                    color: widget.theme.mutedInk,
                    fontSize: 12.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MushafTextPage extends StatelessWidget {
  const _MushafTextPage({
    required this.data,
    required this.theme,
    required this.activeWord,
    required this.selectedVerse,
    required this.onWordTap,
    this.onWordLongPress,
  });

  final QuranPageData data;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final String? selectedVerse;
  final ValueChanged<String> onWordTap;
  final ValueChanged<String>? onWordLongPress;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.copyWith(
      height: 1.15,
      // Material's body style carries a small letterSpacing, which would push
      // the joined Arabic letters apart; the mushaf needs tight clusters.
      letterSpacing: 0,
      wordSpacing: 0,
      color: theme.ink,
      fontFamily: 'AmiriQuran',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Pages 1 and 2 are centred in the printed mushaf, but keep the same
        // script size as every other page.
        final centered = data.page <= 2;
        final topPadding = centered ? height * 0.08 : height * 0.03;
        // Balanced safety margins keep the text block clear of the page edge
        // on narrow phones without shrinking the script on wide pages.
        final horizontal = math.max(width * 0.06, 16.0);
        final bodyWidth = width - horizontal * 2;
        final bodyHeight = height - topPadding - height * 0.03;
        final lineCount = data.lineCount;
        final marginHeading = data.marginHeading;

        // A surah that begins at the top of the page has its name band above
        // the printed line grid, so reserve a strip for it.
        final headerHeight = marginHeading == null ? 0.0 : bodyHeight * 0.085;
        // Size every page against the standard fifteen-line grid. Pages 1 and
        // 2 have fewer lines, so using their own slot height would enlarge the
        // script; the printed mushaf keeps one size throughout. The slot is
        // taken from the full body so the surah band does not shrink the type
        // on pages that open a surah.
        final referenceSlot = bodyHeight / 15;
        final fontSize = _fontSizeFor(baseStyle, bodyWidth, referenceSlot);
        final style = baseStyle.copyWith(fontSize: fontSize);

        Widget grid;
        if (centered) {
          grid = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var number = 1; number <= lineCount; number++)
                  SizedBox(
                    height: referenceSlot,
                    child: _PageLineSlot(
                      data: data,
                      lineNumber: number,
                      style: style,
                      theme: theme,
                      activeWord: activeWord,
                      selectedVerse: selectedVerse,
                      centered: true,
                      onWordTap: onWordTap,
                      onWordLongPress: onWordLongPress,
                    ),
                  ),
              ],
            ),
          );
        } else {
          grid = Column(
            children: [
              for (var number = 1; number <= lineCount; number++)
                Expanded(
                  child: _PageLineSlot(
                    data: data,
                    lineNumber: number,
                    style: style,
                    theme: theme,
                    activeWord: activeWord,
                    selectedVerse: selectedVerse,
                    centered: false,
                    onWordTap: onWordTap,
                    onWordLongPress: onWordLongPress,
                  ),
                ),
            ],
          );
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              topPadding,
              horizontal,
              height * 0.03,
            ),
            child: Column(
              children: [
                if (marginHeading != null)
                  SizedBox(
                    height: headerHeight,
                    child: _SurahBand(
                      chapter: marginHeading.chapter,
                      style: style,
                      theme: theme,
                    ),
                  ),
                Expanded(child: grid),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Picks one font size that fits the widest line and the line height.
  ///
  /// The first pass measures every word at a large size and scales the result
  /// down, which is cheap. Glyph advances are not perfectly linear in the font
  /// size, though, so the chosen size is then checked against the real text
  /// metrics and reduced until no line runs past the margin.
  double _fontSizeFor(TextStyle baseStyle, double width, double slotHeight) {
    const base = 100.0;
    const margin = 0.97;
    final measureStyle = baseStyle.copyWith(fontSize: base);
    var widest = 0.0;

    for (final line in data.lines.values) {
      widest = math.max(widest, _lineWidthAt(line, measureStyle));
    }

    final widthSize = widest == 0 ? slotHeight : width / widest * base;
    var fontSize = math.min(widthSize, slotHeight * 0.58) * margin;

    for (var attempt = 0; attempt < 3; attempt++) {
      final style = baseStyle.copyWith(fontSize: fontSize);
      var actual = 0.0;
      for (final line in data.lines.values) {
        actual = math.max(actual, _lineWidthAt(line, style));
      }
      if (actual <= width * margin) return fontSize;
      fontSize *= width * margin / actual;
    }
    return fontSize;
  }
}

/// Width the line needs at [style], using the same metrics the line renderer
/// uses: real space advances and the smaller ayah-badge digits.
double _lineWidthAt(QuranPageLine line, TextStyle style) {
  final unit = style.fontSize ?? 14;
  final badgeStyle = style.copyWith(fontSize: unit * 0.55, height: 1.0);
  final badgeGap = unit * 0.50;
  var total = 0.0;
  for (var index = 0; index < line.words.length; index++) {
    final word = line.words[index];
    if (word.isAyahEnd) {
      total += _measure(_badgeLabel(word), badgeStyle);
    } else {
      total += _measure(word.text, style);
    }
    if (index < line.words.length - 1) {
      total += _measure(' ', style);
      if (word.isAyahEnd || line.words[index + 1].isAyahEnd) {
        total += badgeGap;
      }
    }
  }
  return total;
}

class _PageLineSlot extends StatelessWidget {
  const _PageLineSlot({
    required this.data,
    required this.lineNumber,
    required this.style,
    required this.theme,
    required this.activeWord,
    required this.selectedVerse,
    required this.centered,
    required this.onWordTap,
    this.onWordLongPress,
  });

  final QuranPageData data;
  final int lineNumber;
  final TextStyle style;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final String? selectedVerse;
  final bool centered;
  final ValueChanged<String> onWordTap;
  final ValueChanged<String>? onWordLongPress;

  @override
  Widget build(BuildContext context) {
    final heading = data.headingAt(lineNumber);
    if (heading != null) {
      return _SurahBand(chapter: heading.chapter, style: style, theme: theme);
    }
    if (data.bismillahAt(lineNumber) != null) {
      return _BismillahLine(style: style, theme: theme);
    }
    final line = data.line(lineNumber);
    if (line == null) return const SizedBox.shrink();
    return _MushafLine(
      line: line,
      style: style,
      theme: theme,
      activeWord: activeWord,
      selectedVerse: selectedVerse,
      centered: centered,
      nextLineBase: _lineStartBase(data, lineNumber + 1),
      onWordTap: onWordTap,
      onWordLongPress: onWordLongPress,
    );
  }
}

/// First pronounced letter of the next printed line, used to colour a tanween
/// or noon sakinah that sits at the end of a line.
int? _lineStartBase(QuranPageData data, int from) {
  for (var number = from; number <= data.lineCount; number++) {
    if (data.headingAt(number) != null) continue;
    // A surah that starts on this line opens with the bismillah.
    if (data.bismillahAt(number) != null) return 0x0628;
    final line = data.line(number);
    if (line == null) continue;
    for (final word in line.words) {
      if (word.isAyahEnd) continue;
      final clusters = _clusters(word.text);
      if (clusters.isEmpty) continue;
      final first = clusters.first.runes.first;
      if ((first == 0x0627 || first == 0x0671) && clusters.length > 1) {
        return clusters[1].runes.first;
      }
      return first;
    }
  }
  return null;
}

class _MushafLine extends StatefulWidget {
  const _MushafLine({
    required this.line,
    required this.style,
    required this.theme,
    required this.activeWord,
    required this.selectedVerse,
    required this.centered,
    required this.nextLineBase,
    this.onWordTap,
    this.onWordLongPress,
  });

  final QuranPageLine line;
  final TextStyle style;
  final QuranTheme theme;
  final ValueListenable<QuranWordRef?> activeWord;
  final String? selectedVerse;
  final bool centered;
  final int? nextLineBase;
  final ValueChanged<String>? onWordTap;
  final ValueChanged<String>? onWordLongPress;

  @override
  State<_MushafLine> createState() => _MushafLineState();
}

class _MushafLineState extends State<_MushafLine> with TickerProviderStateMixin {
  _LineLayout? _layout;
  bool _activeInLine = false;
  Object? _layoutKey;

  Rect? _fromHighlight;
  Rect? _toHighlight;
  double _fromOpacity = 0.0;
  double _toOpacity = 0.0;
  DateTime? _animStart;
  Ticker? _animTicker;

  Rect? get _displayedHighlight {
    if (_fromHighlight == null && _toHighlight == null) return null;
    if (_animStart == null) return _toHighlight;
    final elapsed = DateTime.now().difference(_animStart!).inMilliseconds;
    final t = Curves.easeOutCubic.transform((elapsed / 260.0).clamp(0.0, 1.0));
    if (_fromHighlight == null) return _toHighlight;
    if (_toHighlight == null) {
      return elapsed < 260 ? _fromHighlight : null;
    }
    return Rect.lerp(_fromHighlight, _toHighlight, t);
  }

  double get _displayedOpacity {
    if (_animStart == null) return _toOpacity;
    final elapsed = DateTime.now().difference(_animStart!).inMilliseconds;
    final t = Curves.easeOut.transform((elapsed / 260.0).clamp(0.0, 1.0));
    return _fromOpacity + (_toOpacity - _fromOpacity) * t;
  }

  @override
  void initState() {
    super.initState();
    _activeInLine = _containsActive(widget.activeWord.value);
    widget.activeWord.addListener(_onActiveChanged);
  }

  @override
  void didUpdateWidget(covariant _MushafLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeWord != widget.activeWord) {
      oldWidget.activeWord.removeListener(_onActiveChanged);
      widget.activeWord.addListener(_onActiveChanged);
    }
    _activeInLine = _containsActive(widget.activeWord.value);
  }

  void _startAnim() {
    _animStart = DateTime.now();
    if (_animTicker == null) {
      _animTicker = createTicker((_) {
        if (!mounted) return;
        setState(() {});
        final elapsed = DateTime.now().difference(_animStart!).inMilliseconds;
        if (elapsed >= 260) _animTicker?.stop();
      });
    }
    if (!_animTicker!.isActive) {
      _animTicker!.start();
    }
  }

  @override
  void dispose() {
    widget.activeWord.removeListener(_onActiveChanged);
    _animTicker?.dispose();
    _layout?.dispose();
    super.dispose();
  }

  bool _containsActive(QuranWordRef? ref) {
    if (ref == null) return false;
    for (final word in widget.line.words) {
      if (word.isAyahEnd) continue;
      if (word.verseKey == ref.verseKey && word.wordIndex == ref.wordIndex) {
        return true;
      }
    }
    return false;
  }

  void _onActiveChanged() {
    if (!mounted) return;
    final now = _containsActive(widget.activeWord.value);
    // Repaint when the recitation enters this line or leaves it. Lines that
    // do not hold the active word stay untouched.
    if (now || _activeInLine) {
      setState(() => _activeInLine = now);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Reuse cached layout when inputs are unchanged (avoids re-running
        // kashida on every animation frame).
        _LineLayout? layout = _layout;
        final active = widget.activeWord.value;
        final cacheKey = Object.hash(
          widget.line,
          widget.style,
          widget.theme,
          width,
          height,
          widget.centered,
          widget.nextLineBase,
          active?.verseKey,
          active?.wordIndex,
          widget.selectedVerse,
        );
        if (layout == null || _layoutKey != cacheKey) {
          final previous = _layout;
          layout = _LineLayout.build(
            words: widget.line.words,
            style: widget.style,
            theme: widget.theme,
            width: width,
            height: height,
            centered: widget.centered,
            nextLineBase: widget.nextLineBase,
            active: active,
            selectedVerse: widget.selectedVerse,
          );
          previous?.dispose();
          _layout = layout;
          _layoutKey = cacheKey;
        }

        final newActiveRect = layout!.activeRect;
        if (newActiveRect != _toHighlight) {
          _fromHighlight = _displayedHighlight;
          _fromOpacity = _displayedOpacity;
          _toHighlight = newActiveRect;
          _toOpacity = newActiveRect == null ? 0.0 : 1.0;
          _animStart = DateTime.now();
          _startAnim();
        }

        final displayedRect = _displayedHighlight;
        final displayedOpacity = _displayedOpacity;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final index = layout!.wordAt(details.localPosition);
            if (index == null) return;
            final key = widget.line.words[index].verseKey;
            if (key.isNotEmpty) widget.onWordTap?.call(key);
          },
          onLongPressStart: (details) {
            final index = layout!.wordAt(details.localPosition);
            if (index == null) return;
            final key = widget.line.words[index].verseKey;
            if (key.isNotEmpty) widget.onWordLongPress?.call(key);
          },
          child: SizedBox.expand(
            child: CustomPaint(
              painter: _MushafLinePainter(
                layout: layout,
                theme: widget.theme,
                activeRect: displayedRect,
                activeOpacity: displayedOpacity,
              ),
            ),
          ),
        );
      },
    );
  }

}

/// One printed line, laid out once with a real [TextPainter] so that every
/// highlight rectangle and ayah rosette is derived from the exact glyph spans
/// of the rendered text instead of from independent word boxes.
class _LineLayout {
  _LineLayout._({
    required this.painter,
    required this.originX,
    required this.originY,
    required this.fontSize,
    required this.wordRanges,
    required this.badgeBoxes,
    required this.badgeLabels,
    required this.selectionRect,
    required this.activeRect,
  });

  final TextPainter painter;
  final double originX;
  final double originY;
  final double fontSize;
  final List<TextRange> wordRanges;
  final Map<int, Rect> badgeBoxes;
  final Map<int, String> badgeLabels;
  final Rect? selectionRect;
  final Rect? activeRect;

  void dispose() => painter.dispose();

  /// The word under [local], or the nearest word when the tap lands in the
  /// spacing between two words.
  int? wordAt(Offset local) {
    if (wordRanges.isEmpty) return null;
    final position =
        painter.getPositionForOffset(local - Offset(originX, originY));
    final offset = position.offset;
    var best = 0;
    var bestDistance = 1 << 30;
    for (var index = 0; index < wordRanges.length; index++) {
      final range = wordRanges[index];
      if (offset >= range.start && offset <= range.end) return index;
      final distance = offset < range.start
          ? range.start - offset
          : offset - range.end;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    return best;
  }

  static _LineLayout build({
    required List<QuranPageWord> words,
    required TextStyle style,
    required QuranTheme theme,
    required double width,
    required double height,
    required bool centered,
    required int? nextLineBase,
    required QuranWordRef? active,
    required String? selectedVerse,
  }) {
    final unit = style.fontSize ?? 14;
    final badgeStyle = style.copyWith(
      fontSize: unit * 0.55,
      height: 1.0,
      color: Colors.transparent,
    );
    // Breathing room on both sides of an ayah rosette so the badge never
    // collides with the words around it.
    final badgeGap = unit * 0.30;
    var badgeExtra = 0.0;
    for (var index = 0; index < words.length - 1; index++) {
      if (words[index].isAyahEnd || words[index + 1].isAyahEnd) {
        badgeExtra += badgeGap;
      }
    }
    final texts = <String>[
      for (final word in words)
        word.isAyahEnd ? _badgeLabel(word) : word.text,
    ];
    final wordStyles = <TextStyle>[
      for (final word in words) word.isAyahEnd ? badgeStyle : style,
    ];

    // The natural width decides whether the line can be justified. A short
    // line that closes a surah would need an absurd amount of kashida to reach
    // the margin, so it is centred the way a printed mushaf sets it.
    final naturalWidth =
        _naturalLineWidth(texts, wordStyles, style, extra: badgeExtra);
    final justify =
        !centered && words.length > 1 && naturalWidth >= width * 0.45;

    // Stretch the line with kashida until it reaches the opposite margin.
    // The last few points of slack are absorbed by word spacing, so the
    // glyphs never have to be scaled or clipped.
    var spaceExtra = 0.0;
    if (justify) {
      final candidates = <List<int>>[
        for (final word in words)
          word.isAyahEnd || _isDivineName(_stripMarks(word.text))
              ? const <int>[]
              : _kashidaPositions(word.text),
      ];
      final stretchable = <int>[
        for (var index = 0; index < words.length; index++)
          if (candidates[index].isNotEmpty) index,
      ];
      final added = List<int>.filled(words.length, 0);
      if (stretchable.isNotEmpty) {
        final tatweel = _measure('ـ', style);
        if (tatweel > 0.1) {
          void applyTotal(int total) {
            for (var index = 0; index < added.length; index++) {
              added[index] = 0;
            }
            for (var i = 0; i < total; i++) {
              added[stretchable[i % stretchable.length]]++;
            }
            for (final index in stretchable) {
              texts[index] = _insertKashida(
                words[index].text,
                added[index],
                candidates[index],
              );
            }
          }

          // Grow the kashida count a pass at a time. A contextual tatweel can
          // be wider than the standalone glyph, so a pass that overshoots is
          // trimmed back instead of being thrown away; discarding it would
          // leave the whole line to be closed by wide word gaps.
          var total = 0;
          var current = naturalWidth;
          var fittingTotal = 0;
          final limit = math.min(stretchable.length * 12, 160);
          for (var pass = 0; pass < 10; pass++) {
            final remaining = width - current;
            if (remaining < tatweel) break;
            var next = total + (remaining / tatweel).floor();
            if (next > limit) next = limit;
            if (next <= total) break;
            applyTotal(next);
            var measured =
                _naturalLineWidth(texts, wordStyles, style, extra: badgeExtra);
            var attempts = 0;
            while (measured > width && next > total && attempts < 4) {
              final remove = ((measured - width) / tatweel).ceil();
              next -= math.max(1, remove);
              if (next < total) next = total;
              applyTotal(next);
              measured =
                  _naturalLineWidth(texts, wordStyles, style, extra: badgeExtra);
              attempts++;
            }
            if (measured > width) {
              // Restore the last state that fitted; word spacing closes the
              // remaining sliver without crossing the margin.
              applyTotal(fittingTotal);
              break;
            }
            total = next;
            current = measured;
            fittingTotal = total;
          }
        }
      }
    }

    final colorStyles = <Color, TextStyle>{};
    TextStyle colorStyle(Color color) =>
        colorStyles.putIfAbsent(color, () => style.copyWith(color: color));

    List<InlineSpan> buildSpans(double spacing, List<TextRange> ranges) {
      final spans = <InlineSpan>[];
      var offset = 0;
      for (var index = 0; index < words.length; index++) {
        final word = words[index];
        final start = offset;
        if (word.isAyahEnd) {
          spans.add(TextSpan(text: texts[index], style: wordStyles[index]));
          offset += texts[index].length;
        } else {
          final isActive = active != null &&
              active.verseKey == word.verseKey &&
              active.wordIndex == word.wordIndex;
          final segments = _tajweedSegments(
            texts[index],
            theme,
            active: isActive,
            nextWordBase: _nextWordBase(words, index, nextLineBase),
          );
          if (segments.isEmpty || segments.every((s) => s.text.isEmpty)) {
            // Safety net: never drop a word's text, even if segmentation
            // produced nothing.
            final fallback = texts[index].isNotEmpty ? texts[index] : word.text;
            spans.add(TextSpan(text: fallback, style: colorStyle(theme.ink)));
            offset += fallback.length;
          } else {
            for (final segment in segments) {
              spans.add(TextSpan(
                text: segment.text,
                style: colorStyle(segment.color),
              ));
              offset += segment.text.length;
            }
          }
        }
        ranges.add(TextRange(start: start, end: offset));
        if (index < words.length - 1) {
          final gap = words[index].isAyahEnd || words[index + 1].isAyahEnd
              ? badgeGap
              : 0.0;
          spans.add(TextSpan(
            text: ' ',
            style: style.copyWith(letterSpacing: spacing + gap),
          ));
          offset += 1;
        }
      }
      return spans;
    }

    // Measure the exact, fully built line once. The word-by-word estimate
    // above is only used to decide how much kashida to add; the real paragraph
    // width decides the final few points of spacing.
    final probeRanges = <TextRange>[];
    final probe = TextPainter(
      text: TextSpan(children: buildSpans(0, probeRanges)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.start,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout();
    final exactWidth = probe.width;
    probe.dispose();

    if (justify) {
      final remaining = width - exactWidth;
      spaceExtra = remaining > 0 ? remaining / (words.length - 1) : 0;
    }

    var ranges = <TextRange>[];
    var painter = TextPainter(
      text: TextSpan(children: buildSpans(spaceExtra, ranges)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.start,
      textScaler: TextScaler.noScaling,
      maxLines: 1,
      textWidthBasis: TextWidthBasis.parent,
    )..layout();

    // Position the whole line from its measured width instead of constraining
    // the painter. A constrained single-line painter silently drops the last
    // words when the line overflows by even a fraction, which would lose
    // revealed text; an explicit origin can never truncate.
    // Pages 1-2 stay centred as a block. Every other line is anchored to the
    // left edge (RTL end) so the left margin is a perfectly straight vertical
    // boundary; kashida + word spacing then carry the right edge to the margin
    // for full lines (true justification on both sides).
    var originX = centered ? (width - painter.width) / 2 : 0.0;

    // Safety: ensure justified lines actually reach the right margin so both
    // edges are straight. If the fill fell short, bump word spacing and re-
    // layout (bounded attempts).
    if (!centered && justify && painter.width < width - 1 && words.length > 1) {
      var extra = spaceExtra;
      for (var attempt = 0; attempt < 6; attempt++) {
        if (painter.width >= width - 1) break;
        extra += (width - painter.width) / (words.length - 1);
        painter.dispose();
        final rebuiltRanges = <TextRange>[];
        final rebuilt = TextPainter(
          text: TextSpan(children: buildSpans(extra, rebuiltRanges)),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.start,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          textWidthBasis: TextWidthBasis.parent,
        )..layout();
        ranges.clear();
        ranges.addAll(rebuiltRanges);
        painter = rebuilt;
        spaceExtra = extra;
      }
      originX = 0.0;
    }

    final boxes = <Rect?>[
      for (final range in ranges) _unionBox(painter, range),
    ];

    final badgeBoxes = <int, Rect>{};
    final badgeLabels = <int, String>{};
    for (var index = 0; index < words.length; index++) {
      if (!words[index].isAyahEnd) continue;
      final box = boxes[index];
      if (box != null) {
        badgeBoxes[index] = box;
        badgeLabels[index] = texts[index];
      }
    }

    Rect? selectionRect;
    if (selectedVerse != null) {
      Rect? union;
      for (var index = 0; index < words.length; index++) {
        if (words[index].verseKey != selectedVerse) continue;
        final box = boxes[index];
        if (box == null) continue;
        union = union == null ? box : union.expandToInclude(box);
      }
      if (union != null) {
        final pad = unit * 0.10;
        selectionRect = Rect.fromLTRB(
          union.left - pad,
          union.top - pad,
          union.right + pad,
          union.bottom + pad,
        );
      }
    }

    Rect? activeRect;
    if (active != null) {
      for (var index = 0; index < words.length; index++) {
        final word = words[index];
        if (word.isAyahEnd) continue;
        if (word.verseKey == active.verseKey &&
            word.wordIndex == active.wordIndex) {
          final box = boxes[index];
          if (box != null) {
            final pad = unit * 0.13;
            activeRect = Rect.fromLTRB(
              box.left - pad,
              box.top - pad,
              box.right + pad,
              box.bottom + pad,
            );
          }
          break;
        }
      }
    }

    return _LineLayout._(
      painter: painter,
      originX: originX,
      originY:
          height.isFinite ? math.max(0.0, (height - painter.height) / 2) : 0.0,
      fontSize: unit,
      wordRanges: ranges,
      badgeBoxes: badgeBoxes,
      badgeLabels: badgeLabels,
      selectionRect: selectionRect,
      activeRect: activeRect,
    );
  }
}

class _MushafLinePainter extends CustomPainter {
  _MushafLinePainter({
    required this.layout,
    required this.theme,
    this.activeRect,
    this.activeOpacity = 1.0,
  });

  final _LineLayout layout;
  final QuranTheme theme;
  final Rect? activeRect;
  final double activeOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final dy = layout.originY;
    final offset = Offset(layout.originX, dy);
    final radius = Radius.circular(layout.fontSize * 0.22);

    final selection = layout.selectionRect;
    if (selection != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(selection.shift(offset), radius),
        Paint()..color = theme.selection,
      );
    }

    if (activeRect != null && activeOpacity > 0.01) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect!.shift(offset), radius),
        Paint()..color = theme.highlight.withValues(alpha: theme.highlight.a * activeOpacity),
      );
    }

    for (final entry in layout.badgeBoxes.entries) {
      final label = layout.badgeLabels[entry.key] ?? '';
      _paintAyahBadge(canvas, entry.value.shift(offset), layout.fontSize, theme, label);
    }

    layout.painter.paint(canvas, offset);
  }

  void _paintAyahBadge(
    Canvas canvas,
    Rect rect,
    double fontSize,
    QuranTheme theme,
    String label,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? const Color(0xFFB8B8C4) : const Color(0xFF8A8A96);

    final center = rect.center;
    final diameter = math.max(rect.width, rect.height) * 1.2;
    final radius = math.min(fontSize * 0.55, diameter / 2);
    if (radius <= 0.5) return;

    // Clean circular badge (transparent center).
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, fontSize * 0.08)
        ..color = border,
    );

    // Number centered in the circle.
    final numberPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'AmiriQuran',
          fontSize: fontSize * 0.5,
          color: theme.ink,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    numberPainter.paint(
      canvas,
      center - Offset(numberPainter.width / 2, numberPainter.height / 2),
    );
    numberPainter.dispose();
  }

  @override
  bool shouldRepaint(covariant _MushafLinePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.theme != theme ||
      oldDelegate.activeRect != activeRect ||
      oldDelegate.activeOpacity != activeOpacity;
}

/// A colour-coded run inside one word.
class _TajweedSegment {
  const _TajweedSegment(this.text, this.color);

  final String text;
  final Color color;
}

/// Chooses one colour for a whole word using the standard rules of the
/// colour-coded mushaf.
///
/// Flutter shapes every [TextSpan] independently, so splitting a word at a
/// colour boundary breaks Arabic joining and the obligatory lam-alef ligature
/// (لَا would print as two isolated letters). Keeping each word in a single
/// span preserves every join and ligature; the colour is the first rule that
/// applies while reading the word. Colour never changes metrics, so
/// justification and line breaking are unaffected.
List<_TajweedSegment> _tajweedSegments(
  String text,
  QuranTheme theme, {
  required bool active,
  int? nextWordBase,
}) {
  if (active) {
    return <_TajweedSegment>[_TajweedSegment(text, theme.highlightInk)];
  }
  if (_isDivineName(_stripMarks(text))) {
    return <_TajweedSegment>[_TajweedSegment(text, theme.tajweedDivine)];
  }

  final clusters = _clusters(text);
  for (var index = 0; index < clusters.length; index++) {
    final cluster = clusters[index];
    final base = cluster.runes.first;
    final next = index + 1 < clusters.length
        ? clusters[index + 1].runes.first
        : nextWordBase;
    final color = _tajweedColor(
      cluster,
      base,
      next,
      index == clusters.length - 1,
      theme,
    );
    // A silent mark colours a single letter in a printed mushaf; applied to
    // the whole word it would turn common words grey, so it is skipped here.
    if (color != theme.ink && color != theme.tajweedSilent) {
      return <_TajweedSegment>[_TajweedSegment(text, color)];
    }
  }
  return <_TajweedSegment>[_TajweedSegment(text, theme.ink)];
}

Color _tajweedColor(
  String cluster,
  int base,
  int? next,
  bool isLastCluster,
  QuranTheme theme,
) {
  final runes = cluster.runes.toList();

  // Silent letters (small high rounded/rectangular zero) are not pronounced.
  for (final rune in runes) {
    if (_silentMarks.contains(rune)) return theme.tajweedSilent;
  }

  // Madd: maddah, dagger alif, small high madda and the small waw/yeh that
  // mark a long vowel.
  for (final rune in runes) {
    if (_maddMarks.contains(rune)) return theme.tajweedMadd;
  }

  // Ghunnah: noon or meem carrying a shadda.
  if ((base == 0x0646 || base == 0x0645) && runes.contains(0x0651)) {
    return theme.tajweedGhunnah;
  }

  // Noon sakinah and tanween: iqlab, idgham and ikhfa. This is checked before
  // qalqalah so a tanween mark is coloured by its own rule.
  final hasTanween = runes.any(_tanweenMarks.contains);
  final hasNoonSukun = base == 0x0646 && runes.contains(0x0652);
  if ((hasTanween || hasNoonSukun) && next != null) {
    if (next == 0x0628 ||
        _idghamLetters.contains(next) ||
        _ikhfaLetters.contains(next)) {
      return theme.tajweedNoon;
    }
  }

  // Qalqalah: qaf, ta, ba, jim or dal with a sukun, or word-final without a
  // short vowel.
  if (_qalqalahLetters.contains(base)) {
    final hasSukun = runes.contains(0x0652);
    final hasVowel = runes.any(_shortVowels.contains);
    if (hasSukun || (isLastCluster && !hasVowel)) {
      return theme.tajweedQalqalah;
    }
  }

  return theme.ink;
}

String _stripMarks(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (_isArabicMark(rune) || rune == 0x0640) continue;
    // Uthmani text spells the divine name with alef wasla; fold it to a plain
    // alef so the name is recognised in every grammatical form.
    buffer.writeCharCode(rune == 0x0671 ? 0x0627 : rune);
  }
  return buffer.toString();
}

bool _isDivineName(String normalized) {
  if (normalized.isEmpty || normalized.length > 6) return false;
  return normalized == 'الله' ||
      normalized == 'لله' ||
      normalized.contains('الله') ||
      normalized.endsWith('لله');
}

int? _nextWordBase(List<QuranPageWord> words, int index, [int? lineEndBase]) {
  for (var i = index + 1; i < words.length; i++) {
    if (words[i].isAyahEnd) continue;
    final clusters = _clusters(words[i].text);
    if (clusters.isEmpty) continue;
    // A word opening with alef or alef wasla is read from the following
    // letter, because the alef is elided when the words are joined.
    final first = clusters.first.runes.first;
    if ((first == 0x0627 || first == 0x0671) && clusters.length > 1) {
      return clusters[1].runes.first;
    }
    return first;
  }
  return lineEndBase;
}

double _naturalLineWidth(
  List<String> texts,
  List<TextStyle> styles,
  TextStyle baseStyle, {
  double extra = 0,
}) {
  var total = 0.0;
  for (var index = 0; index < texts.length; index++) {
    total += _measure(texts[index], styles[index]);
    if (index < texts.length - 1) total += _measure(' ', baseStyle);
  }
  return total + extra;
}

Rect? _unionBox(TextPainter painter, TextRange range) {
  if (range.isCollapsed) return null;
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: range.start, extentOffset: range.end),
    boxHeightStyle: BoxHeightStyle.max,
    boxWidthStyle: BoxWidthStyle.tight,
  );
  if (boxes.isEmpty) return null;
  var rect = boxes.first.toRect();
  for (var index = 1; index < boxes.length; index++) {
    rect = rect.expandToInclude(boxes[index].toRect());
  }
  return rect;
}

/// Width of [text] rendered with [style].
double _measure(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.rtl,
    textScaler: TextScaler.noScaling,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The Arabic-Indic number printed inside the ayah rosette.
String _badgeLabel(QuranPageWord word) {
  final buffer = StringBuffer();
  for (final rune in word.text.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x0660 + (rune - 0x06F0));
    } else if (rune >= 0x30 && rune <= 0x39) {
      buffer.writeCharCode(0x0660 + (rune - 0x30));
    }
  }
  if (buffer.isNotEmpty) return buffer.toString();
  final parts = word.verseKey.split(':');
  if (parts.length == 2) {
    final number = int.tryParse(parts[1]);
    if (number != null) return _arabicNumber(number);
  }
  return word.text;
}

const _silentMarks = <int>{0x06DF, 0x06E0, 0x06E1};
const _maddMarks = <int>{0x0653, 0x0670, 0x06E4, 0x06E5, 0x06E6};
const _shortVowels = <int>{0x064E, 0x064F, 0x0650};
const _tanweenMarks = <int>{0x064B, 0x064C, 0x064D};
const _qalqalahLetters = <int>{0x0628, 0x062C, 0x062F, 0x0637, 0x0642};
const _idghamLetters = <int>{0x064A, 0x0631, 0x0645, 0x0644, 0x0648, 0x0646};
const _ikhfaLetters = <int>{
  0x062A, 0x062B, 0x062C, 0x062F, 0x0630, 0x0632, 0x0633, 0x0634,
  0x0635, 0x0636, 0x0637, 0x0638, 0x0641, 0x0642, 0x0643,
};

/// Cluster indexes where a tatweel can be inserted without breaking the
/// joined shape of the word. Marks stay attached to their base letter.
List<int> _kashidaPositions(String text) {
  final clusters = _clusters(text);
  final positions = <int>[];
  for (var i = 0; i < clusters.length - 1; i++) {
    final base = clusters[i].runes.first;
    if (!_dualJoining.contains(String.fromCharCode(base))) continue;
    // Lam followed by alef is an obligatory ligature (لَا). A tatweel inside
    // the pair would print as "lam + alef" and change the word, so it is
    // never stretched.
    final next = clusters[i + 1].runes.first;
    if (base == 0x0644 && _alefForms.contains(next)) continue;
    positions.add(i);
  }
  return positions;
}

/// Inserts [count] tatweel strokes after the given cluster [positions].
String _insertKashida(String text, int count, List<int> positions) {
  if (count <= 0 || positions.isEmpty) return text;
  final clusters = _clusters(text);
  final extra = List<int>.filled(clusters.length, 0);
  for (var i = 0; i < count; i++) {
    extra[positions[i % positions.length]]++;
  }
  final buffer = StringBuffer();
  for (var i = 0; i < clusters.length; i++) {
    buffer.write(clusters[i]);
    if (extra[i] > 0) buffer.write(List.filled(extra[i], 'ـ').join());
  }
  return buffer.toString();
}

/// Splits Arabic text into base-letter clusters, keeping diacritics attached.
List<String> _clusters(String text) {
  final clusters = <String>[];
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (buffer.isNotEmpty && _isArabicMark(rune)) {
      buffer.writeCharCode(rune);
    } else {
      if (buffer.isNotEmpty) clusters.add(buffer.toString());
      buffer.clear();
      buffer.writeCharCode(rune);
    }
  }
  if (buffer.isNotEmpty) clusters.add(buffer.toString());
  return clusters;
}

bool _isArabicMark(int rune) {
  return (rune >= 0x0610 && rune <= 0x061A) ||
      (rune >= 0x064B && rune <= 0x065F) ||
      rune == 0x0670 ||
      // Tatweel is kept with its base letter so an inserted kashida inherits
      // the letter's Tajweed colour instead of breaking the stroke.
      rune == 0x0640 ||
      (rune >= 0x06D6 && rune <= 0x06ED) ||
      (rune >= 0x08D3 && rune <= 0x08FF);
}

/// Letters that join to the following letter, so a tatweel after them keeps
/// the stroke connected. Right-joining letters (ا د ذ ر ز و) are excluded.
const _dualJoining = {
  'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ',
  'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'ي', 'ئ', 'ـ',
};

/// Alef forms that form the obligatory lam-alef ligature with a preceding lam.
const _alefForms = <int>{0x0622, 0x0623, 0x0625, 0x0627, 0x0671};

class _SurahBand extends StatelessWidget {
  const _SurahBand({
    required this.chapter,
    required this.style,
    required this.theme,
  });

  final QuranChapter chapter;
  final TextStyle style;
  final QuranTheme theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final panelWidth = math.min(h * 0.95, constraints.maxWidth * 0.16);
        return SizedBox.expand(
          child: CustomPaint(
            painter: _BannerPainter(border: theme.accent, fill: theme.bandFill),
            child: Center(
              child: Padding(
                // Keeps the name clear of the side medallions, whatever the
                // band height turns out to be.
                padding: EdgeInsets.symmetric(horizontal: panelWidth + h * 0.18),
                child: SizedBox(
                  // A band that starts mid-page is only one line tall, so cap
                  // the title height to keep it inside the inner rule.
                  height: h * 0.60,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'سورة ${chapter.nameArabic}',
                      maxLines: 1,
                      style: style.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        height: 1.0,
                      ),
                      textScaler: TextScaler.noScaling,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the traditional cartouche that frames a surah name in a printed
/// mushaf: a ruled plaque with an ornamental medallion in a side panel at each
/// end, a beaded rule along the top and bottom, and diamond corner accents.
class _BannerPainter extends CustomPainter {
  const _BannerPainter({required this.border, required this.fill});

  final Color border;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 2) return;
    final h = size.height;
    final outer = Rect.fromLTWH(1, h * 0.10, size.width - 2, h * 0.80);
    if (outer.width <= 0 || outer.height <= 0) return;

    final heavy = math.max(0.9, h * 0.050);
    final hair = math.max(0.5, h * 0.018);

    // Filled plaque and its double rule.
    canvas.drawRect(outer, Paint()..color = fill);
    canvas.drawRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = heavy
        ..color = border,
    );
    final inner = outer.deflate(h * 0.10);
    if (inner.width > 4 && inner.height > 4) {
      canvas.drawRect(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair
          ..color = border.withValues(alpha: 0.62),
      );
    }

    // Side panels that hold the end medallions.
    final panelWidth = math.min(h * 0.95, outer.width * 0.16);
    final leftPanel =
        Rect.fromLTWH(outer.left, outer.top, panelWidth, outer.height);
    final rightPanel = Rect.fromLTWH(
      outer.right - panelWidth,
      outer.top,
      panelWidth,
      outer.height,
    );
    for (final panel in <Rect>[leftPanel, rightPanel]) {
      canvas.drawRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair
          ..color = border.withValues(alpha: 0.50),
      );
    }
    _verticalRule(canvas, leftPanel.right, outer.top, outer.bottom, border, hair);
    _verticalRule(canvas, rightPanel.left, outer.top, outer.bottom, border, hair);

    // End medallions.
    final medallion = math.min(panelWidth * 0.32, outer.height * 0.27);
    _drawMedallion(
      canvas,
      Offset(leftPanel.center.dx, leftPanel.center.dy),
      medallion,
      border,
      fill,
    );
    _drawMedallion(
      canvas,
      Offset(rightPanel.center.dx, rightPanel.center.dy),
      medallion,
      border,
      fill,
    );

    // Small diamonds above and below each medallion.
    final diamond = math.min(panelWidth * 0.12, h * 0.065);
    for (final cx in <double>[leftPanel.center.dx, rightPanel.center.dx]) {
      _drawDiamond(canvas, Offset(cx, outer.top + h * 0.10), diamond, border);
      _drawDiamond(canvas, Offset(cx, outer.bottom - h * 0.10), diamond, border);
    }

    // Beaded rules along the top and bottom of the central panel.
    final centralLeft = leftPanel.right + hair * 3;
    final centralRight = rightPanel.left - hair * 3;
    _beadRule(
      canvas,
      centralLeft,
      centralRight,
      outer.top + h * 0.09,
      h * 0.10,
      border,
      hair,
    );
    _beadRule(
      canvas,
      centralLeft,
      centralRight,
      outer.bottom - h * 0.09,
      h * 0.10,
      border,
      hair,
    );

    // Diamond accents at the four corners of the plaque.
    final corner = math.min(h * 0.085, 3.5);
    for (final point in <Offset>[
      outer.topLeft,
      outer.topRight,
      outer.bottomLeft,
      outer.bottomRight,
    ]) {
      _drawDiamond(canvas, point, corner, border);
    }
  }

  void _verticalRule(
    Canvas canvas,
    double x,
    double top,
    double bottom,
    Color color,
    double width,
  ) {
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _beadRule(
    Canvas canvas,
    double left,
    double right,
    double y,
    double bandHeight,
    Color color,
    double hair,
  ) {
    if (right <= left) return;
    final top = y - bandHeight / 2;
    final bottom = y + bandHeight / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.70)
      ..strokeWidth = hair;
    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    final bead = math.max(0.6, bandHeight * 0.18);
    final beadPaint = Paint()..color = color.withValues(alpha: 0.85);
    final step = bead * 4.2;
    for (var x = left + step; x < right; x += step) {
      canvas.drawCircle(Offset(x, y), bead, beadPaint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Color color) {
    if (radius <= 0.2) return;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawMedallion(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    Color core,
  ) {
    if (radius <= 0.5) return;
    canvas.drawCircle(center, radius, Paint()..color = core);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, radius * 0.10)
        ..color = color,
    );

    // Eight-point star.
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final angle = (math.pi / 8) * i - math.pi / 2;
      final r = i.isEven ? radius * 0.78 : radius * 0.34;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawCircle(center, radius * 0.15, Paint()..color = core);
  }

  @override
  bool shouldRepaint(covariant _BannerPainter oldDelegate) =>
      oldDelegate.border != border || oldDelegate.fill != fill;
}

class _BismillahLine extends StatelessWidget {
  const _BismillahLine({required this.style, required this.theme});

  final TextStyle style;
  final QuranTheme theme;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    // Clean calligraphic line: no plaque, border or background, just the
    // bismillah centred directly under the surah banner.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _bismillah,
          style: style.copyWith(
            fontSize: fontSize * 1.05,
            height: 1.0,
            color: theme.ink,
          ),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.theme, required this.child});

  final QuranTheme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.5 : 0.28,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({
    required this.page,
    required this.theme,
    required this.onRetry,
  });

  final int page;
  final QuranTheme theme;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 38, color: theme.mutedInk),
          const SizedBox(height: 12),
          Text(
            'Page $page could not be loaded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection, then try again. Pages you have already '
            'opened stay available offline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.mutedInk,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _QuranThemeSheet extends StatefulWidget {
  const _QuranThemeSheet({required this.selected, required this.onSelected});

  final QuranTheme selected;
  final ValueChanged<QuranTheme> onSelected;

  @override
  State<_QuranThemeSheet> createState() => _QuranThemeSheetState();
}

class _QuranThemeSheetState extends State<_QuranThemeSheet> {
  late QuranTheme _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  void _choose(QuranTheme theme) {
    setState(() => _selected = theme);
    widget.onSelected(theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _selected;
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
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Page theme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Colours the page, the header and the recitation '
                              'highlight.',
                              style: TextStyle(
                                fontSize: 11.5,
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
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: quranThemes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = quranThemes[index];
                      final selected = item.id == _selected.id;
                      return Material(
                        color: item.paper,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _choose(item),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? item.accent : item.border,
                                width: selected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                _ThemeSwatch(theme: item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: item.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.description,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.35,
                                          color: item.mutedInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: item.accent,
                                    size: 21,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme});

  final QuranTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.paper,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 27,
            height: 4,
            decoration: BoxDecoration(
              color: theme.ink,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 27,
            height: 10,
            decoration: BoxDecoration(
              color: theme.highlight,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuranJumpSheet extends StatefulWidget {
  const _QuranJumpSheet({
    required this.currentPage,
    required this.theme,
    required this.bookmarks,
  });

  final int currentPage;
  final QuranTheme theme;
  final QuranBookmarks bookmarks;

  @override
  State<_QuranJumpSheet> createState() => _QuranJumpSheetState();
}

class _QuranJumpSheetState extends State<_QuranJumpSheet> {
  final _search = TextEditingController();
  final _pageInput = TextEditingController();
  String _query = '';
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _pageInput.text = '${widget.currentPage}';
    widget.bookmarks.addListener(_onBookmarks);
  }

  @override
  void dispose() {
    widget.bookmarks.removeListener(_onBookmarks);
    _search.dispose();
    _pageInput.dispose();
    super.dispose();
  }

  void _onBookmarks() {
    if (mounted) setState(() {});
  }

  void _submitPage() {
    final value = int.tryParse(_pageInput.text.trim());
    if (value == null || value < 1 || value > quranPageCount) {
      setState(() {
        _pageError = 'Enter a page between 1 and $quranPageCount.';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final chapters = _query.isEmpty
        ? quranChapters
        : quranChapters
            .where(
              (chapter) =>
                  chapter.nameSimple.toLowerCase().contains(_query) ||
                  chapter.nameArabic.contains(_query) ||
                  chapter.meaning.toLowerCase().contains(_query),
            )
            .toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Theme(
      data: ThemeData(
        brightness: theme.brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.accent,
          brightness: theme.brightness,
        ),
        dividerColor: theme.border,
      ),
      child: Material(
        color: theme.paper,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82 - keyboard,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pageInput,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.go,
                            onSubmitted: (_) => _submitPage(),
                            decoration: InputDecoration(
                              labelText: 'Page number',
                              helperText: '1 – $quranPageCount',
                              errorText: _pageError,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.accent,
                              foregroundColor: theme.accentInk,
                            ),
                            onPressed: _submitPage,
                            child: const Text('Go'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.bookmarks.pages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bookmark_rounded,
                                size: 14,
                                color: theme.accent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Bookmarks',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.mutedInk,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.bookmarks.pages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final page = widget.bookmarks.pages[index];
                                final chapter = quranChapterForPage(page);
                                return InputChip(
                                  label: Text(
                                    '$page · ${chapter.nameSimple}',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop(page),
                                  onDeleted: () => unawaited(
                                    widget.bookmarks.remove(page),
                                  ),
                                  deleteIcon: const Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search a surah',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: chapters.isEmpty
                        ? Center(
                            child: Text(
                              'No surah found.',
                              style: TextStyle(color: theme.mutedInk),
                            ),
                          )
                        : ListView.separated(
                            itemCount: chapters.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: theme.border),
                            itemBuilder: (context, index) {
                              final chapter = chapters[index];
                              final current =
                                  chapter.containsPage(widget.currentPage);
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor:
                                      theme.accent.withValues(alpha: 0.14),
                                  child: Text(
                                    '${chapter.number}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: theme.accent,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  chapter.nameSimple,
                                  style: TextStyle(
                                    color: theme.ink,
                                    fontWeight: current
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${chapter.nameArabic} · ${chapter.meaning}',
                                  style: TextStyle(color: theme.mutedInk),
                                ),
                                trailing: Text(
                                  'Page ${chapter.startPage}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.mutedInk,
                                  ),
                                ),
                                onTap: () =>
                                    Navigator.of(context).pop(chapter.startPage),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String _arabicNumber(int value) {
  return '$value'.split('').map((digit) {
    final index = int.tryParse(digit);
    return index == null ? digit : _arabicDigits[index];
  }).join();
}


