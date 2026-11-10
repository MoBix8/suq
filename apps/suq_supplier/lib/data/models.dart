double asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;
int asInt(Object? value) => (value as num?)?.toInt() ?? 0;
bool asBool(Object? value) => value == true || value == 1;
String asString(Object? value) => value as String? ?? '';
DateTime asDate(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class SupplierUser {
  const SupplierUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
  });

  final String id;
  final String name;
  final String phone;
  final String role;

  factory SupplierUser.fromJson(Map<String, dynamic> json) => SupplierUser(
        id: asString(json['id']),
        name: asString(json['name']),
        phone: asString(json['phone']),
        role: asString(json['role']),
      );

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class SupplierProfile {
  const SupplierProfile({
    required this.id,
    required this.businessName,
    this.latitude,
    this.longitude,
    this.deliveryBaseFee = 0,
    this.deliveryPerKm = 0,
    this.deliveryPerKg = 0,
    this.deliveryPerCubicMeter = 0,
  });

  final String id;
  final String businessName;
  final double? latitude;
  final double? longitude;
  final double deliveryBaseFee;
  final double deliveryPerKm;
  final double deliveryPerKg;
  final double deliveryPerCubicMeter;

  bool get hasLocation => latitude != null && longitude != null;

  factory SupplierProfile.fromJson(Map<String, dynamic> json) =>
      SupplierProfile(
        id: asString(json['id']),
        businessName: asString(json['businessName']),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        deliveryBaseFee: asDouble(json['deliveryBaseFee']),
        deliveryPerKm: asDouble(json['deliveryPerKm']),
        deliveryPerKg: asDouble(json['deliveryPerKg']),
        deliveryPerCubicMeter: asDouble(json['deliveryPerCubicMeter']),
      );
}

class SupplierCategory {
  const SupplierCategory({
    required this.id,
    required this.name,
    this.supplierId = '',
    this.sortOrder = 0,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String supplierId;
  final int sortOrder;
  final int productCount;

  factory SupplierCategory.fromJson(Map<String, dynamic> json) {
    final count = asMap(json['_count']);
    return SupplierCategory(
      id: asString(json['id']),
      name: asString(json['name']),
      supplierId: asString(json['supplierId']),
      sortOrder: asInt(json['sortOrder']),
      productCount: asInt(count['products']),
    );
  }
}

class SupplierProduct {
  const SupplierProduct({
    required this.id,
    required this.supplierId,
    required this.categoryId,
    required this.categoryName,
    required this.sku,
    required this.name,
    this.nameAm,
    this.nameOr,
    this.barcode,
    this.unit = 'pcs',
    this.defaultSellingPrice = 0,
    this.defaultBuyingPrice,
    this.active = true,
  });

  final String id;
  final String supplierId;
  final String categoryId;
  final String categoryName;
  final String sku;
  final String name;
  final String? nameAm;
  final String? nameOr;
  final String? barcode;
  final String unit;
  final double defaultSellingPrice;
  final double? defaultBuyingPrice;
  final bool active;

  factory SupplierProduct.fromJson(Map<String, dynamic> json) {
    final category = asMap(json['category']);
    return SupplierProduct(
      id: asString(json['id']),
      supplierId: asString(json['supplierId']),
      categoryId: asString(json['categoryId']),
      categoryName: asString(category['name']),
      sku: asString(json['sku']),
      name: asString(json['name']),
      nameAm: json['nameAm'] as String?,
      nameOr: json['nameOr'] as String?,
      barcode: json['barcode'] as String?,
      unit: asString(json['unit']).isEmpty ? 'pcs' : asString(json['unit']),
      defaultSellingPrice: asDouble(json['defaultSellingPrice']),
      defaultBuyingPrice: (json['defaultBuyingPrice'] as num?)?.toDouble(),
      active: json['active'] as bool? ?? true,
    );
  }
}

class SupplierListing {
  const SupplierListing({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.saleUnit,
    required this.piecesPerUnit,
    required this.pricePerUnit,
    required this.minOrderQty,
    required this.weightPerUnitKg,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.volumePerUnitM3,
    required this.active,
    required this.createdAt,
    this.publishedById,
    this.publishedByName,
  });

  final String id;
  final String name;
  final String? category;
  final String? description;
  final String saleUnit;
  final int piecesPerUnit;
  final double pricePerUnit;
  final int minOrderQty;
  final double weightPerUnitKg;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double volumePerUnitM3;
  final bool active;
  final DateTime createdAt;
  final String? publishedById;
  final String? publishedByName;

  factory SupplierListing.fromJson(Map<String, dynamic> json) {
    final length = asDouble(json['lengthCm']);
    final width = asDouble(json['widthCm']);
    final height = asDouble(json['heightCm']);
    final publishedBy = asMap(json['publishedBy']);
    return SupplierListing(
      id: asString(json['id']),
      name: asString(json['name']),
      category: json['category'] as String?,
      description: json['description'] as String?,
      saleUnit: asString(json['saleUnit']).isEmpty
          ? 'piece'
          : asString(json['saleUnit']),
      piecesPerUnit: asInt(json['piecesPerUnit']) < 1
          ? 1
          : asInt(json['piecesPerUnit']),
      pricePerUnit: asDouble(json['pricePerUnit']),
      minOrderQty: asInt(json['minOrderQty']) < 1
          ? 1
          : asInt(json['minOrderQty']),
      weightPerUnitKg: asDouble(json['weightPerUnitKg']),
      lengthCm: length,
      widthCm: width,
      heightCm: height,
      volumePerUnitM3: asDouble(json['volumePerUnitM3']) > 0
          ? asDouble(json['volumePerUnitM3'])
          : (length * width * height) / 1000000,
      active: json['active'] as bool? ?? true,
      createdAt: asDate(json['createdAt']),
      publishedById: publishedBy.isEmpty
          ? null
          : asString(publishedBy['id']).isEmpty
              ? null
              : asString(publishedBy['id']),
      publishedByName: publishedBy.isEmpty
          ? null
          : asString(publishedBy['name']).isEmpty
              ? null
              : asString(publishedBy['name']),
    );
  }
}

class OrderShop {
  const OrderShop({
    required this.name,
    this.phone,
    this.city,
    this.subcity,
  });

  final String name;
  final String? phone;
  final String? city;
  final String? subcity;

  String get location {
    final parts = [city, subcity]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>();
    return parts.isEmpty ? 'Location not shared' : parts.join(', ');
  }

  factory OrderShop.fromJson(Map<String, dynamic> json) => OrderShop(
        name: asString(json['name']),
        phone: json['phone'] as String?,
        city: json['city'] as String?,
        subcity: json['subcity'] as String?,
      );
}

class SupplierOrderItem {
  const SupplierOrderItem({
    required this.listingName,
    required this.category,
    required this.saleUnit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.weightKg,
    required this.volumeCubicM,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
  });

  final String listingName;
  final String? category;
  final String saleUnit;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final double weightKg;
  final double volumeCubicM;
  final double lengthCm;
  final double widthCm;
  final double heightCm;

  factory SupplierOrderItem.fromJson(Map<String, dynamic> json) =>
      SupplierOrderItem(
        listingName: asString(json['listingName']),
        category: json['category'] as String?,
        saleUnit: asString(json['saleUnit']).isEmpty
            ? 'piece'
            : asString(json['saleUnit']),
        quantity: asInt(json['quantity']),
        unitPrice: asDouble(json['unitPrice']),
        lineTotal: asDouble(json['lineTotal']),
        weightKg: asDouble(json['weightKg']),
        volumeCubicM: asDouble(json['volumeCubicM']),
        lengthCm: asDouble(json['lengthCm']),
        widthCm: asDouble(json['widthCm']),
        heightCm: asDouble(json['heightCm']),
      );
}

class SupplierOrder {
  const SupplierOrder({
    required this.id,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.deliveryDistanceKm,
    required this.deliveryQuoted,
    required this.shippingWeightKg,
    required this.shippingVolumeM3,
    this.note,
    required this.createdAt,
    required this.shop,
    required this.items,
    this.acceptedById,
    this.acceptedByName,
    this.acceptedAt,
  });

  final String id;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final double? deliveryDistanceKm;
  final bool deliveryQuoted;
  final double shippingWeightKg;
  final double shippingVolumeM3;
  final String? note;
  final DateTime createdAt;
  final OrderShop shop;
  final List<SupplierOrderItem> items;
  final String? acceptedById;
  final String? acceptedByName;
  final DateTime? acceptedAt;

  bool get isPending => status == 'PENDING';
  bool get isOpen => status == 'PENDING' || status == 'ACCEPTED' || status == 'READY';
  bool get isClosed => status == 'DELIVERED' || status == 'REJECTED' || status == 'CANCELLED';

  String get statusLabel => switch (status) {
        'PENDING' => 'Awaiting review',
        'ACCEPTED' => 'Accepted',
        'READY' => 'Ready for delivery',
        'DELIVERED' => 'Delivered',
        'REJECTED' => 'Rejected',
        'CANCELLED' => 'Cancelled',
        _ => status,
      };

  factory SupplierOrder.fromJson(Map<String, dynamic> json) => SupplierOrder(
        id: asString(json['id']),
        status: asString(json['status']),
        subtotal: asDouble(json['subtotal']),
        deliveryFee: asDouble(json['deliveryFee']),
        total: asDouble(json['total']),
        deliveryDistanceKm: (json['deliveryDistanceKm'] as num?)?.toDouble(),
        deliveryQuoted: json['deliveryQuoted'] as bool? ?? false,
        shippingWeightKg: asDouble(json['shippingWeightKg']),
        shippingVolumeM3: asDouble(json['shippingVolumeM3']),
        note: json['note'] as String?,
        createdAt: asDate(json['createdAt']),
        shop: OrderShop.fromJson(asMap(json['shop'])),
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => SupplierOrderItem.fromJson(asMap(row)))
            .toList(),
        acceptedById: _optionalString(asMap(json['acceptedBy'])['id']),
        acceptedByName: _optionalString(asMap(json['acceptedBy'])['name']),
        acceptedAt: DateTime.tryParse(
          json['acceptedAt'] as String? ?? '',
        )?.toLocal(),
      );
}

String? _optionalString(Object? value) {
  final text = asString(value);
  return text.isEmpty ? null : text;
}
