import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_meta.dart';

/// Device-local page bookmarks for the Qur'an reader.
///
/// Bookmarks are pages of the Madinah mushaf, stored in `SharedPreferences` so
/// they belong to the shop's device and need no account or connection.
class QuranBookmarks extends ChangeNotifier {
  QuranBookmarks(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  List<int> _pages = const [];

  /// Bookmarked pages, in ascending order.
  List<int> get pages => List.unmodifiable(_pages);

  bool contains(int page) => _pages.contains(page);

  void _load() {
    final raw = _prefs.getStringList(quranBookmarksKey) ?? const [];
    final pages = <int>[];
    for (final value in raw) {
      final page = int.tryParse(value);
      if (page == null || page < 1 || page > quranPageCount) continue;
      if (!pages.contains(page)) pages.add(page);
    }
    pages.sort();
    _pages = pages;
  }

  Future<void> toggle(int page) async {
    if (page < 1 || page > quranPageCount) return;
    final next = [..._pages];
    if (next.contains(page)) {
      next.remove(page);
    } else {
      next.add(page);
      next.sort();
    }
    _pages = next;
    notifyListeners();
    await _prefs.setStringList(
      quranBookmarksKey,
      [for (final value in next) '$value'],
    );
  }

  Future<void> remove(int page) async {
    if (!_pages.contains(page)) return;
    final next = [..._pages]..remove(page);
    _pages = next;
    notifyListeners();
    await _prefs.setStringList(
      quranBookmarksKey,
      [for (final value in next) '$value'],
    );
  }
}
