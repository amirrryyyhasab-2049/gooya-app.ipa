import { and, desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { voicePresets } from "@/db/schema";
import { ApiError, bool, handleApiError, num, readJson, requireUser, str } from "@/lib/api";
import { getPersona } from "@/lib/tts/personas";

export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db
      .select()
      .from(voicePresets)
      .where(eq(voicePresets.userId, user.id))
      .orderBy(desc(voicePresets.isDefault), desc(voicePresets.updatedAt));
    return Response.json({ items: rows });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<Record<string, unknown>>(req);
    const name = str(body.name, 120);
    if (!name) throw new ApiError(400, "نام پروفایل صدا الزامی است.");
    const engine = body.engine === "browser" ? "browser" : "neural";
    const personaId = getPersona(typeof body.personaId === "string" ? body.personaId : null).id;
    const isDefault = bool(body.isDefault);

    if (isDefault) {
      await db.update(voicePresets).set({ isDefault: false }).where(and(eq(voicePresets.userId, user.id), eq(voicePresets.isDefault, true)));
    }

    const [row] = await db
      .insert(voicePresets)
      .values({
        userId: user.id,
        name,
        description: str(body.description, 500),
        engine,
        personaId,
        rate: num(body.rate, 1, 0.5, 1.6),
        pitch: num(body.pitch, 1, 0.6, 1.4),
        pauseScale: num(body.pauseScale, 1, 0.4, 2.2),
        isDefault,
      })
      .returning();
    return Response.json({ item: row }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
