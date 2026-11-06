import { and, eq } from "drizzle-orm";
import { db } from "@/db";
import { speechHistory } from "@/db/schema";
import { ApiError, handleApiError, parseId, requireUser } from "@/lib/api";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(_req: Request, ctx: Ctx) {
  try {
    const user = await requireUser();
    const id = parseId((await ctx.params).id);
    const [row] = await db
      .select()
      .from(speechHistory)
      .where(and(eq(speechHistory.id, id), eq(speechHistory.userId, user.id)))
      .limit(1);
    if (!row) throw new ApiError(404, "مورد پیدا نشد.");
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
      .delete(speechHistory)
      .where(and(eq(speechHistory.id, id), eq(speechHistory.userId, user.id)))
      .returning({ id: speechHistory.id });
    if (!deleted.length) throw new ApiError(404, "مورد پیدا نشد.");
    return Response.json({ ok: true });
  } catch (error) {
    return handleApiError(error);
  }
}
