import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireBoundDevice, requireShop } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { computeDeliveryQuote } from "../lib/delivery";
import { prisma } from "../prisma";

export const ordersRouter = Router();
ordersRouter.use(requireAuth, requireBoundDevice);

ordersRouter.patch("/location", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const body = z.object({
    latitude: z.number().min(-90).max(90).nullable(),
    longitude: z.number().min(-180).max(180).nullable(),
  }).refine((v) => (v.latitude == null) === (v.longitude == null), "Provide both coordinates or clear both").parse(req.body);
  const shop = await prisma.shop.update({ where: { id: shopId }, data: body });
  res.json({ location: { latitude: shop.latitude, longitude: shop.longitude } });
}));

ordersRouter.get("/suppliers", asyncHandler(async (_req, res) => {
  requireShop(_req);
  const suppliers = await prisma.supplier.findMany({
    where: { listings: { some: { active: true } } },
    select: {
      id: true,
      businessName: true,
      warehouseName: true,
      latitude: true,
      longitude: true,
      deliveryBaseFee: true,
      deliveryPerKm: true,
      deliveryPerKg: true,
      deliveryPerCubicMeter: true,
      listings: {
        where: { active: true },
        include: { publishedBy: { select: { id: true, name: true } } },
        orderBy: { createdAt: "desc" },
      },
    },
    orderBy: { businessName: "asc" },
  });
  res.json({ suppliers });
}));

const orderItemSchema = z.object({
  listingId: z.string().min(1),
  quantity: z.number().int().min(1).max(10000).optional(),
  // Kept for older clients that still send the previous field name.
  packageCount: z.number().int().min(1).max(10000).optional(),
}).refine((v) => v.quantity != null || v.packageCount != null, "Provide a quantity");

const orderInput = z.object({
  supplierId: z.string().min(1),
  note: z.string().trim().max(500).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  items: z.array(orderItemSchema).min(1).max(100),
}).refine((v) => (v.latitude == null) === (v.longitude == null), "Provide both coordinates together");

const quoteInput = z.object({
  supplierId: z.string().min(1),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  items: z.array(orderItemSchema).min(1).max(100),
}).refine((v) => (v.latitude == null) === (v.longitude == null), "Provide both coordinates together");

const roundMoney = (value: number) => Math.round(value * 100) / 100;

function volumePerUnit(listing: {
  volumePerUnitM3: number;
  lengthCm: number;
  widthCm: number;
  heightCm: number;
}): number {
  return listing.volumePerUnitM3 ||
    (listing.lengthCm * listing.widthCm * listing.heightCm) / 1_000_000;
}

async function buildLines(
  supplierId: string,
  items: Array<{ listingId: string; quantity?: number; packageCount?: number }>,
) {
  const listings = await prisma.supplierListing.findMany({
    where: {
      supplierId,
      active: true,
      id: { in: items.map((item) => item.listingId) },
    },
  });
  if (listings.length !== new Set(items.map((item) => item.listingId)).size) {
    throw new AppError(400, "One or more items are unavailable");
  }

  const listingMap = new Map(listings.map((listing) => [listing.id, listing]));
  const lines = items.map((input) => {
    const listing = listingMap.get(input.listingId)!;
    const quantity = input.quantity ?? input.packageCount!;
    if (quantity < listing.minOrderQty) {
      throw new AppError(
        400,
        `${listing.name} has a minimum order of ${listing.minOrderQty} ${listing.saleUnit}`,
      );
    }
    const unitVolume = volumePerUnit(listing);
    return {
      listingId: listing.id,
      listingName: listing.name,
      category: listing.category,
      saleUnit: listing.saleUnit,
      quantity,
      unitPrice: listing.pricePerUnit,
      lineTotal: roundMoney(listing.pricePerUnit * quantity),
      weightKg: Math.round(listing.weightPerUnitKg * quantity * 1000) / 1000,
      volumeCubicM: Math.round(unitVolume * quantity * 1_000_000) / 1_000_000,
      lengthCm: listing.lengthCm,
      widthCm: listing.widthCm,
      heightCm: listing.heightCm,
    };
  });

  return {
    lines,
    subtotal: roundMoney(lines.reduce((sum, line) => sum + line.lineTotal, 0)),
    weightKg: lines.reduce((sum, line) => sum + line.weightKg, 0),
    volumeM3: lines.reduce((sum, line) => sum + line.volumeCubicM, 0),
  };
}

ordersRouter.post("/quote", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const body = quoteInput.parse(req.body);
  const [shop, supplier] = await Promise.all([
    prisma.shop.findUniqueOrThrow({ where: { id: shopId } }),
    prisma.supplier.findUnique({ where: { id: body.supplierId } }),
  ]);
  if (!supplier) throw new AppError(404, "Supplier not found");

  const built = await buildLines(body.supplierId, body.items);
  const delivery = computeDeliveryQuote({
    supplier,
    shopLatitude: body.latitude ?? shop.latitude,
    shopLongitude: body.longitude ?? shop.longitude,
    weightKg: built.weightKg,
    volumeM3: built.volumeM3,
  });

  res.json({
    quote: {
      supplierId: supplier.id,
      supplierName: supplier.businessName,
      subtotal: built.subtotal,
      deliveryFee: delivery.deliveryFee,
      total: roundMoney(built.subtotal + delivery.deliveryFee),
      deliveryDistanceKm: delivery.distanceKm,
      shippingWeightKg: delivery.weightKg,
      shippingVolumeM3: delivery.volumeM3,
      deliveryQuoted: delivery.quoted,
      needsDistanceQuote: !delivery.quoted,
      breakdown: {
        baseFee: delivery.baseFee,
        distanceFee: delivery.distanceFee,
        weightFee: delivery.weightFee,
        volumeFee: delivery.volumeFee,
      },
      warehouse: delivery.warehouse,
    },
  });
}));

ordersRouter.post("/", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const body = orderInput.parse(req.body);
  const [shop, supplier] = await Promise.all([
    prisma.shop.findUniqueOrThrow({ where: { id: shopId } }),
    prisma.supplier.findUnique({ where: { id: body.supplierId } }),
  ]);
  if (!supplier) throw new AppError(404, "Supplier not found");

  const built = await buildLines(body.supplierId, body.items);
  const delivery = computeDeliveryQuote({
    supplier,
    shopLatitude: body.latitude ?? shop.latitude,
    shopLongitude: body.longitude ?? shop.longitude,
    weightKg: built.weightKg,
    volumeM3: built.volumeM3,
  });

  if (body.latitude != null && body.longitude != null) {
    await prisma.shop.update({
      where: { id: shopId },
      data: { latitude: body.latitude, longitude: body.longitude },
    });
  }

  const order = await prisma.shopOrder.create({
    data: {
      shopId,
      supplierId: supplier.id,
      subtotal: built.subtotal,
      deliveryFee: delivery.deliveryFee,
      deliveryBaseFee: delivery.baseFee,
      deliveryDistanceFee: delivery.distanceFee,
      deliveryWeightFee: delivery.weightFee,
      deliveryVolumeFee: delivery.volumeFee,
      warehouseName: delivery.warehouse.name,
      total: roundMoney(built.subtotal + delivery.deliveryFee),
      deliveryDistanceKm: delivery.distanceKm,
      deliveryQuoted: delivery.quoted,
      shippingWeightKg: delivery.weightKg,
      shippingVolumeM3: delivery.volumeM3,
      note: body.note,
      items: { create: built.lines },
    },
    include: {
      items: true,
      supplier: { select: { businessName: true, warehouseName: true } },
    },
  });

  res.status(201).json({ order, needsDistanceQuote: !delivery.quoted });
}));

ordersRouter.get("/", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const orders = await prisma.shopOrder.findMany({
    where: { shopId },
    include: {
      items: true,
      supplier: { select: { businessName: true, warehouseName: true } },
      acceptedBy: { select: { id: true, name: true, phone: true } },
    },
    orderBy: { createdAt: "desc" },
  });
  res.json({ orders });
}));
