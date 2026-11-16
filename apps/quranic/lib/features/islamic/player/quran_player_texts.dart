import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../quran_study.dart';

/// One ayah of a surah, split into words so the player can highlight what is
/// being recited. mp3quran.net ships one MP3 per surah and no word timings, so
/// the player spreads the file duration across these words.
class QuranVerseText {
  const QuranVerseText({
    required this.number,
    required this.arabic,
    required this.words,
  });

  /// Ayah number inside the surah.
  final int number;
  final String arabic;

  /// Recitable words only; ayah end markers are dropped.
  final List<String> words;

  /// Relative time this ayah should occupy in the surah, by text length.
  int get weight {
    var total = 0;
    for (final word in words) {
      total += word.runes.length;
    }
    return total <= 0 ? 1 : total;
  }
}

/// The full text of one surah, ready for the player timeline.
class QuranChapterText {
  const QuranChapterText({required this.chapter, required this.verses});

  final int chapter;
  final List<QuranVerseText> verses;

  bool get isEmpty => verses.isEmpty;

  int get totalWeight {
    var total = 0;
    for (final verse in verses) {
      total += verse.weight;
    }
    return total;
  }

  static const empty = QuranChapterText(chapter: 0, verses: []);
}

/// Loads and keeps surah text for the audio player.
///
/// Text is saved as JSON next to the downloaded audio, so the verse subtitles
/// keep working offline and a surah is only fetched once. When the network is
/// unavailable and nothing is cached, an empty chapter is returned and playback
/// simply continues without subtitles.
class QuranPlayerTexts {
  QuranPlayerTexts({QuranStudyService? study})
      : _study = study ?? QuranStudyService();

  static const _translationId = 20;

  final QuranStudyService _study;
  final Map<int, QuranChapterText> _memory = {};
  final Map<int, Future<QuranChapterText>> _loading = {};
  Directory? _root;

  Future<Directory> _directory() async {
    final cached = _root;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(support.path, 'quran', 'player', 'text'),
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<File> _fileFor(int chapter) async {
    final directory = await _directory();
    return File(p.join(directory.path, '$chapter.json'));
  }

  /// Cached text if it is already in memory, otherwise null.
  QuranChapterText? peek(int chapter) => _memory[chapter];

  Future<QuranChapterText> chapter(int chapter) {
    final memory = _memory[chapter];
    if (memory != null) return Future.value(memory);

    final running = _loading[chapter];
    if (running != null) return running;

    final future = _load(chapter);
    _loading[chapter] = future;
    return future.whenComplete(() {
      if (identical(_loading[chapter], future)) _loading.remove(chapter);
    });
  }

  Future<QuranChapterText> _load(int chapter) async {
    final fromDisk = await _readDisk(chapter);
    if (fromDisk != null && !fromDisk.isEmpty) {
      _memory[chapter] = fromDisk;
      return fromDisk;
    }

    try {
      final study = await _study.chapter(chapter, _translationId);
      final verses = <QuranVerseText>[];
      for (final verse in study.verses) {
        final words = <String>[];
        for (final word in verse.words) {
          if (word.isAyahEnd) continue;
          final text = word.text.trim();
          if (text.isNotEmpty) words.add(text);
        }
        final arabic = verse.arabic.trim();
        if (words.isEmpty && arabic.isEmpty) continue;
        verses.add(
          QuranVerseText(
            number: _verseNumber(verse.verseKey),
            arabic: arabic,
            words: words.isEmpty ? [arabic] : words,
          ),
        );
      }
      final text = QuranChapterText(chapter: chapter, verses: verses);
      if (text.isEmpty) return text;
      _memory[chapter] = text;
      unawaited(_writeDisk(text));
      return text;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Qur’an player text failed for surah $chapter: $error');
      }
      return QuranChapterText(chapter: chapter, verses: const []);
    }
  }

  int _verseNumber(String verseKey) {
    final index = verseKey.lastIndexOf(':');
    if (index < 0) return 0;
    return int.tryParse(verseKey.substring(index + 1)) ?? 0;
  }

  Future<QuranChapterText?> _readDisk(int chapter) async {
    try {
      final file = await _fileFor(chapter);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final rawVerses = decoded['verses'];
      if (rawVerses is! List) return null;
      final verses = <QuranVerseText>[];
      for (final raw in rawVerses) {
        if (raw is! Map) continue;
        final number = (raw['number'] as num?)?.toInt() ?? 0;
        final arabic = raw['arabic'] as String? ?? '';
        final words = <String>[];
        final rawWords = raw['words'];
        if (rawWords is List) {
          for (final word in rawWords) {
            if (word is String && word.isNotEmpty) words.add(word);
          }
        }
        if (arabic.isEmpty && words.isEmpty) continue;
        verses.add(
          QuranVerseText(
            number: number,
            arabic: arabic,
            words: words.isEmpty ? [arabic] : words,
          ),
        );
      }
      return QuranChapterText(chapter: chapter, verses: verses);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(QuranChapterText text) async {
    try {
      final file = await _fileFor(text.chapter);
      final payload = {
        'chapter': text.chapter,
        'verses': [
          for (final verse in text.verses)
            {
              'number': verse.number,
              'arabic': verse.arabic,
              'words': verse.words,
            },
        ],
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Qur’an player text could not be saved: $error');
      }
    }
  }

  Future<void> clear() async {
    _memory.clear();
    try {
      final directory = await _directory();
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // Clearing is best-effort.
    }
  }
}

final quranPlayerTextsProvider = Provider<QuranPlayerTexts>((ref) {
  return QuranPlayerTexts(study: ref.watch(quranStudyProvider));
});
