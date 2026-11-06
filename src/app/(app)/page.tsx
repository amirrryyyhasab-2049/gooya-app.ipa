import type { Metadata } from "next";
import { and, desc, eq } from "drizzle-orm";
import { db } from "@/db";
import { dictionaryEntries, speechHistory, texts, voicePresets } from "@/db/schema";
import { getCurrentUser } from "@/lib/auth";
import { PageHeader } from "@/components/dashboard-shell";
import { Studio } from "@/components/studio";

export const metadata: Metadata = { title: "استودیو گفتار" };
export const dynamic = "force-dynamic";

export default async function StudioPage({ searchParams }: { searchParams: Promise<{ text?: string; history?: string }> }) {
  const user = await getCurrentUser();
  const params = await searchParams;
  const textId = Number(params.text);
  const historyId = Number(params.history);

  const [presets, dictionary, textRow, historyRow] = await Promise.all([
    db.select().from(voicePresets).where(eq(voicePresets.userId, user.id)).orderBy(desc(voicePresets.isDefault), desc(voicePresets.updatedAt)),
    db.select({ word: dictionaryEntries.word, diacritized: dictionaryEntries.diacritized }).from(dictionaryEntries).where(eq(dictionaryEntries.userId, user.id)),
    Number.isInteger(textId) && textId > 0
      ? db.select().from(texts).where(and(eq(texts.id, textId), eq(texts.userId, user.id))).limit(1).then((r) => r[0] ?? null)
      : Promise.resolve(null),
    Number.isInteger(historyId) && historyId > 0
      ? db.select().from(speechHistory).where(and(eq(speechHistory.id, historyId), eq(speechHistory.userId, user.id))).limit(1).then((r) => r[0] ?? null)
      : Promise.resolve(null),
  ]);

  const initialText = textRow
    ? { id: textRow.id, title: textRow.title, content: textRow.content, presetId: textRow.presetId }
    : historyRow
      ? { id: historyRow.textId, title: historyRow.title, content: historyRow.content, presetId: null }
      : null;

  return (
    <div>
      <PageHeader
        title="استودیو گفتار"
        description="متن فارسی را بنویسید یا بچسبانید، روی دکمهٔ پخش بزنید و بشنوید. دکمهٔ سبز «اعراب‌گذاری خودکار» فتحه، کسره و ضمه را روی واژه‌ها می‌گذارد تا تلفظ دقیق‌تر شود."
      />
      <Studio
        key={`${textRow?.id ?? "new"}-${historyRow?.id ?? ""}`}
        initialText={initialText}
        presets={presets}
        dictionary={dictionary}
        aiAvailable={Boolean(process.env.OPENAI_API_KEY)}
      />
    </div>
  );
}
