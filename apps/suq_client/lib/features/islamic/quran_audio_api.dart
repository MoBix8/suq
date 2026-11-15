import 'package:dio/dio.dart';

/// One word's span inside a verse, in absolute chapter milliseconds.
class QuranAudioSegment {
  const QuranAudioSegment(this.word, this.start, this.end);

  /// 1-based word position inside the verse.
  final int word;
  final int start;
  final int end;

  List<int> toJson() => [word, start, end];
}

/// Word timings for one verse of a chapter recording.
class QuranVerseTiming {
  const QuranVerseTiming({required this.base, required this.segments});

  /// Start of the verse inside the chapter recording, in milliseconds.
  ///
  /// Per-verse MP3 files start at this point, so playback position has to be
  /// offset by [base] before it is compared with [segments].
  final int base;
  final List<QuranAudioSegment> segments;

  Map<String, dynamic> toJson() => {
        'base': base,
        'segments': [for (final segment in segments) segment.toJson()],
      };

  static QuranVerseTiming? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final rawSegments = raw['segments'];
    if (rawSegments is! List) return null;

    final segments = <QuranAudioSegment>[];
    for (final item in rawSegments) {
      if (item is! List || item.length < 3) continue;
      final word = (item[0] as num?)?.toInt() ?? 0;
      final start = (item[1] as num?)?.toInt() ?? 0;
      final end = (item[2] as num?)?.toInt() ?? 0;
      if (word < 1) continue;
      segments.add(QuranAudioSegment(word, start, end));
    }
    if (segments.isEmpty) return null;

    final base = (raw['base'] as num?)?.toInt() ?? segments.first.start;
    return QuranVerseTiming(base: base, segments: segments);
  }
}

/// The verse files and word timings of one chapter recording.
class QuranChapterAudio {
  const QuranChapterAudio({required this.urls, required this.timings});

  /// Verse key (`surah:ayah`) to MP3 URL.
  final Map<String, String> urls;
  final Map<String, QuranVerseTiming> timings;

  List<String> get verseKeys {
    final keys = urls.keys.toList();
    keys.sort((a, b) => quranVerseNumber(a).compareTo(quranVerseNumber(b)));
    return keys;
  }
}

class QuranAudioException implements Exception {
  QuranAudioException(this.message);

  final String message;

  @override
  String toString() => message;
}

const quranAudioHosts = [
  'https://api.quran.com/api/v4',
  'https://api.qurancdn.com/api/qdc',
];

/// Loads one chapter of a reciter: the per-ayah MP3 URLs and, when the timing
/// endpoint responds, the word timings that drive the follow-along highlight.
Future<QuranChapterAudio> fetchQuranChapterAudio(
  Dio dio,
  int reciter,
  int chapter,
) async {
  Object? lastError;

  for (final host in quranAudioHosts) {
    Map<String, dynamic>? urlsBody;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$host/recitations/$reciter/by_chapter/$chapter',
        queryParameters: const {'per_page': 300},
      );
      urlsBody = response.data;
    } catch (error) {
      lastError = error;
      continue;
    }

    final urls = <String, String>{};
    final rawFiles = urlsBody?['audio_files'];
    if (rawFiles is List) {
      for (final raw in rawFiles) {
        if (raw is! Map) continue;
        final key = raw['verse_key'];
        final url = raw['url'];
        if (key is! String || url is! String || url.isEmpty) continue;
        urls[key] = quranAbsoluteAudioUrl(url);
      }
    }
    if (urls.isEmpty) {
      lastError = StateError('No recitation files from $host');
      continue;
    }

    final timings = <String, QuranVerseTiming>{};
    final timingFiles = await _fetchTimingFiles(dio, reciter, chapter);
    if (timingFiles != null && timingFiles.isNotEmpty) {
      final first = timingFiles.first;
      if (first is Map) {
        final rawTimings = first['verse_timings'];
        if (rawTimings is List) {
          for (final rawTiming in rawTimings) {
            if (rawTiming is! Map) continue;
            final key = rawTiming['verse_key'];
            if (key is! String) continue;
            final timing = QuranVerseTiming.fromJson(rawTiming);
            if (timing != null) timings[key] = timing;
          }
        }
      }
    }

    return QuranChapterAudio(urls: urls, timings: timings);
  }

  throw QuranAudioException(
    'Could not load the recitation.'
    '${lastError == null ? '' : '\n$lastError'}',
  );
}

/// Word timings are optional: playback still works without the highlight, so a
/// failure here never fails the chapter load.
Future<List<dynamic>?> _fetchTimingFiles(
  Dio dio,
  int reciter,
  int chapter,
) async {
  for (final host in quranAudioHosts) {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '$host/audio/reciters/$reciter/audio_files',
        queryParameters: {
          'chapter': chapter,
          'segments': true,
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      final files = response.data?['audio_files'];
      if (files is List && files.isNotEmpty) return files;
    } catch (_) {
      // Try the next host.
    }
  }
  return null;
}

/// Turns the API's protocol-relative and relative audio paths into full URLs.
String quranAbsoluteAudioUrl(String url) {
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return 'https://verses.quran.com/$url';
}

int? quranChapterNumber(String verseKey) {
  final index = verseKey.indexOf(':');
  if (index <= 0) return null;
  return int.tryParse(verseKey.substring(0, index));
}

int quranVerseNumber(String verseKey) {
  final index = verseKey.lastIndexOf(':');
  if (index < 0) return 0;
  return int.tryParse(verseKey.substring(index + 1)) ?? 0;
}
