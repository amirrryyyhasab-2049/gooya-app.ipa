"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { PageHeader } from "@/components/dashboard-shell";
import { Badge, Button, ConfirmDialog, EmptyState, Field, Input, Modal, Skeleton, Textarea, cn } from "@/components/ui";
import { useToast } from "@/components/toast";
import { useCrud } from "@/hooks/useCrud";
import { formatNumber, snippet, timeAgo } from "@/lib/format";
import { countWords } from "@/lib/tts/segment";

interface TextItem {
  id: number;
  title: string;
  content: string;
  presetId: number | null;
  isFavorite: boolean;
  wordCount: number;
  createdAt: string;
  updatedAt: string;
}

export default function TextsPage() {
  const toast = useToast();
  const { items, loading, error, create, update, remove, refresh } = useCrud<TextItem>("/api/texts");
  const [query, setQuery] = useState("");
  const [onlyFav, setOnlyFav] = useState(false);
  const [editing, setEditing] = useState<TextItem | null | "new">(null);
  const [form, setForm] = useState({ title: "", content: "" });
  const [saving, setSaving] = useState(false);
  const [deleting, setDeleting] = useState<TextItem | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const filtered = useMemo(() => {
    const q = query.trim();
    return items.filter((t) => (!onlyFav || t.isFavorite) && (!q || t.title.includes(q) || t.content.includes(q)));
  }, [items, query, onlyFav]);

  const openNew = () => {
    setForm({ title: "", content: "" });
    setEditing("new");
  };
  const openEdit = (t: TextItem) => {
    setForm({ title: t.title, content: t.content });
    setEditing(t);
  };

  const submit = async () => {
    if (!form.content.trim()) return toast("متن نمی‌تواند خالی باشد.", "warning");
    setSaving(true);
    const now = new Date().toISOString();
    try {
      if (editing === "new") {
        await create(
          { title: form.title, content: form.content },
          { title: form.title || snippet(form.content, 48), content: form.content, presetId: null, isFavorite: false, wordCount: countWords(form.content), createdAt: now, updatedAt: now },
        );
        toast("متن ذخیره شد.", "success");
      } else if (editing) {
        await update(editing.id, { title: form.title, content: form.content }, { title: form.title, content: form.content, wordCount: countWords(form.content), updatedAt: now });
        toast("تغییرات ذخیره شد.", "success");
      }
      setEditing(null);
    } catch (err) {
      toast(err instanceof Error ? err.message : "خطا در ذخیره", "error");
    } finally {
      setSaving(false);
    }
  };

  const toggleFavorite = async (t: TextItem) => {
    try {
      await update(t.id, { isFavorite: !t.isFavorite }, { isFavorite: !t.isFavorite });
    } catch {
      toast("تغییر علاقه‌مندی ناموفق بود.", "error");
    }
  };

  const confirmDelete = async () => {
    if (!deleting) return;
    setDeleteBusy(true);
    try {
      await remove(deleting.id);
      toast("متن حذف شد.", "success");
      setDeleting(null);
    } catch {
      toast("حذف ناموفق بود.", "error");
    } finally {
      setDeleteBusy(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="متن‌های من"
        description="متن‌هایی که ذخیره کرده‌اید؛ هر زمان خواستید با یک کلیک در استودیو پخش کنید."
        action={<Button onClick={openNew}>＋ متن جدید</Button>}
      />

      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center">
        <Input placeholder="جستجو در عنوان و متن…" value={query} onChange={(e) => setQuery(e.target.value)} className="sm:max-w-sm" />
        <button onClick={() => setOnlyFav((v) => !v)} className={cn("inline-flex h-10 items-center gap-1.5 rounded-xl border px-3 text-sm transition", onlyFav ? "border-amber-300 bg-amber-50 text-amber-800" : "border-slate-200 bg-white text-slate-600 hover:bg-slate-50")}>
          ★ فقط علاقه‌مندی‌ها
        </button>
        <span className="text-xs text-slate-400 sm:ms-auto">{formatNumber(filtered.length)} متن</span>
      </div>

      {error && (
        <div className="mb-4 flex items-center justify-between rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {error}
          <Button variant="ghost" size="sm" onClick={refresh}>تلاش دوباره</Button>
        </div>
      )}

      {loading ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="space-y-3 rounded-2xl border border-slate-200/80 bg-white p-5">
              <Skeleton className="h-5 w-2/3" />
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-5/6" />
              <div className="flex gap-2 pt-2"><Skeleton className="h-8 w-20" /><Skeleton className="h-8 w-16" /></div>
            </div>
          ))}
        </div>
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="📝"
          title={items.length === 0 ? "هنوز متنی ذخیره نکرده‌اید" : "چیزی پیدا نشد"}
          description={items.length === 0 ? "متن‌های پرکاربردتان را ذخیره کنید تا هر بار لازم نباشد دوباره بنویسید." : "عبارت دیگری را جستجو کنید یا فیلتر علاقه‌مندی را بردارید."}
          action={items.length === 0 ? <Button onClick={openNew}>＋ اولین متن را بسازید</Button> : undefined}
        />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {filtered.map((t) => (
            <article key={t.id} className={cn("fade-up flex flex-col rounded-2xl border border-slate-200/80 bg-white p-5 shadow-sm transition hover:shadow-md", t.id < 0 && "opacity-60")}>
              <div className="flex items-start gap-2">
                <h3 className="line-clamp-1 flex-1 font-bold text-slate-900">{t.title}</h3>
                <button onClick={() => toggleFavorite(t)} className={cn("text-xl leading-none transition", t.isFavorite ? "text-amber-400" : "text-slate-300 hover:text-amber-300")} aria-label="علاقه‌مندی">★</button>
              </div>
              <p className="mt-2 line-clamp-3 flex-1 text-sm leading-7 text-slate-500">{snippet(t.content, 160)}</p>
              <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-slate-400">
                <Badge>{formatNumber(t.wordCount)} واژه</Badge>
                <span>{timeAgo(t.updatedAt)}</span>
              </div>
              <div className="mt-4 flex items-center gap-2 border-t border-slate-100 pt-3">
                <Link href={`/?text=${t.id}`} className="inline-flex h-9 flex-1 items-center justify-center gap-1 rounded-lg bg-gradient-to-l from-violet-600 to-indigo-600 text-xs font-bold text-white hover:from-violet-500 hover:to-indigo-500">▶ پخش در استودیو</Link>
                <Button variant="secondary" size="sm" onClick={() => openEdit(t)}>ویرایش</Button>
                <Button variant="danger" size="sm" onClick={() => setDeleting(t)}>حذف</Button>
              </div>
            </article>
          ))}
        </div>
      )}

      <Modal
        open={editing !== null}
        onClose={() => setEditing(null)}
        title={editing === "new" ? "متن جدید" : "ویرایش متن"}
        size="lg"
        footer={
          <>
            <Button variant="ghost" onClick={() => setEditing(null)}>انصراف</Button>
            <Button onClick={submit} loading={saving}>ذخیره</Button>
          </>
        }
      >
        <div className="space-y-4">
          <Field label="عنوان" hint="اختیاری — اگر خالی باشد از ابتدای متن ساخته می‌شود.">
            <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="مثلاً: سخنرانی جلسهٔ فردا" />
          </Field>
          <Field label="متن">
            <Textarea value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} rows={10} placeholder="متن فارسی…" className="diacritic-text text-base" />
          </Field>
          <p className="text-xs text-slate-400">{formatNumber(countWords(form.content))} واژه</p>
        </div>
      </Modal>

      <ConfirmDialog
        open={deleting !== null}
        onClose={() => setDeleting(null)}
        onConfirm={confirmDelete}
        loading={deleteBusy}
        title="حذف متن"
        description={`آیا از حذف «${deleting?.title ?? ""}» مطمئن هستید؟ این کار قابل بازگشت نیست.`}
      />
    </div>
  );
}
