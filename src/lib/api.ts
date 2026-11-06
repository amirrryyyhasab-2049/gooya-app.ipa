import { getCurrentUser } from "@/lib/auth";
import { countWords as countWordsImpl } from "@/lib/tts/segment";

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function requireUser() {
  return getCurrentUser();
}

export function handleApiError(error: unknown) {
  if (error instanceof ApiError) {
    return Response.json({ error: error.message }, { status: error.status });
  }
  console.error(error);
  return Response.json({ error: "خطای غیرمنتظره در سرور رخ داد." }, { status: 500 });
}

export async function readJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  try {
    return (await req.json()) as T;
  } catch {
    throw new ApiError(400, "بدنهٔ درخواست نامعتبر است.");
  }
}

export function str(value: unknown, max = 20000): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, max);
}

export function num(value: unknown, fallback: number, min: number, max: number): number {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

export function bool(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

export function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) throw new ApiError(400, "شناسهٔ نامعتبر است.");
  return id;
}

export const countWords = countWordsImpl;
