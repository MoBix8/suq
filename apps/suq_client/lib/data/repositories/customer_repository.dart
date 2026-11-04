import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../models.dart';
import '../queue.dart';

class CustomerRepository {
  CustomerRepository(this._appDb);

  final AppDatabase _appDb;

  Database get _db => _appDb.db;

  Future<List<Customer>> list({String query = ''}) async {
    final clauses = <String>['deleted = 0'];
    final args = <Object?>[];
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      clauses.add("(name LIKE ? OR IFNULL(phone, '') LIKE ?)");
      args.addAll(['%$trimmed%', '%$trimmed%']);
    }
    final rows = await _db.query(
      'customers',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<Customer?> byId(String id) async {
    final rows = await _db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Customer.fromMap(rows.first);
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM customers WHERE deleted = 0');
    return asInt(rows.first['c']);
  }

  Future<double> totalOutstanding() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(credit_balance), 0) AS total FROM customers WHERE deleted = 0',
    );
    return asDouble(rows.first['total']);
  }

  Future<void> save(Customer customer) async {
    await _db.transaction((txn) async {
      await txn.insert(
        'customers',
        customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await enqueue(
        txn,
        entity: 'customer',
        entityId: customer.id,
        op: 'upsert',
        payload: customer.toSyncJson(),
      );
    });
  }

  Future<Customer> create({required String name, String? phone}) async {
    final now = DateTime.now();
    final customer = Customer(
      id: const Uuid().v4(),
      name: name.trim(),
      phone: (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
      creditBalance: 0,
      createdAt: now,
      updatedAt: now,
    );
    await save(customer);
    return customer;
  }

  Future<void> softDelete(String id) async {
    final customer = await byId(id);
    if (customer == null) return;
    final deleted = customer.copyWith(deleted: true, updatedAt: DateTime.now());
    await _db.transaction((txn) async {
      await txn.update(
        'customers',
        deleted.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await enqueue(
        txn,
        entity: 'customer',
        entityId: id,
        op: 'upsert',
        payload: deleted.toSyncJson(),
      );
    });
  }

  Future<List<CreditEntry>> ledger(String customerId) async {
    final rows = await _db.query(
      'credit_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(CreditEntry.fromMap).toList();
  }

  Future<double> receivePayment({
    required String customerId,
    required double amount,
    String? note,
  }) async {
    if (amount <= 0) throw CheckoutException('Enter a valid payment amount.');

    late double newBalance;
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();

    await _db.transaction((txn) async {
      final rows = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (rows.isEmpty) throw CheckoutException('Customer not found.');
      final customer = Customer.fromMap(rows.first);
      if (amount > customer.creditBalance + 0.009) {
        throw CheckoutException('Payment is more than the outstanding balance.');
      }
      newBalance = math.max(0, customer.creditBalance - amount);
      final updated = customer.copyWith(
        creditBalance: newBalance,
        updatedAt: now,
      );
      await txn.update(
        'customers',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [customerId],
      );

      final entryId = const Uuid().v4();
      await txn.insert('credit_entries', {
        'id': entryId,
        'customer_id': customerId,
        'sale_id': null,
        'type': 'PAYMENT',
        'amount': -amount,
        'note': note,
        'created_at': nowUtc,
        'synced': 0,
      });

      await enqueue(
        txn,
        entity: 'customer',
        entityId: customerId,
        op: 'upsert',
        payload: updated.toSyncJson(),
      );
      await enqueue(
        txn,
        entity: 'credit_entry',
        entityId: entryId,
        op: 'upsert',
        payload: {
          'id': entryId,
          'customerId': customerId,
          'saleId': null,
          'type': 'PAYMENT',
          'amount': -amount,
          'note': note,
          'createdAt': nowUtc,
        },
      );
    });

    return newBalance;
  }
}
