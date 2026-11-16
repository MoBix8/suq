import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_meta.dart';

/// Raised when a mushaf page cannot be loaded or saved.
class QuranPageException implements Exception {
  QuranPageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A single word placed on a printed mushaf line.
class QuranPageWord {
  const QuranPageWord({
    required this.text,
    required this.isAyahEnd,
    this.verseKey = '',
    this.wordIndex = 0,
  });

  final String text;
  final bool isAyahEnd;

  /// The verse this word belongs to, in `surah:ayah` form.
  final String verseKey;

  /// 1-based position among the recitable words of [verseKey].
  ///
  /// Reciters voice words only; ayah end markers carry 0 because the audio
  /// timings never segment them.
  final int wordIndex;
}

/// One printed line of a mushaf page.
class QuranPageLine {
  const QuranPageLine({required this.number, required this.words});

  final int number;
  final List<QuranPageWord> words;
}

/// A surah heading printed on a page, with the line its bismillah sits on.
class QuranSurahHeading {
  const QuranSurahHeading({
    required this.chapter,
    required this.line,
    required this.bismillahLine,
  });

  final QuranChapter chapter;

  /// Printed line that holds the surah name band.
  ///
  /// This is null when the surah starts at the top of the page: the band is
  /// then printed in the page margin above the line grid, and line 1 of the
  /// grid holds the bismillah.
  final int? line;

  /// Printed line that holds the bismillah, when the surah has one.
  final int? bismillahLine;
}

/// The text of one printed mushaf page, split into its printed lines.
class QuranPageData {
  const QuranPageData({
    required this.page,
    required this.lines,
    required this.headings,
    required this.verseKeys,
  });

  /// Version of the compact cache format. Bump it whenever [compact] or
  /// [parse] changes what they read, so stale files are downloaded again.
  static const cacheVersion = 2;

  final int page;
  final Map<int, QuranPageLine> lines;
  final List<QuranSurahHeading> headings;

  /// Verses that appear on this page, in reading order.
  final List<String> verseKeys;

  /// How many printed lines the page has (normally 15).
  int get lineCount {
    var maxLine = 0;
    for (final number in lines.keys) {
      if (number > maxLine) maxLine = number;
    }
    for (final heading in headings) {
      final band = heading.line;
      if (band != null && band > maxLine) maxLine = band;
      final bismillah = heading.bismillahLine;
      if (bismillah != null && bismillah > maxLine) maxLine = bismillah;
    }
    return maxLine == 0 ? 15 : maxLine;
  }

  QuranPageLine? line(int number) => lines[number];

  QuranSurahHeading? headingAt(int number) {
    for (final heading in headings) {
      if (heading.line == number) return heading;
    }
    return null;
  }

  /// The surah whose name band is printed above the line grid, if any.
  ///
  /// Only the surah that starts at the top of the page can be in the margin.
  QuranSurahHeading? get marginHeading {
    for (final heading in headings) {
      if (heading.line == null) return heading;
    }
    return null;
  }

  QuranSurahHeading? bismillahAt(int number) {
    for (final heading in headings) {
      if (heading.bismillahLine == number) return heading;
    }
    return null;
  }

  /// Builds a page from the Qur’an.com `verses/by_page` response.
  static QuranPageData parse(int page, Map<String, dynamic> json) {
    final verses = json['verses'];
    if (verses is! List || verses.isEmpty) {
      throw QuranPageException('Page $page has no text.');
    }

    final lines = <int, List<QuranPageWord>>{};
    final chapterStartLines = <int, int>{};
    final verseKeys = <String>[];

    for (final rawVerse in verses) {
      if (rawVerse is! Map) continue;
      final key = rawVerse['verse_key'];
      final rawWords = rawVerse['words'];
      if (key is! String || rawWords is! List) continue;

      final parts = key.split(':');
      if (parts.length != 2) continue;
      final chapter = int.tryParse(parts[0]);
      final verse = int.tryParse(parts[1]);
      if (chapter == null || verse == null) continue;

      int? firstLine;
      var placed = false;
      for (final rawWord in rawWords) {
        if (rawWord is! Map) continue;
        final lineNumber = (rawWord['line_number'] as num?)?.toInt();
        final text = rawWord['text_uthmani'] ?? rawWord['text'];
        if (lineNumber == null || lineNumber < 1 || text is! String) continue;
        if (text.isEmpty) continue;

        final isAyahEnd = rawWord['char_type_name'] == 'end';
        final position = (rawWord['position'] as num?)?.toInt() ?? 0;

        firstLine ??= lineNumber;
        placed = true;
        lines.putIfAbsent(lineNumber, () => <QuranPageWord>[]).add(
          QuranPageWord(
            text: text,
            isAyahEnd: isAyahEnd,
            verseKey: key,
            wordIndex: isAyahEnd ? 0 : position,
          ),
        );
      }

      if (placed) verseKeys.add(key);
      if (verse == 1 && firstLine != null) {
        chapterStartLines[chapter] = firstLine;
      }
    }

    if (lines.isEmpty) throw QuranPageException('Page $page has no text.');

    final headings = <QuranSurahHeading>[];
    chapterStartLines.forEach((number, firstLine) {
      final chapter = quranChapterByNumber(number);

      // The printed page always places the band directly above the bismillah
      // (or directly above verse 1 when there is no bismillah). A surah that
      // starts at the top of the page keeps its band in the page margin, so
      // the grid's first line is the bismillah.
      int? band;
      int? bismillah;
      if (chapter.hasBismillah) {
        bismillah = firstLine - 1;
        if (firstLine >= 3) band = firstLine - 2;
      } else {
        band = firstLine - 1;
      }
      if (band != null && band < 1) band = null;
      if (bismillah != null && bismillah < 1) bismillah = null;

      headings.add(
        QuranSurahHeading(
          chapter: chapter,
          line: band,
          bismillahLine: bismillah,
        ),
      );
    });

    final pageLines = <int, QuranPageLine>{
      for (final entry in lines.entries)
        entry.key: QuranPageLine(number: entry.key, words: entry.value),
    };

    return QuranPageData(
      page: page,
      lines: pageLines,
      headings: headings,
      verseKeys: verseKeys,
    );
  }

  /// Keeps only the fields the reader needs.
  ///
  /// The API response also carries translations, transliterations and audio
  /// links; dropping them keeps the offline cache small (a few kilobytes per
  /// page instead of tens of kilobytes).
  static Map<String, dynamic> compact(Map<String, dynamic> json) {
    final verses = json['verses'];
    final compactVerses = <Map<String, dynamic>>[];
    if (verses is List) {
      for (final rawVerse in verses) {
        if (rawVerse is! Map) continue;
        final key = rawVerse['verse_key'];
        final rawWords = rawVerse['words'];
        if (key is! String || rawWords is! List) continue;

        final words = <Map<String, dynamic>>[];
        for (final rawWord in rawWords) {
          if (rawWord is! Map) continue;
          words.add({
            'line_number': rawWord['line_number'],
            'text_uthmani': rawWord['text_uthmani'] ?? rawWord['text'],
            'char_type_name': rawWord['char_type_name'],
            'position': rawWord['position'],
          });
        }
        compactVerses.add({'verse_key': key, 'words': words});
      }
    }
    return {
      'v': QuranPageData.cacheVersion,
      'verses': compactVerses,
    };
  }
}

/// Downloads and caches the text of the 604 mushaf pages.
///
/// The Qur’an.com API returns every word together with the printed line it
/// belongs to, so each page can be rebuilt exactly like the Madinah mushaf
/// without storing page images. A page is downloaded once and then read from
/// the local cache, which keeps it available offline.
class QuranPageCache {
  QuranPageCache({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                followRedirects: true,
                headers: const {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;
  Directory? _directory;
  final Map<int, Future<QuranPageData>> _inFlight = {};
  final Map<int, QuranPageData> _memory = {};
  final Map<int, Map<String, dynamic>> _bundled = {};

  static const _memoryLimit = 8;

  static const _endpoints = [
    'https://api.quran.com/api/v4/verses/by_page',
    'https://api.qurancdn.com/api/qdc/verses/by_page',
  ];

  static const _query = {
    'words': 'true',
    'word_fields': 'line_number,text_uthmani,position',
    'fields': 'text_uthmani',
  };

  Future<Directory> _pagesDirectory() async {
    final cached = _directory;
    if (cached != null) return cached;

    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'quran', 'pages'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _directory = directory;
    await _removeLegacyImages(directory);
    return directory;
  }

  /// Earlier builds cached page photos here; the reader is text-only now, so
  /// those files are dead weight (tens of megabytes).
  Future<void> _removeLegacyImages(Directory directory) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.jpg') || entity.path.endsWith('.jpg.part')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // A failed cleanup must never stop the reader from working.
    }
  }

  Future<File> _fileFor(int page) async {
    final directory = await _pagesDirectory();
    return File(p.join(directory.path, 'page_$page.json'));
  }

  /// Loads a page from the bundled asset (if present). Returns null when the
  /// page is not bundled or cannot be parsed, so callers fall back to disk /
  /// network.
  Future<QuranPageData?> _loadBundled(int pageNumber) async {
    // Batches 1-11 cover 50 pages each (1-550); batch 12 covers 551-604.
    final batchIndex = pageNumber <= 550
        ? ((pageNumber - 1) ~/ 50) + 1
        : 12;
    final batchNum = batchIndex.toString().padLeft(2, '0');
    final assetPath = 'assets/quran/batch_$batchNum.json';

    Map<String, dynamic>? batch = _bundled[batchIndex];
    if (batch == null) {
      try {
        final raw = await rootBundle.loadString(assetPath);
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          batch = decoded;
          _bundled[batchIndex] = batch;
        }
      } catch (_) {
        return null;
      }
    }
    if (batch == null) return null;

    final pageData = batch['$pageNumber'];
    if (pageData is! Map<String, dynamic>) return null;
    if (pageData['v'] != QuranPageData.cacheVersion) return null;
    try {
      return QuranPageData.parse(pageNumber, pageData);
    } catch (_) {
      return null;
    }
  }

  /// The text of [page], downloading it when necessary.
  Future<QuranPageData> page(int pageNumber, {bool refresh = false}) async {
    if (pageNumber < 1 || pageNumber > quranPageCount) {
      throw QuranPageException('Page $pageNumber is outside the Qur’an.');
    }

    if (!refresh) {
      final memory = _memory[pageNumber];
      if (memory != null) return memory;

      final pending = _inFlight[pageNumber];
      if (pending != null) return pending;
    }

    final future = _load(pageNumber, refresh: refresh);
    _inFlight[pageNumber] = future;
    try {
      final data = await future;
      _remember(pageNumber, data);
      return data;
    } finally {
      if (identical(_inFlight[pageNumber], future)) {
        _inFlight.remove(pageNumber);
      }
    }
  }

  void _remember(int pageNumber, QuranPageData data) {
    _memory.remove(pageNumber);
    _memory[pageNumber] = data;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  /// Warms the cache for a page that is likely to be read next.
  ///
  /// Prefetching is best-effort: failures are ignored because the reader shows
  /// its own error and retry button for the visible page.
  Future<void> prefetch(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > quranPageCount) return;
    try {
      await page(pageNumber);
    } catch (_) {
      // Ignore: this is only a cache warm-up.
    }
  }

  Future<QuranPageData> _load(int pageNumber, {required bool refresh}) async {
    // Bundled asset (shipped with the app) — works fully offline from install.
    if (!refresh) {
      try {
        final bundled = await _loadBundled(pageNumber);
        if (bundled != null) return bundled;
      } catch (_) {
        // Fall through to disk / network.
      }
    }

    final file = await _fileFor(pageNumber);
    if (!refresh && await file.exists()) {
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic> &&
            decoded['v'] == QuranPageData.cacheVersion) {
          return QuranPageData.parse(pageNumber, decoded);
        }
      } catch (_) {
        // Corrupt or outdated cache: delete it and download again.
        try {
          await file.delete();
        } catch (_) {
          // Ignore.
        }
      }
    }

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final response = await _dio.get<String>(
          '$endpoint/$pageNumber',
          queryParameters: _query,
          options: Options(responseType: ResponseType.plain),
        );
        final body = response.data;
        if (body == null || body.isEmpty) {
          lastError = QuranPageException('Empty response from $endpoint');
          continue;
        }

        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) {
          lastError = QuranPageException('Unexpected response from $endpoint');
          continue;
        }

        final data = QuranPageData.parse(pageNumber, decoded);
        await _write(file, jsonEncode(QuranPageData.compact(decoded)));
        return data;
      } catch (error) {
        lastError = error;
      }
    }

    throw QuranPageException(
      'Could not load page $pageNumber. Check your connection and try again.'
      '${lastError == null ? '' : '\n$lastError'}',
    );
  }

  Future<void> _write(File file, String body) async {
    // Write to a temporary file first so an interrupted download never leaves
    // a half-written page in the cache.
    final temp = File('${file.path}.part');
    await temp.writeAsString(body, flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  /// How many pages are already saved on this device.
  Future<int> savedPageCount() async {
    // All 604 pages are bundled with the app, so they are always "saved".
    return quranPageCount;
  }

  /// Saves every page for offline reading.
  ///
  /// Pages already on the device are read from disk, so this can safely be run
  /// again after an interrupted download. A failed page is skipped; the reader
  /// can still open it later with a connection.
  Future<void> downloadAll({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    for (var number = 1; number <= quranPageCount; number++) {
      if (isCancelled?.call() ?? false) return;
      try {
        await page(number);
      } catch (_) {
        // Keep going: one bad page must not stop the whole download.
      }
      onProgress?.call(number, quranPageCount);
    }
  }

  /// Deletes every saved page. The reader downloads pages again on demand.
  Future<void> clear() async {
    final directory = await _pagesDirectory();
    _memory.clear();
    _inFlight.clear();
    if (await directory.exists()) await directory.delete(recursive: true);
    _directory = null;
  }

  void dispose() => _dio.close(force: true);
}

final quranPageCacheProvider = Provider<QuranPageCache>((ref) {
  final cache = QuranPageCache();
  ref.onDispose(cache.dispose);
  return cache;
});
