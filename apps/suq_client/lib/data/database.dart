import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('AppDatabase.init() must be called before use');
    }
    return database;
  }

  Future<void> init() async {
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, 'suq_local.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute('''
          CREATE TABLE products (
            id TEXT PRIMARY KEY,
            library_item_id TEXT,
            name TEXT NOT NULL,
            barcode TEXT,
            unit TEXT NOT NULL DEFAULT 'pcs',
            selling_price REAL NOT NULL,
            buying_price REAL,
            stock_qty REAL NOT NULL DEFAULT 0,
            low_stock_threshold REAL NOT NULL DEFAULT 0,
            track_stock INTEGER NOT NULL DEFAULT 0,
            custom INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        batch.execute(
          'CREATE UNIQUE INDEX idx_products_library ON products(library_item_id) WHERE library_item_id IS NOT NULL',
        );
        batch.execute('CREATE INDEX idx_products_name ON products(name)');

        batch.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            credit_balance REAL NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        batch.execute('CREATE INDEX idx_customers_name ON customers(name)');

        batch.execute('''
          CREATE TABLE sales (
            id TEXT PRIMARY KEY,
            receipt_no TEXT NOT NULL,
            customer_id TEXT,
            customer_name TEXT,
            subtotal REAL NOT NULL,
            discount REAL NOT NULL DEFAULT 0,
            total REAL NOT NULL,
            paid REAL NOT NULL,
            credit REAL NOT NULL DEFAULT 0,
            cost REAL NOT NULL DEFAULT 0,
            profit REAL NOT NULL DEFAULT 0,
            payment_method TEXT NOT NULL,
            sold_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        batch.execute('CREATE INDEX idx_sales_sold_at ON sales(sold_at)');
        batch.execute('CREATE INDEX idx_sales_customer ON sales(customer_id)');

        batch.execute('''
          CREATE TABLE sale_items (
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            product_id TEXT,
            name TEXT NOT NULL,
            unit TEXT NOT NULL,
            qty REAL NOT NULL,
            unit_price REAL NOT NULL,
            unit_cost REAL,
            line_total REAL NOT NULL
          )
        ''');
        batch.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');

        batch.execute('''
          CREATE TABLE credit_entries (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            sale_id TEXT,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            note TEXT,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        batch.execute(
          'CREATE INDEX idx_credit_customer ON credit_entries(customer_id, created_at)',
        );

        batch.execute('''
          CREATE TABLE sync_queue (
            id TEXT PRIMARY KEY,
            entity TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            op TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await batch.commit(noResult: true);
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
