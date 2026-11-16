import { NextResponse } from "next/server";
import { requireSession } from "@/lib/api/route-helpers";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const session = await requireSession(request);
  if (session instanceof NextResponse) return session;

  const { id, name, email, createdAt } = session.user;
  return NextResponse.json({ user: { id, name, email, createdAt } });
}
