import { addDays } from "./date";

export type DateRange = { from: Date; to: Date };

function parseDate(value: unknown, endOfDay = false): Date | null {
  if (typeof value !== "string" || !value.trim()) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  // Date-only values are treated as an entire UTC day (e.g. 2026-11-16).
  if (endOfDay && /^\d{4}-\d{2}-\d{2}$/.test(value.trim())) {
    date.setUTCHours(23, 59, 59, 999);
  }
  return date;
}

/**
 * Reads `from`/`to` ISO dates from a query object.
 *
 * When `defaultDays` is provided and the caller sends neither date, the range
 * falls back to the last `defaultDays` days. Passing no `defaultDays` keeps the
 * filter optional.
 */
export function dateRange(
  query: Record<string, unknown>,
  defaultDays?: number,
): DateRange | null {
  const from = parseDate(query.from);
  const to = parseDate(query.to, true);
  if (!from && !to && defaultDays == null) return null;

  const now = new Date();
  const start =
    from ?? (defaultDays == null ? new Date(0) : addDays(now, -defaultDays));
  const end = to ?? now;

  return start.getTime() <= end.getTime()
    ? { from: start, to: end }
    : { from: end, to: start };
}
