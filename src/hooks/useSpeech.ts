"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { segmentText, type Segment } from "@/lib/tts/segment";
import { prepareForEngine } from "@/lib/tts/diacritize";
import { browserProsody, getPersona, neuralProsody, type EngineKind, type VoiceSettings } from "@/lib/tts/personas";

export type SpeechStatus = "idle" | "loading" | "playing" | "paused";

export interface CompleteInfo {
  settings: VoiceSettings;
  engineUsed: EngineKind;
  durationSec: number;
  text: string;
}

interface Options {
  onComplete?: (info: CompleteInfo) => void;
  onNotice?: (message: string, kind: "info" | "warning" | "error") => void;
}

const SILENT_WAV =
  "data:audio/wav;base64,UklGRjIAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YQ4AAAAAAAAAAAAAAAAAAAAAAA==";

export function useSpeech(options: Options = {}) {
  const [status, setStatus] = useState<SpeechStatus>("idle");
  const [segments, setSegments] = useState<Segment[]>([]);
  const [currentIndex, setCurrentIndex] = useState(-1);
  const [engineUsed, setEngineUsed] = useState<EngineKind>("neural");
  const [browserSupported, setBrowserSupported] = useState(false);
  const [browserVoices, setBrowserVoices] = useState<SpeechSynthesisVoice[]>([]);
  const [lastError, setLastError] = useState<string | null>(null);

  const runIdRef = useRef(0);
  const pausedRef = useRef(false);
  const resumeWaitersRef = useRef<Array<() => void>>([]);
  const abortCurrentRef = useRef<(() => void) | null>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const cacheRef = useRef<Map<string, Promise<string>>>(new Map());
  const utteranceRef = useRef<SpeechSynthesisUtterance | null>(null);
  const optionsRef = useRef(options);
  optionsRef.current = options;

  // بارگذاری صداهای فارسی مرورگر
  useEffect(() => {
    if (typeof window === "undefined" || !("speechSynthesis" in window)) return;
    setBrowserSupported(true);
    const load = () => {
      const all = window.speechSynthesis.getVoices();
      setBrowserVoices(all.filter((v) => /^fa/i.test(v.lang) || /persian|farsi|فارسی/i.test(v.name)));
    };
    load();
    window.speechSynthesis.addEventListener("voiceschanged", load);
    return () => window.speechSynthesis.removeEventListener("voiceschanged", load);
  }, []);

  useEffect(() => {
    const cache = cacheRef.current;
    return () => {
      runIdRef.current += 1;
      if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
      cache.forEach((p) => p.then((url) => URL.revokeObjectURL(url)).catch(() => {}));
      cache.clear();
    };
  }, []);

  const hasPersianBrowserVoice = browserVoices.length > 0;

  const ensureAudio = useCallback(() => {
    if (!audioRef.current && typeof window !== "undefined") {
      const audio = new Audio();
      audio.preload = "auto";
      audioRef.current = audio;
    }
    return audioRef.current;
  }, []);

  const unlockAudio = useCallback(() => {
    const audio = ensureAudio();
    if (!audio) return;
    try {
      audio.src = SILENT_WAV;
      audio.play().catch(() => {});
    } catch {
      /* ignore */
    }
  }, [ensureAudio]);

  const flushWaiters = () => {
    const waiters = resumeWaitersRef.current;
    resumeWaitersRef.current = [];
    waiters.forEach((w) => w());
  };

  const stop = useCallback(() => {
    runIdRef.current += 1;
    pausedRef.current = false;
    flushWaiters();
    abortCurrentRef.current?.();
    abortCurrentRef.current = null;
    if (typeof window !== "undefined" && "speechSynthesis" in window) window.speechSynthesis.cancel();
    const audio = audioRef.current;
    if (audio) {
      audio.onended = null;
      audio.onerror = null;
      audio.pause();
      audio.removeAttribute("src");
    }
    setStatus("idle");
    setCurrentIndex(-1);
  }, []);

  const pause = useCallback(() => {
    if (pausedRef.current) return;
    pausedRef.current = true;
    audioRef.current?.pause();
    if (typeof window !== "undefined" && "speechSynthesis" in window && window.speechSynthesis.speaking) {
      window.speechSynthesis.pause();
    }
    setStatus("paused");
  }, []);

  const resume = useCallback(() => {
    if (!pausedRef.current) return;
    pausedRef.current = false;
    const audio = audioRef.current;
    if (audio && audio.src && !audio.ended && audio.currentTime > 0) audio.play().catch(() => {});
    if (typeof window !== "undefined" && "speechSynthesis" in window && window.speechSynthesis.paused) {
      window.speechSynthesis.resume();
    }
    setStatus("playing");
    flushWaiters();
  }, []);

  const waitIfPaused = (runId: number) =>
    new Promise<void>((resolve) => {
      if (!pausedRef.current || runIdRef.current !== runId) return resolve();
      resumeWaitersRef.current.push(resolve);
    });

  const sleep = (ms: number, runId: number) =>
    new Promise<void>((resolve) => {
      if (ms <= 0) return resolve();
      const start = Date.now();
      const timer = setInterval(() => {
        if (runIdRef.current !== runId || (!pausedRef.current && Date.now() - start >= ms)) {
          clearInterval(timer);
          resolve();
        }
      }, 40);
    });

  const pickBrowserVoice = useCallback(
    (gender: "male" | "female") => {
      if (!browserVoices.length) return undefined;
      const female = browserVoices.find((v) => /female|dilara|woman|زن/i.test(v.name));
      const male = browserVoices.find((v) => /farid|(^|[^fe])male|man\b|مرد/i.test(v.name) && !/female/i.test(v.name));
      const natural = browserVoices.find((v) => /natural|neural|online/i.test(v.name));
      return (gender === "female" ? female : male) ?? natural ?? browserVoices[0];
    },
    [browserVoices],
  );

  const getNeuralUrl = useCallback((text: string, settings: VoiceSettings) => {
    const persona = getPersona(settings.personaId);
    const prosody = neuralProsody(persona, settings.rate, settings.pitch);
    const key = `${persona.neuralVoice}|${prosody.rate}|${prosody.pitch}|${text}`;
    const cache = cacheRef.current;
    if (!cache.has(key)) {
      const promise = fetch("/api/tts", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text, voice: persona.neuralVoice, rate: prosody.rate, pitch: prosody.pitch }),
      })
        .then(async (res) => {
          if (!res.ok) {
            const data = (await res.json().catch(() => ({}))) as { error?: string };
            throw new Error(data.error || "خطا در دریافت صدا");
          }
          const blob = await res.blob();
          return URL.createObjectURL(blob);
        })
        .catch((err) => {
          cache.delete(key);
          throw err;
        });
      cache.set(key, promise);
      if (cache.size > 300) {
        const first = cache.keys().next().value;
        if (first) cache.delete(first);
      }
    }
    return cache.get(key)!;
  }, []);

  const playUrl = (url: string, runId: number) =>
    new Promise<void>((resolve, reject) => {
      const audio = ensureAudio();
      if (!audio) return reject(new Error("audio unsupported"));
      const cleanup = () => {
        audio.onended = null;
        audio.onerror = null;
        abortCurrentRef.current = null;
      };
      abortCurrentRef.current = () => {
        cleanup();
        reject(new Error("stopped"));
      };
      audio.onended = () => {
        // رویداد پایانِ منبع قبلی را نادیده بگیر
        if (audio.currentTime < 0.05 && audio.duration > 0.2) return;
        cleanup();
        resolve();
      };
      audio.onerror = () => {
        cleanup();
        reject(new Error("audio error"));
      };
      audio.src = url;
      if (runIdRef.current !== runId) return resolve();
      audio.play().catch((err: unknown) => {
        cleanup();
        const name = err instanceof Error ? err.name : "";
        reject(name === "NotAllowedError" ? new Error("autoplay-blocked") : err);
      });
    });

  const speakBrowser = (text: string, settings: VoiceSettings, runId: number) =>
    new Promise<void>((resolve, reject) => {
      if (typeof window === "undefined" || !("speechSynthesis" in window)) return reject(new Error("unsupported"));
      const persona = getPersona(settings.personaId);
      const prosody = browserProsody(persona, settings.rate, settings.pitch);
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.lang = "fa-IR";
      const voice = pickBrowserVoice(persona.gender);
      if (voice) utterance.voice = voice;
      utterance.rate = prosody.rate;
      utterance.pitch = prosody.pitch;
      let done = false;
      const words = text.split(/\s+/).length;
      const safety = setTimeout(() => finish(), (words / 1.6) * 1000 / prosody.rate + 6000);
      const finish = () => {
        if (done) return;
        done = true;
        clearTimeout(safety);
        abortCurrentRef.current = null;
        resolve();
      };
      abortCurrentRef.current = () => {
        if (done) return;
        done = true;
        clearTimeout(safety);
        reject(new Error("stopped"));
      };
      utterance.onend = finish;
      utterance.onerror = (e) => {
        if (e.error === "interrupted" || e.error === "canceled") return finish();
        if (done) return;
        done = true;
        clearTimeout(safety);
        reject(new Error(e.error));
      };
      utteranceRef.current = utterance;
      if (runIdRef.current !== runId) return finish();
      window.speechSynthesis.speak(utterance);
    });

  const play = useCallback(
    async (text: string, settings: VoiceSettings, startIndex = 0) => {
      stop();
      const runId = runIdRef.current;
      const segs = segmentText(text, { pauseScale: settings.pauseScale * getPersona(settings.personaId).pauseScale });
      if (!segs.length) return;

      let engine: EngineKind = settings.engine;
      if (engine === "browser" && !hasPersianBrowserVoice) {
        optionsRef.current.onNotice?.(
          browserSupported
            ? "صدای فارسی روی این دستگاه نصب نیست؛ از صدای نیورال آنلاین استفاده می‌شود."
            : "مرورگر شما از گفتار آفلاین پشتیبانی نمی‌کند؛ از صدای آنلاین استفاده می‌شود.",
          "warning",
        );
        engine = "neural";
      }

      setLastError(null);
      setSegments(segs);
      setCurrentIndex(startIndex);
      setStatus("loading");
      setEngineUsed(engine);
      if (engine === "neural") unlockAudio();
      const startedAt = Date.now();

      for (let i = startIndex; i < segs.length; i += 1) {
        if (runIdRef.current !== runId) return;
        await waitIfPaused(runId);
        if (runIdRef.current !== runId) return;
        setCurrentIndex(i);
        const seg = segs[i];
        const spoken = prepareForEngine(seg.text);

        try {
          if (engine === "neural") {
            // پیش‌بارگذاری قطعه‌های بعدی برای پخش بی‌وقفه
            for (let j = i + 1; j <= i + 2 && j < segs.length; j += 1) {
              getNeuralUrl(prepareForEngine(segs[j].text), settings).catch(() => {});
            }
            const url = await getNeuralUrl(spoken, settings);
            if (runIdRef.current !== runId) return;
            await waitIfPaused(runId);
            if (runIdRef.current !== runId) return;
            setStatus("playing");
            await playUrl(url, runId);
          } else {
            setStatus("playing");
            await speakBrowser(spoken, settings, runId);
          }
        } catch (err) {
          if (runIdRef.current !== runId) return;
          const message = err instanceof Error ? err.message : "";
          if (message === "autoplay-blocked") {
            const text = "مرورگر اجازهٔ پخش خودکار صدا را نداد. یک بار دیگر روی دکمهٔ پخش بزنید.";
            setLastError(text);
            optionsRef.current.onNotice?.(text, "warning");
            stop();
            return;
          }
          if (engine === "neural" && hasPersianBrowserVoice) {
            engine = "browser";
            setEngineUsed("browser");
            optionsRef.current.onNotice?.("موتور آنلاین در دسترس نبود؛ ادامه با صدای دستگاه.", "warning");
            i -= 1;
            continue;
          }
          const friendly =
            err instanceof TypeError || /failed to fetch|networkerror|load failed/i.test(message)
              ? "اتصال به سرور برقرار نشد. اینترنت را بررسی کنید و دوباره تلاش کنید."
              : message && message !== "audio error"
                ? message
                : "پخش صدا ممکن نشد. اتصال اینترنت یا صدای دستگاه را بررسی کنید.";
          setLastError(friendly);
          optionsRef.current.onNotice?.(friendly, "error");
          stop();
          return;
        }

        if (runIdRef.current !== runId) return;
        await sleep(seg.pauseAfter, runId);
      }

      if (runIdRef.current === runId) {
        setStatus("idle");
        setCurrentIndex(-1);
        optionsRef.current.onComplete?.({
          settings,
          engineUsed: engine,
          durationSec: Math.round((Date.now() - startedAt) / 1000),
          text,
        });
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [stop, hasPersianBrowserVoice, browserSupported, unlockAudio, getNeuralUrl, pickBrowserVoice],
  );

  const toggle = useCallback(() => {
    if (status === "playing" || status === "loading") pause();
    else if (status === "paused") resume();
  }, [status, pause, resume]);

  const downloadMp3 = useCallback(async (text: string, settings: VoiceSettings, filename = "gooya") => {
    const persona = getPersona(settings.personaId);
    const prosody = neuralProsody(persona, settings.rate, settings.pitch);
    const res = await fetch("/api/tts", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: prepareForEngine(text), voice: persona.neuralVoice, rate: prosody.rate, pitch: prosody.pitch }),
    });
    if (!res.ok) {
      const data = (await res.json().catch(() => ({}))) as { error?: string };
      throw new Error(data.error || "دانلود ممکن نشد");
    }
    const blob = await res.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${filename}.mp3`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
  }, []);

  const clearError = useCallback(() => setLastError(null), []);

  return {
    status,
    segments,
    currentIndex,
    engineUsed,
    lastError,
    clearError,
    browserSupported,
    browserVoices,
    hasPersianBrowserVoice,
    play,
    pause,
    resume,
    toggle,
    stop,
    downloadMp3,
  };
}
