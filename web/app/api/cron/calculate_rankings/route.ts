import { NextResponse } from "next/server";
import { jsonError, serverError } from "@/lib/api/route-helpers";
import { calculateRankings } from "@/lib/rankings/calculate-rankings";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET;
  if (secret && request.headers.get("authorization") !== `Bearer ${secret}`) {
    return jsonError("Unauthorized", 401);
  }
  try {
    return NextResponse.json(await calculateRankings(), { headers: { "Cache-Control": "private, no-store" } });
  } catch (error) {
    return serverError("Cron calculate rankings failed", error, "Unable to calculate rankings");
  }
}
