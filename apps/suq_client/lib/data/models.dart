import 'dart:math' as math;

double asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
bool asBool(Object? value) => value == 1 || value == true;
DateTime asDate(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
DateTime? asDateOrNull(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal();

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final String role;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'OWNER',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
      };
}

class ShopInfo {
  const ShopInfo({
    required this.id,
    required this.name,
    this.city,
    this.subcity,
    this.phone,
  });

  final String id;
  final String name;
  final String? city;
  final String? subcity;
  final String? phone;

  factory ShopInfo.fromJson(Map<String, dynamic> json) => ShopInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        city: json['city'] as String?,
        subcity: json['subcity'] as String?,
        phone: json['phone'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'subcity': subcity,
        'phone': phone,
      };
}

// ─── Local shop data ─────────────────────────────────────────────────────────

class Product {
  const Product({
    required this.id,
    this.libraryItemId,
    required this.name,
    this.barcode,
    this.unit = 'pcs',
    required this.sellingPrice,
    this.buyingPrice,
    this.stockQty = 0,
    this.lowStockThreshold = 0,
    this.trackStock = false,
    this.custom = false,
    this.deleted = false,
    required this.updatedAt,
  });

  final String id;
  final String? libraryItemId;
  final String name;
  final String? barcode;
  final String unit;
  final double sellingPrice;
  final double? buyingPrice;
  final double stockQty;
  final double lowStockThreshold;
  final bool trackStock;
  final bool custom;
  final bool deleted;
  final DateTime updatedAt;

  bool get hasCost => buyingPrice != null && buyingPrice! > 0;
  double get margin =>
      sellingPrice <= 0 ? 0 : ((sellingPrice - (buyingPrice ?? 0)) / sellingPrice) * 100;
  bool get isLowStock => trackStock && stockQty <= lowStockThreshold;

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as String? ?? '',
        libraryItemId: map['library_item_id'] as String?,
        name: map['name'] as String? ?? '',
        barcode: map['barcode'] as String?,
        unit: map['unit'] as String? ?? 'pcs',
        sellingPrice: asDouble(map['selling_price']),
        buyingPrice: map['buying_price'] == null ? null : asDouble(map['buying_price']),
        stockQty: asDouble(map['stock_qty']),
        lowStockThreshold: asDouble(map['low_stock_threshold']),
        trackStock: asBool(map['track_stock']),
        custom: asBool(map['custom']),
        deleted: asBool(map['deleted']),
        updatedAt: asDate(map['updated_at']),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'library_item_id': libraryItemId,
        'name': name,
        'barcode': barcode,
        'unit': unit,
        'selling_price': sellingPrice,
        'buying_price': buyingPrice,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'track_stock': trackStock ? 1 : 0,
        'custom': custom ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'libraryItemId': libraryItemId,
        'name': name,
        'barcode': barcode,
        'unit': unit,
        'sellingPrice': sellingPrice,
        'buyingPrice': buyingPrice,
        'stockQty': stockQty,
        'lowStockThreshold': lowStockThreshold,
        'custom': custom,
        'deleted': deleted,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Product copyWith({
    String? name,
    String? barcode,
    bool clearBarcode = false,
    String? unit,
    double? sellingPrice,
    double? buyingPrice,
    bool clearBuyingPrice = false,
    double? stockQty,
    double? lowStockThreshold,
    bool? trackStock,
    bool? deleted,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id,
        libraryItemId: libraryItemId,
        name: name ?? this.name,
        barcode: clearBarcode ? null : (barcode ?? this.barcode),
        unit: unit ?? this.unit,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        buyingPrice: clearBuyingPrice ? null : (buyingPrice ?? this.buyingPrice),
        stockQty: stockQty ?? this.stockQty,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        trackStock: trackStock ?? this.trackStock,
        custom: custom,
        deleted: deleted ?? this.deleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.creditBalance = 0,
    this.deleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final double creditBalance;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get owes => creditBalance > 0.009;

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String?,
        creditBalance: asDouble(map['credit_balance']),
        deleted: asBool(map['deleted']),
        createdAt: asDate(map['created_at']),
        updatedAt: asDate(map['updated_at']),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'credit_balance': creditBalance,
        'deleted': deleted ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toSyncJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'creditBalance': creditBalance,
        'deleted': deleted,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  Customer copyWith({
    String? name,
    String? phone,
    bool clearPhone = false,
    double? creditBalance,
    bool? deleted,
    DateTime? updatedAt,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: clearPhone ? null : (phone ?? this.phone),
        creditBalance: creditBalance ?? this.creditBalance,
        deleted: deleted ?? this.deleted,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.receiptNo,
    this.customerName,
    required this.total,
    required this.paid,
    required this.credit,
    required this.cost,
    required this.profit,
    required this.paymentMethod,
    required this.soldAt,
    this.itemCount = 0,
  });

  final String id;
  final String receiptNo;
  final String? customerName;
  final double total;
  final double paid;
  final double credit;
  final double cost;
  final double profit;
  final String paymentMethod;
  final DateTime soldAt;
  final int itemCount;

  factory SaleRecord.fromMap(Map<String, Object?> map) => SaleRecord(
        id: map['id'] as String? ?? '',
        receiptNo: map['receipt_no'] as String? ?? '',
        customerName: map['customer_name'] as String?,
        total: asDouble(map['total']),
        paid: asDouble(map['paid']),
        credit: asDouble(map['credit']),
        cost: asDouble(map['cost']),
        profit: asDouble(map['profit']),
        paymentMethod: map['payment_method'] as String? ?? 'CASH',
        soldAt: asDate(map['sold_at']),
        itemCount: asInt(map['item_count']),
      );
}

class SaleItemRecord {
  const SaleItemRecord({
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.unitCost,
    required this.lineTotal,
  });

  final String name;
  final String unit;
  final double qty;
  final double unitPrice;
  final double? unitCost;
  final double lineTotal;

  factory SaleItemRecord.fromMap(Map<String, Object?> map) => SaleItemRecord(
        name: map['name'] as String? ?? '',
        unit: map['unit'] as String? ?? 'pcs',
        qty: asDouble(map['qty']),
        unitPrice: asDouble(map['unit_price']),
        unitCost: map['unit_cost'] == null ? null : asDouble(map['unit_cost']),
        lineTotal: asDouble(map['line_total']),
      );
}

class DailySummary {
  const DailySummary({
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.salesCount = 0,
    this.creditGiven = 0,
    this.cashCollected = 0,
    this.missingCostItems = 0,
  });

  final double revenue;
  final double cost;
  final double profit;
  final int salesCount;
  final double creditGiven;
  final double cashCollected;
  final int missingCostItems;

  double get margin => revenue <= 0 ? 0 : (profit / revenue) * 100;
  bool get hasEstimatedProfit => missingCostItems > 0;
}

class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.revenue,
    required this.profit,
    required this.count,
  });

  final DateTime day;
  final double revenue;
  final double profit;
  final int count;
}

class TopProduct {
  const TopProduct({
    required this.name,
    required this.qty,
    required this.revenue,
    required this.profit,
  });

  final String name;
  final double qty;
  final double revenue;
  final double profit;
}

class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.customerId,
    this.saleId,
    required this.type,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String? saleId;
  final String type;
  final double amount;
  final String? note;
  final DateTime createdAt;

  bool get isDebt => amount > 0;

  factory CreditEntry.fromMap(Map<String, Object?> map) => CreditEntry(
        id: map['id'] as String? ?? '',
        customerId: map['customer_id'] as String? ?? '',
        saleId: map['sale_id'] as String?,
        type: map['type'] as String? ?? 'ADJUSTMENT',
        amount: asDouble(map['amount']),
        note: map['note'] as String?,
        createdAt: asDate(map['created_at']),
      );
}

class DashboardData {
  const DashboardData({
    required this.today,
    required this.last7,
    required this.topToday,
    required this.lowStock,
    required this.outstandingCredit,
    required this.recentSales,
    required this.productCount,
    required this.customerCount,
  });

  final DailySummary today;
  final List<DailyPoint> last7;
  final List<TopProduct> topToday;
  final List<Product> lowStock;
  final double outstandingCredit;
  final List<SaleRecord> recentSales;
  final int productCount;
  final int customerCount;
}

class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.summary,
    required this.daily,
    required this.top,
    required this.outstandingCredit,
    required this.lowStock,
    required this.customerCount,
  });

  final DateTime from;
  final DateTime to;
  final DailySummary summary;
  final List<DailyPoint> daily;
  final List<TopProduct> top;
  final double outstandingCredit;
  final List<Product> lowStock;
  final int customerCount;
}

class CustomerDetail {
  const CustomerDetail({
    required this.customer,
    required this.ledger,
    required this.sales,
  });

  final Customer customer;
  final List<CreditEntry> ledger;
  final List<SaleRecord> sales;
}

class CheckoutResult {
  const CheckoutResult({
    required this.saleId,
    required this.receiptNo,
    required this.total,
    required this.paid,
    required this.change,
    required this.credit,
    this.customerName,
  });

  final String saleId;
  final String receiptNo;
  final double total;
  final double paid;
  final double change;
  final double credit;
  final String? customerName;
}

class CheckoutException implements Exception {
  CheckoutException(this.message);
  final String message;
  @override
  String toString() => message;
}

// ─── Remote / billing models ─────────────────────────────────────────────────

class PackagePlan {
  const PackagePlan({
    required this.id,
    required this.name,
    required this.months,
    required this.priceEtb,
    this.description,
  });

  final String id;
  final String name;
  final int months;
  final double priceEtb;
  final String? description;

  factory PackagePlan.fromJson(Map<String, dynamic> json) => PackagePlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        months: asInt(json['months']),
        priceEtb: asDouble(json['priceEtb']),
        description: json['description'] as String?,
      );
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.branch,
    this.instructions,
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? branch;
  final String? instructions;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: json['id'] as String? ?? '',
        bankName: json['bankName'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        accountNumber: json['accountNumber'] as String? ?? '',
        branch: json['branch'] as String?,
        instructions: json['instructions'] as String?,
      );
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amountEtb,
    required this.transactionRef,
    required this.status,
    required this.submittedAt,
    this.packageName,
    this.adminNote,
  });

  final String id;
  final double amountEtb;
  final String transactionRef;
  final String status;
  final DateTime submittedAt;
  final String? packageName;
  final String? adminNote;

  bool get pending => status == 'PENDING';
  bool get approved => status == 'APPROVED';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final package = json['package'];
    return PaymentRecord(
      id: json['id'] as String? ?? '',
      amountEtb: asDouble(json['amountEtb']),
      transactionRef: json['transactionRef'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      submittedAt: asDate(json['submittedAt']),
      packageName: package is Map ? package['name'] as String? : null,
      adminNote: json['adminNote'] as String?,
    );
  }
}

class SubscriptionInfo {
  const SubscriptionInfo({
    required this.status,
    this.packageName,
    this.startsAt,
    this.endsAt,
    this.active = false,
    this.daysLeft = 0,
  });

  final String status;
  final String? packageName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool active;
  final int daysLeft;

  factory SubscriptionInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SubscriptionInfo(status: 'NONE');
    return SubscriptionInfo(
      status: json['status'] as String? ?? 'NONE',
      packageName: json['packageName'] as String?,
      startsAt: asDateOrNull(json['startsAt']),
      endsAt: asDateOrNull(json['endsAt']),
      active: json['active'] as bool? ?? false,
      daysLeft: asInt(json['daysLeft']),
    );
  }
}

class LibraryCategory {
  const LibraryCategory({
    required this.id,
    required this.name,
    required this.productCount,
  });

  final String id;
  final String name;
  final int productCount;

  factory LibraryCategory.fromJson(Map<String, dynamic> json) => LibraryCategory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        productCount: asInt(json['productCount']),
      );
}

class LibraryProduct {
  const LibraryProduct({
    required this.id,
    required this.sku,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    this.barcode,
    required this.unit,
    required this.defaultSellingPrice,
    this.defaultBuyingPrice,
    required this.version,
  });

  final String id;
  final String sku;
  final String categoryId;
  final String categoryName;
  final String name;
  final String? barcode;
  final String unit;
  final double defaultSellingPrice;
  final double? defaultBuyingPrice;
  final int version;

  factory LibraryProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return LibraryProduct(
      id: json['id'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      categoryName: category is Map ? category['name'] as String? ?? '' : '',
      name: json['name'] as String? ?? '',
      barcode: json['barcode'] as String?,
      unit: json['unit'] as String? ?? 'pcs',
      defaultSellingPrice: asDouble(json['defaultSellingPrice']),
      defaultBuyingPrice: json['defaultBuyingPrice'] == null
          ? null
          : asDouble(json['defaultBuyingPrice']),
      version: asInt(json['version']),
    );
  }
}

class EntitlementState {
  const EntitlementState({
    required this.active,
    this.needsOnline = false,
    this.clockTampered = false,
    this.packageName,
    this.startsAt,
    this.endsAt,
    this.leaseUntil,
    this.daysLeft = 0,
    this.offlineDaysLeft = 0,
    this.message,
  });

  const EntitlementState.locked({
    this.message,
    this.needsOnline = false,
    this.clockTampered = false,
    this.packageName,
    this.endsAt,
    this.leaseUntil,
  })  : active = false,
        startsAt = null,
        daysLeft = 0,
        offlineDaysLeft = 0;

  final bool active;
  final bool needsOnline;
  final bool clockTampered;
  final String? packageName;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? leaseUntil;
  final int daysLeft;
  final int offlineDaysLeft;
  final String? message;

  bool get leaseExpired => leaseUntil != null && leaseUntil!.isBefore(DateTime.now());
}

// ─── Multi-cart ──────────────────────────────────────────────────────────────

class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    this.unitCost,
    this.trackStock = false,
    this.qty = 1,
  });

  final String productId;
  final String name;
  final String unit;
  final double unitPrice;
  final double? unitCost;
  final bool trackStock;
  final double qty;

  double get total => qty * unitPrice;

  CartLine copyWith({double? qty}) => CartLine(
        productId: productId,
        name: name,
        unit: unit,
        unitPrice: unitPrice,
        unitCost: unitCost,
        trackStock: trackStock,
        qty: qty ?? this.qty,
      );

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'unit': unit,
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'trackStock': trackStock,
        'qty': qty,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        productId: json['productId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? 'pcs',
        unitPrice: asDouble(json['unitPrice']),
        unitCost: json['unitCost'] == null ? null : asDouble(json['unitCost']),
        trackStock: json['trackStock'] as bool? ?? false,
        qty: asDouble(json['qty']),
      );
}

class CartTab {
  const CartTab({
    required this.id,
    required this.label,
    this.customerId,
    this.customerName,
    this.discount = 0,
    this.lines = const [],
  });

  final String id;
  final String label;
  final String? customerId;
  final String? customerName;
  final double discount;
  final List<CartLine> lines;

  double get subtotal => lines.fold(0.0, (sum, line) => sum + line.total);
  double get total => math.max(0, subtotal - discount);
  double get cost =>
      lines.fold(0.0, (sum, line) => sum + (line.unitCost ?? 0) * line.qty);
  double get profit => total - cost;
  bool get hasMissingCost => lines.any((line) => line.unitCost == null);
  int get lineCount => lines.length;

  CartTab copyWith({
    String? label,
    String? customerId,
    String? customerName,
    bool clearCustomer = false,
    double? discount,
    List<CartLine>? lines,
  }) =>
      CartTab(
        id: id,
        label: label ?? this.label,
        customerId: clearCustomer ? null : (customerId ?? this.customerId),
        customerName: clearCustomer ? null : (customerName ?? this.customerName),
        discount: discount ?? this.discount,
        lines: lines ?? this.lines,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'customerId': customerId,
        'customerName': customerName,
        'discount': discount,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  factory CartTab.fromJson(Map<String, dynamic> json) => CartTab(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Cart',
        customerId: json['customerId'] as String?,
        customerName: json['customerName'] as String?,
        discount: asDouble(json['discount']),
        lines: (json['lines'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((line) => CartLine.fromJson(Map<String, dynamic>.from(line)))
            .toList(),
      );
}

class CartState {
  const CartState({required this.tabs, required this.activeIndex});

  final List<CartTab> tabs;
  final int activeIndex;

  CartTab get active => tabs[activeIndex.clamp(0, tabs.length - 1)];
  bool get isEmpty => tabs.isEmpty;

  factory CartState.initial() => CartState(
        tabs: [CartTab(id: 'tab-1', label: 'Cart 1')],
        activeIndex: 0,
      );

  CartState copyWith({List<CartTab>? tabs, int? activeIndex}) => CartState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
      );

  Map<String, dynamic> toJson() => {
        'activeIndex': activeIndex,
        'tabs': tabs.map((tab) => tab.toJson()).toList(),
      };

  factory CartState.fromJson(Map<String, dynamic> json) {
    final tabs = (json['tabs'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((tab) => CartTab.fromJson(Map<String, dynamic>.from(tab)))
        .toList();
    if (tabs.isEmpty) return CartState.initial();
    return CartState(
      tabs: tabs,
      activeIndex: math.min(
        asInt(json['activeIndex']),
        tabs.length - 1,
      ),
    );
  }
}
