import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Small key/value cache for server responses that shops need while offline.
class CacheRepository {
  CacheRepository(this._appDb);

  final AppDatabase _appDb;

  Future<Map<String, dynamic>?> read(String key) async {
    final rows = await _appDb.db.query(
      'api_cache',
      columns: ['payload'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['payload'] as String);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt cache entries are treated as a miss.
    }
    return null;
  }

  Future<void> write(String key, Map<String, dynamic> payload) async {
    await _appDb.db.insert(
      'api_cache',
      {
        'key': key,
        'payload': jsonEncode(payload),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
