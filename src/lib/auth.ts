import { cache } from "react";
import { eq } from "drizzle-orm";
import { db } from "@/db";
import { users } from "@/db/schema";
import { GUEST_EMAIL, GUEST_NAME, ensureSeeded } from "@/db/seed";

export type SessionUser = { id: number; name: string; email: string; createdAt: Date };

const columns = { id: users.id, name: users.name, email: users.email, createdAt: users.createdAt };

/**
 * فعلاً برنامه بدون ورود کار می‌کند: همهٔ داده‌ها در یک فضای کاری مشترک («کاربر گویا») ذخیره می‌شوند.
 * این فضای کاری در اولین درخواست به‌صورت خودکار ساخته و با داده‌های نمونه پر می‌شود.
 */
export const getCurrentUser = cache(async (): Promise<SessionUser> => {
  await ensureSeeded();
  const rows = await db.select(columns).from(users).where(eq(users.email, GUEST_EMAIL)).limit(1);
  if (rows[0]) return rows[0];

  const inserted = await db
    .insert(users)
    .values({ name: GUEST_NAME, email: GUEST_EMAIL, passwordHash: "" })
    .onConflictDoNothing()
    .returning(columns);
  if (inserted[0]) return inserted[0];

  const again = await db.select(columns).from(users).where(eq(users.email, GUEST_EMAIL)).limit(1);
  return again[0];
});
