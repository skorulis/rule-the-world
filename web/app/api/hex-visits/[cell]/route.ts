import { NextResponse } from "next/server";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { getHexInfo } from "@/lib/visits/hex-info";
import { isVisitCell } from "@/lib/visits/visit-batch";

export async function GET(request: Request, ctx: RouteContext<"/api/hex-visits/[cell]">) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const { cell: cellParam } = await ctx.params;
    if (!isVisitCell(cellParam)) return jsonError("Invalid cell", 400);
    const cell = BigInt(`0x${cellParam}`);

    return NextResponse.json(await getHexInfo(session.user.id, cell), {
      headers: { "Cache-Control": "private, no-store" },
    });
  } catch {
    return serverError("Hex totals lookup failed", undefined, "Unable to load hexagon");
  }
}
