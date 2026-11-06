"use client";

import type { RefObject } from "react";

const KEYS: Array<{ char: string; label: string; example: string }> = [
  { char: "\u064E", label: "فتحه", example: "اَ" },
  { char: "\u0650", label: "کسره", example: "اِ" },
  { char: "\u064F", label: "ضمه", example: "اُ" },
  { char: "\u0651", label: "تشدید", example: "ـّ" },
  { char: "\u0652", label: "سکون", example: "ـْ" },
  { char: "\u064B", label: "تنوین", example: "ـاً" },
  { char: "\u200C", label: "نیم‌فاصله", example: "‌|" },
];

export function DiacriticKeyboard({
  inputRef,
  value,
  onChange,
  compact = false,
}: {
  inputRef: RefObject<HTMLInputElement | HTMLTextAreaElement | null>;
  value: string;
  onChange: (next: string) => void;
  compact?: boolean;
}) {
  const insert = (ch: string) => {
    const el = inputRef.current;
    const start = el?.selectionStart ?? value.length;
    const end = el?.selectionEnd ?? value.length;
    const next = value.slice(0, start) + ch + value.slice(end);
    onChange(next);
    requestAnimationFrame(() => {
      if (!el) return;
      el.focus();
      el.setSelectionRange(start + ch.length, start + ch.length);
    });
  };

  return (
    <div className="flex flex-wrap gap-1.5" role="toolbar" aria-label="صفحه‌کلید اعراب">
      {KEYS.map((k) => (
        <button
          key={k.label}
          type="button"
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => insert(k.char)}
          className={`inline-flex items-center gap-1.5 rounded-lg border border-slate-200 bg-white text-slate-700 shadow-sm transition hover:border-indigo-300 hover:bg-indigo-50 ${compact ? "px-2 py-1 text-xs" : "px-2.5 py-1.5 text-sm"}`}
          title={k.label}
        >
          <span className="text-base font-bold text-indigo-600">{k.example}</span>
          {!compact && <span className="text-xs text-slate-500">{k.label}</span>}
        </button>
      ))}
    </div>
  );
}
