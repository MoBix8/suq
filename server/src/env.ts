import "dotenv/config";
import path from "node:path";

const leaseDays = Number(process.env.LEASE_DAYS ?? 7);

export const env = {
  port: Number(process.env.PORT ?? 4000),
  jwtSecret: process.env.JWT_SECRET ?? "dev-secret-change-me",
  corsOrigin: process.env.CORS_ORIGIN ?? "*",
  entitlementPrivateKeyPath: path.resolve(
    process.env.ENTITLEMENT_PRIVATE_KEY_PATH ?? "./keys/entitlement-private.pem",
  ),
  entitlementPrivateKeyPem: process.env.ENTITLEMENT_PRIVATE_KEY ?? null,
  leaseDays: Number.isFinite(leaseDays) && leaseDays > 0 ? leaseDays : 7,
};
