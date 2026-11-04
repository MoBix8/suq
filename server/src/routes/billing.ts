import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireShop } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { addDays } from "../lib/date";
import { signEntitlement } from "../lib/entitlement";
import {
  activeSubscription,
  latestSubscription,
  toSubscriptionDto,
} from "../lib/subscription";
import { prisma } from "../prisma";
import { env } from "../env";

export const billingRouter = Router();

billingRouter.use(requireAuth);

const submitPaymentSchema = z.object({
  packageId: z.string().min(1),
  bankAccountId: z.string().min(1),
  transactionRef: z.string().trim().min(4).max(80),
  note: z.string().trim().max(500).optional(),
});

billingRouter.post(
  "/payments",
  asyncHandler(async (req, res) => {
    const { shopId } = requireShop(req);
    const body = submitPaymentSchema.parse(req.body);

    const [pkg, bank] = await Promise.all([
      prisma.package.findUnique({ where: { id: body.packageId } }),
      prisma.bankAccount.findUnique({ where: { id: body.bankAccountId } }),
    ]);
    if (!pkg || !pkg.active) throw new AppError(404, "Package not available");
    if (!bank || !bank.active) throw new AppError(404, "Bank account not available");

    const duplicate = await prisma.payment.findUnique({
      where: { transactionRef: body.transactionRef },
    });
    if (duplicate) {
      throw new AppError(409, "This transaction number has already been submitted");
    }

    const pendingCount = await prisma.payment.count({
      where: { shopId, status: "PENDING" },
    });
    if (pendingCount >= 3) {
      throw new AppError(
        429,
        "You already have 3 pending payments. Wait for the admin to review them.",
      );
    }

    const payment = await prisma.payment.create({
      data: {
        shopId,
        packageId: pkg.id,
        bankAccountId: bank.id,
        amountEtb: pkg.priceEtb,
        transactionRef: body.transactionRef,
        note: body.note,
        status: "PENDING",
      },
      include: { package: true, bankAccount: true },
    });

    res.status(201).json({ payment });
  }),
);

billingRouter.get(
  "/payments/mine",
  asyncHandler(async (req, res) => {
    const { shopId } = requireShop(req);
    const payments = await prisma.payment.findMany({
      where: { shopId },
      orderBy: { submittedAt: "desc" },
      take: 30,
      include: { package: true, bankAccount: true },
    });
    res.json({ payments });
  }),
);

billingRouter.get(
  "/subscription/me",
  asyncHandler(async (req, res) => {
    const { shopId } = requireShop(req);
    const now = new Date();
    const [latest, active, payments] = await Promise.all([
      latestSubscription(shopId),
      activeSubscription(shopId, now),
      prisma.payment.findMany({
        where: { shopId },
        orderBy: { submittedAt: "desc" },
        take: 10,
        include: { package: true },
      }),
    ]);
    res.json({
      subscription: toSubscriptionDto(active ?? latest, now),
      active: !!active,
      latest: toSubscriptionDto(latest, now),
      payments,
      serverTime: now.toISOString(),
    });
  }),
);

const entitlementSchema = z.object({
  deviceId: z.string().min(4).max(120),
  appVersion: z.string().max(40).optional(),
});

billingRouter.post(
  "/subscription/entitlement",
  asyncHandler(async (req, res) => {
    const { shopId } = requireShop(req);
    const body = entitlementSchema.parse(req.body);
    const now = new Date();

    await prisma.device.upsert({
      where: { shopId_deviceId: { shopId, deviceId: body.deviceId } },
      update: {
        lastSeenAt: now,
        lastServerTime: now,
        appVersion: body.appVersion,
      },
      create: {
        shopId,
        deviceId: body.deviceId,
        appVersion: body.appVersion,
        lastSeenAt: now,
        lastServerTime: now,
      },
    });

    const sub = await activeSubscription(shopId, now);
    if (!sub || !sub.startsAt || !sub.endsAt) {
      const latest = await latestSubscription(shopId);
      res.json({
        serverTime: now.toISOString(),
        active: false,
        subscription: toSubscriptionDto(latest, now),
        token: null,
        leaseDays: env.leaseDays,
      });
      return;
    }

    const leaseUntil = new Date(
      Math.min(sub.endsAt.getTime(), addDays(now, env.leaseDays).getTime()),
    );

    const token = signEntitlement({
      v: 1,
      shopId,
      subscriptionId: sub.id,
      packageName: sub.package.name,
      startsAt: sub.startsAt.toISOString(),
      endsAt: sub.endsAt.toISOString(),
      issuedAt: now.toISOString(),
      leaseUntil: leaseUntil.toISOString(),
      deviceId: body.deviceId,
    });

    res.json({
      serverTime: now.toISOString(),
      active: true,
      subscription: toSubscriptionDto(sub, now),
      token,
      leaseDays: env.leaseDays,
      leaseUntil: leaseUntil.toISOString(),
    });
  }),
);
