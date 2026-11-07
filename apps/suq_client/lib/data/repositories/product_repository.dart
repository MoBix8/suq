import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../models.dart';
import '../queue.dart';

class ProductRepository {
  ProductRepository(this._appDb);

  final AppDatabase _appDb;

  Database get _db => _appDb.db;

  Future<List<Product>> list({
    String query = '',
    bool lowStockOnly = false,
    int page = 1,
    int pageSize = 30,
  }) async {
    final clauses = <String>['deleted = 0'];
    final args = <Object?>[];
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      clauses.add("(name LIKE ? OR IFNULL(barcode, '') LIKE ?)");
      args.addAll(['%$trimmed%', '%$trimmed%']);
    }
    if (lowStockOnly) {
      clauses.add('track_stock = 1 AND stock_qty <= low_stock_threshold');
    }
    final rows = await _db.query(
      'products',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC',
      limit: pageSize,
      offset: (page - 1) * pageSize,
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> count({String query = '', bool lowStockOnly = false}) async {
    final clauses = <String>['deleted = 0'];
    final args = <Object?>[];
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      clauses.add("(name LIKE ? OR IFNULL(barcode, '') LIKE ?)");
      args.addAll(['%$trimmed%', '%$trimmed%']);
    }
    if (lowStockOnly) {
      clauses.add('track_stock = 1 AND stock_qty <= low_stock_threshold');
    }
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM products WHERE ${clauses.join(' AND ')}',
      args,
    );
    return asInt(rows.first['c']);
  }

  Future<Product?> byId(String id) async {
    final rows = await _db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Set<String>> libraryIds() async {
    final rows = await _db.query(
      'products',
      columns: ['library_item_id'],
      where: 'library_item_id IS NOT NULL AND deleted = 0',
    );
    return rows.map((row) => row['library_item_id'] as String).toSet();
  }

  Future<int> downloadLibrary(List<LibraryProduct> items) async {
    if (items.isEmpty) return 0;
    var inserted = 0;
    final now = DateTime.now();

    await _db.transaction((txn) async {
      for (final item in items) {
        final existing = await txn.query(
          'products',
          where: 'library_item_id = ?',
          whereArgs: [item.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          // A product that was removed from the shop can be downloaded again.
          final previous = Product.fromMap(existing.first);
          if (previous.deleted) {
            final restored = previous.copyWith(
              deleted: false,
              updatedAt: now,
            );
            await txn.update(
              'products',
              restored.toMap(),
              where: 'id = ?',
              whereArgs: [restored.id],
            );
            await enqueue(
              txn,
              entity: 'product',
              entityId: restored.id,
              op: 'upsert',
              payload: restored.toSyncJson(),
            );
            inserted += 1;
          }
          continue;
        }

        final product = Product(
          id: const Uuid().v4(),
          libraryItemId: item.id,
          name: item.name,
          nameAm: item.nameAm,
          nameOr: item.nameOr,
          barcode: item.barcode,
          unit: item.unit,
          sellingPrice: item.defaultSellingPrice,
          buyingPrice: item.defaultBuyingPrice,
          stockQty: 0,
          lowStockThreshold: 0,
          trackStock: false,
          custom: false,
          updatedAt: now,
        );
        await txn.insert('products', product.toMap());
        await enqueue(
          txn,
          entity: 'product',
          entityId: product.id,
          op: 'upsert',
          payload: product.toSyncJson(),
        );
        inserted += 1;
      }
    });

    return inserted;
  }

  Future<void> save(Product product) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await enqueue(
        txn,
        entity: 'product',
        entityId: product.id,
        op: 'upsert',
        payload: product.toSyncJson(),
      );
    });
  }

  Future<void> softDelete(String id) async {
    final product = await byId(id);
    if (product == null) return;
    final deleted = product.copyWith(deleted: true, updatedAt: DateTime.now());
    await _db.transaction((txn) async {
      await txn.update(
        'products',
        deleted.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await enqueue(
        txn,
        entity: 'product',
        entityId: id,
        op: 'upsert',
        payload: deleted.toSyncJson(),
      );
    });
  }

  Future<List<Product>> lowStock() async {
    final rows = await _db.query(
      'products',
      where: 'deleted = 0 AND track_stock = 1 AND stock_qty <= low_stock_threshold',
      orderBy: 'stock_qty ASC',
      limit: 20,
    );
    return rows.map(Product.fromMap).toList();
  }
}
