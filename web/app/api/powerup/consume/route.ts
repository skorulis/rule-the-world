import { latLngToCell } from "h3-js";
import { NextResponse } from "next/server";
import { jsonError, parsePositiveId, readJsonBody, requireSession, serverError } from "@/lib/api/route-helpers";
import { consumePowerUp, ConsumePowerUpError } from "@/lib/powerups/consume-powerup";
import { powerUpDefinition } from "@/lib/powerups/powerups";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const body = await readJsonBody(request);
    if (body instanceof NextResponse) return body;

    const id = parsePositiveId(body.powerup);
    const definition = id === null ? undefined : powerUpDefinition(id);
    if (!definition) return jsonError("Unknown power-up", 400);

    const location = (body.location ?? {}) as Record<string, unknown>;
    const { latitude, longitude } = location;
    if (typeof latitude !== "number" || typeof longitude !== "number"
      || !Number.isFinite(latitude) || !Number.isFinite(longitude)
      || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
      return jsonError("Invalid location", 400);
    }

    const cell = BigInt(`0x${latLngToCell(latitude, longitude, 10)}`);
    const result = await consumePowerUp(session.user.id, definition, cell);
    return NextResponse.json(result, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    if (error instanceof ConsumePowerUpError) return jsonError(error.message, error.status);
    return serverError("Power-up consume failed", error, "Unable to consume power-up");
  }
}
