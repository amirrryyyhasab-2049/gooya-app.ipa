"use client";

import { useState } from "react";
import { PageHeader } from "@/components/dashboard-shell";
import { Badge, Button, ConfirmDialog, EmptyState, Field, Input, Modal, Skeleton, Slider, cn } from "@/components/ui";
import { useToast } from "@/components/toast";
import { useCrud } from "@/hooks/useCrud";
import { useSpeech } from "@/hooks/useSpeech";
import { PERSONAS, getPersona, type EngineKind } from "@/lib/tts/personas";
import { faNum } from "@/lib/format";

interface PresetItem {
  id: number;
  name: string;
  description: string;
  engine: string;
  personaId: string;
  rate: number;
  pitch: number;
  pauseScale: number;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

const emptyForm = { name: "", description: "", engine: "neural" as EngineKind, personaId: "arman", rate: 1, pitch: 1, pauseScale: 1, isDefault: false };

export default function VoicesPage() {
  const toast = useToast();
  const { items, loading, error, create, update, remove, setItems, refresh } = useCrud<PresetItem>("/api/presets");
  const speech = useSpeech({ onNotice: (m, k) => toast(m, k === "error" ? "error" : "warning") });
  const [editing, setEditing] = useState<PresetItem | null | "new">(null);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<PresetItem | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [previewId, setPreviewId] = useState<number | null>(null);

  const openNew = () => {
    setForm(emptyForm);
    setEditing("new");
  };
  const openEdit = (p: PresetItem) => {
    setForm({ name: p.name, description: p.description, engine: p.engine === "browser" ? "browser" : "neural", personaId: p.personaId, rate: p.rate, pitch: p.pitch, pauseScale: p.pauseScale, isDefault: p.isDefault });
    setEditing(p);
  };

  const preview = (p: { id?: number; engine: string; personaId: string; rate: number; pitch: number; pauseScale: number }) => {
    const persona = getPersona(p.personaId);
    setPreviewId(p.id ?? -1);
    void speech.play(persona.sample, { engine: p.engine === "browser" ? "browser" : "neural", personaId: p.personaId, rate: p.rate, pitch: p.pitch, pauseScale: p.pauseScale });
  };

  const submit = async () => {
    if (!form.name.trim()) return toast("نام پروفایل را وارد کنید.", "warning");
    setSaving(true);
    const now = new Date().toISOString();
    try {
      if (form.isDefault) setItems((prev) => prev.map((i) => ({ ...i, isDefault: false })));
      if (editing === "new") {
        await create({ ...form }, { ...form, createdAt: now, updatedAt: now });
        toast("پروفایل صدا ساخته شد.", "success");
      } else if (editing) {
        await update(editing.id, { ...form }, { ...form, updatedAt: now });
        toast("پروفایل به‌روزرسانی شد.", "success");
      }
      setEditing(null);
      if (form.isDefault) void refresh();
    } catch (err) {
      toast(err instanceof Error ? err.message : "خطا در ذخیره", "error");
      void refresh();
    } finally {
      setSaving(false);
    }
  };

  const makeDefault = async (p: PresetItem) => {
    const snapshot = items;
    setItems((prev) => prev.map((i) => ({ ...i, isDefault: i.id === p.id })));
    try {
      await update(p.id, { isDefault: true });
      toast(`«${p.name}» پروفایل پیش‌فرض شد.`, "success");
    } catch {
      setItems(snapshot);
      toast("تغییر پیش‌فرض ناموفق بود.", "error");
    }
  };

  const confirmDelete = async () => {
    if (!deleting) return;
    setDeleteBusy(true);
    try {
      await remove(deleting.id);
      toast("پروفایل حذف شد.", "success");
      setDeleting(null);
    } catch {
      toast("حذف ناموفق بود.", "error");
    } finally {
      setDeleteBusy(false);
    }
  };

  const formPersona = getPersona(form.personaId);

  return (
    <div>
      <PageHeader
        title="پروفایل‌های صدا"
        description="ترکیب دلخواه‌تان از گوینده، سرعت، زیر و بمی و مکث را ذخیره کنید و در استودیو با یک کلیک اعمال کنید."
        action={<Button onClick={openNew}>＋ پروفایل جدید</Button>}
      />

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-bold text-slate-700">گوینده‌های پایه</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {PERSONAS.map((p) => (
            <div key={p.id} className="flex items-center gap-3 rounded-2xl border border-slate-200/80 bg-white p-3 shadow-sm">
              <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br ${p.gradient} text-xl`}>{p.emoji}</span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-bold text-slate-800">{p.name}</p>
                <p className="truncate text-[11px] text-slate-500">{p.tagline}</p>
              </div>
              <button onClick={() => preview({ engine: "neural", personaId: p.id, rate: 1, pitch: 1, pauseScale: 1 })} className="rounded-lg bg-indigo-50 px-2 py-1.5 text-xs font-bold text-indigo-700 hover:bg-indigo-100" aria-label="پیش‌نمایش">▶</button>
            </div>
          ))}
        </div>
      </section>

      <h2 className="mb-3 text-sm font-bold text-slate-700">پروفایل‌های من</h2>

      {error && (
        <div className="mb-4 flex items-center justify-between rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {error}
          <Button variant="ghost" size="sm" onClick={refresh}>تلاش دوباره</Button>
        </div>
      )}

      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="space-y-3 rounded-2xl border border-slate-200/80 bg-white p-5">
              <div className="flex items-center gap-3"><Skeleton className="h-12 w-12 rounded-xl" /><div className="flex-1 space-y-2"><Skeleton className="h-4 w-1/2" /><Skeleton className="h-3 w-1/3" /></div></div>
              <Skeleton className="h-3 w-full" /><Skeleton className="h-3 w-full" /><Skeleton className="h-3 w-2/3" />
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState icon="🎚️" title="هنوز پروفایلی نساخته‌اید" description="یک گوینده انتخاب کنید، لحن و سرعتش را تنظیم کنید و با نامی دلخواه ذخیره کنید." action={<Button onClick={openNew}>＋ ساخت اولین پروفایل</Button>} />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {items.map((p) => {
            const persona = getPersona(p.personaId);
            const isPreviewing = previewId === p.id && speech.status !== "idle";
            return (
              <article key={p.id} className={cn("fade-up rounded-2xl border bg-white p-5 shadow-sm transition hover:shadow-md", p.isDefault ? "border-emerald-300 ring-2 ring-emerald-100" : "border-slate-200/80", p.id < 0 && "opacity-60")}>
                <div className="flex items-center gap-3">
                  <span className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br ${persona.gradient} text-2xl shadow`}>{persona.emoji}</span>
                  <div className="min-w-0 flex-1">
                    <h3 className="truncate font-bold text-slate-900">{p.name}</h3>
                    <p className="truncate text-xs text-slate-500">{persona.name} · {p.engine === "neural" ? "نیورال آنلاین" : "صدای دستگاه"}</p>
                  </div>
                  {p.isDefault && <Badge tone="emerald">پیش‌فرض</Badge>}
                </div>
                {p.description && <p className="mt-3 line-clamp-2 text-sm leading-6 text-slate-500">{p.description}</p>}
                <dl className="mt-4 space-y-2 text-xs">
                  {[
                    ["سرعت", p.rate, 0.5, 1.6],
                    ["زیر و بمی", p.pitch, 0.6, 1.4],
                    ["مکث", p.pauseScale, 0.4, 2.2],
                  ].map(([label, value, min, max]) => (
                    <div key={label as string} className="flex items-center gap-2">
                      <dt className="w-16 text-slate-500">{label as string}</dt>
                      <dd className="flex-1"><div className="h-1.5 rounded-full bg-slate-100"><div className="h-full rounded-full bg-gradient-to-l from-violet-500 to-indigo-500" style={{ width: `${(((value as number) - (min as number)) / ((max as number) - (min as number))) * 100}%` }} /></div></dd>
                      <dd className="w-10 text-end tabular-nums text-slate-600">×{faNum((value as number).toFixed(2))}</dd>
                    </div>
                  ))}
                </dl>
                <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-3">
                  <Button size="sm" variant={isPreviewing ? "secondary" : "primary"} onClick={() => (isPreviewing ? speech.stop() : preview(p))}>{isPreviewing ? "■ توقف" : "▶ تست صدا"}</Button>
                  <Button size="sm" variant="secondary" onClick={() => openEdit(p)}>ویرایش</Button>
                  {!p.isDefault && <Button size="sm" variant="ghost" onClick={() => makeDefault(p)}>پیش‌فرض شود</Button>}
                  <Button size="sm" variant="danger" className="ms-auto" onClick={() => setDeleting(p)}>حذف</Button>
                </div>
              </article>
            );
          })}
        </div>
      )}

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === "new" ? "پروفایل صدای جدید" : "ویرایش پروفایل"}
        size="lg"
        footer={
          <>
            <Button variant="ghost" onClick={() => setEditing(null)}>انصراف</Button>
            <Button variant="secondary" onClick={() => preview({ ...form })}>▶ پیش‌نمایش</Button>
            <Button onClick={submit} loading={saving}>ذخیره</Button>
          </>
        }
      >
        <div className="space-y-5">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="نام پروفایل"><Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="مثلاً: قصهٔ شب" autoFocus /></Field>
            <Field label="توضیح (اختیاری)"><Input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="برای چه متن‌هایی مناسب است؟" /></Field>
          </div>
          <div>
            <p className="mb-2 text-sm font-medium text-slate-700">موتور</p>
            <div className="grid grid-cols-2 gap-1 rounded-xl bg-slate-100 p-1">
              {(["neural", "browser"] as EngineKind[]).map((eng) => (
                <button key={eng} type="button" onClick={() => setForm({ ...form, engine: eng })} className={cn("rounded-lg px-3 py-2 text-xs font-semibold transition", form.engine === eng ? "bg-white text-indigo-700 shadow" : "text-slate-500")}>
                  {eng === "neural" ? "☁️ نیورال (آنلاین)" : "📱 دستگاه (آفلاین)"}
                </button>
              ))}
            </div>
          </div>
          <div>
            <p className="mb-2 text-sm font-medium text-slate-700">گوینده</p>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              {PERSONAS.map((p) => (
                <button key={p.id} type="button" onClick={() => setForm({ ...form, personaId: p.id })} className={cn("flex flex-col items-center gap-1 rounded-xl border p-2.5 text-center transition", form.personaId === p.id ? "border-indigo-400 bg-indigo-50 ring-2 ring-indigo-200" : "border-slate-200 hover:bg-slate-50")}>
                  <span className={`flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br ${p.gradient} text-lg`}>{p.emoji}</span>
                  <span className="text-xs font-bold text-slate-800">{p.name}</span>
                </button>
              ))}
            </div>
            <p className="mt-2 text-xs text-slate-500">{formPersona.description}</p>
          </div>
          <div className="space-y-4 rounded-xl bg-slate-50 p-4">
            <Slider label="سرعت" min={0.6} max={1.4} step={0.05} value={form.rate} onChange={(v) => setForm({ ...form, rate: v })} format={(v) => `×${faNum(v.toFixed(2))}`} />
            <Slider label="زیر و بمی" min={0.7} max={1.3} step={0.05} value={form.pitch} onChange={(v) => setForm({ ...form, pitch: v })} format={(v) => `×${faNum(v.toFixed(2))}`} />
            <Slider label="مکث‌ها" min={0.5} max={2} step={0.1} value={form.pauseScale} onChange={(v) => setForm({ ...form, pauseScale: v })} format={(v) => `×${faNum(v.toFixed(1))}`} />
          </div>
          <label className="flex cursor-pointer items-center gap-3">
            <input type="checkbox" checked={form.isDefault} onChange={(e) => setForm({ ...form, isDefault: e.target.checked })} className="h-4 w-4 rounded border-slate-300 text-indigo-600" />
            <span className="text-sm text-slate-700">این پروفایل پیش‌فرض استودیو باشد</span>
          </label>
        </div>
      </Modal>

      <ConfirmDialog open={deleting !== null} onClose={() => setDeleting(null)} onConfirm={confirmDelete} loading={deleteBusy} title="حذف پروفایل صدا" description={`آیا از حذف «${deleting?.name ?? ""}» مطمئن هستید؟`} />
    </div>
  );
}
