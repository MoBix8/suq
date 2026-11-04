import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "./env";
import { AppError } from "./errors";

export type AuthClaims = {
  userId: string;
  role: "OWNER" | "ADMIN";
  shopId?: string;
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

export function requireShop(req: Request): AuthClaims & { shopId: string } {
  if (!req.auth) throw new AppError(401, "Not authenticated");
  if (!req.auth.shopId) throw new AppError(403, "No shop linked to this account");
  return req.auth as AuthClaims & { shopId: string };
}
