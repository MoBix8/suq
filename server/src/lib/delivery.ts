/**
 * Delivery pricing shared by the order quote and order creation endpoints.
 *
 * A supplier has one universal warehouse (Merkato by default). The fee is the
 * sum of four independent components so shops can see exactly what they pay:
 *
 *   deliveryFee = baseFee
 *               + distanceKm  × ratePerKm
 *               + weightKg    × ratePerKg
 *               + volumeM3    × ratePerCubicMeter
 */

export const MERKATO = {
  name: "Merkato",
  latitude: 9.03056,
  longitude: 38.73889,
} as const;

export function haversineKm(
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const radians = (degrees: number) => (degrees * Math.PI) / 180;
  const dLat = radians(bLat - aLat);
  const dLng = radians(bLng - aLng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(radians(aLat)) * Math.cos(radians(bLat)) * Math.sin(dLng / 2) ** 2;
  const clamped = Math.min(1, Math.max(0, h));
  return 6371 * 2 * Math.atan2(Math.sqrt(clamped), Math.sqrt(1 - clamped));
}

export interface Warehouse {
  name: string;
  latitude: number;
  longitude: number;
}

export interface DeliveryRates {
  warehouseName?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  deliveryBaseFee: number;
  deliveryPerKm: number;
  deliveryPerKg: number;
  deliveryPerCubicMeter: number;
}

export interface DeliveryQuote {
  warehouse: Warehouse;
  distanceKm: number | null;
  weightKg: number;
  volumeM3: number;
  baseFee: number;
  distanceFee: number;
  weightFee: number;
  volumeFee: number;
  deliveryFee: number;
  quoted: boolean;
}

const roundMoney = (value: number) => Math.round(value * 100) / 100;
const roundWeight = (value: number) => Math.round(value * 1000) / 1000;
const roundVolume = (value: number) => Math.round(value * 1_000_000) / 1_000_000;

export function supplierWarehouse(supplier: DeliveryRates): Warehouse {
  return {
    name: supplier.warehouseName?.trim() || MERKATO.name,
    latitude: supplier.latitude ?? MERKATO.latitude,
    longitude: supplier.longitude ?? MERKATO.longitude,
  };
}

export function computeDeliveryQuote(input: {
  supplier: DeliveryRates;
  shopLatitude?: number | null;
  shopLongitude?: number | null;
  weightKg: number;
  volumeM3: number;
}): DeliveryQuote {
  const warehouse = supplierWarehouse(input.supplier);
  const distanceKm =
    input.shopLatitude != null && input.shopLongitude != null
      ? haversineKm(
          input.shopLatitude,
          input.shopLongitude,
          warehouse.latitude,
          warehouse.longitude,
        )
      : null;

  if (distanceKm == null) {
    // Without a shop pin the distance is unknown, so the supplier must quote
    // manually before accepting the order.
    return {
      warehouse,
      distanceKm: null,
      weightKg: roundWeight(input.weightKg),
      volumeM3: roundVolume(input.volumeM3),
      baseFee: 0,
      distanceFee: 0,
      weightFee: 0,
      volumeFee: 0,
      deliveryFee: 0,
      quoted: false,
    };
  }

  const baseFee = roundMoney(input.supplier.deliveryBaseFee);
  const distanceFee = roundMoney(distanceKm * input.supplier.deliveryPerKm);
  const weightFee = roundMoney(input.weightKg * input.supplier.deliveryPerKg);
  const volumeFee = roundMoney(input.volumeM3 * input.supplier.deliveryPerCubicMeter);
  const deliveryFee = roundMoney(baseFee + distanceFee + weightFee + volumeFee);

  return {
    warehouse,
    distanceKm: Math.round(distanceKm * 100) / 100,
    weightKg: roundWeight(input.weightKg),
    volumeM3: roundVolume(input.volumeM3),
    baseFee,
    distanceFee,
    weightFee,
    volumeFee,
    deliveryFee,
    quoted: true,
  };
}
