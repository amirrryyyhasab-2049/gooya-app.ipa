import { LEXICON, VERBS } from "./lexicon";

const ZWNJ = "\u200C";
const DIACRITICS_RE = /[\u064B-\u0652\u0670]/g;
const HAS_DIACRITICS_RE = /[\u064B-\u0652\u0670]/;
/** واژه‌های فارسی/عربی شامل نیم‌فاصله و اعراب (بدون ارقام و نشانه‌ها) */
const WORD_RE = /[\u0621-\u064A\u066E-\u06D3\u200C\u064B-\u0652\u0670]+/g;

export function stripDiacritics(text: string) {
  return text.replace(DIACRITICS_RE, "");
}

export function normalizePersian(text: string) {
  return text
    .replace(/ي/g, "ی")
    .replace(/ك/g, "ک")
    .replace(/ۀ/g, "هٔ")
    .replace(/ـ/g, "")
    .replace(/\r\n?/g, "\n")
    .replace(/[ \t\u00A0]+/g, " ")
    .replace(/ ?([،؛؟!,.:;])/g, "$1");
}

const PAST_ENDINGS: Record<string, string> = {
  "": "",
  م: "َم",
  ی: "ی",
  یم: "یم",
  ید: "ید",
  ند: "َند",
  ه: "ه",
  ن: "َن",
  [`ه${ZWNJ}ام`]: `ه${ZWNJ}اَم`,
  [`ه${ZWNJ}ای`]: `ه${ZWNJ}ای`,
  [`ه${ZWNJ}ایم`]: `ه${ZWNJ}ایم`,
  [`ه${ZWNJ}اید`]: `ه${ZWNJ}اید`,
  [`ه${ZWNJ}اند`]: `ه${ZWNJ}اَند`,
};

const PRESENT_ENDINGS: Record<string, string> = {
  م: "َم",
  ی: "ی",
  د: "َد",
  یم: "یم",
  ید: "ید",
  ند: "َند",
};

type Prefix = { raw: string; voc: string; kind: "none" | "dur" | "neg" | "negdur" | "subj" };

const PREFIXES: Prefix[] = [
  { raw: "", voc: "", kind: "none" },
  { raw: `نمی${ZWNJ}`, voc: `نِمی${ZWNJ}`, kind: "negdur" },
  { raw: "نمی", voc: `نِمی${ZWNJ}`, kind: "negdur" },
  { raw: `می${ZWNJ}`, voc: `می${ZWNJ}`, kind: "dur" },
  { raw: "می", voc: `می${ZWNJ}`, kind: "dur" },
  { raw: "ن", voc: "نَ", kind: "neg" },
  { raw: "ب", voc: "", kind: "subj" },
];

function conjugate(token: string): string | null {
  for (const p of PREFIXES) {
    if (p.raw && !token.startsWith(p.raw)) continue;
    const rest = token.slice(p.raw.length);
    if (!rest) continue;

    const preferPresent = p.kind === "dur" || p.kind === "negdur" || p.kind === "subj";
    for (const v of VERBS) {
      const tryPast = (): string | null => {
        if (p.kind === "subj" || !rest.startsWith(v.past)) return null;
        const ending = rest.slice(v.past.length);
        return ending in PAST_ENDINGS ? p.voc + v.pastV + PAST_ENDINGS[ending] : null;
      };
      const tryPresent = (): string | null => {
        if (!rest.startsWith(v.pres)) return null;
        const ending = rest.slice(v.pres.length);
        if (!(ending in PRESENT_ENDINGS)) return null;
        const prefixVoc = p.kind === "subj" ? v.b : p.voc;
        return prefixVoc + v.presV + PRESENT_ENDINGS[ending];
      };
      const matched = preferPresent ? tryPresent() ?? tryPast() : tryPast() ?? tryPresent();
      if (matched) return matched;
      // فعل امر (فقط با پیشوند «ب» یا «ن»)
      if (p.kind === "subj" || p.kind === "neg") {
        const impRaw = v.imp ?? v.pres;
        const impVoc = v.impV ?? v.presV;
        if (rest === impRaw) {
          return (p.kind === "subj" ? v.b : p.voc) + impVoc;
        }
      }
    }
  }
  return null;
}

const SUFFIXES: Array<[string, string]> = [
  ["هایشان", "هایِشان"],
  ["هایتان", "هایِتان"],
  ["هایمان", "هایِمان"],
  ["هایی", "هایی"],
  ["هایش", "هایَش"],
  ["هایت", "هایَت"],
  ["هایم", "هایَم"],
  ["های", "هایِ"],
  ["ها", "ها"],
  ["ترین", "تَرین"],
  ["تری", "تَری"],
  ["تر", "تَر"],
  ["شان", "ِشان"],
  ["تان", "ِتان"],
  ["مان", "ِمان"],
  ["ان", "ان"],
  ["یی", "یی"],
  ["ای", "ای"],
  ["ش", "َش"],
  ["ت", "َت"],
  ["م", "َم"],
  ["ی", "ی"],
];

function lookupBase(base: string, dict: Map<string, string>): string | null {
  return dict.get(base) ?? LEXICON.get(base) ?? null;
}

function resolveWord(token: string, dict: Map<string, string>): string | null {
  const direct = lookupBase(token, dict);
  if (direct) return direct;

  const verb = conjugate(token);
  if (verb) return verb;

  // پسوندها (با یا بدون نیم‌فاصله)
  for (const [suffix, voc] of SUFFIXES) {
    for (const joiner of [ZWNJ, ""]) {
      const full = joiner + suffix;
      if (token.length > full.length + 1 && token.endsWith(full)) {
        const base = token.slice(0, -full.length);
        const baseVoc = lookupBase(base, dict);
        if (baseVoc) {
          const endsWithHe = base.endsWith("ه");
          let suffixVoc = voc;
          const startsWithMark = /^[\u064E\u0650]/.test(voc);
          if (joiner === ZWNJ && startsWithMark) suffixVoc = voc.slice(1);
          else if (endsWithHe && !joiner && /^\u0650/.test(voc)) suffixVoc = ZWNJ + voc.slice(1);
          else if (endsWithHe && !joiner && /^\u064E/.test(voc)) suffixVoc = ZWNJ + "ا" + voc;
          return baseVoc + joiner + suffixVoc;
        }
      }
    }
  }
  return null;
}

export interface DiacritizeResult {
  text: string;
  totalWords: number;
  markedWords: number;
  unknownWords: string[];
}

/**
 * اعراب‌گذاری خودکار متن فارسی.
 * اولویت: واژه‌نامهٔ شخصی کاربر ← واژه‌نامهٔ پایه ← صرف فعل ← پسوندها.
 * واژه‌هایی که از قبل اعراب دارند دست‌نخورده می‌مانند.
 */
export function diacritize(input: string, userDictionary: Record<string, string> | Map<string, string> = {}): DiacritizeResult {
  const dict =
    userDictionary instanceof Map
      ? userDictionary
      : new Map(Object.entries(userDictionary).map(([k, v]) => [stripDiacritics(k.trim()), v.trim()]));

  let totalWords = 0;
  let markedWords = 0;
  const unknown = new Set<string>();

  const text = normalizePersian(input).replace(WORD_RE, (token) => {
    if (token === ZWNJ || !/[\u0621-\u064A\u066E-\u06D3]/.test(token)) return token;
    totalWords += 1;
    if (HAS_DIACRITICS_RE.test(token)) {
      markedWords += 1;
      return token;
    }
    const resolved = resolveWord(token, dict);
    if (resolved) {
      if (resolved !== token) markedWords += 1;
      return resolved;
    }
    if (token.length > 2) unknown.add(token);
    return token;
  });

  return { text, totalWords, markedWords, unknownWords: Array.from(unknown).slice(0, 40) };
}

/** متن را برای ارسال به موتور گفتار آماده می‌کند (پاک‌سازی نویسه‌های مشکل‌ساز) */
export function prepareForEngine(text: string, keepDiacritics = true) {
  let t = normalizePersian(text)
    .replace(/[\u200B\u200D\uFEFF]/g, "")
    .replace(/[\u2026]/g, "...")
    .trim();
  if (!keepDiacritics) t = stripDiacritics(t);
  return t;
}
