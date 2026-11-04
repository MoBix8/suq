import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../auth";
import { asyncHandler } from "../errors";
import { prisma } from "../prisma";

export const catalogRouter = Router();

catalogRouter.use(requireAuth);

catalogRouter.get(
  "/library/categories",
  asyncHandler(async (_req, res) => {
    const categories = await prisma.category.findMany({
      orderBy: { sortOrder: "asc" },
      include: {
        _count: { select: { products: { where: { active: true } } } },
      },
    });
    res.json({
      categories: categories.map((c) => ({
        id: c.id,
        name: c.name,
        slug: c.slug,
        sortOrder: c.sortOrder,
        productCount: c._count.products,
      })),
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
    const products = await prisma.productLibraryItem.findMany({
      where: {
        active: true,
        ...(query.categoryId ? { categoryId: query.categoryId } : {}),
        ...(query.updatedSince ? { updatedAt: { gt: new Date(query.updatedSince) } } : {}),
        ...(query.q
          ? {
              OR: [
                { name: { contains: query.q } },
                { barcode: { contains: query.q } },
                { sku: { contains: query.q } },
              ],
            }
          : {}),
      },
      orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }],
      include: { category: { select: { id: true, name: true } } },
      take: 1000,
    });
    res.json({ products });
  }),
);
