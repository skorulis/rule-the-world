import { count } from "drizzle-orm";
import { NextResponse } from "next/server";
import { hexVisit } from "@/db/schema";
import { db } from "@/lib/db";

export const dynamic = "force-dynamic";

export async function GET() {
  const [{ value }] = await db.select({ value: count() }).from(hexVisit);
  return NextResponse.json({ hexVisits: value });
}
