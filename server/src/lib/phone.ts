import { z } from "zod";

export function normalizePhone(raw: string): string {
  let phone = raw.replace(/[\s()-]/g, "");
  if (phone.startsWith("+251")) phone = `0${phone.slice(4)}`;
  else if (phone.startsWith("251")) phone = `0${phone.slice(3)}`;
  return phone;
}

export const phoneSchema = z
  .string()
  .min(9)
  .transform(normalizePhone)
  .refine((value) => /^0[79]\d{8}$/.test(value), "Enter a valid Ethiopian phone number");

export const pinSchema = z
  .string()
  .regex(/^\d{4,6}$/, "PIN must be 4 to 6 digits");

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
}
