import { desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { speechHistory } from "@/db/schema";
import { ApiError, countWords, handleApiError, num, readJson, requireUser, str } from "@/lib/api";

export async function GET() {
  try {
    const user = await requireUser();
    const rows = await db
      .select()
      .from(speechHistory)
      .where(eq(speechHistory.userId, user.id))
      .orderBy(desc(speechHistory.createdAt))
      .limit(200);
    return Response.json({ items: rows });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function POST(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<{ textId?: number | null; title?: string; content?: string; engine?: string; voiceLabel?: string; durationSec?: number }>(req);
    const content = str(body.content, 200000);
    if (!content) throw new ApiError(400, "متن خالی است.");
    const title = str(body.title, 200) || content.slice(0, 48).replace(/\s+/g, " ") + (content.length > 48 ? "…" : "");
    const [row] = await db
      .insert(speechHistory)
      .values({
        userId: user.id,
        textId: typeof body.textId === "number" ? body.textId : null,
        title,
        content,
        engine: body.engine === "browser" ? "browser" : "neural",
        voiceLabel: str(body.voiceLabel, 120),
        wordCount: countWords(content),
        durationSec: body.durationSec === undefined ? null : num(body.durationSec, 0, 0, 1e6),
      })
      .returning();
    return Response.json({ item: row }, { status: 201 });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function DELETE() {
  try {
    const user = await requireUser();
    await db.delete(speechHistory).where(eq(speechHistory.userId, user.id));
    return Response.json({ ok: true });
  } catch (error) {
    return handleApiError(error);
  }
}
