"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { VoicePreset } from "@/db/schema";
import { Badge, Button, Field, Input, Modal, Slider, cn } from "@/components/ui";
import { useToast } from "@/components/toast";
import { DiacriticKeyboard } from "@/components/diacritic-keyboard";
import { useSpeech } from "@/hooks/useSpeech";
import { diacritize, stripDiacritics } from "@/lib/tts/diacritize";
import { countWords, estimateDuration, formatDuration, segmentText } from "@/lib/tts/segment";
import { DEFAULT_SETTINGS, PERSONAS, getPersona, type EngineKind, type VoiceSettings } from "@/lib/tts/personas";
import { faNum, formatNumber } from "@/lib/format";

const SETTINGS_KEY = "gooya:settings";
const DRAFT_KEY = "gooya:draft";

const SAMPLES = [
  { label: "جملهٔ آزمایشی تلفظ", text: "مرد عصبانی، گل سرخ را روی میز گذاشت و با صدایی آرام گفت: «حتی اگر کشتی غرق شود، مهر تو در دل من می‌ماند.»\nکرم کوچک، زیر برگ خوابیده بود؛ اما شکر در فنجان، هنوز حل نشده بود." },
  { label: "شعر", text: "یوسف گم‌گشته بازآید به کنعان، غم مخور.\nکلبهٔ احزان شود روزی گلستان، غم مخور.\n\nای دل غم‌دیده حالت به شود، دل بد مکن.\nوین سر شوریده بازآید به سامان، غم مخور." },
  { label: "خبر", text: "به گزارش خبرگزاری گویا، نسل تازه‌ای از دستیارهای صوتی فارسی امروز رونمایی شد. این سامانه می‌تواند متن را با لحنی طبیعی و شمرده بخواند و در تلفظ واژه‌های دشوار دقت بالایی دارد. کارشناسان معتقدند این فناوری برای نابینایان، سالمندان و دانش‌آموزان بسیار سودمند خواهد بود." },
];

interface InitialText {
  id: number | null;
  title: string;
  content: string;
  presetId: number | null;
}

interface Props {
  initialText: InitialText | null;
  presets: VoicePreset[];
  dictionary: Array<{ word: string; diacritized: string }>;
  aiAvailable: boolean;
}

function settingsFromPreset(p: VoicePreset): VoiceSettings {
  return { engine: p.engine === "browser" ? "browser" : "neural", personaId: p.personaId, rate: p.rate, pitch: p.pitch, pauseScale: p.pauseScale };
}

export function Studio({ initialText, presets: initialPresets, dictionary, aiAvailable }: Props) {
  const toast = useToast();
  const [presets, setPresets] = useState<VoicePreset[]>(initialPresets);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const quickInputRef = useRef<HTMLInputElement>(null);

  const [text, setText] = useState(initialText?.content ?? "");
  const [sourceTextId, setSourceTextId] = useState<number | null>(initialText?.id ?? null);
  const [title, setTitle] = useState(initialText?.title ?? "");
  const [settings, setSettings] = useState<VoiceSettings>(() => {
    const fromText = initialText?.presetId ? presets.find((p) => p.id === initialText.presetId) : null;
    const def = fromText ?? presets.find((p) => p.isDefault) ?? null;
    return def ? settingsFromPreset(def) : DEFAULT_SETTINGS;
  });
  const [activePresetId, setActivePresetId] = useState<number | null>(() => {
    const fromText = initialText?.presetId ? presets.find((p) => p.id === initialText.presetId) : null;
    return (fromText ?? presets.find((p) => p.isDefault))?.id ?? null;
  });
  const [localDict, setLocalDict] = useState(dictionary);
  const [diacritizing, setDiacritizing] = useState(false);
  const [unknownWords, setUnknownWords] = useState<string[]>([]);
  const [showKeyboard, setShowKeyboard] = useState(false);
  const [showReader, setShowReader] = useState(false);
  const [saveOpen, setSaveOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [presetOpen, setPresetOpen] = useState(false);
  const [presetName, setPresetName] = useState("");
  const [savingPreset, setSavingPreset] = useState(false);
  const [quickWord, setQuickWord] = useState<string | null>(null);
  const [quickValue, setQuickValue] = useState("");
  const [quickSaving, setQuickSaving] = useState(false);

  const persona = getPersona(settings.personaId);
  const dictMap = useMemo(() => new Map(localDict.map((d) => [stripDiacritics(d.word), d.diacritized])), [localDict]);

  const speech = useSpeech({
    onNotice: (message, kind) => toast(message, kind === "error" ? "error" : kind === "warning" ? "warning" : "info"),
    onComplete: async (info) => {
      const p = getPersona(info.settings.personaId);
      toast("خواندن متن به پایان رسید. ✨", "success");
      try {
        await fetch("/api/history", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            textId: sourceTextId,
            title: title || undefined,
            content: info.text,
            engine: info.engineUsed,
            voiceLabel: `${p.name} — ${p.tagline}`,
            durationSec: info.durationSec,
          }),
        });
      } catch {
        /* ignore */
      }
    },
  });

  // بازیابی تنظیمات و پیش‌نویس
  useEffect(() => {
    try {
      if (!initialText?.presetId) {
        const raw = localStorage.getItem(SETTINGS_KEY);
        if (raw) {
          const saved = JSON.parse(raw) as Partial<VoiceSettings>;
          setSettings((s) => ({ ...s, ...saved }));
          setActivePresetId(null);
        }
      }
      if (!initialText) {
        const draft = localStorage.getItem(DRAFT_KEY);
        if (draft) setText(draft);
      }
    } catch {
      /* ignore */
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    } catch {
      /* ignore */
    }
  }, [settings]);

  useEffect(() => {
    if (initialText) return;
    const t = setTimeout(() => {
      try {
        localStorage.setItem(DRAFT_KEY, text);
      } catch {
        /* ignore */
      }
    }, 400);
    return () => clearTimeout(t);
  }, [text, initialText]);

  useEffect(() => {
    if (speech.status !== "idle") setShowReader(true);
  }, [speech.status]);

  useEffect(() => {
    if (speech.currentIndex < 0) return;
    document.getElementById(`seg-${speech.currentIndex}`)?.scrollIntoView({ block: "nearest", behavior: "smooth" });
  }, [speech.currentIndex]);

  const previewSegments = useMemo(() => segmentText(text, { pauseScale: settings.pauseScale * persona.pauseScale }), [text, settings.pauseScale, persona.pauseScale]);
  const words = useMemo(() => countWords(text), [text]);
  const estimate = useMemo(() => estimateDuration(previewSegments, settings.rate * persona.rate), [previewSegments, settings.rate, persona.rate]);
  const hasDiacritics = /[\u064B-\u0652]/.test(text);

  const updateSettings = (patch: Partial<VoiceSettings>) => {
    setSettings((s) => ({ ...s, ...patch }));
    setActivePresetId(null);
  };

  const applyPreset = (p: VoicePreset) => {
    setSettings(settingsFromPreset(p));
    setActivePresetId(p.id);
    toast(`پروفایل «${p.name}» اعمال شد.`, "info");
  };

  const handlePlay = useCallback(
    (startIndex = 0) => {
      if (!text.trim()) {
        toast("ابتدا متنی بنویسید یا بچسبانید.", "warning");
        textareaRef.current?.focus();
        return;
      }
      void speech.play(text, settings, startIndex);
    },
    [text, settings, speech, toast],
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        handlePlay();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [handlePlay]);

  const runDiacritize = async (mode: "rules" | "ai") => {
    if (!text.trim()) return toast("متنی برای اعراب‌گذاری وجود ندارد.", "warning");
    setDiacritizing(true);
    try {
      if (mode === "ai") {
        const res = await fetch("/api/diacritize", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text, mode: "ai" }) });
        const data = (await res.json()) as { text: string; totalWords: number; markedWords: number; unknownWords: string[]; usedAi: boolean; error?: string };
        if (!res.ok) throw new Error(data.error);
        setText(data.text);
        setUnknownWords(data.unknownWords);
        toast(`${faNum(data.markedWords)} از ${faNum(data.totalWords)} واژه اعراب‌گذاری شد${data.usedAi ? " (با هوش مصنوعی)" : ""}.`, "success");
      } else {
        const result = diacritize(text, dictMap);
        setText(result.text);
        setUnknownWords(result.unknownWords);
        toast(`${faNum(result.markedWords)} از ${faNum(result.totalWords)} واژه اعراب‌گذاری شد.`, "success");
      }
    } catch (err) {
      toast(err instanceof Error ? err.message : "اعراب‌گذاری ناموفق بود.", "error");
    } finally {
      setDiacritizing(false);
    }
  };

  const saveText = async () => {
    if (!text.trim()) return;
    setSaving(true);
    try {
      const isUpdate = sourceTextId !== null;
      const res = await fetch(isUpdate ? `/api/texts/${sourceTextId}` : "/api/texts", {
        method: isUpdate ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title: title.trim() || undefined, content: text, presetId: activePresetId }),
      });
      const data = (await res.json()) as { item?: { id: number; title: string }; error?: string };
      if (!res.ok || !data.item) throw new Error(data.error);
      setSourceTextId(data.item.id);
      setTitle(data.item.title);
      setSaveOpen(false);
      toast(isUpdate ? "متن به‌روزرسانی شد." : "متن ذخیره شد.", "success");
    } catch (err) {
      toast(err instanceof Error && err.message ? err.message : "ذخیره ناموفق بود.", "error");
    } finally {
      setSaving(false);
    }
  };

  const savePreset = async () => {
    if (!presetName.trim()) return;
    setSavingPreset(true);
    try {
      const res = await fetch("/api/presets", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: presetName.trim(), description: `${persona.name} · ${persona.tagline}`, ...settings }),
      });
      const data = (await res.json()) as { item?: VoicePreset; error?: string };
      if (!res.ok || !data.item) throw new Error(data.error);
      setPresets((prev) => [data.item!, ...prev]);
      setActivePresetId(data.item.id);
      setPresetOpen(false);
      setPresetName("");
      toast("پروفایل صدا ذخیره شد.", "success");
    } catch (err) {
      toast(err instanceof Error && err.message ? err.message : "ذخیره ناموفق بود.", "error");
    } finally {
      setSavingPreset(false);
    }
  };

  const handleDownload = async () => {
    if (!text.trim()) return toast("متنی برای دانلود وجود ندارد.", "warning");
    setDownloading(true);
    try {
      await speech.downloadMp3(text, settings, (title || "gooya").replace(/[\\/:*?"<>|]/g, "-"));
      toast("فایل MP3 آماده شد.", "success");
    } catch (err) {
      toast(err instanceof Error ? err.message : "دانلود ممکن نشد.", "error");
    } finally {
      setDownloading(false);
    }
  };

  const openQuickAdd = (word: string) => {
    setQuickWord(word);
    setQuickValue(word);
  };

  const saveQuickWord = async () => {
    if (!quickWord) return;
    setQuickSaving(true);
    try {
      const res = await fetch("/api/dictionary", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ word: quickWord, diacritized: quickValue.trim() }) });
      const data = (await res.json()) as { item?: { word: string; diacritized: string }; error?: string };
      if (!res.ok || !data.item) throw new Error(data.error);
      setLocalDict((d) => [{ word: data.item!.word, diacritized: data.item!.diacritized }, ...d.filter((x) => x.word !== data.item!.word)]);
      setUnknownWords((u) => u.filter((w) => w !== quickWord));
      setQuickWord(null);
      toast(`«${data.item.diacritized}» به واژه‌نامه اضافه شد.`, "success");
    } catch (err) {
      toast(err instanceof Error && err.message ? err.message : "ذخیره ناموفق بود.", "error");
    } finally {
      setQuickSaving(false);
    }
  };

  const isBusy = speech.status === "playing" || speech.status === "loading";
  const total = speech.status === "idle" ? previewSegments.length : speech.segments.length;
  const progress = speech.status === "idle" || total === 0 ? 0 : Math.round(((speech.currentIndex + 1) / total) * 100);
  const readerSegments = speech.status === "idle" ? previewSegments : speech.segments;

  const engineHint: Record<EngineKind, string> = {
    neural: "کیفیت بالا، دو صدای طبیعی مرد و زن؛ نیاز به اینترنت",
    browser: speech.hasPersianBrowserVoice
      ? `${faNum(speech.browserVoices.length)} صدای فارسی روی این دستگاه یافت شد؛ بدون اینترنت`
      : speech.browserSupported
        ? "صدای فارسی روی این دستگاه نصب نیست (راهنما در بخش نصب)"
        : "مرورگر شما از گفتار آفلاین پشتیبانی نمی‌کند",
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
      {/* ستون اصلی */}
      <div className="space-y-5">
        <div className="rounded-2xl border border-slate-200/80 bg-white shadow-sm">
          <div className="flex flex-wrap items-center gap-2 border-b border-slate-100 px-4 py-3">
            <Button variant="success" size="sm" onClick={() => runDiacritize("rules")} loading={diacritizing} title="فتحه، کسره و ضمه را خودکار روی واژه‌ها می‌گذارد">
              <span className="text-base leading-none">◌َ</span> اعراب‌گذاری خودکار
            </Button>
            {aiAvailable && (
              <Button variant="outline" size="sm" onClick={() => runDiacritize("ai")} loading={diacritizing} title="اعراب‌گذاری کامل با هوش مصنوعی">
                ✨ با هوش مصنوعی
              </Button>
            )}
            {hasDiacritics && (
              <Button variant="ghost" size="sm" onClick={() => setText(stripDiacritics(text))}>حذف اعراب</Button>
            )}
            <div className="ms-auto flex flex-wrap items-center gap-2">
              <select
                className="h-9 rounded-xl border border-slate-200 bg-white px-2.5 text-xs text-slate-600 focus:outline-none"
                value=""
                onChange={(e) => {
                  const s = SAMPLES[Number(e.target.value)];
                  if (s) {
                    setText(s.text);
                    setSourceTextId(null);
                    setTitle(s.label);
                    setUnknownWords([]);
                  }
                }}
              >
                <option value="">نمونه متن…</option>
                {SAMPLES.map((s, i) => <option key={s.label} value={i}>{s.label}</option>)}
              </select>
              <Button variant="ghost" size="sm" onClick={() => setShowKeyboard((v) => !v)} title="صفحه‌کلید اعراب">⌨️</Button>
              {text && (
                <Button variant="ghost" size="sm" onClick={() => { setText(""); setUnknownWords([]); setSourceTextId(null); setTitle(""); speech.stop(); }}>پاک کردن</Button>
              )}
            </div>
          </div>

          {showKeyboard && (
            <div className="border-b border-slate-100 bg-slate-50/70 px-4 py-2.5">
              <DiacriticKeyboard inputRef={textareaRef} value={text} onChange={setText} />
            </div>
          )}

          <textarea
            ref={textareaRef}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder="متن فارسی خود را این‌جا بنویسید یا بچسبانید… (بدون محدودیت واژه)&#10;&#10;نکته: با Ctrl + Enter پخش می‌شود."
            className="diacritic-text min-h-[280px] w-full resize-y border-0 bg-transparent px-5 py-4 text-lg text-slate-900 placeholder:text-slate-400 focus:outline-none sm:text-xl"
            spellCheck={false}
          />

          {!text.trim() && (
            <div className="mx-4 mb-3 flex flex-wrap items-center gap-2 rounded-xl border border-dashed border-indigo-200 bg-indigo-50/60 px-4 py-3 text-xs text-indigo-800">
              <span className="font-semibold">برای شروع:</span>
              <span>متنی بنویسید یا یکی از نمونه‌ها را انتخاب کنید →</span>
              {SAMPLES.map((smp) => (
                <button key={smp.label} onClick={() => { setText(smp.text); setSourceTextId(null); setTitle(smp.label); setUnknownWords([]); }} className="rounded-lg bg-white px-2.5 py-1 font-semibold text-indigo-700 ring-1 ring-indigo-200 hover:bg-indigo-600 hover:text-white">
                  {smp.label}
                </button>
              ))}
            </div>
          )}

          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-slate-100 px-4 py-2.5 text-xs text-slate-500">
            <span><b className="text-slate-700">{formatNumber(words)}</b> واژه</span>
            <span><b className="text-slate-700">{formatNumber(text.length)}</b> نویسه</span>
            <span><b className="text-slate-700">{formatNumber(previewSegments.length)}</b> قطعه</span>
            <span>زمان تقریبی: <b className="text-slate-700">{formatDuration(estimate)}</b></span>
            {title && <span className="truncate">عنوان: <b className="text-slate-700">{title}</b></span>}
          </div>
        </div>

        {unknownWords.length > 0 && (
          <div className="rounded-2xl border border-amber-200 bg-amber-50/70 px-4 py-3">
            <p className="text-xs font-semibold text-amber-800">این واژه‌ها در واژه‌نامه نبودند؛ برای اطمینان از تلفظ درست، روی هرکدام بزنید و اعراب بگذارید:</p>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {unknownWords.slice(0, 14).map((w) => (
                <button key={w} onClick={() => openQuickAdd(w)} className="rounded-lg border border-amber-200 bg-white px-2.5 py-1 text-sm text-amber-900 hover:border-amber-400 hover:bg-amber-100">
                  {w} <span className="text-amber-500">+</span>
                </button>
              ))}
            </div>
          </div>
        )}

        {/* پخش‌کننده */}
        <div className="rounded-2xl border border-slate-200/80 bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900 p-5 text-white shadow-lg">
          <div className="flex flex-col gap-5 sm:flex-row sm:items-center">
            <div className="flex items-center gap-3">
              <button
                onClick={() => (speech.status === "idle" ? handlePlay() : speech.toggle())}
                className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-indigo-500 text-white shadow-xl shadow-indigo-500/40 transition hover:scale-105 active:scale-95"
                aria-label={isBusy ? "مکث" : "پخش"}
              >
                {speech.status === "loading" ? (
                  <svg className="h-7 w-7 animate-spin" viewBox="0 0 24 24" fill="none"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" /><path className="opacity-90" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" /></svg>
                ) : speech.status === "playing" ? (
                  <svg className="h-7 w-7" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="5" width="4" height="14" rx="1" /><rect x="14" y="5" width="4" height="14" rx="1" /></svg>
                ) : (
                  <svg className="h-7 w-7 -scale-x-100" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
                )}
              </button>
              <button onClick={speech.stop} disabled={speech.status === "idle"} className="flex h-11 w-11 items-center justify-center rounded-full bg-white/10 text-white transition hover:bg-white/20 disabled:opacity-30" aria-label="توقف">
                <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2" /></svg>
              </button>
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <span className={`flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br ${persona.gradient} text-base`}>{persona.emoji}</span>
                <div className="min-w-0">
                  <p className="truncate text-sm font-bold">{persona.name} <span className="font-normal text-white/60">— {persona.tagline}</span></p>
                  <p className="text-xs text-white/50">
                    {speech.status === "idle" && "آماده برای خواندن"}
                    {speech.status === "loading" && "در حال آماده‌سازی صدا…"}
                    {speech.status === "playing" && `در حال خواندن قطعهٔ ${faNum(speech.currentIndex + 1)} از ${faNum(total)}`}
                    {speech.status === "paused" && "مکث شده"}
                  </p>
                </div>
                <div className="ms-auto flex items-center gap-2">
                  {speech.status === "playing" && (
                    <span className="hidden items-end gap-0.5 sm:flex" aria-hidden>
                      {[0.5, 0.9, 0.7, 1, 0.6].map((h, i) => (
                        <span key={i} className="wave-bar block w-1 rounded-full bg-emerald-300" style={{ height: `${h * 18}px`, animationDelay: `${i * 0.1}s` }} />
                      ))}
                    </span>
                  )}
                  <span className="rounded-full bg-white/10 px-2.5 py-1 text-[11px] font-semibold text-white/80">
                    {(speech.status === "idle" ? settings.engine : speech.engineUsed) === "neural" ? "نیورال · آنلاین" : "صدای دستگاه · آفلاین"}
                  </span>
                </div>
              </div>
              <div className="mt-3 h-2 overflow-hidden rounded-full bg-white/10">
                <div className="h-full rounded-full bg-gradient-to-l from-emerald-400 to-violet-400 transition-all duration-300" style={{ width: `${progress}%` }} />
              </div>
            </div>
          </div>

          {speech.lastError && (
            <div className="mt-4 flex flex-col gap-3 rounded-xl border border-rose-300/40 bg-rose-500/15 px-4 py-3 text-sm sm:flex-row sm:items-center">
              <p className="flex-1 leading-7 text-rose-100">⚠️ {speech.lastError}</p>
              <div className="flex shrink-0 gap-2">
                <Button size="sm" className="bg-white text-rose-700 hover:from-white hover:to-white" onClick={() => handlePlay()}>تلاش دوباره</Button>
                {settings.engine === "neural" && speech.hasPersianBrowserVoice && (
                  <Button size="sm" variant="outline" className="border-white/20 bg-white/10 text-white hover:bg-white/20" onClick={() => { updateSettings({ engine: "browser" }); void speech.play(text, { ...settings, engine: "browser" }); }}>
                    پخش با صدای دستگاه
                  </Button>
                )}
                <Button size="sm" variant="ghost" className="text-white/70 hover:bg-white/10 hover:text-white" onClick={speech.clearError}>بستن</Button>
              </div>
            </div>
          )}

          <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-white/10 pt-4">
            <Button variant="outline" size="sm" className="border-white/15 bg-white/5 text-white hover:bg-white/10" onClick={() => setSaveOpen(true)} disabled={!text.trim()}>💾 {sourceTextId ? "به‌روزرسانی متن" : "ذخیرهٔ متن"}</Button>
            <Button variant="outline" size="sm" className="border-white/15 bg-white/5 text-white hover:bg-white/10" onClick={handleDownload} loading={downloading} disabled={!text.trim() || settings.engine !== "neural"} title={settings.engine !== "neural" ? "دانلود فقط با موتور نیورال ممکن است" : ""}>⬇️ دانلود MP3</Button>
            <Button variant="outline" size="sm" className="border-white/15 bg-white/5 text-white hover:bg-white/10" onClick={() => setShowReader((v) => !v)} disabled={!text.trim()}>{showReader ? "پنهان‌کردن نمای خواندن" : "📖 نمای خواندن"}</Button>
            <span className="ms-auto hidden text-[11px] text-white/40 sm:inline">Ctrl + Enter = پخش</span>
          </div>
        </div>

        {/* نمای خواندن */}
        {showReader && readerSegments.length > 0 && (
          <div className="rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-sm font-bold text-slate-800">نمای خواندن <span className="font-normal text-slate-400">(برای شروع از هر قطعه روی آن بزنید)</span></h3>
              <span className="text-xs text-slate-400">{faNum(readerSegments.length)} قطعه</span>
            </div>
            <div className="diacritic-text max-h-[420px] overflow-y-auto text-lg leading-[2.4] text-slate-700">
              {readerSegments.map((seg) => {
                const active = seg.index === speech.currentIndex && speech.status !== "idle";
                const done = speech.status !== "idle" && seg.index < speech.currentIndex;
                return (
                  <span key={seg.index}>
                    <span
                      id={`seg-${seg.index}`}
                      onClick={() => handlePlay(seg.index)}
                      className={cn(
                        "cursor-pointer rounded-md px-1 transition-colors",
                        active && "bg-gradient-to-l from-violet-100 to-indigo-100 font-semibold text-indigo-900 ring-2 ring-indigo-300",
                        done && "text-slate-400",
                        !active && !done && "hover:bg-slate-100",
                      )}
                    >
                      {seg.text}
                    </span>
                    {seg.kind === "paragraph" ? <span className="block h-4" /> : seg.kind === "line" ? <br /> : " "}
                  </span>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {/* ستون تنظیمات صدا */}
      <aside className="space-y-5">
        <div className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <h3 className="mb-3 text-sm font-bold text-slate-800">موتور صدا</h3>
          <div className="grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1">
            {(["neural", "browser"] as EngineKind[]).map((eng) => (
              <button
                key={eng}
                onClick={() => updateSettings({ engine: eng })}
                className={cn("rounded-lg px-3 py-2 text-xs font-semibold transition", settings.engine === eng ? "bg-white text-indigo-700 shadow" : "text-slate-500 hover:text-slate-800")}
              >
                {eng === "neural" ? "☁️ نیورال (آنلاین)" : "📱 دستگاه (آفلاین)"}
              </button>
            ))}
          </div>
          <p className="mt-2 text-[11px] leading-5 text-slate-500">{engineHint[settings.engine]}</p>
          {settings.engine === "browser" && !speech.hasPersianBrowserVoice && (
            <Link href="/install" className="mt-1 inline-block text-[11px] font-semibold text-indigo-600 hover:underline">راهنمای صدای فارسی روی گوشی ←</Link>
          )}
        </div>

        <div className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-sm font-bold text-slate-800">گوینده</h3>
            <span className="text-[11px] text-slate-400">{faNum(PERSONAS.length)} صدا</span>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {PERSONAS.map((p) => {
              const selected = p.id === settings.personaId;
              return (
                <div
                  key={p.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => updateSettings({ personaId: p.id })}
                  onKeyDown={(e) => e.key === "Enter" && updateSettings({ personaId: p.id })}
                  className={cn(
                    "group relative cursor-pointer rounded-xl border p-3 text-start transition",
                    selected ? "border-indigo-400 bg-indigo-50/60 ring-2 ring-indigo-200" : "border-slate-200 hover:border-slate-300 hover:bg-slate-50",
                  )}
                >
                  <div className="flex items-center gap-2">
                    <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br ${p.gradient} text-lg shadow-sm`}>{p.emoji}</span>
                    <div className="min-w-0">
                      <p className="truncate text-sm font-bold text-slate-800">{p.name}</p>
                      <p className="truncate text-[11px] text-slate-500">{p.tagline}</p>
                    </div>
                  </div>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      void speech.play(p.sample, { ...settings, personaId: p.id });
                    }}
                    className="mt-2 w-full rounded-lg bg-white px-2 py-1 text-[11px] font-semibold text-indigo-600 ring-1 ring-slate-200 transition hover:bg-indigo-600 hover:text-white"
                  >
                    ▶ پیش‌نمایش
                  </button>
                </div>
              );
            })}
          </div>
        </div>

        <div className="space-y-4 rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
          <h3 className="text-sm font-bold text-slate-800">لحن و سرعت</h3>
          <Slider label="سرعت" min={0.6} max={1.4} step={0.05} value={settings.rate} onChange={(v) => updateSettings({ rate: v })} format={(v) => (v < 0.85 ? "شمرده" : v > 1.15 ? "تند" : "عادی") + ` ×${faNum(v.toFixed(2))}`} />
          <Slider label="زیر و بمی" min={0.7} max={1.3} step={0.05} value={settings.pitch} onChange={(v) => updateSettings({ pitch: v })} format={(v) => (v < 0.9 ? "بم" : v > 1.1 ? "زیر" : "طبیعی")} />
          <Slider label="مکث‌ها" min={0.5} max={2} step={0.1} value={settings.pauseScale} onChange={(v) => updateSettings({ pauseScale: v })} format={(v) => (v < 0.8 ? "کوتاه" : v > 1.3 ? "بلند" : "طبیعی") + ` ×${faNum(v.toFixed(1))}`} />
          <div className="flex gap-2">
            <Button variant="outline" size="sm" className="flex-1" onClick={() => setPresetOpen(true)}>ذخیره به‌عنوان پروفایل</Button>
            <Button variant="ghost" size="sm" onClick={() => { setSettings(DEFAULT_SETTINGS); setActivePresetId(null); }}>بازنشانی</Button>
          </div>
        </div>

        {presets.length > 0 && (
          <div className="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-sm font-bold text-slate-800">پروفایل‌های من</h3>
              <Link href="/voices" className="text-[11px] font-semibold text-indigo-600 hover:underline">مدیریت</Link>
            </div>
            <div className="flex flex-wrap gap-1.5">
              {presets.map((p) => (
                <button
                  key={p.id}
                  onClick={() => applyPreset(p)}
                  className={cn(
                    "rounded-full border px-3 py-1 text-xs font-medium transition",
                    activePresetId === p.id ? "border-indigo-400 bg-indigo-600 text-white" : "border-slate-200 bg-white text-slate-700 hover:border-indigo-300",
                  )}
                >
                  {getPersona(p.personaId).emoji} {p.name}
                </button>
              ))}
            </div>
          </div>
        )}
      </aside>

      {/* مودال ذخیرهٔ متن */}
      <Modal
        open={saveOpen}
        onClose={() => setSaveOpen(false)}
        title={sourceTextId ? "به‌روزرسانی متن" : "ذخیرهٔ متن"}
        footer={
          <>
            <Button variant="ghost" onClick={() => setSaveOpen(false)}>انصراف</Button>
            <Button onClick={saveText} loading={saving}>ذخیره</Button>
          </>
        }
      >
        <Field label="عنوان" hint="اگر خالی بگذارید، از ابتدای متن ساخته می‌شود.">
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="مثلاً: غزل حافظ" autoFocus />
        </Field>
        <div className="mt-3 flex flex-wrap gap-2 text-xs text-slate-500">
          <Badge tone="indigo">{formatNumber(words)} واژه</Badge>
          {activePresetId && <Badge tone="emerald">با پروفایل انتخابی</Badge>}
        </div>
      </Modal>

      {/* مودال ذخیرهٔ پروفایل */}
      <Modal
        open={presetOpen}
        onClose={() => setPresetOpen(false)}
        title="ذخیره به‌عنوان پروفایل صدا"
        footer={
          <>
            <Button variant="ghost" onClick={() => setPresetOpen(false)}>انصراف</Button>
            <Button onClick={savePreset} loading={savingPreset} disabled={!presetName.trim()}>ذخیره</Button>
          </>
        }
      >
        <Field label="نام پروفایل">
          <Input value={presetName} onChange={(e) => setPresetName(e.target.value)} placeholder={`مثلاً: ${persona.name} برای شب`} autoFocus />
        </Field>
        <p className="mt-3 text-xs leading-6 text-slate-500">
          {persona.emoji} {persona.name} · {settings.engine === "neural" ? "نیورال" : "دستگاه"} · سرعت ×{faNum(settings.rate.toFixed(2))} · مکث ×{faNum(settings.pauseScale.toFixed(1))}
        </p>
      </Modal>

      {/* افزودن سریع به واژه‌نامه */}
      <Modal
        open={quickWord !== null}
        onClose={() => setQuickWord(null)}
        title="افزودن تلفظ به واژه‌نامه"
        footer={
          <>
            <Button variant="ghost" onClick={() => setQuickWord(null)}>انصراف</Button>
            <Button variant="success" onClick={saveQuickWord} loading={quickSaving} disabled={!/[\u064B-\u0652]/.test(quickValue)}>ذخیرهٔ تلفظ</Button>
          </>
        }
      >
        <p className="mb-3 text-sm text-slate-600">مکان‌نما را بعد از حرف موردنظر بگذارید و روی علامت بزنید:</p>
        <Input ref={quickInputRef} value={quickValue} onChange={(e) => setQuickValue(e.target.value)} className="diacritic-text text-center text-2xl font-bold" dir="rtl" />
        <div className="mt-3">
          <DiacriticKeyboard inputRef={quickInputRef} value={quickValue} onChange={setQuickValue} />
        </div>
        <p className="mt-3 text-xs text-slate-500">واژهٔ اصلی: <b>{quickWord}</b> → <b className="text-emerald-700">{quickValue || "—"}</b></p>
      </Modal>
    </div>
  );
}
