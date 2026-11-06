import {
  boolean,
  integer,
  pgTable,
  real,
  serial,
  text,
  timestamp,
  uniqueIndex,
  varchar,
} from "drizzle-orm/pg-core";

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 120 }).notNull(),
  email: varchar("email", { length: 255 }).notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const voicePresets = pgTable("voice_presets", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  name: varchar("name", { length: 120 }).notNull(),
  description: text("description").notNull().default(""),
  engine: varchar("engine", { length: 20 }).notNull().default("neural"),
  personaId: varchar("persona_id", { length: 40 }).notNull().default("arman"),
  rate: real("rate").notNull().default(1),
  pitch: real("pitch").notNull().default(1),
  pauseScale: real("pause_scale").notNull().default(1),
  isDefault: boolean("is_default").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const texts = pgTable("texts", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  title: varchar("title", { length: 200 }).notNull(),
  content: text("content").notNull(),
  presetId: integer("preset_id").references(() => voicePresets.id, { onDelete: "set null" }),
  isFavorite: boolean("is_favorite").notNull().default(false),
  wordCount: integer("word_count").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const dictionaryEntries = pgTable(
  "dictionary_entries",
  {
    id: serial("id").primaryKey(),
    userId: integer("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    word: varchar("word", { length: 100 }).notNull(),
    diacritized: varchar("diacritized", { length: 140 }).notNull(),
    note: text("note").notNull().default(""),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => [uniqueIndex("dictionary_user_word_idx").on(t.userId, t.word)],
);

export const speechHistory = pgTable("speech_history", {
  id: serial("id").primaryKey(),
  userId: integer("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  textId: integer("text_id").references(() => texts.id, { onDelete: "set null" }),
  title: varchar("title", { length: 200 }).notNull(),
  content: text("content").notNull(),
  engine: varchar("engine", { length: 20 }).notNull().default("neural"),
  voiceLabel: varchar("voice_label", { length: 120 }).notNull().default(""),
  wordCount: integer("word_count").notNull().default(0),
  durationSec: real("duration_sec"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type VoicePreset = typeof voicePresets.$inferSelect;
export type TextDoc = typeof texts.$inferSelect;
export type DictionaryEntry = typeof dictionaryEntries.$inferSelect;
export type SpeechHistoryItem = typeof speechHistory.$inferSelect;
