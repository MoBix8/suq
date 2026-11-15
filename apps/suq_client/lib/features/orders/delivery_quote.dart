import 'dart:math' as math;

/// Default pickup point for suppliers that have not set a warehouse pin.
const merkatoWarehouseName = 'Merkato';
const merkatoLatitude = 9.03056;
const merkatoLongitude = 38.73889;

/// Distance in kilometres between two points on the earth.
double haversineKm(
  double aLatitude,
  double aLongitude,
  double bLatitude,
  double bLongitude,
) {
  double radians(double degrees) => (degrees * math.pi) / 180;

  final dLat = radians(bLatitude - aLatitude);
  final dLng = radians(bLongitude - aLongitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(aLatitude)) *
          math.cos(radians(bLatitude)) *
          math.pow(math.sin(dLng / 2), 2);
  final clamped = h.clamp(0.0, 1.0);
  return 6371 * 2 * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));
}

double _roundMoney(double value) => (value * 100).round() / 100;
double _roundDistance(double value) => (value * 100).round() / 100;
double _roundWeight(double value) => (value * 1000).round() / 1000;
double _roundVolume(double value) => (value * 1000000).round() / 1000000;

/// The single universal warehouse and transport rates a supplier ships from.
class DeliveryRates {
  const DeliveryRates({
    required this.warehouseName,
    required this.latitude,
    required this.longitude,
    required this.baseFee,
    required this.perKm,
    required this.perKg,
    required this.perCubicMeter,
  });

  final String warehouseName;
  final double latitude;
  final double longitude;
  final double baseFee;
  final double perKm;
  final double perKg;
  final double perCubicMeter;

  factory DeliveryRates.fromJson(Map<String, dynamic> json) {
    final name = json['warehouseName']?.toString().trim() ?? '';
    return DeliveryRates(
      warehouseName: name.isEmpty ? merkatoWarehouseName : name,
      latitude: (json['latitude'] as num?)?.toDouble() ?? merkatoLatitude,
      longitude: (json['longitude'] as num?)?.toDouble() ?? merkatoLongitude,
      baseFee: (json['deliveryBaseFee'] as num?)?.toDouble() ?? 0,
      perKm: (json['deliveryPerKm'] as num?)?.toDouble() ?? 0,
      perKg: (json['deliveryPerKg'] as num?)?.toDouble() ?? 0,
      perCubicMeter:
          (json['deliveryPerCubicMeter'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One cart line's shipping measurements.
class DeliveryLine {
  const DeliveryLine({
    required this.quantity,
    this.weightPerUnitKg = 0,
    this.lengthCm = 0,
    this.widthCm = 0,
    this.heightCm = 0,
    this.volumePerUnitM3 = 0,
  });

  final int quantity;
  final double weightPerUnitKg;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double volumePerUnitM3;

  double get weightKg => weightPerUnitKg * quantity;

  double get unitVolumeM3 => volumePerUnitM3 > 0
      ? volumePerUnitM3
      : (lengthCm * widthCm * heightCm) / 1000000;

  double get volumeM3 => unitVolumeM3 * quantity;
}

/// A transport estimate, broken down by the four components of the formula.
class DeliveryQuote {
  const DeliveryQuote({
    required this.warehouseName,
    required this.distanceKm,
    required this.weightKg,
    required this.volumeM3,
    required this.baseFee,
    required this.distanceFee,
    required this.weightFee,
    required this.volumeFee,
    required this.deliveryFee,
  });

  final String warehouseName;
  final double distanceKm;
  final double weightKg;
  final double volumeM3;
  final double baseFee;
  final double distanceFee;
  final double weightFee;
  final double volumeFee;
  final double deliveryFee;
}

/// Estimates the transport fee exactly like the server:
///
///   base fee + distance × rate/km + weight × rate/kg + volume × rate/m³
///
/// Returns `null` when the shop has no pin, because the distance is unknown
/// and the supplier must quote manually.
DeliveryQuote? quoteDelivery({
  required DeliveryRates supplier,
  required double? shopLatitude,
  required double? shopLongitude,
  required Iterable<DeliveryLine> lines,
}) {
  if (shopLatitude == null || shopLongitude == null) return null;

  var weightKg = 0.0;
  var volumeM3 = 0.0;
  for (final line in lines) {
    weightKg += line.weightKg;
    volumeM3 += line.volumeM3;
  }

  final distanceKm = haversineKm(
    shopLatitude,
    shopLongitude,
    supplier.latitude,
    supplier.longitude,
  );
  final baseFee = _roundMoney(supplier.baseFee);
  final distanceFee = _roundMoney(distanceKm * supplier.perKm);
  final weightFee = _roundMoney(weightKg * supplier.perKg);
  final volumeFee = _roundMoney(volumeM3 * supplier.perCubicMeter);

  return DeliveryQuote(
    warehouseName: supplier.warehouseName,
    distanceKm: _roundDistance(distanceKm),
    weightKg: _roundWeight(weightKg),
    volumeM3: _roundVolume(volumeM3),
    baseFee: baseFee,
    distanceFee: distanceFee,
    weightFee: weightFee,
    volumeFee: volumeFee,
    deliveryFee: _roundMoney(baseFee + distanceFee + weightFee + volumeFee),
  );
}
