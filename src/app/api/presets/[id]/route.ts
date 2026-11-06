import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { voicePresets } from "@/db/schema";
import { ApiError, handleApiError, num, parseId, readJson, requireUser, str } from "@/lib/api";
import { getPersona } from "@/lib/tts/personas";

type Ctx = { params: Promise<{ id: string }> };

export async function PATCH(req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const body = await readJson<Record<string, unknown>>(req);

    const updates: Partial<typeof voicePresets.$inferInsert> = { updatedAt: new Date() };
    if (typeof body.name === "string") {
      const name = str(body.name, 120);
      if (!name) throw new ApiError(400, "نام پروفایل صدا الزامی است.");
      updates.name = name;
    }
    if (typeof body.description === "string") updates.description = str(body.description, 500);
    if (body.engine === "browser" || body.engine === "neural") updates.engine = body.engine;
    if (typeof body.personaId === "string") updates.personaId = getPersona(body.personaId).id;
    if (body.rate !== undefined) updates.rate = num(body.rate, 1, 0.5, 1.6);
    if (body.pitch !== undefined) updates.pitch = num(body.pitch, 1, 0.6, 1.4);
    if (body.pauseScale !== undefined) updates.pauseScale = num(body.pauseScale, 1, 0.4, 2.2);
    if (typeof body.isDefault === "boolean") {
      updates.isDefault = body.isDefault;
      if (body.isDefault) {
        await db.update(voicePresets).set({ isDefault: false }).where(and(eq(voicePresets.userId, user.id), eq(voicePresets.isDefault, true)));
      }
    }

    const [row] = await db
      .update(voicePresets)
      .set(updates)
      .where(and(eq(voicePresets.id, id), eq(voicePresets.userId, user.id)))
      .returning();
    if (!row) throw new ApiError(404, "پروفایل صدا پیدا نشد.");
    return Response.json({ item: row });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE(_req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const deleted = await db
      .delete(voicePresets)
      .where(and(eq(voicePresets.id, id), eq(voicePresets.userId, user.id)))
      .returning({ id: voicePresets.id });
    if (!deleted.length) throw new ApiError(404, "پروفایل صدا پیدا نشد.");
    return Response.json({ ok: true });
  } catch (error) {
    return handleApiError(error);
  }
}
