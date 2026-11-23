import { NextResponse } from "next/server";
import { serverError } from "@/lib/api/route-helpers";
import { calculateRankings } from "@/lib/rankings/calculate-rankings";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

export async function GET() {
  try {
    return NextResponse.json(await calculateRankings(), { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Debug calculate rankings failed", error, "Unable to calculate rankings");
  }
}

export const POST = GET;
