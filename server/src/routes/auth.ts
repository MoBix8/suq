import bcrypt from "bcryptjs";
import { Router } from "express";
import { z } from "zod";
import { requireAuth, requireBoundDevice, signToken } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { phoneSchema, pinSchema } from "../lib/phone";
import { latestSubscription, toSubscriptionDto } from "../lib/subscription";
import { prisma } from "../prisma";

export const authRouter = Router();

const deviceIdSchema = z.string().trim().min(4).max(120);

const registerSchema = z.object({
  phone: phoneSchema,
  pin: pinSchema,
  name: z.string().trim().min(2).max(80),
  shopName: z.string().trim().min(2).max(120),
  city: z.string().trim().max(80).optional(),
  subcity: z.string().trim().max(80).optional(),
  deviceId: deviceIdSchema,
});

const loginSchema = z.object({
  phone: phoneSchema,
  pin: pinSchema,
  deviceId: deviceIdSchema.optional(),
});

function publicUser(user: { id: string; phone: string; name: string; role: string }) {
  return { id: user.id, phone: user.phone, name: user.name, role: user.role };
}

authRouter.post(
  "/register",
  asyncHandler(async (req, res) => {
    const body = registerSchema.parse(req.body);
    const existing = await prisma.user.findUnique({ where: { phone: body.phone } });
    if (existing) throw new AppError(409, "An account with this phone already exists");

    const pinHash = await bcrypt.hash(body.pin, 10);
    const user = await prisma.user.create({
      data: {
        phone: body.phone,
        pinHash,
        name: body.name,
        role: "OWNER",
        shop: {
          create: {
            name: body.shopName,
            city: body.city,
            subcity: body.subcity,
            phone: body.phone,
            boundDeviceId: body.deviceId,
            devices: { create: { deviceId: body.deviceId } },
          },
        },
      },
      include: { shop: true },
    });

    const token = signToken({
      userId: user.id,
      role: "OWNER",
      shopId: user.shop?.id,
      deviceId: body.deviceId,
    });

    res.status(201).json({
      token,
      user: publicUser(user),
      shop: user.shop,
      subscription: null,
      serverTime: new Date().toISOString(),
    });
  }),
);

authRouter.post(
  "/login",
  asyncHandler(async (req, res) => {
    const body = loginSchema.parse(req.body);
    const user = await prisma.user.findUnique({
      where: { phone: body.phone },
      include: { shop: true, supplier: true },
    });
    if (!user) throw new AppError(401, "Wrong phone number or PIN");

    const ok = await bcrypt.compare(body.pin, user.pinHash);
    if (!ok) throw new AppError(401, "Wrong phone number or PIN");

    let deviceId: string | undefined;
    if (user.role === "OWNER") {
      if (!body.deviceId) {
        throw new AppError(
          400,
          "A device identifier is required. Update the SUQ app and try again.",
        );
      }
      if (!user.shop) throw new AppError(403, "No shop linked to this account");

      deviceId = body.deviceId;
      if (!user.shop.boundDeviceId) {
        // Claim the device atomically so two simultaneous first logins cannot
        // both become the primary device.
        const claimed = await prisma.shop.updateMany({
          where: { id: user.shop.id, boundDeviceId: null },
          data: { boundDeviceId: deviceId },
        });
        if (claimed.count === 0) {
          const fresh = await prisma.shop.findUnique({
            where: { id: user.shop.id },
            select: { boundDeviceId: true },
          });
          if (fresh?.boundDeviceId !== deviceId) {
            throw new AppError(
              409,
              "This account is already active on another device. Contact SUQ support to reset it.",
            );
          }
        }
      } else if (user.shop.boundDeviceId !== deviceId) {
        throw new AppError(
          409,
          "This account is already active on another device. Contact SUQ support to reset it.",
        );
      }

      await prisma.device.upsert({
        where: { shopId_deviceId: { shopId: user.shop.id, deviceId } },
        update: { lastSeenAt: new Date() },
        create: { shopId: user.shop.id, deviceId },
      });
    }

    const subscription = user.shop ? await latestSubscription(user.shop.id) : null;
    const token = signToken({
      userId: user.id,
      role: user.role as "OWNER" | "ADMIN" | "SUPPLIER",
      shopId: user.shop?.id,
      ...(user.supplier ? { supplierId: user.supplier.id } : {}),
      ...(deviceId ? { deviceId } : {}),
    });

    res.json({
      token,
      user: publicUser(user),
      shop: user.shop,
      supplier: user.supplier,
      subscription: toSubscriptionDto(subscription),
      serverTime: new Date().toISOString(),
    });
  }),
);

authRouter.post(
  "/logout",
  requireAuth,
  asyncHandler(async (req, res) => {
    const auth = req.auth!;
    if (auth.role === "OWNER" && auth.shopId && auth.deviceId) {
      await prisma.$transaction([
        prisma.shop.updateMany({
          where: { id: auth.shopId, boundDeviceId: auth.deviceId },
          data: { boundDeviceId: null },
        }),
        prisma.device.deleteMany({
          where: { shopId: auth.shopId, deviceId: auth.deviceId },
        }),
      ]);
    }
    res.status(204).end();
  }),
);

authRouter.get(
  "/me",
  requireAuth,
  requireBoundDevice,
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({
      where: { id: req.auth!.userId },
      include: { shop: true },
    });
    if (!user) throw new AppError(404, "User not found");
    const subscription = user.shop ? await latestSubscription(user.shop.id) : null;
    res.json({
      user: publicUser(user),
      shop: user.shop,
      subscription: toSubscriptionDto(subscription),
      serverTime: new Date().toISOString(),
    });
  }),
);
