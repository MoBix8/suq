import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../models.dart';
import '../queue.dart';

class SalesRepository {
  SalesRepository(this._appDb);

  final AppDatabase _appDb;

  Database get _db => _appDb.db;

  Future<CheckoutResult> checkout({
    required CartTab cart,
    Customer? customer,
    String? walkInName,
    required double paidInput,
  }) async {
    if (cart.lines.isEmpty) throw CheckoutException('Cart is empty.');

    final subtotal = cart.subtotal;
    final discount = cart.discount.clamp(0.0, subtotal).toDouble();
    final total = math.max(0.0, subtotal - discount);
    final paid = paidInput.clamp(0.0, total).toDouble();
    final change = math.max(0.0, paidInput - total);
    final credit = total - paid;

    if (credit > 0.009 && customer == null) {
      throw CheckoutException('Choose a customer before giving credit.');
    }

    final cost = cart.cost;
    final profit = total - cost;
    final paymentMethod = credit <= 0.009
        ? 'CASH'
        : (paid <= 0.009 ? 'CREDIT' : 'PARTIAL');

    final saleId = const Uuid().v4();
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();
    late String receiptNo;

    await _db.transaction((txn) async {
      receiptNo = await _nextReceiptNo(txn, now);

      await txn.insert('sales', {
        'id': saleId,
        'receipt_no': receiptNo,
        'customer_id': customer?.id,
        'customer_name': customer?.name ?? walkInName,
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paid': paid,
        'credit': credit,
        'cost': cost,
        'profit': profit,
        'payment_method': paymentMethod,
        'sold_at': nowUtc,
        'created_at': nowUtc,
      });

      final itemPayloads = <Map<String, dynamic>>[];
      for (final line in cart.lines) {
        final itemId = const Uuid().v4();
        await txn.insert('sale_items', {
          'id': itemId,
          'sale_id': saleId,
          'product_id': line.productId,
          'name': line.name,
          'unit': line.unit,
          'qty': line.qty,
          'unit_price': line.unitPrice,
          'unit_cost': line.unitCost,
          'line_total': line.total,
        });
        itemPayloads.add({
          'id': itemId,
          'productId': line.productId,
          'name': line.name,
          'unit': line.unit,
          'qty': line.qty,
          'unitPrice': line.unitPrice,
          'unitCost': line.unitCost,
          'lineTotal': line.total,
        });

        if (line.trackStock) {
          await txn.rawUpdate(
            'UPDATE products SET stock_qty = stock_qty - ?, updated_at = ? WHERE id = ?',
            [line.qty, nowUtc, line.productId],
          );
        }
      }

      if (credit > 0.009 && customer != null) {
        final entryId = const Uuid().v4();
        await txn.rawUpdate(
          'UPDATE customers SET credit_balance = credit_balance + ?, updated_at = ? WHERE id = ?',
          [credit, nowUtc, customer.id],
        );
        await txn.insert('credit_entries', {
          'id': entryId,
          'customer_id': customer.id,
          'sale_id': saleId,
          'type': 'CREDIT',
          'amount': credit,
          'note': 'Credit sale $receiptNo',
          'created_at': nowUtc,
          'synced': 0,
        });

        final updatedCustomer = customer.copyWith(
          creditBalance: customer.creditBalance + credit,
          updatedAt: now,
        );
        await enqueue(
          txn,
          entity: 'customer',
          entityId: customer.id,
          op: 'upsert',
          payload: updatedCustomer.toSyncJson(),
        );
        await enqueue(
          txn,
          entity: 'credit_entry',
          entityId: entryId,
          op: 'upsert',
          payload: {
            'id': entryId,
            'customerId': customer.id,
            'saleId': saleId,
            'type': 'CREDIT',
            'amount': credit,
            'note': 'Credit sale $receiptNo',
            'createdAt': nowUtc,
          },
        );
      }

      await enqueue(
        txn,
        entity: 'sale',
        entityId: saleId,
        op: 'upsert',
        payload: {
          'id': saleId,
          'receiptNo': receiptNo,
          'customerId': customer?.id,
          'customerName': customer?.name ?? walkInName,
          'subtotal': subtotal,
          'discount': discount,
          'total': total,
          'paid': paid,
          'credit': credit,
          'cost': cost,
          'profit': profit,
          'paymentMethod': paymentMethod,
          'soldAt': nowUtc,
          'items': itemPayloads,
        },
      );
    });

    return CheckoutResult(
      saleId: saleId,
      receiptNo: receiptNo,
      total: total,
      paid: paid,
      change: change,
      credit: credit,
      customerName: customer?.name ?? walkInName,
    );
  }

  Future<String> _nextReceiptNo(DatabaseExecutor txn, DateTime now) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS c FROM sales WHERE sold_at >= ? AND sold_at < ?',
      [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()],
    );
    final sequence = asInt(rows.first['c']) + 1;
    return 'SUQ-${DateFormat('yyyyMMdd').format(now)}-${sequence.toString().padLeft(4, '0')}';
  }

  Future<DailySummary> summary(DateTime fromLocal, DateTime toLocal) async {
    final from = fromLocal.toUtc().toIso8601String();
    final to = toLocal.toUtc().toIso8601String();

    final rows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total), 0) AS revenue,
        COALESCE(SUM(cost), 0) AS cost,
        COALESCE(SUM(profit), 0) AS profit,
        COUNT(*) AS sales_count,
        COALESCE(SUM(credit), 0) AS credit_given,
        COALESCE(SUM(paid), 0) AS cash_collected
      FROM sales
      WHERE sold_at >= ? AND sold_at < ?
      ''',
      [from, to],
    );

    final missingRows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sold_at >= ? AND s.sold_at < ? AND si.unit_cost IS NULL
      ''',
      [from, to],
    );

    final row = rows.first;
    return DailySummary(
      revenue: asDouble(row['revenue']),
      cost: asDouble(row['cost']),
      profit: asDouble(row['profit']),
      salesCount: asInt(row['sales_count']),
      creditGiven: asDouble(row['credit_given']),
      cashCollected: asDouble(row['cash_collected']),
      missingCostItems: asInt(missingRows.first['c']),
    );
  }

  Future<DailySummary> todaySummary() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return summary(start, start.add(const Duration(days: 1)));
  }

  Future<List<DailyPoint>> dailySeries(int days) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final points = <DailyPoint>[];
    for (var index = days - 1; index >= 0; index -= 1) {
      final day = today.subtract(Duration(days: index));
      final data = await summary(day, day.add(const Duration(days: 1)));
      points.add(DailyPoint(
        day: day,
        revenue: data.revenue,
        profit: data.profit,
        count: data.salesCount,
      ));
    }
    return points;
  }

  Future<List<TopProduct>> topProducts(
    DateTime fromLocal,
    DateTime toLocal, {
    int limit = 5,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT si.name,
             SUM(si.qty) AS qty,
             SUM(si.line_total) AS revenue,
             SUM(si.line_total - (COALESCE(si.unit_cost, 0) * si.qty)) AS profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.sold_at >= ? AND s.sold_at < ?
      GROUP BY si.name
      ORDER BY revenue DESC
      LIMIT ?
      ''',
      [
        fromLocal.toUtc().toIso8601String(),
        toLocal.toUtc().toIso8601String(),
        limit,
      ],
    );
    return rows
        .map((row) => TopProduct(
              name: row['name'] as String? ?? '',
              qty: asDouble(row['qty']),
              revenue: asDouble(row['revenue']),
              profit: asDouble(row['profit']),
            ))
        .toList();
  }

  Future<List<SaleRecord>> recent({int limit = 20}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT s.*,
             (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS item_count
      FROM sales s
      ORDER BY s.sold_at DESC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(SaleRecord.fromMap).toList();
  }

  Future<List<SaleRecord>> salesForCustomer(String customerId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT s.*,
             (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id) AS item_count
      FROM sales s
      WHERE s.customer_id = ?
      ORDER BY s.sold_at DESC
      ''',
      [customerId],
    );
    return rows.map(SaleRecord.fromMap).toList();
  }

  Future<List<SaleItemRecord>> itemsForSale(String saleId) async {
    final rows = await _db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return rows.map(SaleItemRecord.fromMap).toList();
  }
}
