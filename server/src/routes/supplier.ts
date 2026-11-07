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
  const categories = await prisma.category.findMany({
    where: { supplierId }, orderBy: [{ sortOrder: "asc" }, { name: "asc" }],
    include: { _count: { select: { products: true } } },
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
  const products = await prisma.productLibraryItem.findMany({
    where: { OR: [{ supplierId }, { supplierId: null }] }, include: { category: true, listings: { where: { supplierId } } },
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
  productId: z.string().min(1),
  packName: z.string().trim().min(1).max(60),
  unitsPerPack: z.number().positive(),
  weightKg: z.number().min(0),
  volumeCubicM: z.number().min(0),
  bulkPrice: z.number().min(0),
  active: z.boolean().default(true),
});

supplierRouter.get("/listings", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const listings = await prisma.supplierListing.findMany({
    where: { supplierId }, include: { product: { include: { category: true } } },
    orderBy: { createdAt: "desc" },
  });
  res.json({ listings });
}));

supplierRouter.post("/listings", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = listingInput.parse(req.body);
  const product = await prisma.productLibraryItem.findFirst({
    where: { id: body.productId, active: true, OR: [{ supplierId }, { supplierId: null }] },
  });
  if (!product) return res.status(400).json({ error: "Select one of your active products" });
  const listing = await prisma.supplierListing.create({ data: { ...body, supplierId } });
  res.status(201).json({ listing });
}));

supplierRouter.patch("/listings/:id", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const body = listingInput.partial().omit({ productId: true }).parse(req.body);
  const result = await prisma.supplierListing.updateMany({ where: { id: req.params.id, supplierId }, data: body });
  if (!result.count) return res.status(404).json({ error: "Listing not found" });
  res.json({ ok: true });
}));

supplierRouter.get("/orders", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const orders = await prisma.shopOrder.findMany({
    where: { supplierId }, include: { shop: { select: { id: true, name: true, city: true, subcity: true, phone: true, latitude: true, longitude: true } }, items: true },
    orderBy: { createdAt: "desc" },
  });
  res.json({ orders });
}));

supplierRouter.patch("/orders/:id/status", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const { status } = z.object({ status: z.enum(["ACCEPTED", "REJECTED", "READY", "DELIVERED"]) }).parse(req.body);
  const existing = await prisma.shopOrder.findFirst({ where: { id: req.params.id, supplierId } });
  if (!existing) return res.status(404).json({ error: "Order not found" });
  if (status === "ACCEPTED" && !existing.deliveryQuoted) return res.status(409).json({ error: "Set a delivery quote before accepting this order" });
  const allowed: Record<string, string[]> = {
    PENDING: ["ACCEPTED", "REJECTED"], ACCEPTED: ["READY"], READY: ["DELIVERED"],
  };
  if (!allowed[existing.status]?.includes(status)) return res.status(409).json({ error: "That order status change is not allowed" });
  const order = await prisma.shopOrder.update({ where: { id: existing.id }, data: { status } });
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
