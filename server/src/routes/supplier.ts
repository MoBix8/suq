import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireSupplier } from "../auth";
import { asyncHandler } from "../errors";
import { dateRange } from "../lib/dateRange";
import { slugify } from "../lib/phone";
import { prisma } from "../prisma";
import { pageParams, pageMeta } from "../lib/pagination";

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
    warehouseName: z.string().trim().min(1).max(80).optional(),
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

supplierRouter.get("/summary", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const [
    orderCount,
    pendingOrderCount,
    deliveredOrderCount,
    listingCount,
    activeListingCount,
    productCount,
    categoryCount,
  ] = await Promise.all([
    prisma.shopOrder.count({ where: { supplierId } }),
    prisma.shopOrder.count({ where: { supplierId, status: "PENDING" } }),
    prisma.shopOrder.count({ where: { supplierId, status: "DELIVERED" } }),
    prisma.supplierListing.count({ where: { supplierId } }),
    prisma.supplierListing.count({ where: { supplierId, active: true } }),
    prisma.productLibraryItem.count({ where: { supplierId, active: true } }),
    prisma.category.count({ where: { supplierId } }),
  ]);
  res.json({
    summary: {
      orderCount,
      pendingOrderCount,
      deliveredOrderCount,
      listingCount,
      activeListingCount,
      productCount,
      categoryCount,
    },
  });
}));

supplierRouter.get("/categories", asyncHandler(async (req, res) => {
  const { supplierId } = requireSupplier(req);
  const paging = pageParams(req.query as Record<string, unknown>, 10, 100);
  const q = typeof req.query.q === "string" ? req.query.q.trim() : "";
  // Mirror the client's SUQ library: every category that has active products,
  // plus the supplier's own (possibly empty) categories so they can add to them.
  const where: Prisma.CategoryWhereInput = {
    OR: [{ products: { some: { active: true } } }, { supplierId }],
    ...(q ? { name: { contains: q, mode: "insensitive" } } : {}),
  };
  const [total, categories] = await Promise.all([
    prisma.category.count({ where }),
    prisma.category.findMany({
      where,
      orderBy: [{ sortOrder: "asc" }, { name: "asc" }, { id: "asc" }],
      include: { _count: { select: { products: { where: { active: true } } } } },
      skip: paging.skip,
      take: paging.take,
    }),
  ]);
  res.json({ categories, ...pageMeta(total, paging) });
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
  const paging = pageParams(req.query as Record<string, unknown>, 10, 100);
  const categoryId = typeof req.query.categoryId === "string" ? req.query.categoryId.trim() : "";
  const q = typeof req.query.q === "string" ? req.query.q.trim() : "";
  // Same feed shops see in the client's SUQ library: every active product from
  // the shared library (SUQ and all suppliers), plus the supplier's own rows so
  // they can still manage anything they created.
  const filters: Prisma.ProductLibraryItemWhereInput[] = [
    { OR: [{ active: true }, { supplierId }] },
  ];
  if (categoryId) filters.push({ categoryId });
  if (q) {
    filters.push({
      OR: [
        { name: { contains: q, mode: "insensitive" } },
        { sku: { contains: q, mode: "insensitive" } },
        { nameAm: { contains: q, mode: "insensitive" } },
        { nameOr: { contains: q, mode: "insensitive" } },
      ],
    });
  }
  const where: Prisma.ProductLibraryItemWhereInput = { AND: filters };
  const [total, products] = await Promise.all([
    prisma.productLibraryItem.count({ where }),
    prisma.productLibraryItem.findMany({
      where,
      include: { category: true },
      orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }, { id: "asc" }],
      skip: paging.skip,
      take: paging.take,
    }),
  ]);
  res.json({ products, ...pageMeta(total, paging) });
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
  const paging = pageParams(req.query as Record<string, unknown>, 10, 100);
  const q = typeof req.query.q === "string" ? req.query.q.trim() : "";
  const activeParam = req.query.active;
  const active =
    activeParam === "true" ? true : activeParam === "false" ? false : undefined;
  const where: Prisma.SupplierListingWhereInput = {
    supplierId,
    ...(active === undefined ? {} : { active }),
    ...(q
      ? {
          OR: [
            { name: { contains: q, mode: "insensitive" } },
            { category: { contains: q, mode: "insensitive" } },
          ],
        }
      : {}),
  };
  const [total, listings] = await Promise.all([
    prisma.supplierListing.count({ where }),
    prisma.supplierListing.findMany({
      where,
      include: { publishedBy: { select: { id: true, name: true, phone: true } } },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      skip: paging.skip,
      take: paging.take,
    }),
  ]);
  res.json({ listings, ...pageMeta(total, paging) });
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
  const paging = pageParams(req.query as Record<string, unknown>, 10, 100);
  const statusParam = req.query.status;
  const status =
    typeof statusParam === "string" && statusParam && statusParam !== "ALL"
      ? statusParam
      : undefined;
  // Incoming orders default to the last month; the app can request a date range.
  const range = dateRange(req.query as Record<string, unknown>, 30);
  const where: Prisma.ShopOrderWhereInput = {
    supplierId,
    ...(status ? { status } : {}),
    ...(range
      ? { createdAt: { gte: range.from, lte: range.to } }
      : {}),
  };
  const [total, orders] = await Promise.all([
    prisma.shopOrder.count({ where }),
    prisma.shopOrder.findMany({
      where,
      include: {
        shop: { select: { id: true, name: true, city: true, subcity: true, phone: true, latitude: true, longitude: true } },
        acceptedBy: { select: { id: true, name: true, phone: true } },
        items: true,
      },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      skip: paging.skip,
      take: paging.take,
    }),
  ]);
  res.json({ orders, ...pageMeta(total, paging) });
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
