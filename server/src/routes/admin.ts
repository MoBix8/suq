import { Router } from "express";
import { z } from "zod";
import { requireAdmin } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { addMonths } from "../lib/date";
import { slugify } from "../lib/phone";
import { prisma } from "../prisma";

export const adminRouter = Router();

adminRouter.use(requireAdmin);

// ─── Dashboard ───────────────────────────────────────────────────────────────

adminRouter.get(
  "/dashboard",
  asyncHandler(async (_req, res) => {
    const now = new Date();
    const soon = new Date(now.getTime() + 7 * 86_400_000);

    const [totalShops, pendingPayments, revenue, activeSubs, recentPayments, totalPayments] =
      await Promise.all([
        prisma.shop.count(),
        prisma.payment.count({ where: { status: "PENDING" } }),
        prisma.payment.aggregate({
          where: { status: "APPROVED" },
          _sum: { amountEtb: true },
        }),
        prisma.subscription.findMany({
          where: { status: "ACTIVE", startsAt: { lte: now }, endsAt: { gt: now } },
          include: { shop: { include: { user: true } }, package: true },
          orderBy: { endsAt: "asc" },
        }),
        prisma.payment.findMany({
          orderBy: { submittedAt: "desc" },
          take: 8,
          include: { shop: true, package: true },
        }),
        prisma.payment.count(),
      ]);

    res.json({
      serverTime: now.toISOString(),
      stats: {
        totalShops,
        activeShops: new Set(activeSubs.map((s) => s.shopId)).size,
        pendingPayments,
        totalPayments,
        revenueEtb: revenue._sum.amountEtb ?? 0,
        expiringSoon: activeSubs.filter(
          (s) => !!s.endsAt && s.endsAt.getTime() <= soon.getTime(),
        ).length,
      },
      expiring: activeSubs
        .filter((s) => !!s.endsAt && s.endsAt.getTime() <= soon.getTime())
        .slice(0, 10)
        .map((s) => ({
          shopId: s.shopId,
          shopName: s.shop.name,
          ownerName: s.shop.user.name,
          phone: s.shop.user.phone,
          packageName: s.package.name,
          endsAt: s.endsAt,
        })),
      recentPayments,
    });
  }),
);

// ─── Payments ────────────────────────────────────────────────────────────────

adminRouter.get(
  "/payments",
  asyncHandler(async (req, res) => {
    const status = typeof req.query.status === "string" ? req.query.status : undefined;
    const payments = await prisma.payment.findMany({
      where: status ? { status } : {},
      orderBy: { submittedAt: "desc" },
      take: 100,
      include: {
        shop: { include: { user: true } },
        package: true,
        bankAccount: true,
      },
    });
    res.json({ payments });
  }),
);

adminRouter.post(
  "/payments/:id/approve",
  asyncHandler(async (req, res) => {
    const adminId = req.auth!.userId;
    const result = await prisma.$transaction(async (tx) => {
      const payment = await tx.payment.findUnique({
        where: { id: req.params.id },
        include: { package: true },
      });
      if (!payment) throw new AppError(404, "Payment not found");
      if (payment.status !== "PENDING") {
        throw new AppError(409, `Payment is already ${payment.status.toLowerCase()}`);
      }

      const now = new Date();
      const current = await tx.subscription.findFirst({
        where: {
          shopId: payment.shopId,
          status: "ACTIVE",
          startsAt: { lte: now },
          endsAt: { gt: now },
        },
        orderBy: { endsAt: "desc" },
      });

      let subscription;
      if (current && current.endsAt) {
        subscription = await tx.subscription.update({
          where: { id: current.id },
          data: {
            packageId: payment.packageId,
            status: "ACTIVE",
            endsAt: addMonths(current.endsAt, payment.package.months),
          },
        });
      } else {
        subscription = await tx.subscription.create({
          data: {
            shopId: payment.shopId,
            packageId: payment.packageId,
            status: "ACTIVE",
            startsAt: now,
            endsAt: addMonths(now, payment.package.months),
          },
        });
      }

      const updated = await tx.payment.update({
        where: { id: payment.id },
        data: {
          status: "APPROVED",
          reviewedAt: now,
          reviewedBy: adminId,
          subscriptionId: subscription.id,
        },
        include: { package: true, shop: true },
      });

      return { payment: updated, subscription };
    });

    res.json(result);
  }),
);

const rejectSchema = z.object({
  note: z.string().trim().max(500).optional(),
});

adminRouter.post(
  "/payments/:id/reject",
  asyncHandler(async (req, res) => {
    const body = rejectSchema.parse(req.body ?? {});
    const payment = await prisma.payment.findUnique({ where: { id: req.params.id } });
    if (!payment) throw new AppError(404, "Payment not found");
    if (payment.status !== "PENDING") {
      throw new AppError(409, `Payment is already ${payment.status.toLowerCase()}`);
    }
    const updated = await prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: "REJECTED",
        adminNote: body.note,
        reviewedAt: new Date(),
        reviewedBy: req.auth!.userId,
      },
    });
    res.json({ payment: updated });
  }),
);

// ─── Shops ───────────────────────────────────────────────────────────────────

adminRouter.get(
  "/shops",
  asyncHandler(async (_req, res) => {
    const now = new Date();
    const shops = await prisma.shop.findMany({
      orderBy: { createdAt: "desc" },
      include: {
        user: true,
        subscriptions: {
          orderBy: { createdAt: "desc" },
          take: 1,
          include: { package: true },
        },
        _count: { select: { sales: true, payments: true, customers: true } },
      },
    });

    res.json({
      shops: shops.map((shop) => {
        const sub = shop.subscriptions[0] ?? null;
        const active =
          !!sub &&
          sub.status === "ACTIVE" &&
          !!sub.startsAt &&
          !!sub.endsAt &&
          sub.startsAt <= now &&
          sub.endsAt > now;
        return {
          id: shop.id,
          name: shop.name,
          city: shop.city,
          subcity: shop.subcity,
          createdAt: shop.createdAt,
          owner: { id: shop.user.id, name: shop.user.name, phone: shop.user.phone },
          counts: shop._count,
          subscription: sub
            ? {
                id: sub.id,
                status: active ? "ACTIVE" : sub.status,
                packageName: sub.package.name,
                startsAt: sub.startsAt,
                endsAt: sub.endsAt,
                active,
                daysLeft:
                  active && sub.endsAt
                    ? Math.ceil((sub.endsAt.getTime() - now.getTime()) / 86_400_000)
                    : 0,
              }
            : null,
        };
      }),
    });
  }),
);

const grantSchema = z.object({
  months: z.number().int().min(1).max(36),
  note: z.string().trim().max(300).optional(),
});

adminRouter.post(
  "/shops/:id/grant",
  asyncHandler(async (req, res) => {
    const body = grantSchema.parse(req.body);
    const shop = await prisma.shop.findUnique({ where: { id: req.params.id } });
    if (!shop) throw new AppError(404, "Shop not found");
    const pkg = await prisma.package.findFirst({
      where: { active: true },
      orderBy: { months: "asc" },
    });
    if (!pkg) throw new AppError(400, "No active package exists");

    const now = new Date();
    const current = await prisma.subscription.findFirst({
      where: {
        shopId: shop.id,
        status: "ACTIVE",
        startsAt: { lte: now },
        endsAt: { gt: now },
      },
      orderBy: { endsAt: "desc" },
    });

    const subscription = current && current.endsAt
      ? await prisma.subscription.update({
          where: { id: current.id },
          data: { endsAt: addMonths(current.endsAt, body.months) },
        })
      : await prisma.subscription.create({
          data: {
            shopId: shop.id,
            packageId: pkg.id,
            status: "ACTIVE",
            startsAt: now,
            endsAt: addMonths(now, body.months),
          },
        });

    res.json({ subscription, note: body.note ?? null });
  }),
);

// ─── Packages ────────────────────────────────────────────────────────────────

const packageCreateSchema = z.object({
  name: z.string().trim().min(2).max(60),
  months: z.number().int().min(1).max(36),
  priceEtb: z.number().positive(),
  description: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).default(0),
  active: z.boolean().default(true),
});

const packageUpdateSchema = z.object({
  name: z.string().trim().min(2).max(60).optional(),
  months: z.number().int().min(1).max(36).optional(),
  priceEtb: z.number().positive().optional(),
  description: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).optional(),
  active: z.boolean().optional(),
});

adminRouter.get(
  "/packages",
  asyncHandler(async (_req, res) => {
    const packages = await prisma.package.findMany({
      orderBy: [{ sortOrder: "asc" }, { months: "asc" }],
      include: { _count: { select: { payments: true, subscriptions: true } } },
    });
    res.json({ packages });
  }),
);

adminRouter.post(
  "/packages",
  asyncHandler(async (req, res) => {
    const body = packageCreateSchema.parse(req.body);
    const code = `pkg_${Date.now().toString(36)}`;
    const pkg = await prisma.package.create({
      data: { ...body, description: body.description ?? null, code },
    });
    res.status(201).json({ package: pkg });
  }),
);

adminRouter.patch(
  "/packages/:id",
  asyncHandler(async (req, res) => {
    const body = packageUpdateSchema.parse(req.body);
    const pkg = await prisma.package.update({ where: { id: req.params.id }, data: body });
    res.json({ package: pkg });
  }),
);

adminRouter.delete(
  "/packages/:id",
  asyncHandler(async (req, res) => {
    const pkg = await prisma.package.update({
      where: { id: req.params.id },
      data: { active: false },
    });
    res.json({ package: pkg });
  }),
);

// ─── Bank accounts ───────────────────────────────────────────────────────────

const bankCreateSchema = z.object({
  bankName: z.string().trim().min(2).max(80),
  accountName: z.string().trim().min(2).max(120),
  accountNumber: z.string().trim().min(4).max(40),
  branch: z.string().trim().max(80).nullish(),
  instructions: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).default(0),
  active: z.boolean().default(true),
});

const bankUpdateSchema = z.object({
  bankName: z.string().trim().min(2).max(80).optional(),
  accountName: z.string().trim().min(2).max(120).optional(),
  accountNumber: z.string().trim().min(4).max(40).optional(),
  branch: z.string().trim().max(80).nullish(),
  instructions: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).optional(),
  active: z.boolean().optional(),
});

adminRouter.get(
  "/bank-accounts",
  asyncHandler(async (_req, res) => {
    const accounts = await prisma.bankAccount.findMany({
      orderBy: [{ sortOrder: "asc" }, { bankName: "asc" }],
      include: { _count: { select: { payments: true } } },
    });
    res.json({ accounts });
  }),
);

adminRouter.post(
  "/bank-accounts",
  asyncHandler(async (req, res) => {
    const body = bankCreateSchema.parse(req.body);
    const account = await prisma.bankAccount.create({
      data: {
        ...body,
        branch: body.branch ?? null,
        instructions: body.instructions ?? null,
        code: `bank_${Date.now().toString(36)}`,
      },
    });
    res.status(201).json({ account });
  }),
);

adminRouter.patch(
  "/bank-accounts/:id",
  asyncHandler(async (req, res) => {
    const body = bankUpdateSchema.parse(req.body);
    const account = await prisma.bankAccount.update({
      where: { id: req.params.id },
      data: body,
    });
    res.json({ account });
  }),
);

adminRouter.delete(
  "/bank-accounts/:id",
  asyncHandler(async (req, res) => {
    const account = await prisma.bankAccount.update({
      where: { id: req.params.id },
      data: { active: false },
    });
    res.json({ account });
  }),
);

// ─── Categories ──────────────────────────────────────────────────────────────

const categoryCreateSchema = z.object({
  name: z.string().trim().min(2).max(80),
  slug: z.string().trim().max(80).optional(),
  sortOrder: z.number().int().min(0).default(0),
});

const categoryUpdateSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  slug: z.string().trim().max(80).optional(),
  sortOrder: z.number().int().min(0).optional(),
});

adminRouter.get(
  "/library/categories",
  asyncHandler(async (_req, res) => {
    const categories = await prisma.category.findMany({
      orderBy: { sortOrder: "asc" },
      include: { _count: { select: { products: true } } },
    });
    res.json({ categories });
  }),
);

adminRouter.post(
  "/library/categories",
  asyncHandler(async (req, res) => {
    const body = categoryCreateSchema.parse(req.body);
    const category = await prisma.category.create({
      data: {
        name: body.name,
        slug: body.slug?.trim() || `${slugify(body.name)}-${Date.now().toString(36)}`,
        sortOrder: body.sortOrder,
      },
    });
    res.status(201).json({ category });
  }),
);

adminRouter.patch(
  "/library/categories/:id",
  asyncHandler(async (req, res) => {
    const body = categoryUpdateSchema.parse(req.body);
    const category = await prisma.category.update({
      where: { id: req.params.id },
      data: body,
    });
    res.json({ category });
  }),
);

adminRouter.delete(
  "/library/categories/:id",
  asyncHandler(async (req, res) => {
    const count = await prisma.productLibraryItem.count({
      where: { categoryId: req.params.id },
    });
    if (count > 0) {
      throw new AppError(409, "Move or delete the products in this category first");
    }
    await prisma.category.delete({ where: { id: req.params.id } });
    res.json({ ok: true });
  }),
);

// ─── Library products ────────────────────────────────────────────────────────

const libraryProductCreateSchema = z.object({
  categoryId: z.string().min(1),
  name: z.string().trim().min(2).max(120),
  sku: z.string().trim().max(40).optional(),
  barcode: z.string().trim().max(60).nullish(),
  unit: z.string().trim().max(20).default("pcs"),
  defaultSellingPrice: z.number().positive(),
  defaultBuyingPrice: z.number().nonnegative().nullish(),
  active: z.boolean().default(true),
});

const libraryProductUpdateSchema = z.object({
  categoryId: z.string().min(1).optional(),
  name: z.string().trim().min(2).max(120).optional(),
  sku: z.string().trim().max(40).optional(),
  barcode: z.string().trim().max(60).nullish(),
  unit: z.string().trim().max(20).optional(),
  defaultSellingPrice: z.number().positive().optional(),
  defaultBuyingPrice: z.number().nonnegative().nullish(),
  active: z.boolean().optional(),
});

adminRouter.get(
  "/library/products",
  asyncHandler(async (req, res) => {
    const categoryId = typeof req.query.categoryId === "string" ? req.query.categoryId : undefined;
    const q = typeof req.query.q === "string" ? req.query.q : undefined;
    const all = req.query.all === "true";
    const products = await prisma.productLibraryItem.findMany({
      where: {
        ...(all ? {} : { active: true }),
        ...(categoryId ? { categoryId } : {}),
        ...(q
          ? { OR: [{ name: { contains: q } }, { sku: { contains: q } }, { barcode: { contains: q } }] }
          : {}),
      },
      orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }],
      include: { category: { select: { id: true, name: true } } },
      take: 500,
    });
    res.json({ products });
  }),
);

adminRouter.post(
  "/library/products",
  asyncHandler(async (req, res) => {
    const body = libraryProductCreateSchema.parse(req.body);
    const product = await prisma.productLibraryItem.create({
      data: {
        categoryId: body.categoryId,
        name: body.name,
        sku: body.sku?.trim() || `ADM-${Date.now().toString(36).toUpperCase()}`,
        barcode: body.barcode ?? null,
        unit: body.unit,
        defaultSellingPrice: body.defaultSellingPrice,
        defaultBuyingPrice: body.defaultBuyingPrice ?? null,
        active: body.active,
      },
    });
    res.status(201).json({ product });
  }),
);

adminRouter.patch(
  "/library/products/:id",
  asyncHandler(async (req, res) => {
    const body = libraryProductUpdateSchema.parse(req.body);
    const product = await prisma.productLibraryItem.update({
      where: { id: req.params.id },
      data: { ...body, version: { increment: 1 } },
    });
    res.json({ product });
  }),
);

adminRouter.delete(
  "/library/products/:id",
  asyncHandler(async (req, res) => {
    const product = await prisma.productLibraryItem.update({
      where: { id: req.params.id },
      data: { active: false, version: { increment: 1 } },
    });
    res.json({ product });
  }),
);
