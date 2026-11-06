import { desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { texts } from "@/db/schema";
import { ApiError, bool, countWords, handleApiError, readJson, requireUser, str } from "@/lib/api";

export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db.select().from(texts).where(eq(texts.userId, user.id)).orderBy(desc(texts.updatedAt));
    return Response.json({ items: rows });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<{ title?: string; content?: string; presetId?: number | null; isFavorite?: boolean }>(req);
    const content = str(body.content, 200000);
    if (!content) throw new ApiError(400, "متن نمی‌تواند خالی باشد.");
    const title = str(body.title, 200) || content.slice(0, 48).replace(/\s+/g, " ") + (content.length > 48 ? "…" : "");
    const presetId = typeof body.presetId === "number" ? body.presetId : null;

    const [row] = await db
      .insert(texts)
      .values({
        userId: user.id,
        title,
        content,
        presetId,
        isFavorite: bool(body.isFavorite),
        wordCount: countWords(content),
      })
      .returning();
    return Response.json({ item: row }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}
