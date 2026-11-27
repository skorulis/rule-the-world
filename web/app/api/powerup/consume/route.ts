import { getResolution, isValidCell } from "h3-js";
import { NextResponse } from "next/server";
import { jsonError, parsePositiveId, readJsonBody, requireSession, serverError } from "@/lib/api/route-helpers";
import { consumePowerUp, ConsumePowerUpError } from "@/lib/powerups/consume-powerup";
import { powerUpDefinition } from "@/lib/powerups/powerups";

export const dynamic = "force-dynamic";

const maxCells = 16;

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const body = await readJsonBody(request);
    if (body instanceof NextResponse) return body;

    const id = parsePositiveId(body.powerup);
    const definition = id === null ? undefined : powerUpDefinition(id);
    if (!definition) return jsonError("Unknown power-up", 400);

    const rawCells = body.cells;
    if (!Array.isArray(rawCells) || rawCells.length === 0 || rawCells.length > maxCells
      || !rawCells.every((cell) => typeof cell === "string")) {
      return jsonError("Invalid cells", 400);
    }
    if (!rawCells.every((cell) => isValidCell(cell) && getResolution(cell) === 10)) {
      return jsonError("Invalid cells", 400);
    }
    const cells = rawCells.map((cell) => BigInt(`0x${cell}`));

    const result = await consumePowerUp(session.user.id, definition, cells);
    return NextResponse.json(result, { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    if (error instanceof ConsumePowerUpError) return jsonError(error.message, error.status);
    return serverError("Power-up consume failed", error, "Unable to consume power-up");
  }
}
