double asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
bool asBool(Object? value) => value == true || value == 1;
String asString(Object? value) => value as String? ?? '';
DateTime asDate(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();
DateTime? asDateOrNull(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal();

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final String role;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: asString(json['id']),
        name: asString(json['name']),
        phone: asString(json['phone']),
        role: asString(json['role']),
      );
}

class SubscriptionSummary {
  const SubscriptionSummary({
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

  factory SubscriptionSummary.fromJson(Map<String, dynamic> json) =>
      SubscriptionSummary(
        status: asString(json['status']),
        packageName: json['packageName'] as String?,
        startsAt: asDateOrNull(json['startsAt']),
        endsAt: asDateOrNull(json['endsAt']),
        active: json['active'] as bool? ?? false,
        daysLeft: asInt(json['daysLeft']),
      );
}

class ShopRecord {
  const ShopRecord({
    required this.id,
    required this.name,
    this.city,
    this.subcity,
    required this.createdAt,
    this.ownerName,
    this.ownerPhone,
    this.salesCount = 0,
    this.customersCount = 0,
    this.paymentsCount = 0,
    this.subscription,
  });

  final String id;
  final String name;
  final String? city;
  final String? subcity;
  final DateTime createdAt;
  final String? ownerName;
  final String? ownerPhone;
  final int salesCount;
  final int customersCount;
  final int paymentsCount;
  final SubscriptionSummary? subscription;

  bool get active => subscription?.active == true;

  factory ShopRecord.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final sub = json['subscription'];
    final counts = json['counts'];
    return ShopRecord(
      id: asString(json['id']),
      name: asString(json['name']),
      city: json['city'] as String?,
      subcity: json['subcity'] as String?,
      createdAt: asDate(json['createdAt']),
      ownerName: owner is Map ? owner['name'] as String? : null,
      ownerPhone: owner is Map ? owner['phone'] as String? : null,
      salesCount: counts is Map ? asInt(counts['sales']) : 0,
      customersCount: counts is Map ? asInt(counts['customers']) : 0,
      paymentsCount: counts is Map ? asInt(counts['payments']) : 0,
      subscription: sub is Map
          ? SubscriptionSummary.fromJson(Map<String, dynamic>.from(sub))
          : null,
    );
  }
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.amountEtb,
    required this.transactionRef,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.note,
    this.adminNote,
    this.shopId,
    this.shopName,
    this.ownerName,
    this.ownerPhone,
    this.packageName,
    this.packageMonths = 0,
    this.bankName,
    this.bankAccountNumber,
  });

  final String id;
  final double amountEtb;
  final String transactionRef;
  final String status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? note;
  final String? adminNote;
  final String? shopId;
  final String? shopName;
  final String? ownerName;
  final String? ownerPhone;
  final String? packageName;
  final int packageMonths;
  final String? bankName;
  final String? bankAccountNumber;

  bool get pending => status == 'PENDING';
  bool get approved => status == 'APPROVED';
  bool get rejected => status == 'REJECTED';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    final pkg = json['package'];
    final bank = json['bankAccount'];
    final user = shop is Map ? shop['user'] : null;
    return PaymentRecord(
      id: asString(json['id']),
      amountEtb: asDouble(json['amountEtb']),
      transactionRef: asString(json['transactionRef']),
      status: asString(json['status']).isEmpty ? 'PENDING' : asString(json['status']),
      submittedAt: asDate(json['submittedAt']),
      reviewedAt: asDateOrNull(json['reviewedAt']),
      note: json['note'] as String?,
      adminNote: json['adminNote'] as String?,
      shopId: shop is Map ? shop['id'] as String? : null,
      shopName: shop is Map ? shop['name'] as String? : null,
      ownerName: user is Map ? user['name'] as String? : null,
      ownerPhone: user is Map ? user['phone'] as String? : null,
      packageName: pkg is Map ? pkg['name'] as String? : null,
      packageMonths: pkg is Map ? asInt(pkg['months']) : 0,
      bankName: bank is Map ? bank['bankName'] as String? : null,
      bankAccountNumber: bank is Map ? bank['accountNumber'] as String? : null,
    );
  }
}

class PackagePlan {
  const PackagePlan({
    required this.id,
    required this.name,
    required this.months,
    required this.priceEtb,
    this.description,
    this.sortOrder = 0,
    this.active = true,
    this.paymentCount = 0,
    this.subscriptionCount = 0,
  });

  final String id;
  final String name;
  final int months;
  final double priceEtb;
  final String? description;
  final int sortOrder;
  final bool active;
  final int paymentCount;
  final int subscriptionCount;

  factory PackagePlan.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'];
    return PackagePlan(
      id: asString(json['id']),
      name: asString(json['name']),
      months: asInt(json['months']),
      priceEtb: asDouble(json['priceEtb']),
      description: json['description'] as String?,
      sortOrder: asInt(json['sortOrder']),
      active: json['active'] as bool? ?? true,
      paymentCount: counts is Map ? asInt(counts['payments']) : 0,
      subscriptionCount: counts is Map ? asInt(counts['subscriptions']) : 0,
    );
  }
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.branch,
    this.instructions,
    this.sortOrder = 0,
    this.active = true,
    this.paymentCount = 0,
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? branch;
  final String? instructions;
  final int sortOrder;
  final bool active;
  final int paymentCount;

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'];
    return BankAccount(
      id: asString(json['id']),
      bankName: asString(json['bankName']),
      accountName: asString(json['accountName']),
      accountNumber: asString(json['accountNumber']),
      branch: json['branch'] as String?,
      instructions: json['instructions'] as String?,
      sortOrder: asInt(json['sortOrder']),
      active: json['active'] as bool? ?? true,
      paymentCount: counts is Map ? asInt(counts['payments']) : 0,
    );
  }
}

class LibraryCategory {
  const LibraryCategory({
    required this.id,
    required this.name,
    this.slug,
    this.sortOrder = 0,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String? slug;
  final int sortOrder;
  final int productCount;

  factory LibraryCategory.fromJson(Map<String, dynamic> json) {
    final counts = json['_count'];
    return LibraryCategory(
      id: asString(json['id']),
      name: asString(json['name']),
      slug: json['slug'] as String?,
      sortOrder: asInt(json['sortOrder']),
      productCount: counts is Map ? asInt(counts['products']) : 0,
    );
  }
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
    this.version = 1,
    this.active = true,
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
  final bool active;

  factory LibraryProduct.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    return LibraryProduct(
      id: asString(json['id']),
      sku: asString(json['sku']),
      categoryId: asString(json['categoryId']),
      categoryName: category is Map ? asString(category['name']) : '',
      name: asString(json['name']),
      barcode: json['barcode'] as String?,
      unit: asString(json['unit']).isEmpty ? 'pcs' : asString(json['unit']),
      defaultSellingPrice: asDouble(json['defaultSellingPrice']),
      defaultBuyingPrice: json['defaultBuyingPrice'] == null
          ? null
          : asDouble(json['defaultBuyingPrice']),
      version: asInt(json['version']),
      active: json['active'] as bool? ?? true,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    this.totalShops = 0,
    this.activeShops = 0,
    this.pendingPayments = 0,
    this.totalPayments = 0,
    this.revenueEtb = 0,
    this.expiringSoon = 0,
  });

  final int totalShops;
  final int activeShops;
  final int pendingPayments;
  final int totalPayments;
  final double revenueEtb;
  final int expiringSoon;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalShops: asInt(json['totalShops']),
        activeShops: asInt(json['activeShops']),
        pendingPayments: asInt(json['pendingPayments']),
        totalPayments: asInt(json['totalPayments']),
        revenueEtb: asDouble(json['revenueEtb']),
        expiringSoon: asInt(json['expiringSoon']),
      );
}

class ExpiringShop {
  const ExpiringShop({
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.packageName,
    required this.endsAt,
  });

  final String shopName;
  final String ownerName;
  final String phone;
  final String packageName;
  final DateTime? endsAt;

  factory ExpiringShop.fromJson(Map<String, dynamic> json) => ExpiringShop(
        shopName: asString(json['shopName']),
        ownerName: asString(json['ownerName']),
        phone: asString(json['phone']),
        packageName: asString(json['packageName']),
        endsAt: asDateOrNull(json['endsAt']),
      );
}

class AdminDashboard {
  const AdminDashboard({
    required this.serverTime,
    required this.stats,
    required this.expiring,
    required this.recentPayments,
  });

  final DateTime serverTime;
  final DashboardStats stats;
  final List<ExpiringShop> expiring;
  final List<PaymentRecord> recentPayments;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'];
    final expiring = json['expiring'] as List<dynamic>? ?? [];
    final payments = json['recentPayments'] as List<dynamic>? ?? [];
    return AdminDashboard(
      serverTime: asDate(json['serverTime']),
      stats: stats is Map
          ? DashboardStats.fromJson(Map<String, dynamic>.from(stats))
          : const DashboardStats(),
      expiring: expiring
          .whereType<Map>()
          .map((item) => ExpiringShop.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      recentPayments: payments
          .whereType<Map>()
          .map((item) => PaymentRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
