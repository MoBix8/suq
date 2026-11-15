import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'quran_audio.dart';
import 'quran_audio_store.dart';
import 'quran_meta.dart';
import 'quran_page_cache.dart';
import 'quran_theme.dart';

/// Manages offline copies of the recitation and the mushaf text.
class QuranDownloadSheet extends ConsumerStatefulWidget {
  const QuranDownloadSheet({
    super.key,
    required this.theme,
    required this.reciterId,
    required this.page,
  });

  final QuranTheme theme;
  final int reciterId;
  final int page;

  @override
  ConsumerState<QuranDownloadSheet> createState() =>
      _QuranDownloadSheetState();
}

class _QuranDownloadSheetState extends ConsumerState<QuranDownloadSheet> {
  late final QuranAudioStore _store;
  late final QuranPageCache _cache;
  late final QuranChapter _chapter;

  bool? _chapterDownloaded;
  int _chapterBytes = 0;
  int _reciterBytes = 0;
  int _downloadedChapters = 0;
  int _savedPages = 0;
  int _statsToken = 0;

  bool _savingPages = false;
  int _pageDone = 0;
  bool _pageCancel = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(quranAudioStoreProvider);
    _cache = ref.read(quranPageCacheProvider);
    _chapter = quranChapterForPage(widget.page);
    _store.addListener(_onStoreChanged);
    unawaited(_loadStats());
  }

  @override
  void dispose() {
    _pageCancel = true;
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_store.isDownloading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadStats());
      });
    }
  }

  Future<void> _loadStats() async {
    final token = ++_statsToken;
    final downloaded = await _store.hasChapter(
      widget.reciterId,
      _chapter.number,
    );
    final chapterBytes = await _store.chapterBytes(
      widget.reciterId,
      _chapter.number,
    );
    final reciterBytes = await _store.reciterBytes(widget.reciterId);
    final chapters = await _store.downloadedChapterCount(widget.reciterId);
    final pages = await _cache.savedPageCount();
    if (!mounted || token != _statsToken) return;
    setState(() {
      _chapterDownloaded = downloaded;
      _chapterBytes = chapterBytes;
      _reciterBytes = reciterBytes;
      _downloadedChapters = chapters;
      _savedPages = pages;
    });
  }

  void _downloadChapter() {
    _store.startDownload(reciter: widget.reciterId, chapter: _chapter.number);
  }

  Future<void> _removeChapter() async {
    await _store.removeChapter(widget.reciterId, _chapter.number);
    if (mounted) unawaited(_loadStats());
  }

  Future<void> _downloadAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download every surah?'),
        content: Text(
          'All 114 surahs recited by '
          '${quranReciterById(widget.reciterId).name} will be saved on this '
          'device. This can use well over 1 GB of storage and take a while on '
          'a slow connection. You can cancel at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _store.startDownload(reciter: widget.reciterId);
  }

  Future<void> _removeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove downloaded recitation?'),
        content: Text(
          'Every downloaded surah by '
          '${quranReciterById(widget.reciterId).name} will be deleted from '
          'this device. The reader will stream recitation again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.removeReciter(widget.reciterId);
    if (mounted) unawaited(_loadStats());
  }

  Future<void> _savePages() async {
    if (_savingPages) return;
    setState(() {
      _savingPages = true;
      _pageDone = 0;
      _pageCancel = false;
    });
    await _cache.downloadAll(
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() => _pageDone = done);
      },
      isCancelled: () => _pageCancel || !mounted,
    );
    if (!mounted) return;
    setState(() => _savingPages = false);
    unawaited(_loadStats());
  }

  Future<void> _clearPages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved pages?'),
        content: const Text(
          'The 604 pages saved on this device will be deleted. The reader will '
          'download each page again when it is opened.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _cache.clear();
    if (mounted) unawaited(_loadStats());
  }

  String _bytes(int value) {
    if (value <= 0) return '0 MB';
    const megabyte = 1024 * 1024;
    if (value >= 1024 * megabyte) {
      return '${(value / (1024 * megabyte)).toStringAsFixed(1)} GB';
    }
    final mb = value / megabyte;
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final reciter = quranReciterById(widget.reciterId);
    final job = _store.job;
    final busy = job != null;

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
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline Qur’an',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: theme.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Keep recitation and pages on this device. '
                              'Downloaded audio plays without a connection.',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.35,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _DownloadCard(
                        theme: theme,
                        icon: Icons.record_voice_over_rounded,
                        title: reciter.name,
                        subtitle: 'Reciter · ${reciter.style}',
                      ),
                      const SizedBox(height: 10),
                      _DownloadCard(
                        theme: theme,
                        icon: Icons.menu_book_rounded,
                        title: _chapter.nameSimple,
                        subtitle: _chapterDownloaded == true
                            ? 'Surah audio saved · ${_bytes(_chapterBytes)}'
                            : 'Surah audio streams while you listen',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_chapterDownloaded == true)
                              OutlinedButton.icon(
                                onPressed: busy ? null : _removeChapter,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Remove'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: busy ? null : _downloadChapter,
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 18,
                                ),
                                label: Text('Download ${_chapter.nameSimple}'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DownloadCard(
                        theme: theme,
                        icon: Icons.library_music_rounded,
                        title: 'Whole reciter',
                        subtitle:
                            '$_downloadedChapters of 114 surahs · '
                            '${_bytes(_reciterBytes)} saved',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_downloadedChapters > 0)
                              OutlinedButton.icon(
                                onPressed: busy ? null : _removeAll,
                                icon: const Icon(
                                  Icons.delete_sweep_outlined,
                                  size: 18,
                                ),
                                label: const Text('Remove all'),
                              ),
                            if (_downloadedChapters < 114)
                              FilledButton.icon(
                                onPressed: busy ? null : _downloadAll,
                                icon: const Icon(
                                  Icons.download_for_offline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Download all surahs'),
                              ),
                          ],
                        ),
                      ),
                      if (job != null) ...[
                        const SizedBox(height: 10),
                        _DownloadProgress(
                          theme: theme,
                          label: job.isSingleChapter
                              ? 'Downloading '
                                  '${quranChapterByNumber(job.chapter).nameSimple}'
                                  ' · ${job.fileDone} of ${job.fileTotal} verses'
                              : 'Downloading '
                                  '${quranChapterByNumber(job.chapter).nameSimple}'
                                  ' · ${job.doneChapters} of '
                                  '${job.chapters.length} surahs',
                          value: job.progress,
                          onCancel: _store.cancelDownload,
                        ),
                      ],
                      if (_store.error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _store.error!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.accent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        'Mushaf text',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: theme.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _DownloadCard(
                        theme: theme,
                        icon: Icons.auto_stories_rounded,
                        title: '604 pages',
                        subtitle: _savedPages >= quranPageCount
                            ? 'Every page is saved for offline reading'
                            : '$_savedPages of $quranPageCount pages saved · '
                                'reading works without any audio download',
                        child: _savingPages
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: _pageDone / quranPageCount,
                                    color: theme.accent,
                                    backgroundColor: theme.border,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Saving page $_pageDone of '
                                          '$quranPageCount…',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.mutedInk,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _pageCancel = true),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_savedPages > 0)
                                    OutlinedButton.icon(
                                      onPressed: _clearPages,
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Clear pages'),
                                    ),
                                  FilledButton.icon(
                                    onPressed: _savePages,
                                    icon: const Icon(
                                      Icons.save_alt_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      _savedPages >= quranPageCount
                                          ? 'Save again'
                                          : 'Save all pages',
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Pages are always saved as you read, so the mushaf '
                        'opens offline even if you never download audio. '
                        'Translations, tafsir and undownloaded recitation need '
                        'a connection.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.45,
                          color: theme.mutedInk,
                        ),
                      ),
                    ],
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

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  final QuranTheme theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: theme.bandFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: theme.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: theme.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 10),
            child!,
          ],
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({
    required this.theme,
    required this.label,
    required this.value,
    required this.onCancel,
  });

  final QuranTheme theme;
  final String label;
  final double value;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: theme.bandFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: value,
            color: theme.accent,
            backgroundColor: theme.border,
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Cancel download'),
            ),
          ),
        ],
      ),
    );
  }
}
