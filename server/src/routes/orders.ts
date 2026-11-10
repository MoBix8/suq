import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireBoundDevice, requireShop } from "../auth";
import { AppError, asyncHandler } from "../errors";
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

const orderInput = z.object({
  supplierId: z.string().min(1),
  note: z.string().trim().max(500).optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  items: z.array(z.object({
    listingId: z.string().min(1),
    quantity: z.number().int().min(1).max(10000).optional(),
    // Kept for older clients that still send the previous field name.
    packageCount: z.number().int().min(1).max(10000).optional(),
  }).refine((v) => v.quantity != null || v.packageCount != null, "Provide a quantity")).min(1).max(100),
}).refine((v) => v.latitude == null === (v.longitude == null), "Provide both coordinates together");

function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const dLat = radians(bLat - aLat);
  const dLng = radians(bLng - aLng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(radians(aLat)) * Math.cos(radians(bLat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

ordersRouter.post("/", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const body = orderInput.parse(req.body);
  const [shop, supplier, listings] = await Promise.all([
    prisma.shop.findUniqueOrThrow({ where: { id: shopId } }),
    prisma.supplier.findUnique({ where: { id: body.supplierId } }),
    prisma.supplierListing.findMany({ where: { supplierId: body.supplierId, active: true, id: { in: body.items.map((i) => i.listingId) } } }),
  ]);
  if (!supplier) throw new AppError(404, "Supplier not found");
  if (listings.length !== new Set(body.items.map((i) => i.listingId)).size) throw new AppError(400, "One or more items are unavailable");
  const lat = body.latitude ?? shop.latitude;
  const lng = body.longitude ?? shop.longitude;
  const distance = lat != null && lng != null && supplier.latitude != null && supplier.longitude != null
    ? haversineKm(lat, lng, supplier.latitude, supplier.longitude)
    : null;
  if (body.latitude != null && body.longitude != null) {
    await prisma.shop.update({ where: { id: shopId }, data: { latitude: body.latitude, longitude: body.longitude } });
  }

  const roundMoney = (value: number) => Math.round(value * 100) / 100;
  const listingMap = new Map(listings.map((listing) => [listing.id, listing]));
  const lines = body.items.map((input) => {
    const listing = listingMap.get(input.listingId)!;
    const quantity = input.quantity ?? input.packageCount!;
    if (quantity < listing.minOrderQty) {
      throw new AppError(400, `${listing.name} has a minimum order of ${listing.minOrderQty} ${listing.saleUnit}`);
    }
    const volumePerUnit = listing.volumePerUnitM3 ||
      (listing.lengthCm * listing.widthCm * listing.heightCm) / 1_000_000;
    return {
      listingId: listing.id,
      listingName: listing.name,
      category: listing.category,
      saleUnit: listing.saleUnit,
      quantity,
      unitPrice: listing.pricePerUnit,
      lineTotal: roundMoney(listing.pricePerUnit * quantity),
      weightKg: Math.round(listing.weightPerUnitKg * quantity * 1000) / 1000,
      volumeCubicM: Math.round(volumePerUnit * quantity * 1_000_000) / 1_000_000,
      lengthCm: listing.lengthCm,
      widthCm: listing.widthCm,
      heightCm: listing.heightCm,
    };
  });
  const subtotal = roundMoney(lines.reduce((sum, line) => sum + line.lineTotal, 0));
  const weight = lines.reduce((sum, line) => sum + line.weightKg, 0);
  const volume = lines.reduce((sum, line) => sum + line.volumeCubicM, 0);
  const deliveryFee = roundMoney(supplier.deliveryBaseFee + (distance ?? 0) * supplier.deliveryPerKm + weight * supplier.deliveryPerKg + volume * supplier.deliveryPerCubicMeter);
  const order = await prisma.shopOrder.create({
    data: {
      shopId, supplierId: supplier.id, subtotal, deliveryFee, total: roundMoney(subtotal + deliveryFee),
      deliveryDistanceKm: distance, deliveryQuoted: distance != null,
      shippingWeightKg: Math.round(weight * 1000) / 1000,
      shippingVolumeM3: Math.round(volume * 1_000_000) / 1_000_000,
      note: body.note, items: { create: lines },
    },
    include: { items: true, supplier: { select: { businessName: true } } },
  });
  res.status(201).json({ order, needsDistanceQuote: distance == null });
}));

ordersRouter.get("/", asyncHandler(async (req, res) => {
  const { shopId } = requireShop(req);
  const orders = await prisma.shopOrder.findMany({
    where: { shopId },
    include: {
      items: true,
      supplier: { select: { businessName: true } },
      acceptedBy: { select: { id: true, name: true, phone: true } },
    },
    orderBy: { createdAt: "desc" },
  });
  res.json({ orders });
}));
