"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { PageHeader } from "@/components/dashboard-shell";
import { Button, Card, Field, Input, Skeleton } from "@/components/ui";
import { useToast } from "@/components/toast";
import { apiRequest } from "@/hooks/useCrud";
import { formatDate } from "@/lib/format";

interface Me {
  id: number;
  name: string;
  email: string;
  createdAt: string;
}

export default function SettingsPage() {
  const toast = useToast();
  const router = useRouter();
  const [me, setMe] = useState<Me | null>(null);
  const [name, setName] = useState("");
  const [savingName, setSavingName] = useState(false);

  useEffect(() => {
    apiRequest<{ user: Me }>("/api/me")
      .then((d) => {
        setMe(d.user);
        setName(d.user.name);
      })
      .catch(() => toast("دریافت اطلاعات ناموفق بود.", "error"));
  }, [toast]);

  const saveName = async (e: FormEvent) => {
    e.preventDefault();
    if (name.trim().length < 2) return toast("نام باید حداقل ۲ حرف باشد.", "warning");
    setSavingName(true);
    const prev = me;
    setMe((m) => (m ? { ...m, name: name.trim() } : m));
    try {
      const d = await apiRequest<{ user: Me }>("/api/me", { method: "PATCH", body: JSON.stringify({ name: name.trim() }) });
      setMe((m) => (m ? { ...m, ...d.user } : m));
      toast("نام شما به‌روزرسانی شد.", "success");
      router.refresh();
    } catch (err) {
      setMe(prev);
      toast(err instanceof Error ? err.message : "خطا", "error");
    } finally {
      setSavingName(false);
    }
  };

  const resetLocal = () => {
    localStorage.removeItem("gooya:settings");
    localStorage.removeItem("gooya:draft");
    toast("تنظیمات محلی استودیو بازنشانی شد.", "success");
  };

  return (
    <div className="space-y-6">
      <PageHeader title="تنظیمات" description="نام نمایشی و ترجیحات برنامه. فعلاً برنامه بدون ورود و ثبت‌نام کار می‌کند." />

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="p-6">
          <h2 className="text-lg font-bold text-slate-900">فضای کاری</h2>
          {!me ? (
            <div className="mt-4 space-y-3"><Skeleton className="h-10 w-full" /><Skeleton className="h-10 w-28" /></div>
          ) : (
            <form onSubmit={saveName} className="mt-4 space-y-4">
              <Field label="نام نمایشی"><Input value={name} onChange={(e) => setName(e.target.value)} /></Field>
              <p className="text-xs text-slate-400">ساخته‌شده در {formatDate(me.createdAt)}</p>
              <Button type="submit" loading={savingName} disabled={name.trim() === me.name}>ذخیرهٔ نام</Button>
            </form>
          )}
        </Card>

        <Card className="p-6">
          <h2 className="text-lg font-bold text-slate-900">استودیو</h2>
          <p className="mt-2 text-sm leading-7 text-slate-500">تنظیمات صدا و پیش‌نویس متن در همین دستگاه ذخیره می‌شوند. اگر چیزی به‌هم ریخته، می‌توانید آن‌ها را بازنشانی کنید.</p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button variant="outline" onClick={resetLocal}>بازنشانی تنظیمات محلی</Button>
          </div>
        </Card>
      </div>
    </div>
  );
}
