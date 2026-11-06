"use client";

import { useEffect } from "react";

declare global {
  interface Window {
    __gooyaInstallPrompt?: BeforeInstallPromptEvent | null;
  }
  interface BeforeInstallPromptEvent extends Event {
    prompt: () => Promise<void>;
    userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
  }
}

export function PwaRegister() {
  useEffect(() => {
    if (typeof window === "undefined") return;
    const onPrompt = (e: Event) => {
      e.preventDefault();
      window.__gooyaInstallPrompt = e as BeforeInstallPromptEvent;
      window.dispatchEvent(new CustomEvent("gooya:installable"));
    };
    window.addEventListener("beforeinstallprompt", onPrompt);

    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => {});
    }
    return () => window.removeEventListener("beforeinstallprompt", onPrompt);
  }, []);
  return null;
}
