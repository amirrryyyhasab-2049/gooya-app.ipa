import Link from "next/link";
import { count, desc, eq, sum } from "drizzle-orm";
import { db } from "@/db";
import { dictionaryEntries, speechHistory, texts, voicePresets } from "@/db/schema";
import { getCurrentUser } from "@/lib/auth";
import { PageHeader } from "@/components/dashboard-shell";
import { formatNumber, snippet, timeAgo } from "@/lib/format";
import { getPersona } from "@/lib/tts/personas";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const user = await getCurrentUser();

  const [[textStats], [presetStats], [dictStats], [historyStats], recentTexts, recentHistory, presets] = await Promise.all([
    db.select({ total: count() }).from(texts).where(eq(texts.userId, user.id)),
    db.select({ total: count() }).from(voicePresets).where(eq(voicePresets.userId, user.id)),
    db.select({ total: count() }).from(dictionaryEntries).where(eq(dictionaryEntries.userId, user.id)),
    db.select({ total: count(), words: sum(speechHistory.wordCount) }).from(speechHistory).where(eq(speechHistory.userId, user.id)),
    db.select().from(texts).where(eq(texts.userId, user.id)).orderBy(desc(texts.updatedAt)).limit(5),
    db.select().from(speechHistory).where(eq(speechHistory.userId, user.id)).orderBy(desc(speechHistory.createdAt)).limit(5),
    db.select().from(voicePresets).where(eq(voicePresets.userId, user.id)).orderBy(desc(voicePresets.isDefault)).limit(4),
  ]);

  const stats = [
    { label: "متن‌های ذخیره‌شده", value: Number(textStats.total), icon: "📝", href: "/texts", tone: "from-indigo-500 to-violet-600" },
    { label: "پروفایل صدا", value: Number(presetStats.total), icon: "🎚️", href: "/voices", tone: "from-rose-400 to-pink-600" },
    { label: "واژهٔ تلفظ", value: Number(dictStats.total), icon: "🔤", href: "/dictionary", tone: "from-emerald-500 to-teal-600" },
    { label: "واژهٔ خوانده‌شده", value: Number(historyStats.words ?? 0), icon: "🔊", href: "/history", tone: "from-amber-400 to-orange-600" },
  ];

  const hour = new Date().getHours();
  const greeting = hour < 12 ? "صبح بخیر" : hour < 18 ? "عصر بخیر" : "شب بخیر";

  return (
    <div className="space-y-8">
      <PageHeader
        title={`${greeting} 👋`}
        description="آمادهٔ شنیدن هستید؟ متن تازه‌ای بنویسید یا یکی از متن‌های ذخیره‌شده را پخش کنید."
        action={
          <Link href="/" className="inline-flex h-11 items-center gap-2 rounded-xl bg-gradient-to-l from-violet-600 to-indigo-600 px-5 text-sm font-bold text-white shadow-md shadow-indigo-500/25 hover:from-violet-500 hover:to-indigo-500">
            🎙️ شروع گویندگی
          </Link>
        }
      />

      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {stats.map((s, i) => (
          <Link key={s.label} href={s.href} className="fade-up group rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md" style={{ animationDelay: `${i * 60}ms` }}>
            <span className={`inline-flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br ${s.tone} text-lg text-white shadow`}>{s.icon}</span>
            <p className="mt-4 text-3xl font-black tabular-nums text-slate-900">{formatNumber(s.value)}</p>
            <p className="mt-1 text-xs text-slate-500">{s.label}</p>
          </Link>
        ))}
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <section className="rounded-2xl border border-slate-200/80 bg-white shadow-sm lg:col-span-2">
          <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
            <h2 className="font-bold text-slate-900">متن‌های اخیر</h2>
            <Link href="/texts" className="text-xs font-semibold text-indigo-600 hover:underline">همهٔ متن‌ها</Link>
          </div>
          {recentTexts.length === 0 ? (
            <div className="px-5 py-12 text-center text-sm text-slate-500">هنوز متنی ذخیره نکرده‌اید. از استودیو شروع کنید.</div>
          ) : (
            <ul className="divide-y divide-slate-100">
              {recentTexts.map((t) => (
                <li key={t.id} className="flex items-center gap-4 px-5 py-4 transition hover:bg-slate-50">
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold text-slate-800">{t.isFavorite && <span className="text-amber-500">★ </span>}{t.title}</p>
                    <p className="mt-0.5 truncate text-xs text-slate-500">{snippet(t.content, 90)}</p>
                  </div>
                  <span className="hidden text-xs text-slate-400 sm:block">{formatNumber(t.wordCount)} واژه</span>
                  <Link href={`/?text=${t.id}`} className="inline-flex h-9 items-center gap-1 rounded-lg bg-indigo-50 px-3 text-xs font-bold text-indigo-700 hover:bg-indigo-100">
                    ▶ پخش
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="space-y-6">
          <div className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
            <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
              <h2 className="font-bold text-slate-900">گوینده‌های من</h2>
              <Link href="/voices" className="text-xs font-semibold text-indigo-600 hover:underline">مدیریت</Link>
            </div>
            <ul className="space-y-2 p-4">
              {presets.map((p) => {
                const persona = getPersona(p.personaId);
                return (
                  <li key={p.id} className="flex items-center gap-3 rounded-xl border border-slate-100 p-3">
                    <span className={`flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br ${persona.gradient} text-lg`}>{persona.emoji}</span>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-semibold text-slate-800">{p.name}</p>
                      <p className="truncate text-xs text-slate-500">{persona.name} · {p.engine === "neural" ? "نیورال" : "دستگاه"}</p>
                    </div>
                    {p.isDefault && <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-bold text-emerald-700">پیش‌فرض</span>}
                  </li>
                );
              })}
              {presets.length === 0 && <li className="py-6 text-center text-sm text-slate-500">پروفایلی ندارید.</li>}
            </ul>
          </div>

          <div className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
            <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
              <h2 className="font-bold text-slate-900">آخرین پخش‌ها</h2>
              <Link href="/history" className="text-xs font-semibold text-indigo-600 hover:underline">تاریخچه</Link>
            </div>
            <ul className="divide-y divide-slate-100">
              {recentHistory.map((h) => (
                <li key={h.id} className="px-5 py-3">
                  <p className="truncate text-sm font-medium text-slate-800">{h.title}</p>
                  <p className="mt-0.5 text-xs text-slate-500">{h.voiceLabel} · {timeAgo(h.createdAt)}</p>
                </li>
              ))}
              {recentHistory.length === 0 && <li className="py-6 text-center text-sm text-slate-500">هنوز چیزی پخش نشده.</li>}
            </ul>
          </div>
        </section>
      </div>

      <section className="rounded-3xl bg-gradient-to-l from-emerald-600 via-teal-600 to-emerald-700 p-6 text-white shadow-lg sm:p-8">
        <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-xl font-black">نکتهٔ تلفظ 💡</h2>
            <p className="mt-2 max-w-xl text-sm leading-8 text-white/85">
              اگر گوینده واژه‌ای را اشتباه خواند (مثلاً «عُصبانی» به‌جای «عَصَبانی»)، آن را در واژه‌نامهٔ تلفظ ثبت کنید. دکمهٔ سبز «اعراب‌گذاری خودکار» در استودیو، واژه‌نامهٔ شما را همیشه اولویت می‌دهد.
            </p>
          </div>
          <Link href="/dictionary" className="inline-flex h-11 shrink-0 items-center rounded-xl bg-white px-5 text-sm font-bold text-emerald-700 shadow hover:bg-emerald-50">
            باز کردن واژه‌نامه
          </Link>
        </div>
      </section>
    </div>
  );
}
