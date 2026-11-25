import { NextResponse } from "next/server";
import { jsonError, requireSession, serverError } from "@/lib/api/route-helpers";
import { ingestVisits } from "@/lib/visits/ingest-visits";
import { parseVisitBatch, readVisitBody, VisitBatchError } from "@/lib/visits/visit-batch";

export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    const session = await requireSession(request);
    if (session instanceof NextResponse) return session;
    const batch = parseVisitBatch(await readVisitBody(request));
    return NextResponse.json(await ingestVisits(session.user.id, batch));
  } catch (error) {
    if (error instanceof VisitBatchError) return jsonError(error.message, error.status);
    return serverError("Visit batch upload failed", undefined, "Unable to upload visits");
  }
}
