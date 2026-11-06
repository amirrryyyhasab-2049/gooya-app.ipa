import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { dictionaryEntries } from "@/db/schema";
import { ApiError, handleApiError, parseId, readJson, requireUser, str } from "@/lib/api";
import { stripDiacritics } from "@/lib/tts/diacritize";

type Ctx = { params: Promise<{ id: string }> };

export async function PATCH(req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const body = await readJson<{ word?: string; diacritized?: string; note?: string }>(req);

    const [current] = await db
      .select()
      .from(dictionaryEntries)
      .where(and(eq(dictionaryEntries.id, id), eq(dictionaryEntries.userId, user.id)))
      .limit(1);
    if (!current) throw new ApiError(404, "مدخل پیدا نشد.");

    const word = typeof body.word === "string" ? stripDiacritics(str(body.word, 100)) : current.word;
    const diacritized = typeof body.diacritized === "string" ? str(body.diacritized, 140) : current.diacritized;
    if (!word || !diacritized) throw new ApiError(400, "واژه و شکل اعراب‌گذاری‌شده الزامی هستند.");
    if (stripDiacritics(diacritized).replace(/\u200C/g, "") !== word.replace(/\u200C/g, "")) {
      throw new ApiError(400, "شکل اعراب‌گذاری‌شده باید همان واژه با اعراب باشد.");
    }

    const [row] = await db
      .update(dictionaryEntries)
      .set({
        word,
        diacritized,
        note: typeof body.note === "string" ? str(body.note, 500) : current.note,
        updatedAt: new Date(),
      })
      .where(eq(dictionaryEntries.id, id))
      .returning();
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
      .delete(dictionaryEntries)
      .where(and(eq(dictionaryEntries.id, id), eq(dictionaryEntries.userId, user.id)))
      .returning({ id: dictionaryEntries.id });
    if (!deleted.length) throw new ApiError(404, "مدخل پیدا نشد.");
    return Response.json({ ok: true });
  } catch (error) {
    return handleApiError(error);
  }
}
