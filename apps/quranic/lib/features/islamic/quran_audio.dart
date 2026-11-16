import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_audio_api.dart';
import 'quran_audio_store.dart';
import 'quran_meta.dart';

/// A reciter offered by the reader.
class QuranReciter {
  const QuranReciter({required this.id, required this.name, required this.style});

  /// Qur'an.com recitation id.
  final int id;
  final String name;
  final String style;

  String get label => '$name · $style';
}

const quranReciters = <QuranReciter>[
  QuranReciter(id: 7, name: 'Mishary al-Afasy', style: 'Murattal'),
  QuranReciter(id: 2, name: 'Abdul Basit', style: 'Murattal'),
  QuranReciter(id: 1, name: 'Abdul Basit', style: 'Mujawwad'),
  QuranReciter(id: 3, name: 'Abdur-Rahman as-Sudais', style: 'Murattal'),
  QuranReciter(id: 4, name: 'Abu Bakr ash-Shatri', style: 'Murattal'),
  QuranReciter(id: 5, name: 'Hani ar-Rifai', style: 'Murattal'),
  QuranReciter(id: 6, name: 'Mahmoud al-Husary', style: 'Murattal'),
  QuranReciter(id: 8, name: 'Mohamed al-Minshawi', style: 'Mujawwad'),
  QuranReciter(id: 9, name: 'Mohamed al-Minshawi', style: 'Murattal'),
  QuranReciter(id: 10, name: 'Saud ash-Shuraym', style: 'Murattal'),
  QuranReciter(id: 11, name: 'Mohamed al-Tablawi', style: 'Murattal'),
  QuranReciter(id: 12, name: 'Mahmoud al-Husary', style: 'Mu‘allim'),
];

QuranReciter quranReciterById(int id) {
  for (final reciter in quranReciters) {
    if (reciter.id == id) return reciter;
  }
  return quranReciters.first;
}

/// One word of a verse, used to drive the subtitle-style highlight.
@immutable
class QuranWordRef {
  const QuranWordRef(this.verseKey, this.wordIndex);

  final String verseKey;
  final int wordIndex;

  @override
  bool operator ==(Object other) {
    return other is QuranWordRef &&
        other.verseKey == verseKey &&
        other.wordIndex == wordIndex;
  }

  @override
  int get hashCode => Object.hash(verseKey, wordIndex);
}

/// A chapter ready to play, either from the device or from the network.
class _LoadedChapter {
  const _LoadedChapter({
    required this.urls,
    required this.local,
    required this.timings,
  });

  /// Remote MP3 URL per verse, used when no local copy exists.
  final Map<String, String> urls;

  /// Local MP3 path per verse.
  final Map<String, String> local;
  final Map<String, QuranVerseTiming> timings;

  List<String> get verseKeys {
    final keys = <String>{...urls.keys, ...local.keys}.toList();
    keys.sort((a, b) => quranVerseNumber(a).compareTo(quranVerseNumber(b)));
    return keys;
  }

}

/// Plays a recitation verse by verse and reports the word being recited.
///
/// The Qur'an.com API provides one MP3 per ayah plus word-level timings for
/// the whole surah. Playback walks the ayah queue in order, continues into the
/// next surah, and converts the player position into the active word so the
/// reader can highlight it like a subtitle. A downloaded surah plays from the
/// device; everything else streams.
class QuranAudioController extends ChangeNotifier {
  QuranAudioController({
    required SharedPreferences prefs,
    Dio? dio,
    QuranAudioStore? store,
  })  : _prefs = prefs,
        _store = store,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 30),
                followRedirects: true,
                headers: const {'Accept': 'application/json'},
              ),
            ),
        _reciterId = prefs.getInt(quranReciterKey) ?? quranReciters.first.id {
    _player.setReleaseMode(ReleaseMode.stop);
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (!_playing) return;
      unawaited(_advance(_request));
    });
    _positionSubscription = _player.onPositionChanged.listen(_onPosition);
    _store?.addListener(_onStoreChanged);
  }

  final SharedPreferences _prefs;
  final Dio _dio;
  final QuranAudioStore? _store;
  final AudioPlayer _player = AudioPlayer();

  late final StreamSubscription<void> _completeSubscription;
  late final StreamSubscription<Duration> _positionSubscription;

  final ValueNotifier<QuranWordRef?> activeWord = ValueNotifier(null);
  final ValueNotifier<String?> currentVerse = ValueNotifier(null);

  final Map<String, Future<_LoadedChapter>> _chapterCache = {};

  /// Recitation is sequential, so only the current chapter and a few recently
  /// played ones are worth keeping in memory.
  static const _chapterCacheLimit = 4;

  int _reciterId;
  int _chapter = 1;
  String? _currentVerseKey;
  List<String> _queue = const [];
  Map<String, String> _urls = const {};
  Map<String, String> _local = const {};
  Map<String, QuranVerseTiming> _timings = const {};
  int _index = 0;
  int _request = 0;
  bool _playing = false;
  bool _loading = false;
  String? _error;

  int get reciterId => _reciterId;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get currentVerseKey => currentVerse.value;
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _onStoreChanged() {
    final store = _store;
    if (store == null) return;
    // Progress ticks arrive while a download runs; only a finished or removed
    // download changes which source the next chapter load should use.
    if (!store.isDownloading) _chapterCache.clear();
  }

  /// Starts reciting from [verseKey] and continues through the following
  /// ayahs and surahs.
  Future<void> playFromVerse(String verseKey) async {
    final chapter = quranChapterNumber(verseKey);
    if (chapter == null) return;

    final token = ++_request;
    _playing = false;
    _loading = true;
    _error = null;
    activeWord.value = null;
    notifyListeners();

    await _player.stop();
    if (token != _request) return;

    await _beginChapter(chapter, quranVerseNumber(verseKey), token);
  }

  Future<void> _beginChapter(int chapter, int startVerse, int token) async {
    _loading = true;
    notifyListeners();

    _LoadedChapter audio;
    try {
      audio = await _chapterAudio(chapter);
    } catch (error) {
      if (token != _request) return;
      _loading = false;
      _playing = false;
      _error = 'The recitation could not be loaded. Check your connection.';
      notifyListeners();
      return;
    }
    if (token != _request) return;

    _chapter = chapter;
    _urls = audio.urls;
    _local = audio.local;
    _timings = audio.timings;
    _queue = audio.verseKeys
        .where((key) => quranVerseNumber(key) >= startVerse)
        .toList(growable: false);
    _index = 0;

    if (_queue.isEmpty) {
      _loading = false;
      _playing = false;
      _error = 'This verse has no recitation for the selected reciter.';
      notifyListeners();
      return;
    }

    await _startVerse(_queue.first, token);
  }

  Future<void> _startVerse(String verseKey, int token) async {
    if (token != _request) return;

    _currentVerseKey = verseKey;
    currentVerse.value = verseKey;
    activeWord.value = null;
    _playing = false;
    notifyListeners();

    try {
      await _player.stop();
      if (token != _request) return;

      final localPath = _local[verseKey];
      var started = false;
      if (localPath != null && File(localPath).existsSync()) {
        try {
          await _player.play(DeviceFileSource(localPath));
          started = true;
        } catch (_) {
          // A missing or unreadable download falls back to streaming.
        }
      }
      if (!started) {
        final url = _urls[verseKey];
        if (url == null) {
          await _advance(token);
          return;
        }
        await _player.play(UrlSource(url));
      }
      if (token != _request) {
        await _player.stop();
        return;
      }
      _playing = true;
      _loading = false;
      notifyListeners();
    } catch (_) {
      if (token != _request) return;
      _playing = false;
      _loading = false;
      _error = 'The recitation could not be played.';
      notifyListeners();
    }
  }

  Future<void> _advance(int token) async {
    if (token != _request) return;

    _index++;
    if (_index < _queue.length) {
      await _startVerse(_queue[_index], token);
      return;
    }

    // The surah finished: keep reciting into the next one.
    final next = _chapter + 1;
    if (next > quranChapters.length) {
      await _stopPlayback();
      return;
    }
    await _beginChapter(next, 1, token);
  }

  /// Pauses playback, keeping the current verse so [resume] can continue.
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _player.pause();
  }

  /// Continues a paused verse, or starts the page again when nothing is loaded.
  Future<void> resume() async {
    if (_playing) return;
    if (_currentVerseKey == null) return;
    try {
      await _player.resume();
      _playing = true;
      _error = null;
      notifyListeners();
    } catch (_) {
      _error = 'The recitation could not be resumed.';
      notifyListeners();
    }
  }

  /// Stops playback and forgets the current verse.
  Future<void> stop() async {
    _request++;
    await _stopPlayback();
  }

  Future<void> _stopPlayback() async {
    _playing = false;
    _loading = false;
    _currentVerseKey = null;
    currentVerse.value = null;
    activeWord.value = null;
    notifyListeners();
    await _player.stop();
  }

  /// Switches reciter and restarts the current verse when it was playing.
  Future<void> setReciter(int id) async {
    if (id == _reciterId) return;

    final wasPlaying = _playing;
    final verse = _currentVerseKey;
    _request++;
    _reciterId = id;
    await _prefs.setInt(quranReciterKey, id);

    if (verse != null && wasPlaying) {
      await playFromVerse(verse);
      return;
    }
    if (verse != null) {
      await stop();
      return;
    }
    notifyListeners();
  }

  void _onPosition(Duration position) {
    final verse = _currentVerseKey;
    if (verse == null) return;
    final timing = _timings[verse];
    if (timing == null || timing.segments.isEmpty) return;

    final ms = position.inMilliseconds + timing.base;
    QuranAudioSegment? current;
    for (final segment in timing.segments) {
      if (ms < segment.start) break;
      current = segment;
      if (ms <= segment.end) break;
    }
    if (current == null) return;

    final next = QuranWordRef(verse, current.word);
    if (activeWord.value != next) activeWord.value = next;
  }

  Future<_LoadedChapter> _chapterAudio(int chapter) {
    final key = '$_reciterId:$chapter';
    final cached = _chapterCache[key];
    if (cached != null) return cached;

    final future = _loadChapterAudio(_reciterId, chapter);
    _chapterCache[key] = future;
    while (_chapterCache.length > _chapterCacheLimit) {
      final oldest = _chapterCache.keys.first;
      if (oldest == key) break;
      _chapterCache.remove(oldest);
    }
    // A network failure must not poison the cache; the reader can try again.
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_chapterCache[key], future)) {
            _chapterCache.remove(key);
          }
        },
      ),
    );
    return future;
  }

  Future<_LoadedChapter> _loadChapterAudio(int reciter, int chapter) async {
    final local = await _store?.localChapter(reciter, chapter);
    if (local != null && local.files.isNotEmpty) {
      return _LoadedChapter(
        urls: local.urls,
        local: local.files,
        timings: local.timings,
      );
    }

    final audio = await fetchQuranChapterAudio(_dio, reciter, chapter);
    return _LoadedChapter(
      urls: audio.urls,
      local: const {},
      timings: audio.timings,
    );
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _completeSubscription.cancel();
    _positionSubscription.cancel();
    _player.dispose();
    _dio.close(force: true);
    activeWord.dispose();
    currentVerse.dispose();
    super.dispose();
  }
}
