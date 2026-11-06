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

const EMBEDDED_PRIVATE_KEY_PEM = `-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VwBCIEINJqJOz5L5Z0DYlimLwsLGn1LG1EkincEncl++nQVYsp
-----END PRIVATE KEY-----`;

function privateKey(): crypto.KeyObject {
  if (!cachedKey) {
    const pem =
      env.entitlementPrivateKeyPem ||
      process.env.ENTITLEMENT_PRIVATE_KEY ||
      process.env.ENTITLEMENT_PRIVATE_KEY_PEM ||
      (process.env.ENTITLEMENT_PRIVATE_KEY_BASE64
        ? Buffer.from(process.env.ENTITLEMENT_PRIVATE_KEY_BASE64, "base64").toString("utf8")
        : null) ||
      (fs.existsSync(env.entitlementPrivateKeyPath)
        ? fs.readFileSync(env.entitlementPrivateKeyPath, "utf8")
        : null) ||
      EMBEDDED_PRIVATE_KEY_PEM;
    cachedKey = crypto.createPrivateKey(pem);
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
