import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers.dart';
import '../quran_meta.dart';
import 'quran_player_downloads.dart';
import 'quran_player_models.dart';

/// Plays one surah at a time, from a downloaded file when there is one and
/// from mp3quran.net otherwise.
///
/// The controller is the single source of truth for the mini player and the
/// full player screen, so audio keeps running while the rest of the app is
/// used. It also keeps the last surah and reciter on the device so the mini
/// player can offer to resume after a restart.
class QuranPlayerController extends ChangeNotifier {
  QuranPlayerController({
    required SharedPreferences prefs,
    required QuranPlayerDownloads downloads,
  })  : _prefs = prefs,
        _downloads = downloads {
    _speed = _readSpeed();
    _repeat = _prefs.getBool(_repeatKey) ?? false;
    _player = AudioPlayer(playerId: 'quran_player');
    _bindPlayer();
    _restoreSaved();
    unawaited(_preparePlayer());
    unawaited(_downloads.warmUp());
  }

  static const _reciterKey = 'quran.player.reciter';
  static const _reciterJsonKey = 'quran.player.reciterJson';
  static const _chapterKey = 'quran.player.chapter';
  static const _speedKey = 'quran.player.speed';
  static const _repeatKey = 'quran.player.repeat';

  final SharedPreferences _prefs;
  final QuranPlayerDownloads _downloads;

  late final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subs = [];

  QuranPlayerReciter? _reciter;
  int? _chapter;
  bool _playing = false;
  bool _buffering = false;
  bool _hasSource = false;
  bool _screenOpen = false;
  bool _repeat = false;
  bool _restored = false;
  double _speed = 1;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  QuranPlayerReciter? get reciter => _reciter;
  int? get chapter => _chapter;
  QuranChapter? get chapterMeta =>
      _chapter == null ? null : quranChapterByNumber(_chapter!);
  bool get isPlaying => _playing;
  bool get isBuffering => _buffering;
  bool get isScreenOpen => _screenOpen;
  bool get repeatChapter => _repeat;
  double get speed => _speed;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get error => _error;
  bool get hasSession => _reciter != null && _chapter != null;

  double get progress {
    final total = _duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  bool get isDownloaded {
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null) return false;
    return _downloads.isDownloaded(reciter.key, chapter);
  }

  Future<void> _preparePlayer() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setAudioContext(
        AudioContextConfig(stayAwake: true).build(),
      );
      await _player.setPlaybackRate(_speed);
    } catch (error) {
      if (kDebugMode) debugPrint('Qur’an player setup failed: $error');
    }
  }

  void _bindPlayer() {
    _subs.add(
      _player.onPlayerStateChanged.listen((state) {
        final playing = state == PlayerState.playing;
        if (_playing == playing) return;
        _playing = playing;
        notifyListeners();
      }),
    );
    _subs.add(
      _player.onPositionChanged.listen((value) {
        _position = value;
        _buffering = false;
        notifyListeners();
      }),
    );
    _subs.add(
      _player.onDurationChanged.listen((value) {
        if (value.inMilliseconds <= 0) return;
        _duration = value;
        notifyListeners();
      }),
    );
    _subs.add(
      _player.onPlayerComplete.listen((_) {
        _buffering = false;
        unawaited(_handleComplete());
      }),
    );
  }

  Future<void> _handleComplete() async {
    if (_repeat) {
      await _player.seek(Duration.zero);
      await _player.resume();
      return;
    }
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null) return;
    final index = reciter.chapters.indexOf(chapter);
    if (index >= 0 && index < reciter.chapters.length - 1) {
      await open(reciter, reciter.chapters[index + 1]);
      return;
    }
    _playing = false;
    _hasSource = false;
    _position = _duration;
    notifyListeners();
  }

  /// Reloads the last reciter from preferences, so the mini player appears
  /// as soon as the app starts without waiting for the catalogue.
  void _restoreSaved() {
    final raw = _prefs.getString(_reciterJsonKey);
    final chapter = _prefs.getInt(_chapterKey);
    if (raw == null || raw.isEmpty || chapter == null) return;
    try {
      final reciter = QuranPlayerReciter.fromJson(jsonDecode(raw));
      if (reciter == null || !reciter.hasChapter(chapter)) return;
      _reciter = reciter;
      _chapter = chapter;
      _restored = true;
    } catch (_) {
      // A corrupt entry is ignored; the library can restore it again.
    }
  }

  /// Brings back the last reciter and surah without starting playback.
  Future<void> restore(List<QuranPlayerReciter> catalog) async {
    if (_restored) return;
    _restored = true;
    if (_reciter != null) return;

    final key = _prefs.getString(_reciterKey);
    final chapter = _prefs.getInt(_chapterKey);
    if (key == null || chapter == null) return;

    QuranPlayerReciter? match;
    for (final item in catalog) {
      if (item.key == key) {
        match = item;
        break;
      }
    }
    if (match == null || !match.hasChapter(chapter)) return;

    _reciter = match;
    _chapter = chapter;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  /// Loads [chapter] from [reciter] and starts it unless [autoplay] is false.
  Future<void> open(
    QuranPlayerReciter reciter,
    int chapter, {
    bool autoplay = true,
  }) async {
    if (!reciter.hasChapter(chapter)) {
      _error = 'This reciter did not record that surah.';
      notifyListeners();
      return;
    }

    final same = _reciter?.key == reciter.key && _chapter == chapter;
    if (same && _hasSource) {
      if (autoplay && !_playing) await _player.resume();
      return;
    }

    if (_playing) await _player.pause();

    _reciter = reciter;
    _chapter = chapter;
    _hasSource = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    _buffering = autoplay;
    notifyListeners();

    _persist();

    if (autoplay) await _playCurrent();
  }

  Future<void> _playCurrent() async {
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null) return;

    final url = reciter.urlFor(chapter);
    if (url == null) {
      _error = 'This surah is not available from that reciter.';
      _buffering = false;
      notifyListeners();
      return;
    }

    File? file;
    try {
      final candidate = await _downloads.audioFile(reciter.key, chapter);
      if (await candidate.exists() && await candidate.length() > 0) {
        file = candidate;
      }
    } catch (_) {
      // Fall back to streaming.
    }

    _buffering = true;
    _error = null;
    notifyListeners();

    try {
      await _player.play(
        file == null ? UrlSource(url) : DeviceFileSource(file.path),
      );
      await _player.setPlaybackRate(_speed);
      _hasSource = true;
      _playing = true;
    } catch (error) {
      _buffering = false;
      _playing = false;
      _error = 'Could not play this surah. Check your connection and retry.';
      if (kDebugMode) debugPrint('Qur’an player playback failed: $error');
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_reciter == null || _chapter == null) return;
    if (!_hasSource) {
      await _playCurrent();
      return;
    }
    try {
      if (_playing) {
        await _player.pause();
        _playing = false;
      } else {
        await _player.resume();
        _playing = true;
      }
      notifyListeners();
    } catch (error) {
      if (kDebugMode) debugPrint('Qur’an player toggle failed: $error');
    }
  }

  Future<void> seek(Duration value) async {
    if (!_hasSource) return;
    var target = value;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    _position = target;
    notifyListeners();
    try {
      await _player.seek(target);
    } catch (error) {
      if (kDebugMode) debugPrint('Qur’an player seek failed: $error');
    }
  }

  Future<void> next() async {
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null || reciter.chapters.isEmpty) return;
    final index = reciter.chapters.indexOf(chapter);
    final target = index < 0
        ? reciter.chapters.first
        : reciter.chapters[(index + 1) % reciter.chapters.length];
    await open(reciter, target);
  }

  Future<void> previous() async {
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null || reciter.chapters.isEmpty) return;
    if (_position > const Duration(seconds: 4) && _hasSource) {
      await seek(Duration.zero);
      return;
    }
    final index = reciter.chapters.indexOf(chapter);
    final target = index <= 0
        ? reciter.chapters.last
        : reciter.chapters[(index - 1) % reciter.chapters.length];
    await open(reciter, target);
  }

  Future<void> stop() async {
    if (!_hasSource) return;
    try {
      await _player.pause();
      await _player.seek(Duration.zero);
    } catch (_) {
      // The source may already be gone.
    }
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> close() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore a player that never started.
    }
    _reciter = null;
    _chapter = null;
    _hasSource = false;
    _playing = false;
    _buffering = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _error = null;
    await _prefs.remove(_reciterKey);
    await _prefs.remove(_reciterJsonKey);
    await _prefs.remove(_chapterKey);
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    final next = value.clamp(0.5, 2.0).toDouble();
    if (next == _speed) return;
    _speed = next;
    notifyListeners();
    await _prefs.setDouble(_speedKey, next);
    try {
      await _player.setPlaybackRate(next);
    } catch (error) {
      if (kDebugMode) debugPrint('Qur’an player speed failed: $error');
    }
  }

  void toggleRepeat() {
    _repeat = !_repeat;
    _prefs.setBool(_repeatKey, _repeat);
    notifyListeners();
  }

  void setScreenOpen(bool value) {
    if (_screenOpen == value) return;
    _screenOpen = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _persist() {
    final reciter = _reciter;
    final chapter = _chapter;
    if (reciter == null || chapter == null) return;
    _prefs.setString(_reciterKey, reciter.key);
    _prefs.setString(_reciterJsonKey, jsonEncode(reciter.toJson()));
    _prefs.setInt(_chapterKey, chapter);
  }

  double _readSpeed() {
    final saved = _prefs.getDouble(_speedKey) ?? 1;
    return saved.clamp(0.5, 2.0).toDouble();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

final quranPlayerProvider = Provider<QuranPlayerController>((ref) {
  final controller = QuranPlayerController(
    prefs: ref.watch(prefsProvider),
    downloads: ref.watch(quranPlayerDownloadsProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
