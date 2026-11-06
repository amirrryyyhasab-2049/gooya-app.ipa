"use client";

import { useMemo, useRef, useState } from "react";
import { PageHeader } from "@/components/dashboard-shell";
import { Button, ConfirmDialog, EmptyState, Field, Input, Modal, Skeleton, cn } from "@/components/ui";
import { useToast } from "@/components/toast";
import { DiacriticKeyboard } from "@/components/diacritic-keyboard";
import { useCrud } from "@/hooks/useCrud";
import { useSpeech } from "@/hooks/useSpeech";
import { DEFAULT_SETTINGS } from "@/lib/tts/personas";
import { stripDiacritics } from "@/lib/tts/diacritize";
import { formatNumber, timeAgo } from "@/lib/format";

interface DictItem {
  id: number;
  word: string;
  diacritized: string;
  note: string;
  createdAt: string;
  updatedAt: string;
}

const SUGGESTIONS: Array<{ word: string; diacritized: string; note: string }> = [
  { word: "عصبانی", diacritized: "عَصَبانی", note: "نه عُصبانی" },
  { word: "مرد", diacritized: "مَرد", note: "مَرد در برابر مُرد" },
  { word: "گل", diacritized: "گُل", note: "گُل در برابر گِل" },
  { word: "کرم", diacritized: "کِرم", note: "کِرم / کَرَم / کِرِم" },
  { word: "شکر", diacritized: "شِکَر", note: "شِکَر در برابر شُکر" },
  { word: "کشتی", diacritized: "کَشتی", note: "کَشتی در برابر کُشتی" },
  { word: "ملک", diacritized: "مِلک", note: "مِلک / مُلک / مَلَک" },
  { word: "سر", diacritized: "سَر", note: "سَر در برابر سِر" },
  { word: "مهر", diacritized: "مِهر", note: "مِهر در برابر مُهر" },
  { word: "خرد", diacritized: "خِرَد", note: "خِرَد در برابر خُرد" },
  { word: "بعد", diacritized: "بَعد", note: "بَعد در برابر بُعد" },
  { word: "درست", diacritized: "دُرُست", note: "" },
];

export default function DictionaryPage() {
  const toast = useToast();
  const { items, loading, error, create, update, remove, refresh } = useCrud<DictItem>("/api/dictionary");
  const speech = useSpeech({ onNotice: (m, k) => toast(m, k === "error" ? "error" : "warning") });
  const [query, setQuery] = useState("");
  const [editing, setEditing] = useState<DictItem | null | "new">(null);
  const [form, setForm] = useState({ word: "", diacritized: "", note: "" });
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<DictItem | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [bulkBusy, setBulkBusy] = useState(false);
  const diacritizedRef = useRef<HTMLInputElement>(null);

  const filtered = useMemo(() => {
    const q = stripDiacritics(query.trim());
    return items.filter((d) => !q || d.word.includes(q) || d.note.includes(q));
  }, [items, query]);

  const missingSuggestions = SUGGESTIONS.filter((s) => !items.some((i) => i.word === s.word));

  const openNew = () => {
    setForm({ word: "", diacritized: "", note: "" });
    setEditing("new");
  };
  const openEdit = (d: DictItem) => {
    setForm({ word: d.word, diacritized: d.diacritized, note: d.note });
    setEditing(d);
  };

  const valid = form.word.trim() && form.diacritized.trim() && stripDiacritics(form.diacritized).replace(/\u200C/g, "") === stripDiacritics(form.word).replace(/\u200C/g, "");

  const submit = async () => {
    if (!valid) return toast("شکل اعراب‌گذاری‌شده باید همان واژه با اعراب باشد.", "warning");
    setSaving(true);
    const now = new Date().toISOString();
    const payload = { word: stripDiacritics(form.word.trim()), diacritized: form.diacritized.trim(), note: form.note.trim() };
    try {
      if (editing === "new") {
        await create(payload, { ...payload, createdAt: now, updatedAt: now });
        toast("واژه به واژه‌نامه اضافه شد.", "success");
        void refresh();
      } else if (editing) {
        await update(editing.id, payload, { ...payload, updatedAt: now });
        toast("مدخل به‌روزرسانی شد.", "success");
      }
      setEditing(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : "خطا در ذخیره", "error");
    } finally {
      setSaving(false);
    }
  };

  const addSuggestions = async () => {
    setBulkBusy(true);
    let added = 0;
    for (const s of missingSuggestions) {
      try {
        await create(s, { ...s, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
        added += 1;
      } catch {
        /* skip */
      }
    }
    setBulkBusy(false);
    toast(`${formatNumber(added)} واژهٔ پیشنهادی اضافه شد.`, "success");
  };

  const confirmDelete = async () => {
    if (!deleting) return;
    setDeleteBusy(true);
    try {
      await remove(deleting.id);
      toast("مدخل حذف شد.", "success");
      setDeleting(null);
    } catch {
      toast("حذف ناموفق بود.", "error");
    } finally {
      setDeleteBusy(false);
    }
  };

  const say = (text: string) => void speech.play(text, { ...DEFAULT_SETTINGS, rate: 0.9 });

  return (
    <div>
      <PageHeader
        title="واژه‌نامهٔ تلفظ"
        description="تلفظ درست واژه‌های دوپهلو را یک بار ثبت کنید. دکمهٔ «اعراب‌گذاری خودکار» همیشه این واژه‌نامه را بر همه‌چیز مقدم می‌داند."
        action={
          <>
            {missingSuggestions.length > 0 && !loading && <Button variant="outline" onClick={addSuggestions} loading={bulkBusy}>افزودن {formatNumber(missingSuggestions.length)} واژهٔ پیشنهادی</Button>}
            <Button onClick={openNew}>＋ واژهٔ جدید</Button>
          </>
        }
      />

      <div className="mb-5 flex items-center gap-3">
        <Input placeholder="جستجوی واژه…" value={query} onChange={(e) => setQuery(e.target.value)} className="sm:max-w-sm" />
        <span className="text-xs text-slate-400">{formatNumber(filtered.length)} مدخل</span>
      </div>

      {error && (
        <div className="mb-4 flex items-center justify-between rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {error}
          <Button variant="ghost" size="sm" onClick={refresh}>تلاش دوباره</Button>
        </div>
      )}

      {loading ? (
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex items-center gap-4 border-b border-slate-100 px-5 py-4 last:border-0">
              <Skeleton className="h-6 w-20" /><Skeleton className="h-6 w-24" /><Skeleton className="h-4 flex-1" /><Skeleton className="h-8 w-24" />
            </div>
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="🔤"
          title={items.length === 0 ? "واژه‌نامهٔ شما خالی است" : "واژه‌ای پیدا نشد"}
          description={items.length === 0 ? "واژه‌هایی مثل «عصبانی»، «گل» یا «مرد» را با اعراب درست ثبت کنید تا گوینده هرگز اشتباه نخواند." : "عبارت دیگری را جستجو کنید."}
          action={items.length === 0 ? <div className="flex gap-2"><Button onClick={openNew}>＋ افزودن واژه</Button><Button variant="outline" onClick={addSuggestions} loading={bulkBusy}>افزودن واژه‌های پیشنهادی</Button></div> : undefined}
        />
      ) : (
        <div className="overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm">
          <div className="hidden grid-cols-[1fr_1fr_2fr_auto] gap-4 border-b border-slate-100 bg-slate-50/70 px-5 py-2.5 text-xs font-semibold text-slate-500 sm:grid">
            <span>واژه</span><span>تلفظ درست</span><span>یادداشت</span><span className="w-44 text-end">عملیات</span>
          </div>
          <ul className="divide-y divide-slate-100">
            {filtered.map((d) => (
              <li key={d.id} className={cn("fade-up grid gap-2 px-5 py-3.5 transition hover:bg-slate-50/60 sm:grid-cols-[1fr_1fr_2fr_auto] sm:items-center sm:gap-4", d.id < 0 && "opacity-60")}>
                <span className="text-base font-semibold text-slate-800">{d.word}</span>
                <span className="diacritic-text text-xl font-bold text-emerald-700">{d.diacritized}</span>
                <span className="text-xs leading-6 text-slate-500">{d.note || <span className="text-slate-300">—</span>} <span className="text-slate-300">· {timeAgo(d.updatedAt)}</span></span>
                <span className="flex items-center gap-1.5 sm:w-44 sm:justify-end">
                  <Button size="sm" variant="secondary" onClick={() => say(d.diacritized)} title="بشنو">🔊</Button>
                  <Button size="sm" variant="ghost" onClick={() => openEdit(d)}>ویرایش</Button>
                  <Button size="sm" variant="danger" onClick={() => setDeleting(d)}>حذف</Button>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === "new" ? "واژهٔ جدید" : "ویرایش واژه"}
        footer={
          <>
            <Button variant="ghost" onClick={() => setEditing(null)}>انصراف</Button>
            <Button variant="secondary" onClick={() => say(form.diacritized || form.word)} disabled={!form.diacritized && !form.word}>🔊 بشنو</Button>
            <Button variant="success" onClick={submit} loading={saving} disabled={!valid}>ذخیره</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="واژه (بدون اعراب)">
            <Input
              value={form.word}
              onChange={(e) => {
                const w = e.target.value;
                const base = stripDiacritics(form.diacritized);
                setForm({ ...form, word: w, diacritized: base === form.word || !form.diacritized ? w : form.diacritized });
              }}
              placeholder="مثلاً: عصبانی"
              autoFocus
            />
          </Field>
          <Field label="تلفظ درست (با اعراب)" hint="مکان‌نما را بعد از حرف بگذارید و روی علامت بزنید.">
            <Input ref={diacritizedRef} value={form.diacritized} onChange={(e) => setForm({ ...form, diacritized: e.target.value })} placeholder="مثلاً: عَصَبانی" className="diacritic-text text-xl font-bold" />
          </Field>
          <DiacriticKeyboard inputRef={diacritizedRef} value={form.diacritized} onChange={(v) => setForm({ ...form, diacritized: v })} />
          {form.diacritized && !valid && <p className="text-xs text-rose-600">شکل اعراب‌گذاری‌شده باید دقیقاً همان واژه باشد (فقط با علامت‌های اضافه).</p>}
          <Field label="یادداشت (اختیاری)">
            <Input value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} placeholder="مثلاً: نه عُصبانی!" />
          </Field>
        </div>
      </Modal>

      <ConfirmDialog open={deleting !== null} onClose={() => setDeleting(null)} onConfirm={confirmDelete} loading={deleteBusy} title="حذف واژه" description={`آیا «${deleting?.word ?? ""}» از واژه‌نامه حذف شود؟`} />
    </div>
  );
}
