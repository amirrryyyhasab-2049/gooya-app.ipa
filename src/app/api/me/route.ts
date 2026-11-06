import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { ApiError, handleApiError, readJson, requireUser, str } from "@/lib/api";

export async function GET() {
  try {
    const user = await requireUser();
    return Response.json({ user });
  } catch (error) {
    return handleApiError(error);
  }
}

export async function PATCH(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<{ name?: string }>(req);
    const name = str(body.name, 120);
    if (name.length < 2) throw new ApiError(400, "نام باید حداقل ۲ حرف باشد.");
    const [updated] = await db
      .update(users)
      .set({ name })
      .where(eq(users.id, user.id))
      .returning({ id: users.id, name: users.name, email: users.email, createdAt: users.createdAt });
    return Response.json({ user: updated });
  } catch (error) {
    return handleApiError(error);
  }
}
