import 'package:sqflite/sqflite.dart';

import '../../core/api_client.dart';
import '../database.dart';
import '../models.dart';

class LibraryRepository {
  LibraryRepository(this._api, this._appDb);

  final ApiClient _api;
  final AppDatabase _appDb;

  Database get _db => _appDb.db;

  bool _isAuthError(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);

  Future<List<LibraryCategory>> categories() async {
    try {
      final response = await _api.get(
        '/library/categories',
        query: {'page': 1, 'pageSize': 200},
      );
      final list = response['categories'] as List<dynamic>? ?? [];
      final categories = list
          .whereType<Map>()
          .map((item) => LibraryCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      await _cacheCategories(categories);
      return categories;
    } catch (error) {
      if (_isAuthError(error)) rethrow;
      final cached = await _readCategories();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<LibraryProductPage> products({
    String? categoryId,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await _api.get(
        '/library/products',
        query: {
          'page': page,
          'pageSize': pageSize,
          if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
          if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        },
      );
      final list = response['products'] as List<dynamic>? ?? [];
      final items = list
          .whereType<Map>()
          .map((item) => LibraryProduct.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      await _cacheProducts(items);
      return LibraryProductPage(
        items: items,
        total: asInt(response['total']),
        page: asInt(response['page']) == 0 ? page : asInt(response['page']),
        pageSize:
            asInt(response['pageSize']) == 0 ? pageSize : asInt(response['pageSize']),
      );
    } catch (error) {
      if (_isAuthError(error)) rethrow;
      final cached = await _readProducts(
        categoryId: categoryId,
        search: search,
        page: page,
        pageSize: pageSize,
      );
      if (cached.total > 0 || await _hasCachedProducts()) return cached;
      rethrow;
    }
  }

  /// Fetches every page that matches the query. Used only when a shop explicitly
  /// chooses "Select all" in the library.
  Future<List<LibraryProduct>> allProducts({
    String? categoryId,
    String? search,
  }) async {
    const pageSize = 200;
    try {
      final all = <LibraryProduct>[];
      var page = 1;
      while (true) {
        final response = await _api.get(
          '/library/products',
          query: {
            'page': page,
            'pageSize': pageSize,
            if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
            if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
          },
        );
        final list = response['products'] as List<dynamic>? ?? [];
        final items = list
            .whereType<Map>()
            .map((item) => LibraryProduct.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        await _cacheProducts(items);
        all.addAll(items);

        final total = asInt(response['total']);
        if (items.isEmpty || all.length >= total) break;
        page += 1;
      }
      return all;
    } catch (error) {
      if (_isAuthError(error)) rethrow;
      final cached = await _readAllProducts(categoryId: categoryId, search: search);
      if (cached.isNotEmpty || await _hasCachedProducts()) return cached;
      rethrow;
    }
  }

  Future<void> _cacheCategories(List<LibraryCategory> categories) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    batch.delete('library_categories');
    for (final category in categories) {
      batch.insert(
        'library_categories',
        category.toMap(cachedAt: now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<LibraryCategory>> _readCategories() async {
    final rows = await _db.query(
      'library_categories',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(LibraryCategory.fromMap).toList();
  }

  Future<void> _cacheProducts(List<LibraryProduct> products) async {
    if (products.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();
    for (final product in products) {
      batch.insert(
        'library_products',
        product.toMap(cachedAt: now),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> _hasCachedProducts() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM library_products'),
    );
    return (count ?? 0) > 0;
  }

  Future<LibraryProductPage> _readProducts({
    String? categoryId,
    String? search,
    required int page,
    required int pageSize,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (categoryId != null && categoryId.isNotEmpty) {
      clauses.add('category_id = ?');
      args.add(categoryId);
    }
    final trimmed = search?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      clauses.add('(name LIKE ? OR sku LIKE ? OR IFNULL(barcode, \'\') LIKE ?)');
      final like = '%$trimmed%';
      args.addAll([like, like, like]);
    }
    final where = clauses.isEmpty ? null : clauses.join(' AND ');

    final countRows = await _db.rawQuery(
      'SELECT COUNT(*) AS total FROM library_products'
      '${where == null ? '' : ' WHERE $where'}',
      args,
    );
    final total = countRows.isEmpty ? 0 : asInt(countRows.first['total']);
    final rows = await _db.query(
      'library_products',
      where: where,
      whereArgs: args,
      orderBy: 'category_name COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
      limit: pageSize,
      offset: (page - 1) * pageSize,
    );
    return LibraryProductPage(
      items: rows.map(LibraryProduct.fromMap).toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<List<LibraryProduct>> _readAllProducts({
    String? categoryId,
    String? search,
  }) async {
    final page = await _readProducts(
      categoryId: categoryId,
      search: search,
      page: 1,
      pageSize: 100000,
    );
    return page.items;
  }
}
