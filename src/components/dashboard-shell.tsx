"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState, type ReactNode } from "react";
import { cn } from "@/components/ui";

const NAV = [
  { href: "/", label: "استودیو گفتار", icon: "🎙️", highlight: true },
  { href: "/texts", label: "متن‌های من", icon: "📝" },
  { href: "/voices", label: "پروفایل‌های صدا", icon: "🎚️" },
  { href: "/dictionary", label: "واژه‌نامهٔ تلفظ", icon: "🔤" },
  { href: "/history", label: "تاریخچه", icon: "🕘" },
  { href: "/overview", label: "نمای کلی", icon: "▦" },
  { href: "/install", label: "نصب روی موبایل", icon: "📲" },
  { href: "/settings", label: "تنظیمات", icon: "⚙️" },
];

export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <div className="flex items-center gap-2.5">
      <span className="relative flex h-10 w-10 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-indigo-600 text-white shadow-lg shadow-indigo-500/30">
        <svg viewBox="0 0 24 24" className="h-6 w-6" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round">
          <path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4" />
        </svg>
      </span>
      {!compact && (
        <span className="leading-tight">
          <span className="block text-lg font-black tracking-tight">گویا</span>
          <span className="block text-[11px] text-white/60">نوشتار به گفتار فارسی</span>
        </span>
      )}
    </div>
  );
}

export function DashboardShell({ user, children }: { user: { name: string }; children: ReactNode }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  useEffect(() => setOpen(false), [pathname]);

  const initials = user.name.trim().slice(0, 1) || "گ";

  const sidebar = (
    <div className="flex h-full flex-col bg-gradient-to-b from-slate-900 via-indigo-950 to-slate-900 text-white">
      <div className="px-5 pb-4 pt-6">
        <Logo />
      </div>
      <nav className="flex-1 space-y-1 overflow-y-auto px-3">
        {NAV.map((item) => {
          const active = item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition",
                active ? "bg-white/15 font-semibold text-white shadow-inner" : "text-white/70 hover:bg-white/10 hover:text-white",
                item.highlight && !active && "text-violet-200",
              )}
            >
              <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-white/10 text-base">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-white/10 p-4">
        <div className="flex items-center gap-3 rounded-2xl bg-white/5 p-3">
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 font-bold text-slate-900">{initials}</span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold">{user.name}</p>
            <p className="truncate text-xs text-white/50">بدون نیاز به ورود · فضای کاری محلی</p>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-slate-50 lg:flex">
      <aside className="sticky top-0 hidden h-screen w-72 shrink-0 lg:block">{sidebar}</aside>

      {open && (
        <div className="fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <aside className="absolute inset-y-0 right-0 w-72 shadow-2xl animate-[drawerIn_.22s_ease-out]">{sidebar}</aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex h-16 items-center gap-3 border-b border-slate-200/80 bg-white/80 px-4 backdrop-blur lg:hidden">
          <button onClick={() => setOpen(true)} className="rounded-xl p-2 text-slate-600 hover:bg-slate-100" aria-label="منو">
            <svg className="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M4 6h16M4 12h16M4 18h16" /></svg>
          </button>
          <Link href="/" className="flex items-center gap-2 font-black text-slate-900">
            <span className="flex h-8 w-8 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 text-white">
              <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"><path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4" /></svg>
            </span>
            گویا
          </Link>
          {pathname !== "/" && (
            <Link href="/" className="ms-auto rounded-xl bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white">🎙️ استودیو</Link>
          )}
        </header>
        <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</main>
      </div>
    </div>
  );
}

export function PageHeader({ title, description, action }: { title: string; description?: string; action?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-2xl font-black tracking-tight text-slate-900">{title}</h1>
        {description && <p className="mt-1 text-sm leading-7 text-slate-500">{description}</p>}
      </div>
      {action && <div className="flex shrink-0 gap-2">{action}</div>}
    </div>
  );
}
