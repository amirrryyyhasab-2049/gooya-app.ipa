import { normalizePersian, stripDiacritics } from "./diacritize";

export interface Segment {
  index: number;
  text: string;
  /** مکث بعد از این قطعه (میلی‌ثانیه) */
  pauseAfter: number;
  kind: "sentence" | "clause" | "line" | "paragraph";
}

export interface SegmentOptions {
  pauseScale?: number;
  maxChars?: number;
}

const BASE_PAUSE = {
  period: 620,
  exclaim: 700,
  question: 720,
  ellipsis: 950,
  comma: 300,
  semicolon: 420,
  colon: 450,
  line: 560,
  verse: 700,
  paragraph: 1050,
  forced: 160,
};

function terminalPause(sentence: string): number {
  const last = sentence.trim().slice(-1);
  if (sentence.trim().endsWith("...") || last === "…") return BASE_PAUSE.ellipsis;
  if (last === "." ) return BASE_PAUSE.period;
  if (last === "!" ) return BASE_PAUSE.exclaim;
  if (last === "?" || last === "؟") return BASE_PAUSE.question;
  if (last === "،" || last === ",") return BASE_PAUSE.comma;
  if (last === "؛" || last === ";") return BASE_PAUSE.semicolon;
  if (last === ":") return BASE_PAUSE.colon;
  return 0;
}

function splitLong(sentence: string, maxChars: number): string[] {
  if (sentence.length <= maxChars) return [sentence];
  // ابتدا در مرز ویرگول/نقطه‌ویرگول
  const clauses = sentence.match(/[^،,؛;:]+(?:[،,؛;:]+|$)/g)?.map((c) => c.trim()).filter(Boolean) ?? [sentence];
  const out: string[] = [];
  let buffer = "";
  for (const clause of clauses) {
    if (!buffer) buffer = clause;
    else if ((buffer + " " + clause).length <= maxChars) buffer = `${buffer} ${clause}`;
    else {
      out.push(buffer);
      buffer = clause;
    }
  }
  if (buffer) out.push(buffer);
  // اگر هنوز بلند بود، بر اساس تعداد واژه تقسیم کن
  return out.flatMap((piece) => {
    if (piece.length <= maxChars) return [piece];
    const words = piece.split(" ");
    const chunks: string[] = [];
    let cur = "";
    for (const w of words) {
      if ((cur + " " + w).trim().length > maxChars && cur) {
        chunks.push(cur.trim());
        cur = w;
      } else cur = `${cur} ${w}`;
    }
    if (cur.trim()) chunks.push(cur.trim());
    return chunks;
  });
}

/**
 * متن را به قطعه‌های قابل خواندن تبدیل می‌کند و برای هر قطعه مکث مناسب تعیین می‌کند.
 * - پاراگراف‌ها: مکث بلند
 * - خطوط کوتاه (شعر): مکث موزون بین مصراع‌ها
 * - جمله‌ها: بر اساس نشانهٔ پایانی
 */
export function segmentText(input: string, options: SegmentOptions = {}): Segment[] {
  const pauseScale = options.pauseScale ?? 1;
  const maxChars = options.maxChars ?? 220;
  const text = normalizePersian(input).trim();
  if (!text) return [];

  const segments: Segment[] = [];
  const paragraphs = text.split(/\n\s*\n+/);

  paragraphs.forEach((paragraph, pIdx) => {
    const lines = paragraph.split("\n").map((l) => l.trim()).filter(Boolean);
    const looksLikePoem = lines.length >= 2 && lines.every((l) => stripDiacritics(l).length <= 90);

    lines.forEach((line, lIdx) => {
      const sentences = line.match(/[^.!?؟…]+(?:[.!?؟…]+|$)/g)?.map((s) => s.trim()).filter(Boolean) ?? [line];
      sentences.forEach((sentence, sIdx) => {
        const pieces = splitLong(sentence, maxChars);
        pieces.forEach((piece, pcIdx) => {
          const isLastPiece = pcIdx === pieces.length - 1;
          const isLastSentence = sIdx === sentences.length - 1;
          const isLastLine = lIdx === lines.length - 1;
          const isLastParagraph = pIdx === paragraphs.length - 1;

          let pause = terminalPause(piece);
          let kind: Segment["kind"] = "sentence";
          if (!isLastPiece) {
            pause = pause || BASE_PAUSE.forced;
            kind = "clause";
          } else if (isLastSentence) {
            if (isLastLine) {
              pause = Math.max(pause, BASE_PAUSE.paragraph);
              kind = "paragraph";
            } else {
              pause = Math.max(pause, looksLikePoem ? BASE_PAUSE.verse : BASE_PAUSE.line);
              kind = "line";
            }
          } else {
            pause = pause || BASE_PAUSE.period;
          }
          if (isLastParagraph && isLastLine && isLastSentence && isLastPiece) pause = 0;

          segments.push({
            index: segments.length,
            text: piece,
            pauseAfter: Math.round(pause * pauseScale),
            kind,
          });
        });
      });
    });
  });

  return segments;
}

export function countWords(text: string): number {
  return stripDiacritics(text)
    .split(/[\s\u200C]+/)
    .filter((w) => /[\p{L}\p{N}]/u.test(w)).length;
}

/** تخمین مدت‌زمان خواندن (ثانیه) */
export function estimateDuration(segments: Segment[], rate: number): number {
  const words = segments.reduce((sum, s) => sum + countWords(s.text), 0);
  const pauses = segments.reduce((sum, s) => sum + s.pauseAfter, 0) / 1000;
  return words / (2.4 * Math.max(0.4, rate)) + pauses;
}

export function formatDuration(totalSeconds: number): string {
  const s = Math.max(0, Math.round(totalSeconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return m > 0 ? `${m} دقیقه و ${r} ثانیه` : `${r} ثانیه`;
}
