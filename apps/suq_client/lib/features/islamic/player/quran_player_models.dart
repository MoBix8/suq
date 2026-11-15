import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers.dart';

/// Where a reciter's audio files come from.
enum QuranPlayerSource { mp3quran }

/// One downloadable recitation: a reciter with one of their rewayas.
class QuranPlayerReciter {
  const QuranPlayerReciter({
    required this.key,
    required this.name,
    required this.arabicName,
    required this.style,
    required this.server,
    required this.chapters,
    this.letter = '',
    this.photoUrl,
    this.bio,
    this.source = QuranPlayerSource.mp3quran,
  });

  final String key;
  final String name;
  final String arabicName;
  final String style;

  /// Base URL that holds `001.mp3` … `114.mp3`.
  final String server;

  /// Surah numbers this recording actually covers.
  final List<int> chapters;
  final String letter;
  final String? photoUrl;

  /// A short biography when the image source also publishes one.
  final String? bio;
  final QuranPlayerSource source;

  String get initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  String get firstLetter {
    final value = letter.trim();
    if (value.isNotEmpty) return value.toUpperCase();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '#';
    return trimmed[0].toUpperCase();
  }

  bool hasChapter(int chapter) => chapters.contains(chapter);

  String? urlFor(int chapter) {
    if (!chapters.contains(chapter)) return null;
    final base = server.endsWith('/') ? server : '$server/';
    return '$base${chapter.toString().padLeft(3, '0')}.mp3';
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'arabicName': arabicName,
        'style': style,
        'server': server,
        'chapters': chapters,
        'letter': letter,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (bio != null) 'bio': bio,
      };

  static QuranPlayerReciter? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final name = raw['name'];
    final server = raw['server'];
    if (key is! String || name is! String || server is! String) return null;
    final chapters = <int>[];
    final rawChapters = raw['chapters'];
    if (rawChapters is List) {
      for (final item in rawChapters) {
        if (item is num) chapters.add(item.toInt());
      }
    }
    if (chapters.isEmpty) return null;
    return QuranPlayerReciter(
      key: key,
      name: name,
      arabicName: raw['arabicName'] as String? ?? '',
      style: raw['style'] as String? ?? 'Murattal',
      server: server,
      chapters: chapters,
      letter: raw['letter'] as String? ?? '',
      photoUrl: raw['photoUrl'] as String?,
      bio: raw['bio'] as String?,
    );
  }
}

/// Loads the reciter catalogue from mp3quran.net and keeps it on the device.
///
/// The catalogue is fetched once, saved to preferences and reused offline.
/// It holds one entry per reciter/rewaya pair, so reciters that recite in more
/// than one style appear more than once.
class QuranPlayerCatalog {
  QuranPlayerCatalog({Dio? dio, SharedPreferences? prefs})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 40),
                followRedirects: true,
                headers: const {'Accept': 'application/json'},
              ),
            ),
        _prefs = prefs;

  static const _cacheKey = 'quran.player.catalog.v2';
  static const _stampKey = 'quran.player.catalog.savedAt';
  static const _maxAge = Duration(days: 7);

  final Dio _dio;
  final SharedPreferences? _prefs;

  List<QuranPlayerReciter>? _memory;

  Future<List<QuranPlayerReciter>> load({bool refresh = false}) async {
    final memory = _memory;
    if (!refresh && memory != null) return memory;

    final cached = _readCache();
    if (!refresh && cached.isNotEmpty) {
      _memory = cached;
      if (_isStale()) unawaited(_refreshQuietly());
      return cached;
    }

    try {
      final fetched = await _fetch();
      if (fetched.isNotEmpty) {
        _memory = fetched;
        await _writeCache(fetched);
        return fetched;
      }
    } catch (error) {
      debugPrint('Qur’an player catalogue failed: $error');
    }

    if (cached.isNotEmpty) {
      _memory = cached;
      return cached;
    }
    return const [];
  }

  Future<void> _refreshQuietly() async {
    try {
      final fetched = await _fetch();
      if (fetched.isEmpty) return;
      _memory = fetched;
      await _writeCache(fetched);
    } catch (_) {
      // A background refresh must never disturb the library.
    }
  }

  Future<List<QuranPlayerReciter>> _fetch() async {
    final arabicFuture = _getReciters('ar').catchError(
      (Object _) => <dynamic>[],
    );
    final profilesFuture = _reciterProfiles();
    final english = await _getReciters('eng');
    final arabic = await arabicFuture;
    final profiles = await profilesFuture;

    final arabicNames = <int, String>{};
    for (final raw in arabic) {
      if (raw is! Map) continue;
      final id = (raw['id'] as num?)?.toInt();
      final name = raw['name'];
      if (id != null && name is String && name.trim().isNotEmpty) {
        arabicNames[id] = name.trim();
      }
    }

    final result = <QuranPlayerReciter>[];
    final seen = <String>{};
    for (final raw in english) {
      if (raw is! Map) continue;
      for (final reciter in _recitersFromJson(raw, arabicNames, profiles)) {
        if (seen.add(reciter.key)) result.add(reciter);
      }
    }
    result.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.style.toLowerCase().compareTo(b.style.toLowerCase());
    });
    return result;
  }

  /// Portrait and biography data for reciters that also appear on
  /// QuranHub. mp3quran.net publishes no artist photos, so this is an
  /// optional enrichment: when it fails the catalogue still loads and the
  /// library falls back to monograms.
  Future<_ReciterProfiles> _reciterProfiles() async {
    try {
      final response = await _dio.get<dynamic>(
        'https://api.quranhub.com/v1/edition/audio/distinct',
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final data = response.data;
      if (data is! List) return const _ReciterProfiles.empty();

      final byArabic = <String, _ReciterProfile>{};
      final byEnglish = <String, _ReciterProfile>{};
      for (final raw in data) {
        if (raw is! Map) continue;
        final image = raw['imageUrl'];
        final photo = image is String && image.trim().isNotEmpty
            ? image.trim()
            : null;
        final description = raw['shortDescription'];
        String? bio;
        if (description is Map) {
          final englishBio = description['en'];
          final arabicBio = description['ar'];
          if (englishBio is String && englishBio.trim().isNotEmpty) {
            bio = englishBio.trim();
          } else if (arabicBio is String && arabicBio.trim().isNotEmpty) {
            bio = arabicBio.trim();
          }
        }
        if (photo == null && bio == null) continue;

        final profile = _ReciterProfile(photoUrl: photo, bio: bio);
        final arabicName = raw['name'];
        if (arabicName is String) {
          final key = _normalizeArabic(arabicName);
          if (key.isNotEmpty) byArabic.putIfAbsent(key, () => profile);
        }
        final englishName = raw['englishName'];
        if (englishName is String) {
          final key = _normalizeEnglish(englishName);
          if (key.isNotEmpty) byEnglish.putIfAbsent(key, () => profile);
        }
      }
      return _ReciterProfiles(byArabic: byArabic, byEnglish: byEnglish);
    } catch (error) {
      debugPrint('Qur’an reciter portraits failed: $error');
      return const _ReciterProfiles.empty();
    }
  }

  Future<List<dynamic>> _getReciters(String language) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://www.mp3quran.net/api/v3/reciters',
      queryParameters: {'language': language},
    );
    final list = response.data?['reciters'];
    if (list is! List) return const [];
    return list;
  }

  List<QuranPlayerReciter> _recitersFromJson(
    Map raw,
    Map<int, String> arabicNames,
    _ReciterProfiles profiles,
  ) {
    final id = (raw['id'] as num?)?.toInt();
    final name = raw['name'];
    final moshafs = raw['moshaf'];
    if (id == null || name is! String || name.trim().isEmpty) return const [];
    if (moshafs is! List) return const [];

    final letter = raw['letter'] is String ? raw['letter'] as String : '';
    final photo = raw['photo'] ?? raw['image'];
    final photoUrl = photo is String && photo.trim().isNotEmpty
        ? photo.trim()
        : null;
    final arabicName = arabicNames[id] ?? '';
    final profile = profiles.match(
      arabicName: arabicName,
      englishName: name.trim(),
    );
    final result = <QuranPlayerReciter>[];

    for (final item in moshafs) {
      if (item is! Map) continue;
      final moshafId = (item['id'] as num?)?.toInt();
      final server = item['server'];
      final list = item['surah_list'];
      if (moshafId == null || server is! String || server.trim().isEmpty) {
        continue;
      }
      if (list is! String && list is! List) continue;

      final chapters = <int>[];
      if (list is String) {
        for (final part in list.split(',')) {
          final number = int.tryParse(part.trim());
          if (number != null && number >= 1 && number <= 114) {
            chapters.add(number);
          }
        }
      } else {
        for (final part in list as List) {
          final number = part is num
              ? part.toInt()
              : (part is String ? int.tryParse(part.trim()) : null);
          if (number != null && number >= 1 && number <= 114) {
            chapters.add(number);
          }
        }
      }
      if (chapters.isEmpty) continue;
      chapters.sort();

      final style =
          item['name'] is String ? (item['name'] as String).trim() : '';
      result.add(
        QuranPlayerReciter(
          key: 'mp3quran:$id:$moshafId',
          name: name.trim(),
          arabicName: arabicName,
          style: style.isEmpty ? 'Murattal' : style,
          server: server.trim(),
          chapters: chapters,
          letter: letter,
          photoUrl: photoUrl ?? profile?.photoUrl,
          bio: profile?.bio,
        ),
      );
    }
    return result;
  }

  List<QuranPlayerReciter> _readCache() {
    final prefs = _prefs;
    if (prefs == null) return const [];
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <QuranPlayerReciter>[];
      for (final item in decoded) {
        final reciter = QuranPlayerReciter.fromJson(item);
        if (reciter != null) result.add(reciter);
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<QuranPlayerReciter> reciters) async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await prefs.setString(
        _cacheKey,
        jsonEncode([for (final reciter in reciters) reciter.toJson()]),
      );
      await prefs.setInt(
        _stampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('Qur’an player catalogue could not be saved: $error');
    }
  }

  bool _isStale() {
    final savedAt = _prefs?.getInt(_stampKey);
    if (savedAt == null) return true;
    final saved = DateTime.fromMillisecondsSinceEpoch(savedAt);
    return DateTime.now().difference(saved) > _maxAge;
  }

  void dispose() => _dio.close(force: true);
}

class _ReciterProfile {
  const _ReciterProfile({this.photoUrl, this.bio});

  final String? photoUrl;
  final String? bio;
}

class _ReciterProfiles {
  const _ReciterProfiles({
    required this.byArabic,
    required this.byEnglish,
  });

  const _ReciterProfiles.empty()
      : byArabic = const {},
        byEnglish = const {};

  final Map<String, _ReciterProfile> byArabic;
  final Map<String, _ReciterProfile> byEnglish;

  _ReciterProfile? match({
    required String arabicName,
    required String englishName,
  }) {
    final arabicKey = _normalizeArabic(arabicName);
    if (arabicKey.isNotEmpty) {
      final profile = byArabic[arabicKey];
      if (profile != null) return profile;
    }
    final englishKey = _normalizeEnglish(englishName);
    if (englishKey.isEmpty) return null;
    return byEnglish[englishKey];
  }
}

/// Strips diacritics and spelling differences so the Arabic names published by
/// mp3quran.net and QuranHub can be compared. Spaces and punctuation are
/// removed as well, which also folds "عبد الرحمن" into "عبدالرحمن".
String _normalizeArabic(String value) {
  var text = value.trim();
  if (text.isEmpty) return '';
  text = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '');
  text = text.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
  text = text.replaceAll('ى', 'ي');
  text = text.replaceAll('ؤ', 'و');
  text = text.replaceAll('ئ', 'ي');
  text = text.replaceAll('ة', 'ه');
  text = text.replaceAll(RegExp(r'[^\u0621-\u064A0-9]'), '');
  return text;
}

String _normalizeEnglish(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// A reciter portrait that fills the space it is given.
///
/// mp3quran.net publishes no photographs. When [QuranPlayerReciter.photoUrl]
/// is available the image is shown; otherwise a monogram is drawn from the
/// reciter's name and the palette above.
class QuranReciterPortrait extends StatelessWidget {
  const QuranReciterPortrait({
    super.key,
    required this.reciter,
    this.borderRadius = BorderRadius.zero,
  });

  final QuranPlayerReciter reciter;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final photo = reciter.photoUrl;

    return ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortest =
              constraints.hasBoundedWidth && constraints.hasBoundedHeight
                  ? constraints.biggest.shortestSide
                  : 56.0;
          final fallback = Container(
            color: const Color(0xFFE7ECE7),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: (shortest * 0.5).clamp(16.0, 48.0).toDouble(),
              color: Color(0xFF6B7A72),
            ),
          );

          if (photo == null) return fallback;
          return Image.network(
            photo,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback,
            errorBuilder: (context, error, stack) => fallback,
          );
        },
      ),
    );
  }
}

/// A square reciter portrait with rounded corners.
class QuranReciterAvatar extends StatelessWidget {
  const QuranReciterAvatar({
    super.key,
    required this.reciter,
    this.size = 52,
    this.radius,
  });

  final QuranPlayerReciter reciter;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: QuranReciterPortrait(
          reciter: reciter,
          borderRadius: BorderRadius.zero,
        ),
      ),
    );
  }
}

String formatQuranBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb < 1) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String formatQuranDuration(Duration duration) {
  final total = duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

final quranPlayerCatalogProvider = Provider<QuranPlayerCatalog>((ref) {
  final catalog = QuranPlayerCatalog(prefs: ref.watch(prefsProvider));
  ref.onDispose(catalog.dispose);
  return catalog;
});
