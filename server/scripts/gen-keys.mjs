import { generateKeyPairSync } from "node:crypto";
import fs from "node:fs";
const { publicKey, privateKey } = generateKeyPairSync("ed25519");
fs.writeFileSync("keys/entitlement-private.pem", privateKey.export({ type: "pkcs8", format: "pem" }));
const der = publicKey.export({ type: "spki", format: "der" });
const raw = der.subarray(der.length - 32);
fs.writeFileSync("keys/entitlement-public.b64", raw.toString("base64"));
console.log(raw.toString("base64"));
