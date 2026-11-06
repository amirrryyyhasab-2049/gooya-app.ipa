import { sql } from "drizzle-orm";
import { db, dbMode } from "@/db";
import { ensureSeeded } from "@/db/seed";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    await db.execute(sql`select 1`);
    await ensureSeeded();
    return Response.json({ ok: true, db: dbMode });
  } catch {
    return Response.json({ ok: false }, { status: 500 });
  }
}
