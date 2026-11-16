import { NextResponse } from "next/server";
import pkg from "@/package.json";

export const dynamic = "force-dynamic";

export async function GET() {
  return NextResponse.json({
    status: "ok",
    service: "rule-the-world",
    version: pkg.version,
    timestamp: new Date().toISOString(),
  });
}
