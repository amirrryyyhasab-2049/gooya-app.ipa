"use client";

import Link from "next/link";
import { useState } from "react";
import { PageHeader } from "@/components/dashboard-shell";
import { Badge, Button, ConfirmDialog, EmptyState, Skeleton, cn } from "@/components/ui";
import { useToast } from "@/components/toast";
import { apiRequest, useCrud } from "@/hooks/useCrud";
import { formatDate, formatNumber, snippet, timeAgo } from "@/lib/format";
import { formatDuration } from "@/lib/tts/segment";

interface HistoryItem {
  id: number;
  textId: number | null;
  title: string;
  content: string;
  engine: string;
  voiceLabel: string;
  wordCount: number;
  durationSec: number | null;
  createdAt: string;
}

export default function HistoryPage() {
  const toast = useToast();
  const { items, loading, error, remove, setItems, refresh } = useCrud<HistoryItem>("/api/history");
  const [deleting, setDeleting] = useState<HistoryItem | null>(null);
  const [clearing, setClearing] = useState(false);
  const [busy, setBusy] = useState(false);

  const totalWords = items.reduce((s, i) => s + i.wordCount, 0);
  const totalSeconds = items.reduce((s, i) => s + (i.durationSec ?? 0), 0);

  const confirmDelete = async () => {
    if (!deleting) return;
    setBusy(true);
    try {
      await remove(deleting.id);
      setDeleting(null);
      toast("مورد حذف شد.", "success");
    } catch {
      toast("حذف ناموفق بود.", "error");
    } finally {
      setBusy(false);
    }
  };

  const clearAll = async () => {
    setBusy(true);
    const snapshot = items;
    setItems([]);
    try {
      await apiRequest("/api/history", { method: "DELETE" });
      setClearing(false);
      toast("تاریخچه پاک شد.", "success");
    } catch {
      setItems(snapshot);
      toast("پاک‌کردن ناموفق بود.", "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <PageHeader
        title="تاریخچهٔ پخش"
        description="هر متنی که تا انتها خوانده شود این‌جا ثبت می‌شود تا بتوانید دوباره بشنوید."
        action={items.length > 0 ? <Button variant="danger" onClick={() => setClearing(true)}>پاک‌کردن همه</Button> : undefined}
      />

      {!loading && items.length > 0 && (
        <div className="mb-6 grid grid-cols-3 gap-3">
          {[
            { label: "پخش", value: formatNumber(items.length) },
            { label: "واژه", value: formatNumber(totalWords) },
            { label: "زمان شنیدن", value: formatDuration(totalSeconds) },
          ].map((s) => (
            <div key={s.label} className="rounded-2xl border border-slate-200/80 bg-white p-4 text-center shadow-sm">
              <p className="text-lg font-black text-slate-900 sm:text-2xl">{s.value}</p>
              <p className="text-xs text-slate-500">{s.label}</p>
            </div>
          ))}
        </div>
      )}

      {error && (
        <div className="mb-4 flex items-center justify-between rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {error}
          <Button variant="ghost" size="sm" onClick={refresh}>تلاش دوباره</Button>
        </div>
      )}

      {loading ? (
        <div className="space-y-3">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="flex items-center gap-4 rounded-2xl border border-slate-200/80 bg-white p-4">
              <Skeleton className="h-10 w-10 rounded-xl" />
              <div className="flex-1 space-y-2"><Skeleton className="h-4 w-1/3" /><Skeleton className="h-3 w-2/3" /></div>
              <Skeleton className="h-8 w-24" />
            </div>
          ))}
        </div>
      ) : items.length === 0 ? (
        <EmptyState icon="🕘" title="تاریخچه خالی است" description="وقتی متنی را در استودیو تا پایان بشنوید، این‌جا ثبت می‌شود." action={<Link href="/" className="inline-flex h-11 items-center rounded-xl bg-indigo-600 px-5 text-sm font-bold text-white hover:bg-indigo-500">رفتن به استودیو</Link>} />
      ) : (
        <ul className="space-y-3">
          {items.map((h) => (
            <li key={h.id} className={cn("fade-up flex flex-col gap-3 rounded-2xl border border-slate-200/80 bg-white p-4 shadow-sm transition hover:shadow-md sm:flex-row sm:items-center", h.id < 0 && "opacity-60")}>
              <span className={cn("flex h-11 w-11 shrink-0 items-center justify-center rounded-xl text-lg", h.engine === "neural" ? "bg-indigo-50" : "bg-emerald-50")}>{h.engine === "neural" ? "☁️" : "📱"}</span>
              <div className="min-w-0 flex-1">
                <p className="truncate font-bold text-slate-900">{h.title}</p>
                <p className="mt-0.5 line-clamp-1 text-xs text-slate-500">{snippet(h.content, 120)}</p>
                <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
                  <Badge tone={h.engine === "neural" ? "indigo" : "emerald"}>{h.voiceLabel || (h.engine === "neural" ? "نیورال" : "دستگاه")}</Badge>
                  <span>{formatNumber(h.wordCount)} واژه</span>
                  {h.durationSec ? <span>· {formatDuration(h.durationSec)}</span> : null}
                  <span title={formatDate(h.createdAt)}>· {timeAgo(h.createdAt)}</span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Link href={`/?history=${h.id}`} className="inline-flex h-9 items-center gap-1 rounded-lg bg-gradient-to-l from-violet-600 to-indigo-600 px-3 text-xs font-bold text-white hover:from-violet-500 hover:to-indigo-500">▶ پخش دوباره</Link>
                <Button size="sm" variant="danger" onClick={() => setDeleting(h)}>حذف</Button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <ConfirmDialog open={deleting !== null} onClose={() => setDeleting(null)} onConfirm={confirmDelete} loading={busy} title="حذف از تاریخچه" description={`«${deleting?.title ?? ""}» از تاریخچه حذف شود؟`} />
      <ConfirmDialog open={clearing} onClose={() => setClearing(false)} onConfirm={clearAll} loading={busy} title="پاک‌کردن تاریخچه" description="تمام موارد تاریخچه حذف می‌شوند. متن‌های ذخیره‌شده دست‌نخورده می‌مانند." confirmLabel="پاک‌کردن همه" />
    </div>
  );
}
