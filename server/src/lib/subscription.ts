import type { Package, Subscription } from "@prisma/client";
import { prisma } from "../prisma";

export async function latestSubscription(shopId: string) {
  return prisma.subscription.findFirst({
    where: { shopId },
    orderBy: { createdAt: "desc" },
    include: { package: true },
  });
}

export async function activeSubscription(shopId: string, now = new Date()) {
  return prisma.subscription.findFirst({
    where: {
      shopId,
      status: "ACTIVE",
      startsAt: { lte: now },
      endsAt: { gt: now },
    },
    orderBy: { endsAt: "desc" },
    include: { package: true },
  });
}

export type SubscriptionDto = {
  id: string;
  status: string;
  packageName: string;
  months: number;
  startsAt: string | null;
  endsAt: string | null;
  active: boolean;
  daysLeft: number;
};

export function toSubscriptionDto(
  sub: (Subscription & { package?: Package | null }) | null,
  now = new Date(),
): SubscriptionDto | null {
  if (!sub) return null;
  const active =
    sub.status === "ACTIVE" &&
    !!sub.startsAt &&
    !!sub.endsAt &&
    sub.startsAt.getTime() <= now.getTime() &&
    sub.endsAt.getTime() > now.getTime();
  const daysLeft =
    sub.endsAt && active
      ? Math.max(0, Math.ceil((sub.endsAt.getTime() - now.getTime()) / 86_400_000))
      : 0;
  return {
    id: sub.id,
    status: active ? "ACTIVE" : sub.status,
    packageName: sub.package?.name ?? "SUQ",
    months: sub.package?.months ?? 0,
    startsAt: sub.startsAt?.toISOString() ?? null,
    endsAt: sub.endsAt?.toISOString() ?? null,
    active,
    daysLeft,
  };
}
