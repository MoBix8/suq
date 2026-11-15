import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One running download, either a single surah or a whole reciter.
class QuranPlayerDownloadJob {
  QuranPlayerDownloadJob({required this.reciterKey, required this.chapters});

  final String reciterKey;
  final List<int> chapters;

  int doneChapters = 0;
  int fileDone = 0;
  int fileTotal = 0;
  bool cancelled = false;

  /// Surah currently being written.
  int get chapter {
    if (chapters.isEmpty) return 1;
    final index = doneChapters.clamp(0, chapters.length - 1).toInt();
    return chapters[index];
  }

  /// 0–1 across the whole job.
  double get progress {
    if (chapters.isEmpty) return 1;
    final within = fileTotal <= 0
        ? 0.0
        : (fileDone / fileTotal).clamp(0.0, 1.0).toDouble();
    return ((doneChapters + within) / chapters.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

/// Downloads surah MP3s from mp3quran.net and keeps them on the device.
///
/// Files are written to a `.part` file first, so an interrupted download
/// continues from the last byte with an HTTP `Range` request. A finished
/// surah is renamed to `<chapter>.mp3`, which is what the player looks for.
class QuranPlayerDownloads extends ChangeNotifier {
  QuranPlayerDownloads({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: true,
              ),
            );

  final Dio _dio;
  Directory? _root;

  final Map<String, Set<int>> _downloaded = {};
  final Map<String, Set<int>> _partials = {};
  final Map<String, int> _bytes = {};

  QuranPlayerDownloadJob? _job;
  String? _error;
  bool _warmed = false;
  bool _warming = false;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  QuranPlayerDownloadJob? get job => _job;
  bool get isDownloading => _job != null;
  String? get error => _error;
  bool get isWarm => _warmed;

  Set<int> downloaded(String reciterKey) =>
      _downloaded[reciterKey] ?? const <int>{};

  bool isDownloaded(String reciterKey, int chapter) =>
      downloaded(reciterKey).contains(chapter);

  bool hasPartial(String reciterKey, int chapter) =>
      (_partials[reciterKey] ?? const <int>{}).contains(chapter);

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _dirName(String reciterKey) => reciterKey.replaceAll(':', '_');

  String _keyFromDir(String dirName) => dirName.replaceAll('_', ':');

  Future<Directory> _rootDirectory() async {
    final cached = _root;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'quran', 'player'));
    if (!await directory.exists()) await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<Directory> _reciterDirectory(String reciterKey) async {
    final root = await _rootDirectory();
    return Directory(p.join(root.path, _dirName(reciterKey)));
  }

  Future<File> audioFile(String reciterKey, int chapter) async {
    final directory = await _reciterDirectory(reciterKey);
    return File(p.join(directory.path, '$chapter.mp3'));
  }

  /// Scans the download folder once so the library can show offline badges
  /// without waiting on a network call.
  Future<void> warmUp() async {
    if (_warmed || _warming) return;
    _warming = true;
    try {
      final root = await _rootDirectory();
      if (await root.exists()) {
        await for (final entity in root.list(followLinks: false)) {
          if (entity is! Directory) continue;
          final key = _keyFromDir(p.basename(entity.path));
          final complete = <int>{};
          final partial = <int>{};
          await for (final file in entity.list(followLinks: false)) {
            if (file is! File) continue;
            final name = p.basename(file.path);
            if (name.endsWith('.mp3.part')) {
              final number = int.tryParse(
                name.substring(0, name.length - '.mp3.part'.length),
              );
              if (number != null) partial.add(number);
            } else if (name.endsWith('.mp3')) {
              final number = int.tryParse(
                name.substring(0, name.length - '.mp3'.length),
              );
              if (number != null && await file.length() > 0) {
                complete.add(number);
              }
            }
          }
          if (complete.isNotEmpty) _downloaded[key] = complete;
          if (partial.isNotEmpty) _partials[key] = partial;
        }
      }
    } finally {
      _warming = false;
      _warmed = true;
      notifyListeners();
    }
  }

  /// Starts downloading [chapters] that are not on the device yet.
  ///
  /// Returns false when another job is running or nothing is left to fetch.
  bool start({
    required String reciterKey,
    required List<int> chapters,
    required String? Function(int chapter) urlFor,
  }) {
    if (_job != null) return false;

    final targets = <int>[];
    for (final chapter in chapters) {
      if (urlFor(chapter) == null) continue;
      if (isDownloaded(reciterKey, chapter)) continue;
      targets.add(chapter);
    }
    if (targets.isEmpty) return false;

    final job = QuranPlayerDownloadJob(
      reciterKey: reciterKey,
      chapters: targets,
    );
    _job = job;
    _error = null;
    notifyListeners();
    unawaited(_run(job, urlFor));
    return true;
  }

  void cancel() {
    final job = _job;
    if (job == null) return;
    job.cancelled = true;
    notifyListeners();
  }

  Future<void> _run(
    QuranPlayerDownloadJob job,
    String? Function(int chapter) urlFor,
  ) async {
    try {
      for (var index = 0; index < job.chapters.length; index++) {
        if (job.cancelled) break;
        job.doneChapters = index;
        final chapter = job.chapters[index];
        final url = urlFor(chapter);
        if (url == null) continue;

        final target = await audioFile(job.reciterKey, chapter);
        await target.parent.create(recursive: true);
        job.fileDone = 0;
        job.fileTotal = 0;
        notifyListeners();

        await _download(url, target, job);
        if (job.cancelled) break;

        _downloaded.putIfAbsent(job.reciterKey, () => <int>{}).add(chapter);
        _partials[job.reciterKey]?.remove(chapter);
        _bytes.remove(job.reciterKey);
        job.doneChapters = index + 1;
        notifyListeners();
      }
    } catch (error) {
      if (job.fileDone > 0) {
        _partials.putIfAbsent(job.reciterKey, () => <int>{}).add(job.chapter);
      }
      _error = 'The download stopped. Check your connection and try again.';
      if (kDebugMode) debugPrint('Qur’an player download failed: $error');
    } finally {
      _job = null;
      notifyListeners();
    }
  }

  Future<void> _download(
    String url,
    File target,
    QuranPlayerDownloadJob job,
  ) async {
    final part = File('${target.path}.part');
    var existing = await part.exists() ? await part.length() : 0;

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
        validateStatus: (status) =>
            status != null && (status < 400 || status == 416),
      ),
    );

    if (response.statusCode == 416) {
      if (existing <= 0) throw StateError('The saved download is unusable.');
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      _partials[job.reciterKey]?.remove(job.chapter);
      return;
    }

    final body = response.data;
    if (body == null) throw StateError('The server returned no audio.');

    if (existing > 0 && response.statusCode != 206) {
      existing = 0;
      if (await part.exists()) await part.delete();
    }

    final lengthHeader = response.headers.value(Headers.contentLengthHeader);
    final remaining = lengthHeader == null ? 0 : int.tryParse(lengthHeader) ?? 0;
    final total = existing + remaining;

    final sink = part.openWrite(
      mode: existing > 0 ? FileMode.append : FileMode.write,
    );
    var received = existing;
    try {
      await for (final chunk in body.stream) {
        if (job.cancelled) break;
        sink.add(chunk);
        received += chunk.length;
        job.fileDone = received;
        job.fileTotal = total;
        _tick();
      }
    } catch (_) {
      _partials.putIfAbsent(job.reciterKey, () => <int>{}).add(job.chapter);
      rethrow;
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (job.cancelled) {
      _partials.putIfAbsent(job.reciterKey, () => <int>{}).add(job.chapter);
      notifyListeners();
      return;
    }
    if (received == 0) {
      throw StateError('The server returned an empty file.');
    }
    if (total > 0 && received < total) {
      _partials.putIfAbsent(job.reciterKey, () => <int>{}).add(job.chapter);
      throw StateError('The audio download stopped early.');
    }
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    _partials[job.reciterKey]?.remove(job.chapter);
  }

  void _tick() {
    final now = DateTime.now();
    if (now.difference(_lastTick) < const Duration(milliseconds: 150)) return;
    _lastTick = now;
    notifyListeners();
  }

  Future<void> removeChapter(String reciterKey, int chapter) async {
    final file = await audioFile(reciterKey, chapter);
    final part = File('${file.path}.part');
    if (await file.exists()) await file.delete();
    if (await part.exists()) await part.delete();
    _downloaded[reciterKey]?.remove(chapter);
    _partials[reciterKey]?.remove(chapter);
    _bytes.remove(reciterKey);
    notifyListeners();
  }

  Future<void> removeReciter(String reciterKey) async {
    final directory = await _reciterDirectory(reciterKey);
    if (await directory.exists()) await directory.delete(recursive: true);
    _downloaded.remove(reciterKey);
    _partials.remove(reciterKey);
    _bytes.remove(reciterKey);
    notifyListeners();
  }

  Future<int> bytesForReciter(String reciterKey) async {
    final cached = _bytes[reciterKey];
    if (cached != null) return cached;
    final directory = await _reciterDirectory(reciterKey);
    var total = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
    }
    _bytes[reciterKey] = total;
    return total;
  }

  @override
  void dispose() {
    _job?.cancelled = true;
    _dio.close(force: true);
    super.dispose();
  }
}

final quranPlayerDownloadsProvider = Provider<QuranPlayerDownloads>((ref) {
  final store = QuranPlayerDownloads();
  ref.onDispose(store.dispose);
  return store;
});
