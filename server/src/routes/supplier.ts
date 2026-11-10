import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireSupplier } from "../auth";
import { asyncHandler } from "../errors";
import { slugify } from "../lib/phone";
import { prisma } from "../prisma";

export const supplierRouter = Router();
supplierRouter.use(requireAuth, (req, _res, next) => {
  try {
    requireSupplier(req);
    next();
  } catch (error) {
    next(error);
  }
});

const categoryInput = z.object({
  name: z.string().trim().min(2).max(80),
  sortOrder: z.number().int().default(0),
});

supplierRouter.get("/profile", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const supplier = await prisma.supplier.findUniqueOrThrow({ where: { id: supplierId } });
  res.json({ supplier });
}));

supplierRouter.patch("/profile", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = z.object({
    businessName: z.string().trim().min(2).max(120).optional(),
    latitude: z.number().min(-90).max(90).nullable().optional(),
    longitude: z.number().min(-180).max(180).nullable().optional(),
    deliveryBaseFee: z.number().min(0).optional(),
    deliveryPerKm: z.number().min(0).optional(),
    deliveryPerKg: z.number().min(0).optional(),
    deliveryPerCubicMeter: z.number().min(0).optional(),
  }).parse(req.body);
  const supplier = await prisma.supplier.update({ where: { id: supplierId }, data: body });
  res.json({ supplier });
}));

supplierRouter.get("/categories", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  // Mirror the client's SUQ library: every category that has active products,
  // plus the supplier's own (possibly empty) categories so they can add to them.
  const categories = await prisma.category.findMany({
    where: {
      OR: [{ products: { some: { active: true } } }, { supplierId }],
    },
    orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: { _count: { select: { products: { where: { active: true } } } } },
  });
  res.json({ categories });
}));

supplierRouter.post("/categories", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = categoryInput.parse(req.body);
  const category = await prisma.category.create({
    data: { supplierId, name: body.name, slug: slugify(body.name), sortOrder: body.sortOrder },
  });
  res.status(201).json({ category });
}));

supplierRouter.patch("/categories/:id", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = categoryInput.partial().parse(req.body);
  const category = await prisma.category.updateMany({
    where: { id: req.params.id, supplierId },
    data: { ...body, ...(body.name ? { slug: slugify(body.name) } : {}) },
  });
  if (!category.count) return res.status(404).json({ error: "Category not found" });
  res.json({ ok: true });
}));

supplierRouter.delete("/categories/:id", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const products = await prisma.productLibraryItem.count({ where: { supplierId, categoryId: req.params.id } });
  if (products) return res.status(409).json({ error: "Move or remove the category's products first" });
  await prisma.category.deleteMany({ where: { id: req.params.id, supplierId } });
  res.json({ ok: true });
}));

const productInput = z.object({
  categoryId: z.string().min(1),
  sku: z.string().trim().min(2).max(50),
  name: z.string().trim().min(2).max(120),
  nameAm: z.string().trim().max(120).nullish(),
  nameOr: z.string().trim().max(120).nullish(),
  barcode: z.string().trim().max(80).nullish(),
  unit: z.string().trim().min(1).max(20),
  defaultSellingPrice: z.number().min(0),
  defaultBuyingPrice: z.number().min(0).nullish(),
});

supplierRouter.get("/products", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  // Same feed shops see in the client's SUQ library: every active product from
  // the shared library (SUQ and all suppliers), plus the supplier's own rows so
  // they can still manage anything they created.
  const products = await prisma.productLibraryItem.findMany({
    where: { OR: [{ active: true }, { supplierId }] },
    include: { category: true },
    orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }],
  });
  res.json({ products });
}));

supplierRouter.post("/products", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = productInput.parse(req.body);
  const category = await prisma.category.findFirst({ where: { id: body.categoryId, supplierId } });
  if (!category) return res.status(400).json({ error: "Choose one of your categories" });
  const product = await prisma.productLibraryItem.create({
    data: { ...body, supplierId, barcode: body.barcode || null, nameAm: body.nameAm || null, nameOr: body.nameOr || null },
  });
  res.status(201).json({ product });
}));

supplierRouter.patch("/products/:id", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = productInput.partial().parse(req.body);
  if (body.categoryId && !await prisma.category.findFirst({ where: { id: body.categoryId, supplierId } })) {
    return res.status(400).json({ error: "Choose one of your categories" });
  }
  const result = await prisma.productLibraryItem.updateMany({ where: { id: req.params.id, supplierId }, data: body });
  if (!result.count) return res.status(404).json({ error: "Product not found" });
  res.json({ ok: true });
}));

const listingInput = z.object({
  name: z.string().trim().min(2).max(120),
  description: z.string().trim().max(500).nullish(),
  category: z.string().trim().max(80).nullish(),
  saleUnit: z.enum(["piece", "dozen", "pack", "sack", "crate", "bulk"]),
  piecesPerUnit: z.number().int().min(1).max(100000).optional(),
  pricePerUnit: z.number().positive(),
  minOrderQty: z.number().int().min(1).max(10000),
  weightPerUnitKg: z.number().positive(),
  lengthCm: z.number().positive(),
  widthCm: z.number().positive(),
  heightCm: z.number().positive(),
  active: z.boolean(),
});

function volumePerUnit(lengthCm: number, widthCm: number, heightCm: number): number {
  return (lengthCm * widthCm * heightCm) / 1_000_000;
}

supplierRouter.get("/listings", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const listings = await prisma.supplierListing.findMany({
    where: { supplierId },
    include: { publishedBy: { select: { id: true, name: true, phone: true } } },
    orderBy: { createdAt: "desc" },
  });
  res.json({ listings });
}));

supplierRouter.post("/listings", asyncHandler(async (req, res) => {
  const { supplierId, userId } = requireSupplier(req);
  const body = listingInput.parse(req.body);
  const listing = await prisma.supplierListing.create({
    data: {
      ...body,
      supplierId,
      publishedById: userId,
      piecesPerUnit: body.piecesPerUnit ?? 1,
      description: body.description || null,
      category: body.category || null,
      volumePerUnitM3: volumePerUnit(body.lengthCm, body.widthCm, body.heightCm),
    },
    include: { publishedBy: { select: { id: true, name: true, phone: true } } },
  });
  res.status(201).json({ listing });
}));

supplierRouter.patch("/listings/:id", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = listingInput.partial().parse(req.body);
  const existing = await prisma.supplierListing.findFirst({ where: { id: req.params.id, supplierId } });
  if (!existing) return res.status(404).json({ error: "Listing not found" });

  const lengthCm = body.lengthCm ?? existing.lengthCm;
  const widthCm = body.widthCm ?? existing.widthCm;
  const heightCm = body.heightCm ?? existing.heightCm;
  const listing = await prisma.supplierListing.update({
    where: { id: existing.id },
    data: {
      ...body,
      description: body.description === undefined ? undefined : body.description || null,
      category: body.category === undefined ? undefined : body.category || null,
      volumePerUnitM3: volumePerUnit(lengthCm, widthCm, heightCm),
    },
    include: { publishedBy: { select: { id: true, name: true, phone: true } } },
  });
  res.json({ listing });
}));

supplierRouter.get("/orders", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const orders = await prisma.shopOrder.findMany({
    where: { supplierId },
    include: {
      shop: { select: { id: true, name: true, city: true, subcity: true, phone: true, latitude: true, longitude: true } },
      acceptedBy: { select: { id: true, name: true, phone: true } },
      items: true,
    },
    orderBy: { createdAt: "desc" },
  });
  res.json({ orders });
}));

supplierRouter.patch("/orders/:id/status", asyncHandler(async (req, res) => {
  const { supplierId, userId } = requireSupplier(req);
  const { status } = z.object({ status: z.enum(["ACCEPTED", "REJECTED", "READY", "DELIVERED"]) }).parse(req.body);
  const existing = await prisma.shopOrder.findFirst({ where: { id: req.params.id, supplierId } });
  if (!existing) return res.status(404).json({ error: "Order not found" });
  if (status === "ACCEPTED" && !existing.deliveryQuoted) return res.status(409).json({ error: "Set a delivery quote before accepting this order" });
  const allowed: Record<string, string[]> = {
    PENDING: ["ACCEPTED", "REJECTED"], ACCEPTED: ["READY"], READY: ["DELIVERED"],
  };
  if (!allowed[existing.status]?.includes(status)) return res.status(409).json({ error: "That order status change is not allowed" });
  const order = await prisma.shopOrder.update({
    where: { id: existing.id },
    data: {
      status,
      ...(status === "ACCEPTED" ? { acceptedById: userId, acceptedAt: new Date() } : {}),
    },
    include: { acceptedBy: { select: { id: true, name: true, phone: true } } },
  });
  res.json({ order });
}));

supplierRouter.patch("/orders/:id/delivery", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const { deliveryFee } = z.object({ deliveryFee: z.number().min(0) }).parse(req.body);
  const existing = await prisma.shopOrder.findFirst({ where: { id: req.params.id, supplierId } });
  if (!existing) return res.status(404).json({ error: "Order not found" });
  if (existing.status !== "PENDING") return res.status(409).json({ error: "Delivery can only be quoted before accepting the order" });
  const order = await prisma.shopOrder.update({
    where: { id: existing.id },
    data: { deliveryFee, total: existing.subtotal + deliveryFee, deliveryQuoted: true },
  });
  res.json({ order });
}));
