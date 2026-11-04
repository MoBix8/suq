import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Adds a change to the outbox. The id is deterministic so repeated edits of the
/// same entity collapse into one queued row.
Future<void> enqueue(
  DatabaseExecutor db, {
  required String entity,
  required String entityId,
  required String op,
  required Map<String, dynamic> payload,
}) async {
  await db.insert(
    'sync_queue',
    {
      'id': '$entity:$entityId',
      'entity': entity,
      'entity_id': entityId,
      'op': op,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
