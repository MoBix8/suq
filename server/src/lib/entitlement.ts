import crypto from "node:crypto";
import fs from "node:fs";
import { env } from "../env";

export type EntitlementPayload = {
  v: 1;
  shopId: string;
  subscriptionId: string;
  packageName: string;
  startsAt: string;
  endsAt: string;
  issuedAt: string;
  leaseUntil: string;
  deviceId: string;
};

let cachedKey: crypto.KeyObject | null = null;

function privateKey(): crypto.KeyObject {
  if (!cachedKey) {
    if (env.entitlementPrivateKeyPem) {
      cachedKey = crypto.createPrivateKey(env.entitlementPrivateKeyPem);
    } else {
      if (!fs.existsSync(env.entitlementPrivateKeyPath)) {
        throw new Error(
          `Entitlement private key not found at ${env.entitlementPrivateKeyPath}. Run "npm run keys".`,
        );
      }
      cachedKey = crypto.createPrivateKey(fs.readFileSync(env.entitlementPrivateKeyPath));
    }
  }
  return cachedKey;
}

function base64url(input: Buffer): string {
  return input.toString("base64url");
}

/** Signs the exact UTF-8 payload bytes with Ed25519. */
export function signEntitlement(payload: EntitlementPayload): string {
  const json = JSON.stringify(payload);
  const signature = crypto.sign(null, Buffer.from(json, "utf8"), privateKey());
  return `${base64url(Buffer.from(json, "utf8"))}.${base64url(signature)}`;
}

/** Raw 32-byte Ed25519 public key, base64. Embed this in the Flutter client. */
export function entitlementPublicKeyBase64(): string {
  const der = crypto.createPublicKey(privateKey()).export({
    type: "spki",
    format: "der",
  }) as Buffer;
  return der.subarray(der.length - 32).toString("base64");
}
