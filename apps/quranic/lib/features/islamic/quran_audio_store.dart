import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_audio_api.dart';
import 'quran_meta.dart';

/// A chapter recording that has been downloaded to this device.
class QuranLocalChapter {
  const QuranLocalChapter({
    required this.files,
    required this.urls,
    required this.timings,
  });

  /// Verse key to local MP3 path.
  final Map<String, String> files;

  /// Verse key to the original URL, used as a fallback if a file is missing.
  final Map<String, String> urls;
  final Map<String, QuranVerseTiming> timings;

  List<String> get verseKeys {
    final keys = files.keys.toList();
    keys.sort((a, b) => quranVerseNumber(a).compareTo(quranVerseNumber(b)));
    return keys;
  }
}

/// A running audio download, either one surah or a whole reciter.
class QuranDownloadJob {
  QuranDownloadJob({required this.reciter, required this.chapters});

  final int reciter;
  final List<int> chapters;

  int doneChapters = 0;
  int fileDone = 0;
  int fileTotal = 0;
  bool cancelled = false;

  /// The surah currently being downloaded.
  int get chapter {
    if (chapters.isEmpty) return 1;
    final index = doneChapters.clamp(0, chapters.length - 1).toInt();
    return chapters[index];
  }

  /// 0–1 across every chapter in the job.
  double get progress {
    if (chapters.isEmpty) return 1;
    final within = fileTotal == 0
        ? 0.0
        : (fileDone / fileTotal).clamp(0.0, 1.0).toDouble();
    return ((doneChapters + within) / chapters.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  bool get isSingleChapter => chapters.length == 1;
}

/// Downloads recitation audio so it can be played without a connection.
///
/// Each downloaded surah is one directory under the app support folder with
/// its MP3 files, the original URLs and the word timings. The reader checks
/// this store before touching the network, so a downloaded surah plays from
/// the device and everything else streams.
class QuranAudioStore extends ChangeNotifier {
  QuranAudioStore({Dio? dio})
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

  final Map<String, QuranLocalChapter> _chapters = {};
  final Map<String, int> _sizes = {};
  QuranDownloadJob? _job;
  String? _error;

  QuranDownloadJob? get job => _job;
  bool get isDownloading => _job != null;
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _chapterKey(int reciter, int chapter) => '$reciter:$chapter';

  Future<Directory> _rootDirectory() async {
    final cached = _root;
    if (cached != null) return cached;

    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'quran', 'audio'));
    if (!await directory.exists()) await directory.create(recursive: true);
    _root = directory;
    return directory;
  }

  Future<Directory> _chapterDirectory(int reciter, int chapter) async {
    final root = await _rootDirectory();
    return Directory(p.join(root.path, '$reciter', '$chapter'));
  }

  Future<File> _manifestFile(int reciter, int chapter) async {
    final directory = await _chapterDirectory(reciter, chapter);
    return File(p.join(directory.path, 'manifest.json'));
  }

  /// The downloaded recording for [chapter], or null when it is not on the
  /// device.
  Future<QuranLocalChapter?> localChapter(int reciter, int chapter) async {
    final key = _chapterKey(reciter, chapter);
    final cached = _chapters[key];
    if (cached != null) return cached;

    final manifest = await _manifestFile(reciter, chapter);
    if (!await manifest.exists()) return null;

    try {
      final decoded = jsonDecode(await manifest.readAsString());
      if (decoded is! Map) return null;

      final directory = await _chapterDirectory(reciter, chapter);
      final files = <String, String>{};
      final urls = <String, String>{};
      final timings = <String, QuranVerseTiming>{};

      final rawFiles = decoded['files'];
      if (rawFiles is Map) {
        for (final entry in rawFiles.entries) {
          final verseKey = entry.key;
          final name = entry.value;
          if (verseKey is! String || name is! String || name.isEmpty) continue;
          files[verseKey] = p.join(directory.path, name);
        }
      }
      final rawUrls = decoded['urls'];
      if (rawUrls is Map) {
        for (final entry in rawUrls.entries) {
          final verseKey = entry.key;
          final url = entry.value;
          if (verseKey is! String || url is! String || url.isEmpty) continue;
          urls[verseKey] = url;
        }
      }
      final rawTimings = decoded['timings'];
      if (rawTimings is Map) {
        for (final entry in rawTimings.entries) {
          final verseKey = entry.key;
          if (verseKey is! String) continue;
          final timing = QuranVerseTiming.fromJson(entry.value);
          if (timing != null) timings[verseKey] = timing;
        }
      }
      if (files.isEmpty) return null;

      final local = QuranLocalChapter(
        files: files,
        urls: urls,
        timings: timings,
      );
      _chapters[key] = local;
      return local;
    } catch (_) {
      // A corrupt manifest is treated as "not downloaded"; the reader streams
      // instead of failing.
      return null;
    }
  }

  Future<bool> hasChapter(int reciter, int chapter) async {
    return await localChapter(reciter, chapter) != null;
  }

  /// Surah numbers of [reciter] that are fully saved on this device.
  Future<Set<int>> downloadedChapters(int reciter) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root.path, '$reciter'));
    final result = <int>{};
    if (!await directory.exists()) return result;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      final chapter = int.tryParse(name);
      if (chapter == null) continue;
      final manifest = File(p.join(entity.path, 'manifest.json'));
      if (await manifest.exists()) result.add(chapter);
    }
    return result;
  }

  /// How many surahs of [reciter] are saved on this device.
  Future<int> downloadedChapterCount(int reciter) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root.path, '$reciter'));
    if (!await directory.exists()) return 0;

    var count = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final manifest = File(p.join(entity.path, 'manifest.json'));
      if (await manifest.exists()) count++;
    }
    return count;
  }

  /// Bytes used by one downloaded surah.
  Future<int> chapterBytes(int reciter, int chapter) async {
    final key = _chapterKey(reciter, chapter);
    final cached = _sizes[key];
    if (cached != null) return cached;

    final directory = await _chapterDirectory(reciter, chapter);
    var total = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
    }
    _sizes[key] = total;
    return total;
  }

  /// Bytes used by every downloaded surah of [reciter].
  Future<int> reciterBytes(int reciter) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root.path, '$reciter'));
    var total = 0;
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  /// Starts downloading [chapter], or every surah when [chapter] is null.
  void startDownload({required int reciter, int? chapter}) {
    if (_job != null) return;

    final chapters = chapter == null
        ? [for (var number = 1; number <= quranChapters.length; number++) number]
        : [chapter];
    _job = QuranDownloadJob(reciter: reciter, chapters: chapters);
    _error = null;
    notifyListeners();
    unawaited(_run(_job!));
  }

  void cancelDownload() {
    final job = _job;
    if (job == null) return;
    job.cancelled = true;
    notifyListeners();
  }

  Future<void> _run(QuranDownloadJob job) async {
    try {
      for (var index = 0; index < job.chapters.length; index++) {
        if (job.cancelled) break;
        job.doneChapters = index;
        final chapter = job.chapters[index];

        if (await hasChapter(job.reciter, chapter)) {
          job.doneChapters = index + 1;
          notifyListeners();
          continue;
        }

        final audio = await fetchQuranChapterAudio(
          _dio,
          job.reciter,
          chapter,
        );
        if (job.cancelled) break;

        final keys = audio.verseKeys;
        if (keys.isEmpty) {
          job.doneChapters = index + 1;
          notifyListeners();
          continue;
        }

        job.fileDone = 0;
        job.fileTotal = keys.length;
        notifyListeners();

        final directory = await _chapterDirectory(job.reciter, chapter);
        if (await directory.exists()) await directory.delete(recursive: true);
        await directory.create(recursive: true);

        final files = <String, String>{};
        final urls = <String, String>{};
        try {
          for (var fileIndex = 0; fileIndex < keys.length; fileIndex++) {
            if (job.cancelled) break;
            final verseKey = keys[fileIndex];
            final url = audio.urls[verseKey];
            if (url == null) continue;

            final name = '${verseKey.replaceAll(':', '_')}.mp3';
            final file = File(p.join(directory.path, name));
            await _dio.download(url, file.path, deleteOnError: true);
            files[verseKey] = name;
            urls[verseKey] = url;
            job.fileDone = fileIndex + 1;
            notifyListeners();
          }
        } catch (_) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {
            // Best-effort cleanup; the download is already failing.
          }
          rethrow;
        }

        if (job.cancelled) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {
            // Best-effort cleanup; the download is already failing.
          }
          break;
        }
        if (files.isEmpty) {
          try {
            await directory.delete(recursive: true);
          } catch (_) {
            // Best-effort cleanup; the download is already failing.
          }
          continue;
        }

        final manifest = <String, dynamic>{
          'v': 1,
          'reciter': job.reciter,
          'chapter': chapter,
          'files': files,
          'urls': urls,
          'timings': {
            for (final entry in audio.timings.entries)
              entry.key: entry.value.toJson(),
          },
        };
        final manifestFile = File(p.join(directory.path, 'manifest.json'));
        final temp = File('${manifestFile.path}.part');
        await temp.writeAsString(jsonEncode(manifest), flush: true);
        if (await manifestFile.exists()) await manifestFile.delete();
        await temp.rename(manifestFile.path);

        _chapters.remove(_chapterKey(job.reciter, chapter));
        _sizes.remove(_chapterKey(job.reciter, chapter));
        job.doneChapters = index + 1;
        notifyListeners();
      }
    } catch (error) {
      _error = 'The download stopped. Check your connection and try again.';
      if (kDebugMode) debugPrint('Quran audio download failed: $error');
    } finally {
      final cancelled = job.cancelled;
      _job = null;
      notifyListeners();
      if (cancelled) {
        _error = null;
        notifyListeners();
      }
    }
  }

  /// Deletes one downloaded surah.
  Future<void> removeChapter(int reciter, int chapter) async {
    final key = _chapterKey(reciter, chapter);
    final directory = await _chapterDirectory(reciter, chapter);
    if (await directory.exists()) await directory.delete(recursive: true);
    _chapters.remove(key);
    _sizes.remove(key);
    notifyListeners();
  }

  /// Deletes every downloaded surah of [reciter].
  Future<void> removeReciter(int reciter) async {
    final root = await _rootDirectory();
    final directory = Directory(p.join(root.path, '$reciter'));
    if (await directory.exists()) await directory.delete(recursive: true);
    _chapters.removeWhere((key, _) => key.startsWith('$reciter:'));
    _sizes.removeWhere((key, _) => key.startsWith('$reciter:'));
    notifyListeners();
  }

  @override
  void dispose() {
    _job?.cancelled = true;
    _dio.close(force: true);
    super.dispose();
  }
}

final quranAudioStoreProvider = Provider<QuranAudioStore>((ref) {
  final store = QuranAudioStore();
  ref.onDispose(store.dispose);
  return store;
});
