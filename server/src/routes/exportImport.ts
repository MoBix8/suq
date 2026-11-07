import { Router } from "express";
import { z } from "zod";
import { requireAdmin } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { prisma } from "../prisma";

export const exportImportRouter = Router();

exportImportRouter.use(requireAdmin);

// ─── Export ───────────────────────────────────────────────────────────────────

exportImportRouter.get(
  "/export/categories",
  asyncHandler(async (_req, res) => {
    const categories = await prisma.category.findMany({ orderBy: { sortOrder: "asc" } });
    res.json({ categories: categories.map((c) => ({ name: c.name, slug: c.slug, sortOrder: c.sortOrder })) });
  }),
);

exportImportRouter.get(
  "/export/bank-accounts",
  asyncHandler(async (_req, res) => {
    const accounts = await prisma.bankAccount.findMany({ orderBy: { bankName: "asc" } });
    res.json({
      bankAccounts: accounts.map((a) => ({
        code: a.code,
        bankName: a.bankName,
        accountName: a.accountName,
        accountNumber: a.accountNumber,
        branch: a.branch,
        instructions: a.instructions,
        active: a.active,
      })),
    });
  }),
);

exportImportRouter.get(
  "/export/packages",
  asyncHandler(async (_req, res) => {
    const packages = await prisma.package.findMany({ orderBy: { sortOrder: "asc" } });
    res.json({
      packages: packages.map((p) => ({
        code: p.code,
        name: p.name,
        months: p.months,
        priceEtb: p.priceEtb,
        description: p.description,
        sortOrder: p.sortOrder,
        active: p.active,
      })),
    });
  }),
);

exportImportRouter.get(
  "/export/products",
  asyncHandler(async (_req, res) => {
    const products = await prisma.productLibraryItem.findMany({
      include: { category: { select: { slug: true, name: true } } },
      orderBy: [{ category: { sortOrder: "asc" } }, { name: "asc" }],
    });
    res.json({
      products: products.map((p) => ({
        sku: p.sku,
        categorySlug: p.category.slug,
        categoryName: p.category.name,
        name: p.name,
        nameAm: p.nameAm,
        nameOr: p.nameOr,
        barcode: p.barcode,
        unit: p.unit,
        defaultSellingPrice: p.defaultSellingPrice,
        defaultBuyingPrice: p.defaultBuyingPrice,
        active: p.active,
        version: p.version,
      })),
    });
  }),
);

// ─── Import ───────────────────────────────────────────────────────────────────

const categoryImportSchema = z.object({
  name: z.string().trim().min(2).max(80),
  slug: z.string().trim().min(2).max(80),
  sortOrder: z.number().int().min(0).default(0),
});

exportImportRouter.post(
  "/import/categories",
  asyncHandler(async (req, res) => {
    const body = z.object({ categories: z.array(categoryImportSchema) }).parse(req.body);
    let created = 0;
    let updated = 0;
    for (const item of body.categories) {
      const existing = await prisma.category.findFirst({ where: { slug: item.slug, supplierId: null } });
      if (existing) {
        await prisma.category.update({ where: { id: existing.id }, data: { name: item.name, sortOrder: item.sortOrder } });
        updated += 1;
      } else {
        await prisma.category.create({ data: { name: item.name, slug: item.slug, sortOrder: item.sortOrder } });
        created += 1;
      }
    }
    res.json({ created, updated, total: body.categories.length });
  }),
);

const bankAccountImportSchema = z.object({
  code: z.string().trim().min(2).max(60),
  bankName: z.string().trim().min(2).max(80),
  accountName: z.string().trim().min(2).max(120),
  accountNumber: z.string().trim().min(2).max(80),
  branch: z.string().trim().max(80).nullish(),
  instructions: z.string().trim().max(300).nullish(),
  active: z.boolean().default(true),
});

exportImportRouter.post(
  "/import/bank-accounts",
  asyncHandler(async (req, res) => {
    const body = z.object({ bankAccounts: z.array(bankAccountImportSchema) }).parse(req.body);
    let created = 0;
    let updated = 0;
    for (const item of body.bankAccounts) {
      const existing = await prisma.bankAccount.findUnique({ where: { code: item.code } });
      if (existing) {
        await prisma.bankAccount.update({
          where: { code: item.code },
          data: {
            bankName: item.bankName,
            accountName: item.accountName,
            accountNumber: item.accountNumber,
            branch: item.branch ?? null,
            instructions: item.instructions ?? null,
            active: item.active,
          },
        });
        updated += 1;
      } else {
        await prisma.bankAccount.create({
          data: {
            code: item.code,
            bankName: item.bankName,
            accountName: item.accountName,
            accountNumber: item.accountNumber,
            branch: item.branch ?? null,
            instructions: item.instructions ?? null,
            active: item.active,
          },
        });
        created += 1;
      }
    }
    res.json({ created, updated, total: body.bankAccounts.length });
  }),
);

const packageImportSchema = z.object({
  code: z.string().trim().min(2).max(60),
  name: z.string().trim().min(2).max(80),
  months: z.number().int().min(1).max(36),
  priceEtb: z.number().positive(),
  description: z.string().trim().max(300).nullish(),
  sortOrder: z.number().int().min(0).default(0),
  active: z.boolean().default(true),
});

exportImportRouter.post(
  "/import/packages",
  asyncHandler(async (req, res) => {
    const body = z.object({ packages: z.array(packageImportSchema) }).parse(req.body);
    let created = 0;
    let updated = 0;
    for (const item of body.packages) {
      const existing = await prisma.package.findUnique({ where: { code: item.code } });
      if (existing) {
        await prisma.package.update({
          where: { code: item.code },
          data: {
            name: item.name,
            months: item.months,
            priceEtb: item.priceEtb,
            description: item.description ?? null,
            sortOrder: item.sortOrder,
            active: item.active,
          },
        });
        updated += 1;
      } else {
        await prisma.package.create({
          data: {
            code: item.code,
            name: item.name,
            months: item.months,
            priceEtb: item.priceEtb,
            description: item.description ?? null,
            sortOrder: item.sortOrder,
            active: item.active,
          },
        });
        created += 1;
      }
    }
    res.json({ created, updated, total: body.packages.length });
  }),
);

const productImportSchema = z.object({
  sku: z.string().trim().min(2).max(60),
  categorySlug: z.string().trim().min(2).max(80),
  name: z.string().trim().min(2).max(120),
  nameAm: z.string().trim().max(120).nullish(),
  nameOr: z.string().trim().max(120).nullish(),
  barcode: z.string().trim().max(80).nullish(),
  unit: z.string().trim().min(1).max(40),
  defaultSellingPrice: z.number().positive(),
  defaultBuyingPrice: z.number().positive().nullish(),
  active: z.boolean().default(true),
  version: z.number().int().min(1).default(1),
});

exportImportRouter.post(
  "/import/products",
  asyncHandler(async (req, res) => {
    const body = z.object({ products: z.array(productImportSchema) }).parse(req.body);
    let created = 0;
    let updated = 0;
    let skipped = 0;
    for (const item of body.products) {
      const category = await prisma.category.findFirst({ where: { slug: item.categorySlug, supplierId: null } });
      if (!category) {
        skipped += 1;
        continue;
      }
      const existing = await prisma.productLibraryItem.findUnique({ where: { sku: item.sku } });
      if (existing) {
        await prisma.productLibraryItem.update({
          where: { sku: item.sku },
          data: {
            categoryId: category.id,
            name: item.name,
            nameAm: item.nameAm ?? null,
            nameOr: item.nameOr ?? null,
            barcode: item.barcode ?? null,
            unit: item.unit,
            defaultSellingPrice: item.defaultSellingPrice,
            defaultBuyingPrice: item.defaultBuyingPrice ?? null,
            active: item.active,
            version: item.version,
          },
        });
        updated += 1;
      } else {
        await prisma.productLibraryItem.create({
          data: {
            sku: item.sku,
            categoryId: category.id,
            name: item.name,
            nameAm: item.nameAm ?? null,
            nameOr: item.nameOr ?? null,
            barcode: item.barcode ?? null,
            unit: item.unit,
            defaultSellingPrice: item.defaultSellingPrice,
            defaultBuyingPrice: item.defaultBuyingPrice ?? null,
            active: item.active,
            version: item.version,
          },
        });
        created += 1;
      }
    }
    res.json({ created, updated, skipped, total: body.products.length });
  }),
);
