import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "./env";
import { AppError } from "./errors";
import { prisma } from "./prisma";

export type AuthClaims = {
  userId: string;
  role: "OWNER" | "ADMIN";
  shopId?: string;
  deviceId?: string;
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      auth?: AuthClaims;
    }
  }
}

export function signToken(claims: AuthClaims): string {
  return jwt.sign(claims, env.jwtSecret, { expiresIn: "90d" });
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    next(new AppError(401, "Missing bearer token"));
    return;
  }
  try {
    const decoded = jwt.verify(header.slice(7), env.jwtSecret) as jwt.JwtPayload & AuthClaims;
    if (!decoded.userId || !decoded.role) {
      next(new AppError(401, "Invalid token"));
      return;
    }
    req.auth = {
      userId: decoded.userId,
      role: decoded.role,
      shopId: decoded.shopId,
      deviceId: decoded.deviceId,
    };
    next();
  } catch {
    next(new AppError(401, "Invalid or expired token"));
  }
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction) {
  requireAuth(req, _res, (err?: unknown) => {
    if (err) {
      next(err);
      return;
    }
    if (req.auth?.role !== "ADMIN") {
      next(new AppError(403, "Admin access required"));
      return;
    }
    next();
  });
}

/**
 * Owners are bound to one device. Admins are not device-bound so they can
 * review payments from any machine.
 */
export async function requireBoundDevice(
  req: Request,
  _res: Response,
  next: NextFunction,
) {
  try {
    const auth = req.auth;
    if (!auth) throw new AppError(401, "Not authenticated");
    if (auth.role === "ADMIN") {
      next();
      return;
    }
    if (!auth.shopId || !auth.deviceId) {
      throw new AppError(
        403,
        "This session is not linked to a device. Please log in again.",
      );
    }

    const shop = await prisma.shop.findUnique({
      where: { id: auth.shopId },
      select: { boundDeviceId: true },
    });
    if (!shop) throw new AppError(404, "Shop not found");
    if (shop.boundDeviceId !== auth.deviceId) {
      throw new AppError(
        403,
        "This account is active on another device. Contact SUQ support to reset it.",
      );
    }
    next();
  } catch (error) {
    next(error);
  }
}

export function requireShop(req: Request): AuthClaims & { shopId: string } {
  if (!req.auth) throw new AppError(401, "Not authenticated");
  if (!req.auth.shopId) throw new AppError(403, "No shop linked to this account");
  return req.auth as AuthClaims & { shopId: string };
}
