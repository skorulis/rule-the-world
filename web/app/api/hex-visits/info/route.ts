import { NextResponse } from "next/server";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { getHexInfos } from "@/lib/visits/hex-info";
import { isVisitCell } from "@/lib/visits/visit-batch";

const maxInfoCells = 500;

export async function GET(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const cellsParam = new URL(request.url).searchParams.get("cells");
    const parts = [...new Set(cellsParam?.split(",") ?? [])];
    if (parts.length < 1 || parts.length > maxInfoCells
      || parts.some((part) => !isVisitCell(part))) {
      return jsonError("Invalid cells", 400);
    }
    const cells = parts.map((part) => BigInt(`0x${part}`));
    const infos = await getHexInfos(session.user.id, cells);

    return NextResponse.json({
      visits: cells.map((cell) => ({
        cell: cell.toString(16),
        ...infos.get(cell) ?? { totals: null, userVisit: null },
      })),
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Hex info lookup failed", undefined, "Unable to load hexagons");
  }
}
