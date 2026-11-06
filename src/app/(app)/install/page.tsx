"use client";

import { useEffect, useState } from "react";
import { PageHeader } from "@/components/dashboard-shell";
import { Button, Card } from "@/components/ui";
import { useToast } from "@/components/toast";

export default function InstallPage() {
  const toast = useToast();
  const [installable, setInstallable] = useState(false);
  const [installed, setInstalled] = useState(false);
  const [origin, setOrigin] = useState("");
  const [localInfo, setLocalInfo] = useState<{ local: boolean; lanUrls: string[] } | null>(null);

  useEffect(() => {
    fetch("/api/local-info", { cache: "no-store" })
      .then((r) => r.json())
      .then((d: { local: boolean; lanUrls: string[] }) => setLocalInfo(d))
      .catch(() => {});
  }, []);

  useEffect(() => {
    setOrigin(window.location.origin);
    setInstalled(window.matchMedia("(display-mode: standalone)").matches);
    setInstallable(Boolean(window.__gooyaInstallPrompt));
    const onInstallable = () => setInstallable(true);
    const onInstalled = () => {
      setInstalled(true);
      toast("گویا روی دستگاه شما نصب شد! 🎉", "success");
    };
    window.addEventListener("gooya:installable", onInstallable);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("gooya:installable", onInstallable);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, [toast]);

  const install = async () => {
    const prompt = window.__gooyaInstallPrompt;
    if (!prompt) return toast("از منوی مرورگر گزینهٔ «افزودن به صفحهٔ اصلی» را بزنید.", "info");
    await prompt.prompt();
    const choice = await prompt.userChoice;
    if (choice.outcome === "accepted") window.__gooyaInstallPrompt = null;
  };

  const copy = async () => {
    await navigator.clipboard.writeText(origin);
    toast("آدرس کپی شد.", "success");
  };

  return (
    <div className="space-y-6">
      <PageHeader title="نصب روی موبایل" description="اپ بومی آیفون (فایل IPA)، یا نصب سریع به‌عنوان وب‌اپ از Safari. راه‌های دیگر: اجرا روی کامپیوتر و بازکردن از طریق Wi-Fi." />

      <section className="rounded-3xl bg-gradient-to-br from-emerald-600 via-teal-600 to-emerald-700 p-6 text-white shadow-xl sm:p-8">
        <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="flex items-center gap-2 text-2xl font-black"><span>🍎</span> اپ بومی آیفون (IPA)</h2>
            <p className="mt-2 max-w-xl text-sm leading-7 text-white/90">
              نسخهٔ بومی گویا با Swift؛ مستقل و بدون نیاز به این سرور. موتور صدای نیورال (فرید و دیلارا) مستقیماً از خود گوشی گرفته می‌شود، اعراب‌گذاری خودکار، ۸ گوینده و نوار پیمایش داخل اپ است.
            </p>
            <ol className="mt-3 space-y-1 text-xs leading-6 text-white/80">
              <li>۱. فایل <span dir="ltr" className="font-mono">Gooya.ipa</span> را از GitHub Actions یا Releases دانلود کنید.</li>
              <li>۲. چون فایل امضا ندارد، با ابزار <span dir="ltr" className="font-mono">Sideloadly</span> و Apple ID خودتان روی آیفون نصب کنید (روی آیفون باید Developer Mode روشن باشد).</li>
              <li>۳. با Apple ID رایگان، نصب ۷ روز اعتبار دارد و بعد از آن باید دوباره امضا شود. راهنمای کامل در فایل <span dir="ltr" className="font-mono">IOS.md</span> پروژه است.</li>
            </ol>
          </div>
          <a href="https://github.com/amirrryyyhasab-2049/gooya-app.ipa/releases" target="_blank" rel="noreferrer" className="inline-flex h-12 shrink-0 items-center gap-2 rounded-xl bg-white px-6 text-sm font-bold text-emerald-700 shadow-lg hover:bg-emerald-50">
            ⬇️ دانلود Gooya.ipa
          </a>
        </div>
      </section>

      {localInfo?.local && (
        <section className="rounded-3xl border-2 border-emerald-300 bg-emerald-50 p-6 shadow-sm sm:p-8">
          <h2 className="flex items-center gap-2 text-xl font-black text-emerald-900"><span>📶</span> روی گوشی باز کنید (همین حالا)</h2>
          <p className="mt-2 text-sm leading-7 text-emerald-800">گویا الان روی این کامپیوتر اجرا شده است. گوشی را به <b>همان Wi-Fi</b> وصل کنید و یکی از این آدرس‌ها را در Safari آیفون باز کنید:</p>
          <div className="mt-4 flex flex-wrap gap-2">
            {localInfo.lanUrls.length === 0 && <span className="text-sm text-emerald-700">آدرس شبکه‌ای پیدا نشد؛ مطمئن شوید کامپیوتر به Wi-Fi متصل است.</span>}
            {localInfo.lanUrls.map((u) => (
              <button key={u} onClick={() => navigator.clipboard.writeText(u).then(() => toast("آدرس کپی شد.", "success"))} className="rounded-xl bg-white px-4 py-2 font-mono text-base font-bold text-emerald-800 shadow ring-1 ring-emerald-200 hover:bg-emerald-100" dir="ltr" title="کپی">
                {u}
              </button>
            ))}
          </div>
          <p className="mt-4 text-xs leading-6 text-emerald-700">سپس دکمهٔ <b>Share</b> (مربع با فلش) را بزنید و <b>Add to Home Screen</b> را انتخاب کنید تا آیکون گویا روی صفحهٔ اصلی آیفون بنشیند. اگر باز نشد، فایروال ویندوز را برای Node.js اجازه دهید (پنجره‌ای که بار اول باز می‌شود) و مطمئن شوید هر دو دستگاه در یک شبکه هستند.</p>
        </section>
      )}

      <Card className="p-6">
        <h3 className="flex items-center gap-2 text-lg font-bold text-slate-900"><span>💻</span> اجرا روی کامپیوتر خودتان (بدون انتشار)</h3>
        <p className="mt-3 text-sm leading-7 text-slate-600">به PostgreSQL یا سرور نیازی نیست؛ دیتابیس داخلی در پوشهٔ <span dir="ltr" className="font-mono text-xs">data/</span> کنار برنامه ذخیره می‌شود.</p>
        <ol className="mt-4 space-y-3 text-sm leading-7 text-slate-600">
          {[
            <>Node.js نسخهٔ LTS را از <a href="https://nodejs.org" target="_blank" rel="noreferrer" className="font-semibold text-indigo-600 hover:underline" dir="ltr">nodejs.org</a> نصب کنید (یک بار).</>,
            <>در پوشهٔ پروژه، در ویندوز روی <span dir="ltr" className="font-mono text-xs">start-gooya.bat</span> دوبار کلیک کنید؛ در مک/لینوکس <span dir="ltr" className="font-mono text-xs">bash start-gooya.sh</span>. (یا در ترمینال: <span dir="ltr" className="font-mono text-xs">npm install</span> و سپس <span dir="ltr" className="font-mono text-xs">npm run local</span>)</>,
            <>بار اول چند دقیقه صبر کنید؛ مرورگر خودکار باز می‌شود و آدرس Wi-Fi برای گوشی در ترمینال و همین صفحه نمایش داده می‌شود.</>,
          ].map((step, i) => (
            <li key={i} className="flex gap-3">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-xs font-bold text-indigo-700">{i + 1}</span>
              <span>{step}</span>
            </li>
          ))}
        </ol>
      </Card>

      <section className="rounded-3xl bg-gradient-to-br from-indigo-600 via-violet-600 to-fuchsia-600 p-6 text-white shadow-xl sm:p-8">
        <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="text-2xl font-black">{installed ? "گویا نصب شده است ✓" : "نصب یک‌کلیکی"}</h2>
            <p className="mt-2 max-w-lg text-sm leading-7 text-white/85">
              {installed
                ? "شما در حال استفاده از نسخهٔ نصب‌شده هستید. از همین‌جا می‌توانید بدون مرورگر از گویا استفاده کنید."
                : installable
                  ? "مرورگر شما از نصب مستقیم پشتیبانی می‌کند. روی دکمه بزنید تا گویا به صفحهٔ اصلی اضافه شود."
                  : "اگر دکمهٔ نصب فعال نیست، از راهنمای زیر برای نصب دستی استفاده کنید."}
            </p>
          </div>
          {!installed && (
            <Button size="lg" onClick={install} className="shrink-0 bg-white text-indigo-700 shadow-lg hover:bg-indigo-50 hover:from-white hover:to-white">
              📲 نصب گویا
            </Button>
          )}
        </div>
      </section>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="p-6">
          <h3 className="flex items-center gap-2 text-lg font-bold text-slate-900"><span>🧭</span> نصب روی آیفون (Safari)</h3>
          <ol className="mt-4 space-y-3 text-sm leading-7 text-slate-600">
            {[
              "همین صفحه را در مرورگر Safari آیفون باز کنید (نه Chrome).",
              "روی دکمهٔ Share (مربع با فلش رو به بالا) پایین صفحه بزنید.",
              "گزینهٔ «Add to Home Screen» (افزودن به صفحهٔ اصلی) را انتخاب کنید.",
              "آیکون گویا روی صفحهٔ اصلی ظاهر می‌شود و مثل یک برنامهٔ مستقل باز می‌شود.",
            ].map((step, i) => (
              <li key={i} className="flex gap-3">
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-indigo-100 text-xs font-bold text-indigo-700">{i + 1}</span>
                <span>{step}</span>
              </li>
            ))}
          </ol>
        </Card>

        <Card className="p-6">
          <h3 className="flex items-center gap-2 text-lg font-bold text-slate-900"><span>📦</span> ساخت فایل IPA (بدون مک)</h3>
          <p className="mt-3 text-sm leading-7 text-slate-600">
            فایل <span dir="ltr" className="font-mono text-xs">.ipa</span> با GitHub Actions روی ماشین مک ابری ساخته می‌شود؛ به مک یا Xcode نیازی ندارید.
          </p>
          <ol className="mt-4 space-y-3 text-sm leading-7 text-slate-600">
            <li className="flex gap-3"><span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-xs font-bold text-emerald-700">1</span><span>پروژه را در یک مخزن GitHub بگذارید و به تب <b>Actions</b> بروید.</span></li>
            <li className="flex gap-3"><span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-xs font-bold text-emerald-700">2</span><span>گردش‌کار <b>Build iOS IPA (unsigned)</b> را با Run workflow اجرا کنید.</span></li>
            <li className="flex gap-3"><span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-xs font-bold text-emerald-700">3</span><span>بعد از پایان، از بخش Artifacts فایل <span dir="ltr" className="font-mono text-xs">Gooya-iOS</span> را دانلود و از حالت zip خارج کنید.</span></li>
            <li className="flex gap-3"><span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-xs font-bold text-emerald-700">4</span><span>با <a href="https://sideloadly.io" target="_blank" rel="noreferrer" className="font-semibold text-indigo-600 hover:underline" dir="ltr">Sideloadly</a> و Apple ID خودتان روی آیفون نصب کنید. نصب با Apple ID رایگان ۷ روز اعتبار دارد؛ جزئیات کامل در <span dir="ltr" className="font-mono text-xs">IOS.md</span> است.</span></li>
          </ol>
          <div className="mt-4 flex items-center gap-2 rounded-xl bg-slate-50 p-3">
            <code className="flex-1 truncate text-xs text-slate-700" dir="ltr">{origin || "…"}</code>
            <Button size="sm" variant="secondary" onClick={copy}>کپی آدرس</Button>
          </div>
        </Card>

        <Card className="p-6 lg:col-span-2">
          <h3 className="flex items-center gap-2 text-lg font-bold text-slate-900"><span>🔈</span> صدای فارسی آفلاین روی آیفون</h3>
          <p className="mt-3 text-sm leading-7 text-slate-600">
            موتور «صدای دستگاه» بدون اینترنت کار می‌کند، اما به یک صدای فارسی نصب‌شده روی آیفون نیاز دارد. ممکن است آیفون شما صدای فارسی داخلی نداشته باشد؛ در این صورت فقط موتور «نیورال (آنلاین)» قابل استفاده است.
          </p>
          <div className="mt-4 grid gap-3 sm:grid-cols-2">
            <div className="rounded-xl border border-slate-200 p-4 text-sm leading-7 text-slate-600">
              <p className="font-bold text-slate-800">بررسی صداهای نصب‌شده</p>
              Settings ← Accessibility ← Spoken Content ← Voices ← <b>Persian (فارسی)</b> (اگر موجود بود دانلود کنید)
            </div>
            <div className="rounded-xl border border-slate-200 p-4 text-sm leading-7 text-slate-600">
              <p className="font-bold text-slate-800">نکته</p>
              موتور «نیورال (آنلاین)» همیشه بدون نیاز به این مرحله با دو صدای طبیعی مرد و زن کار می‌کند.
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
