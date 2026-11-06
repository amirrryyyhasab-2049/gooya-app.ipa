import fs from "node:fs";
import path from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { drizzle as drizzleNodePg } from "drizzle-orm/node-postgres";
import { drizzle as drizzlePglite } from "drizzle-orm/pglite";
import type { PgDatabase, PgQueryResultHKT } from "drizzle-orm/pg-core";
import { Pool } from "pg";

/**
 * دو حالت اتصال به دیتابیس:
 *  - "postgres": وقتی DATABASE_URL تنظیم شده باشد (سرور/پلتفرم).
 *  - "embedded": دیتابیس داخلی PGlite که در پوشهٔ data/ ذخیره می‌شود؛ بدون نیاز به نصب PostgreSQL.
 *    با `npm run local` (یا GOOYA_DB=embedded) فعال می‌شود و وقتی DATABASE_URL وجود نداشته باشد پیش‌فرض است.
 */
export type Db = PgDatabase<PgQueryResultHKT>;
export type DbMode = "postgres" | "embedded";

const databaseUrl = process.env.DATABASE_URL?.trim();
export const dbMode: DbMode = process.env.GOOYA_DB === "embedded" || !databaseUrl ? "embedded" : "postgres";

export const embeddedDataDir = process.env.GOOYA_DATA_DIR
  ? path.resolve(process.env.GOOYA_DATA_DIR)
  : path.join(process.cwd(), "data", "gooya-db");

const g = globalThis as typeof globalThis & {
  __gooyaPool?: Pool;
  __gooyaPglite?: PGlite;
  __gooyaDb?: Db;
};

function createDb(): Db {
  if (dbMode === "embedded") {
    fs.mkdirSync(embeddedDataDir, { recursive: true });
    g.__gooyaPglite ??= new PGlite(embeddedDataDir);
    return drizzlePglite(g.__gooyaPglite) as unknown as Db;
  }
  if (!g.__gooyaPool) {
    g.__gooyaPool = new Pool({ connectionString: databaseUrl });
    g.__gooyaPool.on("error", (err) => console.error("PostgreSQL pool error:", err.message));
  }
  return drizzleNodePg(g.__gooyaPool) as unknown as Db;
}

function getDb(): Db {
  g.__gooyaDb ??= createDb();
  return g.__gooyaDb;
}

/** کلاینت Drizzle؛ اتصال واقعی فقط در اولین کوئری ساخته می‌شود (نه هنگام build). */
export const db: Db = new Proxy({} as Db, {
  get(_target, prop) {
    const real = getDb();
    const value = Reflect.get(real, prop, real) as unknown;
    return typeof value === "function" ? (value as (...args: unknown[]) => unknown).bind(real) : value;
  },
});
