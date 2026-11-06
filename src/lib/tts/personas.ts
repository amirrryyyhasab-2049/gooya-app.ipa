export type EngineKind = "neural" | "browser";
export type NeuralVoice = "fa-IR-FaridNeural" | "fa-IR-DilaraNeural";

export interface Persona {
  id: string;
  name: string;
  tagline: string;
  description: string;
  gender: "male" | "female";
  emoji: string;
  gradient: string;
  neuralVoice: NeuralVoice;
  /** ضریب سرعت پایه */
  rate: number;
  /** جابه‌جایی زیر و بمی برای موتور نیورال (هرتز) */
  neuralPitchHz: number;
  /** زیر و بمی پایه برای موتور مرورگر (۰ تا ۲) */
  browserPitch: number;
  /** ضریب مکث پایه */
  pauseScale: number;
  sample: string;
}

export const PERSONAS: Persona[] = [
  {
    id: "arman",
    name: "آرمان",
    tagline: "مرد مهربان و روان",
    description: "صدایی گرم، آرام و شمرده؛ مناسب مقاله، نامه و متن‌های روزمره.",
    gender: "male",
    emoji: "🧔🏻",
    gradient: "from-indigo-500 to-violet-600",
    neuralVoice: "fa-IR-FaridNeural",
    rate: 0.96,
    neuralPitchHz: 0,
    browserPitch: 0.95,
    pauseScale: 1,
    sample: "سلام! من آرمان هستم. خوشحالم که متن شما را با آرامش و شمرده می‌خوانم.",
  },
  {
    id: "ava",
    name: "آوا",
    tagline: "زن مهربان و آرام",
    description: "لطیف، صمیمی و دلنشین؛ عالی برای داستان، پیام‌های شخصی و لالایی.",
    gender: "female",
    emoji: "👩🏻",
    gradient: "from-rose-400 to-pink-600",
    neuralVoice: "fa-IR-DilaraNeural",
    rate: 0.9,
    neuralPitchHz: -2,
    browserPitch: 1.1,
    pauseScale: 1.2,
    sample: "سلام، من آوا هستم. با صدایی آرام و مهربان همراه شما خواهم بود.",
  },
  {
    id: "ravi",
    name: "راوی کلاسیک",
    tagline: "گرم، عمیق و شمرده",
    description: "لحن روایتگران قدیمی رادیو و سینما؛ باوقار و تأثیرگذار برای متن‌های ادبی.",
    gender: "male",
    emoji: "🎙️",
    gradient: "from-amber-500 to-orange-600",
    neuralVoice: "fa-IR-FaridNeural",
    rate: 0.86,
    neuralPitchHz: -10,
    browserPitch: 0.8,
    pauseScale: 1.35,
    sample: "شبی از شب‌های دور، در شهری که نامش را کسی به یاد نمی‌آورد، داستان ما آغاز شد.",
  },
  {
    id: "khabar",
    name: "گویندهٔ خبر",
    tagline: "رسا، شفاف و حرفه‌ای",
    description: "واضح و پرانرژی با آهنگ خبری؛ مناسب اطلاعیه، خبر و متن‌های رسمی.",
    gender: "male",
    emoji: "📰",
    gradient: "from-sky-500 to-blue-600",
    neuralVoice: "fa-IR-FaridNeural",
    rate: 1.05,
    neuralPitchHz: 2,
    browserPitch: 1,
    pauseScale: 0.85,
    sample: "به گزارش خبرگزاری گویا، نسل تازه‌ای از دستیارهای صوتی فارسی امروز رونمایی شد.",
  },
  {
    id: "ghesegoo",
    name: "قصه‌گو",
    tagline: "گرم و صمیمی برای داستان",
    description: "با حس و حال و مکث‌های داستانی؛ عالی برای کودکان و کتاب صوتی.",
    gender: "female",
    emoji: "📖",
    gradient: "from-emerald-500 to-teal-600",
    neuralVoice: "fa-IR-DilaraNeural",
    rate: 0.88,
    neuralPitchHz: 4,
    browserPitch: 1.2,
    pauseScale: 1.3,
    sample: "یکی بود، یکی نبود. زیر گنبد کبود، خرگوش کوچکی بود که عاشق ستاره‌ها بود.",
  },
  {
    id: "mostanad",
    name: "راوی مستند",
    tagline: "جدی، عمیق و باوقار",
    description: "لحن مستندهای طبیعت و تاریخ؛ آرام و پرابهت.",
    gender: "male",
    emoji: "🎬",
    gradient: "from-slate-600 to-slate-800",
    neuralVoice: "fa-IR-FaridNeural",
    rate: 0.92,
    neuralPitchHz: -6,
    browserPitch: 0.85,
    pauseScale: 1.15,
    sample: "در دامنهٔ کوه رحمت، ویرانه‌هایی ایستاده‌اند که روزگاری قلب یک امپراتوری بودند.",
  },
  {
    id: "sher",
    name: "شعرخوان",
    tagline: "آرام با مکث‌های موزون",
    description: "برای غزل و شعر؛ آهسته، با وزن و سکوت‌های معنادار بین مصراع‌ها.",
    gender: "female",
    emoji: "🪶",
    gradient: "from-fuchsia-500 to-purple-700",
    neuralVoice: "fa-IR-DilaraNeural",
    rate: 0.8,
    neuralPitchHz: -1,
    browserPitch: 1.05,
    pauseScale: 1.6,
    sample: "یوسف گم‌گشته بازآید به کنعان، غم مخور. کلبهٔ احزان شود روزی گلستان، غم مخور.",
  },
  {
    id: "podcast",
    name: "پادکست",
    tagline: "صمیمی و پرانرژی",
    description: "لحن گفت‌وگویی و زنده؛ مناسب پادکست و محتوای آموزشی.",
    gender: "male",
    emoji: "🎧",
    gradient: "from-lime-500 to-green-600",
    neuralVoice: "fa-IR-FaridNeural",
    rate: 1,
    neuralPitchHz: 3,
    browserPitch: 1.05,
    pauseScale: 0.95,
    sample: "سلام به همهٔ شنونده‌های عزیز! امروز می‌خواهیم دربارهٔ یک موضوع جذاب صحبت کنیم.",
  },
];

export const DEFAULT_PERSONA_ID = "arman";

export function getPersona(id: string | null | undefined): Persona {
  return PERSONAS.find((p) => p.id === id) ?? PERSONAS[0];
}

export const NEURAL_VOICE_LABELS: Record<NeuralVoice, string> = {
  "fa-IR-FaridNeural": "فرید (مرد)",
  "fa-IR-DilaraNeural": "دیلارا (زن)",
};

export function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

/** تبدیل تنظیمات کاربر + پرسونا به پارامترهای موتور نیورال */
export function neuralProsody(persona: Persona, rate: number, pitch: number) {
  const ratePct = Math.round((clamp(persona.rate * rate, 0.5, 1.8) - 1) * 100);
  const pitchHz = Math.round(persona.neuralPitchHz + (pitch - 1) * 40);
  const sign = (n: number) => (n >= 0 ? `+${n}` : `${n}`);
  return { rate: `${sign(ratePct)}%`, pitch: `${sign(pitchHz)}Hz` };
}

/** پارامترهای موتور مرورگر (Web Speech API) */
export function browserProsody(persona: Persona, rate: number, pitch: number) {
  return {
    rate: clamp(persona.rate * rate, 0.5, 2),
    pitch: clamp(persona.browserPitch * pitch, 0.1, 2),
  };
}

export interface VoiceSettings {
  engine: EngineKind;
  personaId: string;
  rate: number;
  pitch: number;
  pauseScale: number;
}

export const DEFAULT_SETTINGS: VoiceSettings = {
  engine: "neural",
  personaId: DEFAULT_PERSONA_ID,
  rate: 1,
  pitch: 1,
  pauseScale: 1,
};
