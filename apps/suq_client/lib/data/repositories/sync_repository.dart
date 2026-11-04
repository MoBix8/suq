import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../database.dart';

class SyncRepository {
  SyncRepository(this._appDb, this._api, this._prefs);

  final AppDatabase _appDb;
  final ApiClient _api;
  final SharedPreferences _prefs;

  Database get _db => _appDb.db;

  Future<int> pendingCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<DateTime?> lastSyncedAt() async {
    final raw = _prefs.getString('sync.lastAt');
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Pushes the outbox. Throws [ApiException] if the server is unreachable;
  /// the queue is kept in that case.
  Future<int> flush() async {
    if (_api.token == null || _api.token!.isEmpty) return 0;

    final rows = await _db.query('sync_queue', orderBy: 'created_at ASC');
    if (rows.isEmpty) return 0;

    final customers = <String, Map<String, dynamic>>{};
    final products = <String, Map<String, dynamic>>{};
    final sales = <Map<String, dynamic>>[];
    final creditEntries = <Map<String, dynamic>>[];

    for (final row in rows) {
      final entity = row['entity'] as String? ?? '';
      final raw = row['payload'] as String? ?? '{}';
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final payload = Map<String, dynamic>.from(decoded);
      final id = payload['id'] as String? ?? '';
      switch (entity) {
        case 'customer':
          customers[id] = payload;
          break;
        case 'product':
          products[id] = payload;
          break;
        case 'sale':
          sales.add(payload);
          break;
        case 'credit_entry':
          creditEntries.add(payload);
          break;
      }
    }

    await _api.post('/sync', body: {
      'deviceId': _prefs.getString('device.id') ?? 'unknown-device',
      'appVersion': AppConfig.version,
      'customers': customers.values.toList(),
      'products': products.values.toList(),
      'sales': sales,
      'creditEntries': creditEntries,
    });

    await _db.delete('sync_queue');
    await _prefs.setString('sync.lastAt', DateTime.now().toUtc().toIso8601String());
    return rows.length;
  }
}
