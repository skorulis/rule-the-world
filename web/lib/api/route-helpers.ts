import { NextResponse } from "next/server";

export function jsonError(error: string, status: number): NextResponse {
  return NextResponse.json({ error }, { status });
}

export function serverError(
  logMessage: string,
  error: unknown,
  publicMessage: string = logMessage,
): NextResponse {
  console.error(logMessage, error);
  return jsonError(publicMessage, 500);
}

/** Parses the JSON body, or returns a 400 response to return as-is. */
export async function readJsonBody<T = Record<string, unknown>>(
  request: Request,
): Promise<T | NextResponse> {
  try {
    return (await request.json()) as T;
  } catch {
    return jsonError("Invalid JSON body", 400);
  }
}

/** Accepts a positive integer as a number or numeric string (route params, JSON ids). */
export function parsePositiveId(value: unknown): number | null {
  const id =
    typeof value === "number"
      ? value
      : typeof value === "string" && value.trim() !== ""
        ? Number(value)
        : NaN;
  return Number.isInteger(id) && id > 0 ? id : null;
}

export type OptionalTextResult =
  | { ok: true; value: string | null }
  | { ok: false; reason: "invalid" | "tooLong" };

/** Optional free text: trimmed, empty becomes null, capped at `maxLength`. */
export function parseOptionalText(
  value: unknown,
  maxLength: number,
): OptionalTextResult {
  if (value === undefined || value === null) {
    return { ok: true, value: null };
  }
  if (typeof value !== "string") {
    return { ok: false, reason: "invalid" };
  }

  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    return { ok: false, reason: "tooLong" };
  }
  return { ok: true, value: trimmed.length > 0 ? trimmed : null };
}
