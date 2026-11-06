import { and, desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { dictionaryEntries } from "@/db/schema";
import { ApiError, handleApiError, readJson, requireUser, str } from "@/lib/api";
import { stripDiacritics } from "@/lib/tts/diacritize";

export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db
      .select()
      .from(dictionaryEntries)
      .where(eq(dictionaryEntries.userId, user.id))
      .orderBy(desc(dictionaryEntries.updatedAt));
    return Response.json({ items: rows });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<{ word?: string; diacritized?: string; note?: string }>(req);
    const word = stripDiacritics(str(body.word, 100)).replace(/\s+/g, " ");
    const diacritized = str(body.diacritized, 140);
    if (!word) throw new ApiError(400, "واژه را وارد کنید.");
    if (!diacritized) throw new ApiError(400, "شکل اعراب‌گذاری‌شده را وارد کنید.");
    if (stripDiacritics(diacritized).replace(/\u200C/g, "") !== word.replace(/\u200C/g, "")) {
      throw new ApiError(400, "شکل اعراب‌گذاری‌شده باید همان واژه با اعراب باشد.");
    }

    const existing = await db
      .select({ id: dictionaryEntries.id })
      .from(dictionaryEntries)
      .where(and(eq(dictionaryEntries.userId, user.id), eq(dictionaryEntries.word, word)))
      .limit(1);

    if (existing.length) {
      const [row] = await db
        .update(dictionaryEntries)
        .set({ diacritized, note: str(body.note, 500), updatedAt: new Date() })
        .where(eq(dictionaryEntries.id, existing[0].id))
        .returning();
      return Response.json({ item: row, updated: true });
    }

    const [row] = await db
      .insert(dictionaryEntries)
      .values({ userId: user.id, word, diacritized, note: str(body.note, 500) })
      .returning();
    return Response.json({ item: row }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
