import { Router } from "express";
import { asyncHandler } from "../errors";
import { prisma } from "../prisma";

export const publicRouter = Router();

publicRouter.get("/time", (_req, res) => {
  res.json({ serverTime: new Date().toISOString() });
});

publicRouter.get(
  "/packages",
  asyncHandler(async (_req, res) => {
    const packages = await prisma.package.findMany({
      where: { active: true },
      orderBy: [{ sortOrder: "asc" }, { months: "asc" }],
    });
    res.json({ packages });
  }),
);

publicRouter.get(
  "/bank-accounts",
  asyncHandler(async (_req, res) => {
    const accounts = await prisma.bankAccount.findMany({
      where: { active: true },
      orderBy: [{ sortOrder: "asc" }, { bankName: "asc" }],
    });
    res.json({ accounts });
  }),
);
