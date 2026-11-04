import bcrypt from "bcryptjs";
import { Router } from "express";
import { z } from "zod";
import { requireAuth, signToken } from "../auth";
import { AppError, asyncHandler } from "../errors";
import { phoneSchema, pinSchema } from "../lib/phone";
import { latestSubscription, toSubscriptionDto } from "../lib/subscription";
import { prisma } from "../prisma";

export const authRouter = Router();

const registerSchema = z.object({
  phone: phoneSchema,
  pin: pinSchema,
  name: z.string().trim().min(2).max(80),
  shopName: z.string().trim().min(2).max(120),
  city: z.string().trim().max(80).optional(),
  subcity: z.string().trim().max(80).optional(),
});

const loginSchema = z.object({
  phone: phoneSchema,
  pin: pinSchema,
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
          },
        },
      },
      include: { shop: true },
    });

    const token = signToken({
      userId: user.id,
      role: "OWNER",
      shopId: user.shop?.id,
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
      include: { shop: true },
    });
    if (!user) throw new AppError(401, "Wrong phone number or PIN");

    const ok = await bcrypt.compare(body.pin, user.pinHash);
    if (!ok) throw new AppError(401, "Wrong phone number or PIN");

    const subscription = user.shop ? await latestSubscription(user.shop.id) : null;
    const token = signToken({
      userId: user.id,
      role: user.role as "OWNER" | "ADMIN",
      shopId: user.shop?.id,
    });

    res.json({
      token,
      user: publicUser(user),
      shop: user.shop,
      subscription: toSubscriptionDto(subscription),
      serverTime: new Date().toISOString(),
    });
  }),
);

authRouter.get(
  "/me",
  requireAuth,
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
