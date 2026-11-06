import { eq } from "drizzle-orm";
import { db } from "@/db";
import { dictionaryEntries } from "@/db/schema";
import { ApiError, handleApiError, readJson, requireUser, str } from "@/lib/api";
import { diacritize, stripDiacritics } from "@/lib/tts/diacritize";

export const runtime = "nodejs";

function aiAvailable() {
  return Boolean(process.env.OPENAI_API_KEY);
}

export async function GET() {
  return Response.json({ ai: aiAvailable() });
}

async function aiDiacritize(text: string): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${process.env.OPENAI_API_KEY}` },
    body: JSON.stringify({
      model: process.env.OPENAI_DIACRITIZE_MODEL || "gpt-4o-mini",
      temperature: 0,
      messages: [
        {
          role: "system",
          content:
            "You are an expert Persian (Farsi) linguist preparing text for a text-to-speech engine. Add full Persian diacritics (فتحه، کسره، ضمه، تشدید and کسرهٔ اضافه where grammatically present) to every Persian word so pronunciation is unambiguous, e.g. عصبانی→عَصَبانی, مشکل→مُشکِل, درست→دُرُست. Do NOT change, add, remove or reorder any words, punctuation, line breaks or spacing. Return ONLY the diacritized text with no explanations.",
        },
        { role: "user", content: text },
      ],
    }),
  });
  if (!res.ok) throw new Error(`OpenAI ${res.status}`);
  const data = (await res.json()) as { choices?: Array<{ message?: { content?: string } }> };
  const out = data.choices?.[0]?.message?.content?.trim();
  if (!out) throw new Error("empty");
  // اگر مدل متن را تغییر داده باشد، نتیجه را نمی‌پذیریم
  const same = stripDiacritics(out).replace(/\s+/g, " ").trim() === stripDiacritics(text).replace(/\s+/g, " ").trim();
  if (!same) throw new Error("mismatch");
  return out;
}

export async function POST(req: Request) {
  try {
    const user = await requireUser();
    const body = await readJson<{ text?: string; mode?: "rules" | "ai" }>(req);
    const text = str(body.text, 200000);
    if (!text) throw new ApiError(400, "متنی برای اعراب‌گذاری وجود ندارد.");

    const rows = await db
      .select({ word: dictionaryEntries.word, diacritized: dictionaryEntries.diacritized })
      .from(dictionaryEntries)
      .where(eq(dictionaryEntries.userId, user.id));
    const userDict = new Map(rows.map((r) => [r.word, r.diacritized]));

    let source = text;
    let usedAi = false;
    if (body.mode === "ai" && aiAvailable()) {
      try {
        source = await aiDiacritize(text.slice(0, 6000)) + text.slice(6000);
        usedAi = true;
      } catch (err) {
        console.warn("AI diacritization failed, falling back to rules:", err);
      }
    }

    // واژه‌نامهٔ شخصی همیشه اولویت دارد (حتی روی خروجی هوش مصنوعی)
    const result = usedAi ? diacritize(stripDiacriticsForDict(source, userDict), userDict) : diacritize(source, userDict);
    return Response.json({ ...result, usedAi });
  } catch (error) {
    return handleApiError(error);
  }
}

/** اعراب واژه‌هایی را که در واژه‌نامهٔ کاربر هستند حذف می‌کند تا نسخهٔ کاربر جایگزین شود */
function stripDiacriticsForDict(text: string, dict: Map<string, string>) {
  if (dict.size === 0) return text;
  return text.replace(/[\u0621-\u064A\u066E-\u06D3\u200C\u064B-\u0652\u0670]+/g, (token) => {
    const bare = stripDiacritics(token);
    return dict.has(bare) ? bare : token;
  });
}
