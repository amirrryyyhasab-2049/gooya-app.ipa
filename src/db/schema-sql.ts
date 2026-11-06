import { sql } from "drizzle-orm";
import { db } from "@/db";

/**
 * ساخت جدول‌ها در صورت نبودن (idempotent).
 * دقیقاً معادل خروجی `drizzle-kit generate` برای src/db/schema.ts است تا در حالت دیتابیس داخلی
 * نیازی به اجرای دستی drizzle-kit نباشد. روی PostgreSQL واقعی هم بی‌خطر است (IF NOT EXISTS).
 */
const STATEMENTS = [
  `CREATE TABLE IF NOT EXISTS "users" (
    "id" serial PRIMARY KEY NOT NULL,
    "name" varchar(120) NOT NULL,
    "email" varchar(255) NOT NULL,
    "password_hash" text NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "users_email_unique" UNIQUE("email")
  )`,
  `CREATE TABLE IF NOT EXISTS "voice_presets" (
    "id" serial PRIMARY KEY NOT NULL,
    "user_id" integer NOT NULL,
    "name" varchar(120) NOT NULL,
    "description" text DEFAULT '' NOT NULL,
    "engine" varchar(20) DEFAULT 'neural' NOT NULL,
    "persona_id" varchar(40) DEFAULT 'arman' NOT NULL,
    "rate" real DEFAULT 1 NOT NULL,
    "pitch" real DEFAULT 1 NOT NULL,
    "pause_scale" real DEFAULT 1 NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "voice_presets_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE cascade ON UPDATE no action
  )`,
  `CREATE TABLE IF NOT EXISTS "texts" (
    "id" serial PRIMARY KEY NOT NULL,
    "user_id" integer NOT NULL,
    "title" varchar(200) NOT NULL,
    "content" text NOT NULL,
    "preset_id" integer,
    "is_favorite" boolean DEFAULT false NOT NULL,
    "word_count" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "texts_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE cascade ON UPDATE no action,
    CONSTRAINT "texts_preset_id_voice_presets_id_fk" FOREIGN KEY ("preset_id") REFERENCES "voice_presets"("id") ON DELETE set null ON UPDATE no action
  )`,
  `CREATE TABLE IF NOT EXISTS "dictionary_entries" (
    "id" serial PRIMARY KEY NOT NULL,
    "user_id" integer NOT NULL,
    "word" varchar(100) NOT NULL,
    "diacritized" varchar(140) NOT NULL,
    "note" text DEFAULT '' NOT NULL,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "dictionary_entries_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE cascade ON UPDATE no action
  )`,
  `CREATE UNIQUE INDEX IF NOT EXISTS "dictionary_user_word_idx" ON "dictionary_entries" USING btree ("user_id","word")`,
  `CREATE TABLE IF NOT EXISTS "speech_history" (
    "id" serial PRIMARY KEY NOT NULL,
    "user_id" integer NOT NULL,
    "text_id" integer,
    "title" varchar(200) NOT NULL,
    "content" text NOT NULL,
    "engine" varchar(20) DEFAULT 'neural' NOT NULL,
    "voice_label" varchar(120) DEFAULT '' NOT NULL,
    "word_count" integer DEFAULT 0 NOT NULL,
    "duration_sec" real,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "speech_history_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE cascade ON UPDATE no action,
    CONSTRAINT "speech_history_text_id_texts_id_fk" FOREIGN KEY ("text_id") REFERENCES "texts"("id") ON DELETE set null ON UPDATE no action
  )`,
];

const g = globalThis as typeof globalThis & { __gooyaSchemaPromise?: Promise<void> };

export function ensureSchema(): Promise<void> {
  if (!g.__gooyaSchemaPromise) {
    g.__gooyaSchemaPromise = (async () => {
      for (const statement of STATEMENTS) {
        await db.execute(sql.raw(statement));
      }
    })().catch((err) => {
      g.__gooyaSchemaPromise = undefined;
      throw err;
    });
  }
  return g.__gooyaSchemaPromise;
}
