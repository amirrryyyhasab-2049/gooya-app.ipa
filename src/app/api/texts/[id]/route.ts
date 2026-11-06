import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { texts } from "@/db/schema";
import { ApiError, countWords, handleApiError, parseId, readJson, requireUser, str } from "@/lib/api";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const [row] = await db.select().from(texts).where(and(eq(texts.id, id), eq(texts.userId, user.id))).limit(1);
    if (!row) throw new ApiError(404, "متن پیدا نشد.");
    return Response.json({ item: row });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const body = await readJson<{ title?: string; content?: string; presetId?: number | null; isFavorite?: boolean }>(req);

    const updates: Partial<typeof texts.$inferInsert> = { updatedAt: new Date() };
    if (typeof body.title === "string") {
      const title = str(body.title, 200);
      if (!title) throw new ApiError(400, "عنوان نمی‌تواند خالی باشد.");
      updates.title = title;
    }
    if (typeof body.content === "string") {
      const content = str(body.content, 200000);
      if (!content) throw new ApiError(400, "متن نمی‌تواند خالی باشد.");
      updates.content = content;
      updates.wordCount = countWords(content);
    }
    if (body.presetId === null || typeof body.presetId === "number") updates.presetId = body.presetId;
    if (typeof body.isFavorite === "boolean") updates.isFavorite = body.isFavorite;

    const [row] = await db
      .update(texts)
      .set(updates)
      .where(and(eq(texts.id, id), eq(texts.userId, user.id)))
      .returning();
    if (!row) throw new ApiError(404, "متن پیدا نشد.");
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
      .delete(texts)
      .where(and(eq(texts.id, id), eq(texts.userId, user.id)))
      .returning({ id: texts.id });
    if (!deleted.length) throw new ApiError(404, "متن پیدا نشد.");
    return Response.json({ ok: true });
  } catch (error) {
    return handleApiError(error);
  }
}
