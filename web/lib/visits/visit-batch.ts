export const maxBatchSize = 500;
export const maxBodyBytes = 256 * 1024;

export class VisitBatchError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

export type VisitUpload = { id: string; cell: string; timestamp: string; score: number };
export type VisitDay = { cell: string; day: string; score: number };
export type VisitBatch = {
  acceptedIds: string[];
  cells: { cell: string; lastVisit: Date }[];
  days: VisitDay[];
};

export function isVisitCell(value: unknown): value is string {
  if (typeof value !== "string" || !/^8a[0-9a-f]{13}$/.test(value)) return false;
  const bits = BigInt(`0x${value}`);
  const base = Number((bits >> BigInt(45)) & BigInt(127));
  if (base > 121) return false;
  let firstDigit: number | undefined;
  for (let resolution = 1; resolution <= 15; resolution++) {
    const digit = Number((bits >> BigInt(3 * (15 - resolution))) & BigInt(7));
    if (resolution <= 10) {
      if (digit > 6) return false;
      if (firstDigit === undefined && digit !== 0) firstDigit = digit;
    } else if (digit !== 7) return false;
  }
  return !([4, 14, 24, 38, 49, 58, 63, 72, 83, 97, 107, 117].includes(base) && firstDigit === 1);
}

function parseTimestamp(value: unknown): Date | null {
  if (typeof value !== "string") return null;
  const match = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$/.exec(value);
  if (!match || match[1].startsWith("0000")) return null;
  const day = new Date(`${match[1]}T00:00:00Z`);
  if (!Number.isFinite(day.getTime()) || day.toISOString().slice(0, 10) !== match[1]) return null;
  if (+match[2] > 23 || +match[3] > 59 || +match[4] > 59) return null;
  if (match[5] !== "Z" && (+match[5].slice(1, 3) > 23 || +match[5].slice(4) > 59)) return null;
  const date = new Date(value);
  return Number.isFinite(date.getTime()) && date.getUTCFullYear() >= 1 && date.getUTCFullYear() <= 9999 ? date : null;
}

export function parseVisitBatch(body: unknown): VisitBatch {
  if (!body || typeof body !== "object" || !("visits" in body) || !Array.isArray(body.visits)
    || body.visits.length < 1 || body.visits.length > maxBatchSize) {
    throw new VisitBatchError(`visits must contain 1–${maxBatchSize} entries`);
  }
  const ids = new Set<string>();
  const cells = new Map<string, Date>();
  const days = new Map<string, VisitDay>();
  for (const value of body.visits) {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new VisitBatchError("Invalid visit");
    const { id, cell, timestamp, score } = value;
    const date = parseTimestamp(timestamp);
    if (typeof id !== "string" || !id.trim() || id.length > 128 || ids.has(id)
      || !isVisitCell(cell) || !date || typeof score !== "number" || !Number.isFinite(score) || score < 0 || score > 1) {
      throw new VisitBatchError("Invalid visit fields or duplicate id");
    }
    ids.add(id);
    if (!cells.has(cell) || date > cells.get(cell)!) cells.set(cell, date);
    const day = date.toISOString().slice(0, 10);
    const key = `${cell}/${day}`;
    days.set(key, { cell, day, score: Math.max(score, days.get(key)?.score ?? 0) });
  }
  return {
    acceptedIds: [...ids],
    cells: [...cells].sort(([a], [b]) => a.localeCompare(b)).map(([cell, lastVisit]) => ({ cell, lastVisit })),
    days: [...days.values()].sort((a, b) => a.cell.localeCompare(b.cell) || a.day.localeCompare(b.day)),
  };
}

export async function readVisitBody(request: Request): Promise<unknown> {
  if (Number(request.headers.get("content-length")) > maxBodyBytes) throw new VisitBatchError("Payload too large", 413);
  if (!request.body) throw new VisitBatchError("Invalid JSON body");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBodyBytes) {
        await reader.cancel();
        throw new VisitBatchError("Payload too large", 413);
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch (error) {
    if (error instanceof VisitBatchError) throw error;
    throw new VisitBatchError("Invalid JSON body");
  } finally {
    reader.releaseLock();
  }
}
