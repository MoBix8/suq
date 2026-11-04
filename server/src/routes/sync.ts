import { Prisma } from "@prisma/client";
import { Router } from "express";
import { z } from "zod";
import { requireShop } from "../auth";
import { asyncHandler } from "../errors";
import { prisma } from "../prisma";

export const syncRouter = Router();

const customerSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  phone: z.string().nullish(),
  creditBalance: z.number().default(0),
  deleted: z.boolean().default(false),
  createdAt: z.string().datetime().optional(),
  updatedAt: z.string().datetime().optional(),
});

const productSchema = z.object({
  id: z.string().min(1),
  libraryItemId: z.string().nullish(),
  name: z.string().min(1),
  barcode: z.string().nullish(),
  unit: z.string().default("pcs"),
  sellingPrice: z.number(),
  buyingPrice: z.number().nullish(),
  stockQty: z.number().default(0),
  lowStockThreshold: z.number().default(0),
  custom: z.boolean().default(false),
  deleted: z.boolean().default(false),
  updatedAt: z.string().datetime().optional(),
});

const saleItemSchema = z.object({
  id: z.string().min(1),
  productId: z.string().nullish(),
  name: z.string().min(1),
  unit: z.string().default("pcs"),
  qty: z.number(),
  unitPrice: z.number(),
  unitCost: z.number().nullish(),
  lineTotal: z.number(),
});

const saleSchema = z.object({
  id: z.string().min(1),
  receiptNo: z.string().min(1),
  customerId: z.string().nullish(),
  customerName: z.string().nullish(),
  subtotal: z.number(),
  discount: z.number().default(0),
  total: z.number(),
  paid: z.number(),
  credit: z.number().default(0),
  cost: z.number().default(0),
  profit: z.number().default(0),
  paymentMethod: z.string(),
  soldAt: z.string().datetime(),
  items: z.array(saleItemSchema).min(1),
});

const creditEntrySchema = z.object({
  id: z.string().min(1),
  customerId: z.string().min(1),
  saleId: z.string().nullish(),
  type: z.enum(["CREDIT", "PAYMENT", "ADJUSTMENT"]),
  amount: z.number(),
  note: z.string().nullish(),
  createdAt: z.string().datetime().optional(),
});

const syncSchema = z.object({
  deviceId: z.string().min(4).max(120),
  appVersion: z.string().max(40).optional(),
  customers: z.array(customerSchema).default([]),
  products: z.array(productSchema).default([]),
  sales: z.array(saleSchema).default([]),
  creditEntries: z.array(creditEntrySchema).default([]),
});

syncRouter.post(
  "/sync",
  asyncHandler(async (req, res) => {
    const { shopId } = requireShop(req);
    const body = syncSchema.parse(req.body);
    const now = new Date();

    const accepted = { customers: 0, products: 0, sales: 0, creditEntries: 0 };
    const skipped = { customers: 0, products: 0, sales: 0, creditEntries: 0 };

    // 1. Customers (sales may reference them)
    for (const c of body.customers) {
      const existing = await prisma.customer.findUnique({ where: { id: c.id } });
      if (existing && existing.shopId !== shopId) {
        skipped.customers += 1;
        continue;
      }
      await prisma.customer.upsert({
        where: { id: c.id },
        update: {
          name: c.name,
          phone: c.phone ?? null,
          creditBalance: c.creditBalance,
          deleted: c.deleted,
          ...(c.updatedAt ? { updatedAt: new Date(c.updatedAt) } : {}),
        },
        create: {
          id: c.id,
          shopId,
          name: c.name,
          phone: c.phone ?? null,
          creditBalance: c.creditBalance,
          deleted: c.deleted,
          ...(c.createdAt ? { createdAt: new Date(c.createdAt) } : {}),
          ...(c.updatedAt ? { updatedAt: new Date(c.updatedAt) } : {}),
        },
      });
      accepted.customers += 1;
    }

    // 2. Products
    for (const p of body.products) {
      const existing = await prisma.shopProduct.findUnique({ where: { id: p.id } });
      if (existing && existing.shopId !== shopId) {
        skipped.products += 1;
        continue;
      }
      try {
        await prisma.shopProduct.upsert({
          where: { id: p.id },
          update: {
            name: p.name,
            barcode: p.barcode ?? null,
            unit: p.unit,
            sellingPrice: p.sellingPrice,
            buyingPrice: p.buyingPrice ?? null,
            stockQty: p.stockQty,
            lowStockThreshold: p.lowStockThreshold,
            deleted: p.deleted,
            ...(p.updatedAt ? { updatedAt: new Date(p.updatedAt) } : {}),
          },
          create: {
            id: p.id,
            shopId,
            libraryItemId: p.libraryItemId ?? null,
            name: p.name,
            barcode: p.barcode ?? null,
            unit: p.unit,
            sellingPrice: p.sellingPrice,
            buyingPrice: p.buyingPrice ?? null,
            stockQty: p.stockQty,
            lowStockThreshold: p.lowStockThreshold,
            custom: p.custom,
            deleted: p.deleted,
            ...(p.updatedAt ? { updatedAt: new Date(p.updatedAt) } : {}),
          },
        });
        accepted.products += 1;
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
          skipped.products += 1;
          continue;
        }
        throw error;
      }
    }

    // 3. Sales (immutable, idempotent by client UUID)
    for (const s of body.sales) {
      const existing = await prisma.sale.findUnique({ where: { id: s.id } });
      if (existing) {
        skipped.sales += 1;
        continue;
      }
      let customerId: string | null = null;
      if (s.customerId) {
        const customer = await prisma.customer.findUnique({ where: { id: s.customerId } });
        if (customer && customer.shopId === shopId) customerId = customer.id;
      }
      try {
        await prisma.sale.create({
          data: {
            id: s.id,
            shopId,
            receiptNo: s.receiptNo,
            customerId,
            customerName: s.customerName ?? null,
            subtotal: s.subtotal,
            discount: s.discount,
            total: s.total,
            paid: s.paid,
            credit: s.credit,
            cost: s.cost,
            profit: s.profit,
            paymentMethod: s.paymentMethod,
            soldAt: new Date(s.soldAt),
            items: {
              create: s.items.map((item) => ({
                id: item.id,
                productId: item.productId ?? null,
                name: item.name,
                unit: item.unit,
                qty: item.qty,
                unitPrice: item.unitPrice,
                unitCost: item.unitCost ?? null,
                lineTotal: item.lineTotal,
              })),
            },
          },
        });
        accepted.sales += 1;
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
          skipped.sales += 1;
          continue;
        }
        throw error;
      }
    }

    // 4. Credit ledger
    for (const entry of body.creditEntries) {
      const existing = await prisma.creditEntry.findUnique({ where: { id: entry.id } });
      if (existing) {
        skipped.creditEntries += 1;
        continue;
      }
      const customer = await prisma.customer.findUnique({ where: { id: entry.customerId } });
      if (!customer || customer.shopId !== shopId) {
        skipped.creditEntries += 1;
        continue;
      }
      let saleId: string | null = null;
      if (entry.saleId) {
        const sale = await prisma.sale.findUnique({ where: { id: entry.saleId } });
        if (sale && sale.shopId === shopId) saleId = sale.id;
      }
      await prisma.creditEntry.create({
        data: {
          id: entry.id,
          shopId,
          customerId: entry.customerId,
          saleId,
          type: entry.type,
          amount: entry.amount,
          note: entry.note ?? null,
          ...(entry.createdAt ? { createdAt: new Date(entry.createdAt) } : {}),
        },
      });
      accepted.creditEntries += 1;
    }

    await prisma.device.upsert({
      where: { shopId_deviceId: { shopId, deviceId: body.deviceId } },
      update: { lastSeenAt: now, lastServerTime: now, appVersion: body.appVersion },
      create: {
        shopId,
        deviceId: body.deviceId,
        appVersion: body.appVersion,
        lastSeenAt: now,
        lastServerTime: now,
      },
    });

    const logRows = [
      ...body.sales.map((s) => ({ shopId, deviceId: body.deviceId, entity: "sale", entityId: s.id })),
      ...body.customers.map((c) => ({ shopId, deviceId: body.deviceId, entity: "customer", entityId: c.id })),
    ];
    if (logRows.length) await prisma.syncLog.createMany({ data: logRows });

    res.json({ accepted, skipped, serverTime: now.toISOString() });
  }),
);
