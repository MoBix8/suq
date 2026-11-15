import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A translation offered in the verse sheet.
class QuranTranslation {
  const QuranTranslation({
    required this.id,
    required this.label,
    required this.nativeLabel,
  });

  /// Qur’an.com translation resource id.
  final int id;
  final String label;
  final String nativeLabel;
}

/// Translations curated for the shop app: English plus the languages spoken
/// around the Horn of Africa. Tigrinya is not published by the Qur’an.com
/// translation catalogue, so it is not listed.
const quranTranslations = <QuranTranslation>[
  QuranTranslation(id: 20, label: 'English', nativeLabel: 'English'),
  QuranTranslation(id: 87, label: 'Amharic', nativeLabel: 'አማርኛ'),
  QuranTranslation(id: 111, label: 'Oromo', nativeLabel: 'Afaan Oromoo'),
  QuranTranslation(id: 46, label: 'Somali', nativeLabel: 'Soomaali'),
  QuranTranslation(id: 231, label: 'Swahili', nativeLabel: 'Kiswahili'),
];

/// An explanation (tafsir) offered for a verse.
class QuranTafsir {
  const QuranTafsir({
    required this.id,
    required this.label,
    required this.author,
    required this.language,
  });

  /// Qur’an.com tafsir resource id.
  final int id;
  final String label;
  final String author;

  /// Language the explanation is written in.
  final String language;

  String get displayLabel => '$language · $label';
}

const quranTafsirs = <QuranTafsir>[
  QuranTafsir(
    id: 16,
    label: 'Muyassar',
    author: 'King Fahd Complex',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 91,
    label: 'As-Sa‘di',
    author: 'Abd ar-Rahman as-Sa‘di',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 14,
    label: 'Ibn Kathir',
    author: 'Isma‘il ibn Kathir',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 15,
    label: 'At-Tabari',
    author: 'Ibn Jarir at-Tabari',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 90,
    label: 'Al-Qurtubi',
    author: 'Al-Qurtubi',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 94,
    label: 'Al-Baghawi',
    author: 'Al-Baghawi',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 93,
    label: 'Al-Wasit',
    author: 'Al-Wasit',
    language: 'Arabic',
  ),
  QuranTafsir(
    id: 169,
    label: 'Ibn Kathir (Abridged)',
    author: 'Hafiz Ibn Kathir',
    language: 'English',
  ),
  QuranTafsir(
    id: 168,
    label: 'Ma‘arif al-Qur’an',
    author: 'Mufti Muhammad Shafi',
    language: 'English',
  ),
  QuranTafsir(
    id: 817,
    label: 'Tazkirul Quran',
    author: 'Maulana Wahiduddin Khan',
    language: 'English',
  ),
];

/// One word of a verse, used for the recitation highlight in the list view.
class QuranStudyWord {
  const QuranStudyWord({
    required this.text,
    required this.position,
    required this.isAyahEnd,
  });

  final String text;

  /// 1-based position among the recitable words; 0 for an ayah end marker.
  final int position;
  final bool isAyahEnd;
}

/// Everything the verse sheet shows for one ayah.
class QuranVerseStudy {
  const QuranVerseStudy({
    required this.verseKey,
    required this.arabic,
    required this.translations,
    this.words = const [],
    this.pageNumber,
  });

  final String verseKey;
  final String arabic;

  /// Translation text keyed by translation resource id.
  final Map<int, String> translations;

  /// Words as they appear in the mushaf, when the request asked for them.
  final List<QuranStudyWord> words;

  /// Printed mushaf page this verse belongs to.
  final int? pageNumber;
}

/// The verses of one mushaf page, for the reader's list view.
class QuranPageStudy {
  const QuranPageStudy({required this.page, required this.verses});

  final int page;
  final List<QuranVerseStudy> verses;
}

/// Every verse of one surah, for the whole-surah list view.
class QuranChapterStudy {
  const QuranChapterStudy({required this.chapter, required this.verses});

  final int chapter;
  final List<QuranVerseStudy> verses;
}


/// Fetches verse translations and tafsir from the Qur’an.com API.
///
/// Results are cached in memory for the session, so reopening the same verse
/// or switching between tafsirs that were already read is instant.
class QuranStudyService {
  QuranStudyService({Dio? dio})
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
  final Map<String, Future<QuranVerseStudy>> _verses = {};
  final Map<String, Future<String>> _tafsirs = {};
  final Map<String, Future<QuranPageStudy>> _pages = {};
  final Map<String, Future<QuranChapterStudy>> _chapters = {};

  static const _hosts = [
    'https://api.quran.com/api/v4',
    'https://api.qurancdn.com/api/qdc',
  ];

  static const _cacheLimit = 240;

  Future<QuranVerseStudy> verse(String verseKey) {
    final cached = _verses[verseKey];
    if (cached != null) return cached;

    final future = _loadVerse(verseKey);
    _verses[verseKey] = future;
    _evict(_verses, verseKey);
    // A failed download must not poison the cache: the sheet offers a retry.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_verses[verseKey], future)) _verses.remove(verseKey);
        },
      ),
    );
    return future;
  }

  Future<String> tafsir(int id, String verseKey) {
    final key = '$id:$verseKey';
    final cached = _tafsirs[key];
    if (cached != null) return cached;

    final future = _loadTafsir(id, verseKey);
    _tafsirs[key] = future;
    _evict(_tafsirs, key);
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_tafsirs[key], future)) _tafsirs.remove(key);
        },
      ),
    );
    return future;
  }

  /// The verses printed on [page], with [translationId] for the list view.
  Future<QuranPageStudy> page(int page, int translationId) {
    final key = '$page:$translationId';
    final cached = _pages[key];
    if (cached != null) return cached;

    final future = _loadPage(page, translationId);
    _pages[key] = future;
    _evict(_pages, key);
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_pages[key], future)) _pages.remove(key);
        },
      ),
    );
    return future;
  }

  /// Every verse of [chapter], with [translationId] for the list view.
  Future<QuranChapterStudy> chapter(int chapter, int translationId) {
    final key = '$chapter:$translationId';
    final cached = _chapters[key];
    if (cached != null) return cached;

    final future = _loadChapter(chapter, translationId);
    _chapters[key] = future;
    _evict(_chapters, key);
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_chapters[key], future)) _chapters.remove(key);
        },
      ),
    );
    return future;
  }

  Future<QuranPageStudy> _loadPage(int page, int translationId) async {
    final verses = await _loadVerses(
      'by_page/$page',
      translationId,
      perPage: 50,
      errorLabel: 'page $page',
    );
    return QuranPageStudy(page: page, verses: verses);
  }

  Future<QuranChapterStudy> _loadChapter(
    int chapter,
    int translationId,
  ) async {
    final verses = await _loadVerses(
      'by_chapter/$chapter',
      translationId,
      perPage: 300,
      errorLabel: 'surah $chapter',
    );
    return QuranChapterStudy(chapter: chapter, verses: verses);
  }

  Future<List<QuranVerseStudy>> _loadVerses(
    String path,
    int translationId, {
    required int perPage,
    required String errorLabel,
  }) async {
    final query = {
      'translations': '$translationId',
      'fields': 'text_uthmani',
      'words': 'true',
      'word_fields': 'text_uthmani,position,char_type_name',
      'per_page': '$perPage',
    };

    Object? lastError;
    for (final host in _hosts) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$host/verses/$path',
          queryParameters: query,
        );
        final rawVerses = response.data?['verses'];
        if (rawVerses is! List || rawVerses.isEmpty) {
          lastError = StateError('Unexpected response from $host');
          continue;
        }

        final verses = <QuranVerseStudy>[];
        for (final raw in rawVerses) {
          if (raw is! Map) continue;
          final key = raw['verse_key'];
          if (key is! String) continue;
          verses.add(_studyVerse(raw, key));
        }
        if (verses.isEmpty) {
          lastError = StateError('No verses from $host');
          continue;
        }
        return verses;
      } catch (error) {
        lastError = error;
      }
    }

    throw QuranStudyException(
      'Could not load $errorLabel.'
      '${lastError == null ? '' : '\n$lastError'}',
    );
  }

  Future<QuranVerseStudy> _loadVerse(String verseKey) async {
    final query = {
      'translations': quranTranslations.map((item) => item.id).join(','),
      'fields': 'text_uthmani',
      'words': 'true',
      'word_fields': 'text_uthmani,position,char_type_name',
    };

    Object? lastError;
    for (final host in _hosts) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$host/verses/by_key/$verseKey',
          queryParameters: query,
        );
        final verse = response.data?['verse'];
        if (verse is! Map) {
          lastError = StateError('Unexpected response from $host');
          continue;
        }
        return _studyVerse(verse, verseKey);
      } catch (error) {
        lastError = error;
      }
    }

    throw QuranStudyException(
      'Could not load the translations for $verseKey.'
      '${lastError == null ? '' : '\n$lastError'}',
    );
  }

  static QuranVerseStudy _studyVerse(Map verse, String verseKey) {
    final translations = <int, String>{};
    final rawTranslations = verse['translations'];
    if (rawTranslations is List) {
      for (final raw in rawTranslations) {
        if (raw is! Map) continue;
        final id = (raw['resource_id'] as num?)?.toInt();
        if (id == null) continue;
        final text = quranPlainText(raw['text'] as String?);
        if (text.isNotEmpty) translations[id] = text;
      }
    }

    final words = <QuranStudyWord>[];
    final rawWords = verse['words'];
    if (rawWords is List) {
      for (final raw in rawWords) {
        if (raw is! Map) continue;
        final text = raw['text_uthmani'] ?? raw['text'];
        if (text is! String || text.isEmpty) continue;
        final isAyahEnd = raw['char_type_name'] == 'end';
        final position = (raw['position'] as num?)?.toInt() ?? 0;
        words.add(
          QuranStudyWord(
            text: text,
            position: isAyahEnd ? 0 : position,
            isAyahEnd: isAyahEnd,
          ),
        );
      }
    }

    return QuranVerseStudy(
      verseKey: verseKey,
      arabic: (verse['text_uthmani'] as String?)?.trim() ?? '',
      translations: translations,
      words: words,
      pageNumber: (verse['page_number'] as num?)?.toInt(),
    );
  }

  Future<String> _loadTafsir(int id, String verseKey) async {
    Object? lastError;
    for (final host in _hosts) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$host/tafsirs/$id/by_ayah/$verseKey',
        );
        final tafsir = response.data?['tafsir'];
        if (tafsir is! Map) {
          lastError = StateError('Unexpected response from $host');
          continue;
        }
        return quranPlainText(tafsir['text'] as String?);
      } catch (error) {
        lastError = error;
      }
    }

    throw QuranStudyException(
      'Could not load the tafsir for $verseKey.'
      '${lastError == null ? '' : '\n$lastError'}',
    );
  }

  void _evict(Map<String, Object?> cache, String keep) {
    while (cache.length > _cacheLimit) {
      final first = cache.keys.first;
      if (first == keep) break;
      cache.remove(first);
    }
  }

  void dispose() => _dio.close(force: true);
}

class QuranStudyException implements Exception {
  QuranStudyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns the API's small HTML snippets into readable plain text.
///
/// Translations carry footnote markers (`<sup …>1</sup>`) and tafsirs colour
/// words with `<span>`; both are markup the sheet does not need.
String quranPlainText(String? html) {
  if (html == null || html.isEmpty) return '';

  var text = html;
  text = text.replaceAll(
    RegExp(r'<sup[^>]*>.*?</sup>', caseSensitive: false, dotAll: true),
    '',
  );
  text = text.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(
    RegExp(r'</p\s*>', caseSensitive: false),
    '\n\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–');
  text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final code = int.tryParse(match.group(1)!, radix: 16);
    return code == null ? match.group(0)! : String.fromCharCode(code);
  });
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final code = int.tryParse(match.group(1)!);
    return code == null ? match.group(0)! : String.fromCharCode(code);
  });

  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r' ?\n ?'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

final quranStudyProvider = Provider<QuranStudyService>((ref) {
  final service = QuranStudyService();
  ref.onDispose(service.dispose);
  return service;
});
