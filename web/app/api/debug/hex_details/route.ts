import { latLngToCell } from "h3-js";
import { NextResponse } from "next/server";
import { serverError } from "@/lib/api/route-helpers";
import { getOrCreateHexDetails } from "@/lib/regions/hex-details";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const latitude = Math.asin(2 * Math.random() - 1) * 180 / Math.PI;
    const longitude = Math.random() * 360 - 180;
    const cell = BigInt(`0x${latLngToCell(latitude, longitude, 10)}`);
    const details = await getOrCreateHexDetails(cell);
    return NextResponse.json({
      cell: details.cell.toString(16),
      region_country: details.regionCountry?.toString() ?? null,
      region_state: details.regionState?.toString() ?? null,
      region_suburb: details.regionSuburb?.toString() ?? null,
    }, { headers: { "Cache-Control": "private, no-store" } });
  } catch {
    return serverError("Debug hex details failed", undefined, "Unable to load hex details");
  }
}
