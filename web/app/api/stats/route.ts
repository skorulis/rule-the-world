import { count } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexRegion, hexVisit } from "@/db/schema";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const [[{ value: hexVisits }], [{ value: hexRegions }]] = await Promise.all([
    db.select({ value: count() }).from(hexVisit),
    db.select({ value: count() }).from(hexRegion),
  ]);
  return NextResponse.json({ hexVisits, hexRegions });
}
