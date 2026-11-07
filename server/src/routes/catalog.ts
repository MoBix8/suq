import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireBoundDevice } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { pageMeta, pageParams } from "../lib/pagination";
import { prisma } from "../prisma";

export const catalogRouter = Router();

catalogRouter.use(requireAuth);
catalogRouter.use(requireBoundDevice);
catalogRouter.use((req, _res, next) => {
  if (req.auth?.role !== "OWNER") return next(new AppError(403, "Shop owner access required"));
  next();
});

catalogRouter.get(
  "/library/categories",
  asyncHandler(async (req, res) => {
    const paging = pageParams(req.query as Record<string, unknown>, 100, 200);
    const [total, categories] = await Promise.all([
      prisma.category.count({ where: { products: { some: { active: true, listings: { some: { active: true } } } } } }),
      prisma.category.findMany({
        where: { products: { some: { active: true, listings: { some: { active: true } } } } },
        skip: paging.skip,
        take: paging.take,
        orderBy: { sortOrder: "asc" },
        include: {
          _count: {
            select: {
              products: {
                where: { active: true, listings: { some: { active: true } } },
              },
            },
          },
        },
      }),
    ]);
    res.json({
      categories: categories.map((c) => ({
        id: c.id,
        name: c.name,
        slug: c.slug,
        sortOrder: c.sortOrder,
        productCount: c._count.products,
      })),
      ...pageMeta(total, paging),
    });
  }),
);

const productQuerySchema = z.object({
  updatedSince: z.string().datetime().optional(),
  categoryId: z.string().optional(),
  q: z.string().optional(),
});

catalogRouter.get(
  "/library/products",
  asyncHandler(async (req, res) => {
    const query = productQuerySchema.parse(req.query);
    const paging = pageParams(req.query as Record<string, unknown>, 50, 500);
    const where: Prisma.ProductLibraryItemWhereInput = {
      active: true,
      listings: { some: { active: true } },
      ...(query.categoryId ? { categoryId: query.categoryId } : {}),
      ...(query.updatedSince ? { updatedAt: { gt: new Date(query.updatedSince) } } : {}),
      ...(query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: "insensitive" } },
              { barcode: { contains: query.q, mode: "insensitive" } },
              { sku: { contains: query.q, mode: "insensitive" } },
            ],
          }
        : {}),
    };

    const [total, products] = await Promise.all([
      prisma.productLibraryItem.count({ where }),
      prisma.productLibraryItem.findMany({
        where,
        orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }],
        include: { category: { select: { id: true, name: true } } },
        skip: paging.skip,
        take: paging.take,
      }),
    ]);

    res.json({ products, ...pageMeta(total, paging) });
  }),
);
