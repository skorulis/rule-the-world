import { NextResponse } from "next/server";

export function proxy() {
  if (process.env.NODE_ENV !== "development") {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }
  return NextResponse.next();
}

export const config = {
  matcher: "/api/debug/cheat/:path*",
};
