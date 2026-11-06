import { eq } from "drizzle-orm";
import { db, dbMode } from "@/db";
import { ensureSchema } from "@/db/schema-sql";
import { dictionaryEntries, speechHistory, texts, users, voicePresets } from "@/db/schema";
import { countWords } from "@/lib/tts/segment";

export const GUEST_EMAIL = "guest@gooya.local";
export const GUEST_NAME = "کاربر گویا";

const SAMPLE_TEXTS = [
  {
    title: "غزل حافظ — غم مخور",
    content: `یوسف گم‌گشته بازآید به کنعان، غم مخور.
کلبهٔ احزان شود روزی گلستان، غم مخور.

ای دل غم‌دیده حالت به شود، دل بد مکن.
وین سر شوریده بازآید به سامان، غم مخور.

گر بهار عمر باشد باز بر تخت چمن،
چتر گل در سر کشی ای مرغ خوش‌خوان، غم مخور.

دور گردون گر دو روزی بر مراد ما نرفت،
دائماً یکسان نباشد حال دوران، غم مخور.`,
  },
  {
    title: "سعدی — بنی‌آدم",
    content: `بنی‌آدم اعضای یک پیکرند،
که در آفرینش ز یک گوهرند.

چو عضوی به درد آورد روزگار،
دگر عضوها را نماند قرار.

تو کز محنت دیگران بی‌غمی،
نشاید که نامت نهند آدمی.`,
  },
  {
    title: "خبر فناوری: دستیار صوتی فارسی",
    content: `پژوهشگران ایرانی از نسل تازه‌ای از دستیارهای صوتی رونمایی کردند که می‌تواند متن فارسی را با لحنی طبیعی و شمرده بخواند. به گفتهٔ مدیر این پروژه، مدل جدید با بیش از دو هزار ساعت گفتار آموزش دیده و در تلفظ واژه‌های دشوار، مانند «عصبانی» و «مشکل»، دقت قابل توجهی دارد.

این سامانه از علامت‌گذاری خودکار پشتیبانی می‌کند؛ یعنی حتی اگر متن بدون اعراب نوشته شده باشد، گوینده می‌داند کجا باید فتحه، کسره یا ضمه بگذارد. کارشناسان معتقدند این فناوری می‌تواند برای نابینایان، سالمندان و دانش‌آموزان بسیار سودمند باشد.`,
  },
  {
    title: "داستان کوتاه: چراغ کوچه",
    content: `هر شب، درست وقتی که آخرین مغازهٔ محله تعطیل می‌شد، پیرمردی با عصای چوبی از خانه بیرون می‌آمد. نه برای خرید، نه برای قدم زدن؛ فقط برای این‌که چراغ شکستهٔ سر کوچه را روشن کند.

بچه‌ها فکر می‌کردند او عصبانی است، چون همیشه اخم داشت. اما یک شب، دختر کوچکی جرئت کرد و پرسید: «پدربزرگ، چرا هر شب این‌جا می‌آیی؟»

پیرمرد لبخند زد و گفت: «سال‌ها پیش، کسی همین‌جا منتظر من ماند و من دیر رسیدم. حالا نمی‌خواهم هیچ‌کس در تاریکی منتظر بماند.»

از آن شب، بچه‌ها هم با او می‌آمدند. و کوچه، دیگر هیچ‌وقت تاریک نشد.`,
  },
  {
    title: "راهنمای شروع گویا",
    content: `به گویا خوش آمدید! این برنامه متن فارسی شما را با صدایی روان، شمرده و انسانی می‌خواند.

برای شروع، متن خود را در استودیو بنویسید یا بچسبانید. سپس روی دکمهٔ سبز «اعراب‌گذاری خودکار» بزنید تا فتحه، کسره و ضمه به‌صورت خودکار روی واژه‌ها قرار بگیرد. بعد یکی از گوینده‌ها را انتخاب کنید و دکمهٔ پخش را فشار دهید.

اگر واژه‌ای را اشتباه می‌خواند، آن را در واژه‌نامهٔ تلفظ ثبت کنید؛ از آن پس همیشه درست خوانده می‌شود.`,
  },
  {
    title: "مستند: تخت جمشید",
    content: `در دامنهٔ کوه رحمت، در شصت کیلومتری شیراز، ویرانه‌هایی ایستاده‌اند که روزگاری قلب یک امپراتوری بودند. تخت جمشید، یا پارسه، به فرمان داریوش بزرگ بنا شد و نزدیک به دویست سال، صحنهٔ جشن‌های نوروزی شاهان هخامنشی بود.

پلکان‌های سنگی، نقش‌برجسته‌های نمایندگان ملت‌ها، و ستون‌های بلندی که آسمان را لمس می‌کردند؛ همهٔ این‌ها از هنر و اندیشه‌ای حکایت دارند که هنوز هم، پس از بیست و پنج قرن، بیننده را خاموش و شگفت‌زده می‌کند.`,
  },
];

const SAMPLE_PRESETS = [
  { name: "روایت گرم آرمان", description: "برای مقاله و متن‌های روزمره؛ روان و مهربان", engine: "neural", personaId: "arman", rate: 0.95, pitch: 1, pauseScale: 1.1, isDefault: true },
  { name: "لالایی آرام آوا", description: "آهسته و لطیف، مناسب شب و داستان کودک", engine: "neural", personaId: "ava", rate: 0.85, pitch: 1, pauseScale: 1.4, isDefault: false },
  { name: "اخبار سریع", description: "رسا و پرانرژی برای خبر و اطلاعیه", engine: "neural", personaId: "khabar", rate: 1.1, pitch: 1, pauseScale: 0.8, isDefault: false },
  { name: "راوی مستند (آفلاین)", description: "صدای دستگاه با لحن عمیق و شمرده", engine: "browser", personaId: "mostanad", rate: 0.9, pitch: 0.9, pauseScale: 1.2, isDefault: false },
];

const SAMPLE_DICTIONARY = [
  { word: "عصبانی", diacritized: "عَصَبانی", note: "نه عُصبانی!" },
  { word: "کرم", diacritized: "کِرم", note: "کِرم (جانور) — برای کرم پودر از کِرِم استفاده کنید" },
  { word: "مرد", diacritized: "مَرد", note: "مَرد (انسان) در برابر مُرد (فوت کرد)" },
  { word: "گل", diacritized: "گُل", note: "گُل در برابر گِل" },
  { word: "سر", diacritized: "سَر", note: "سَر (عضو بدن) در برابر سِر (راز)" },
  { word: "ملک", diacritized: "مِلک", note: "مِلک (دارایی) / مُلک (سرزمین) / مَلَک (فرشته)" },
  { word: "کشتی", diacritized: "کَشتی", note: "کَشتی (شناور) در برابر کُشتی (ورزش)" },
  { word: "مهر", diacritized: "مِهر", note: "مِهر (محبت) در برابر مُهر" },
  { word: "خرد", diacritized: "خِرَد", note: "خِرَد (عقل) در برابر خُرد (ریز)" },
  { word: "شکر", diacritized: "شِکَر", note: "شِکَر (قند) در برابر شُکر (سپاس)" },
  { word: "بعد", diacritized: "بَعد", note: "بَعد (پس از) در برابر بُعد (اندازه)" },
  { word: "درست", diacritized: "دُرُست", note: "" },
  { word: "مشکل", diacritized: "مُشکِل", note: "" },
];

const globalForSeed = globalThis as typeof globalThis & { __gooyaSeedPromise?: Promise<void> };

async function runSeed() {
  await ensureSchema();
  const existing = await db.select({ id: users.id }).from(users).where(eq(users.email, GUEST_EMAIL)).limit(1);
  if (existing.length) return;

  const [user] = await db
    .insert(users)
    .values({ name: GUEST_NAME, email: GUEST_EMAIL, passwordHash: "" })
    .onConflictDoNothing()
    .returning();
  if (!user) return;

  const presets = await db
    .insert(voicePresets)
    .values(SAMPLE_PRESETS.map((p) => ({ ...p, userId: user.id })))
    .returning();

  const now = Date.now();
  const insertedTexts = await db
    .insert(texts)
    .values(
      SAMPLE_TEXTS.map((t, i) => ({
        userId: user.id,
        title: t.title,
        content: t.content,
        wordCount: countWords(t.content),
        isFavorite: i < 2,
        presetId: presets[i % presets.length]?.id ?? null,
        createdAt: new Date(now - (SAMPLE_TEXTS.length - i) * 86400000 * 2),
        updatedAt: new Date(now - (SAMPLE_TEXTS.length - i) * 86400000),
      })),
    )
    .returning();

  await db.insert(dictionaryEntries).values(SAMPLE_DICTIONARY.map((d) => ({ ...d, userId: user.id })));

  const historySeeds = [
    { text: insertedTexts[0], engine: "neural", voiceLabel: "آرمان — مرد مهربان و روان", hoursAgo: 2 },
    { text: insertedTexts[3], engine: "neural", voiceLabel: "قصه‌گو — گرم و صمیمی", hoursAgo: 7 },
    { text: insertedTexts[2], engine: "neural", voiceLabel: "گویندهٔ خبر — رسا و شفاف", hoursAgo: 26 },
    { text: insertedTexts[1], engine: "browser", voiceLabel: "شعرخوان — آرام با مکث‌های موزون", hoursAgo: 50 },
    { text: insertedTexts[5], engine: "neural", voiceLabel: "راوی مستند — جدی و باوقار", hoursAgo: 80 },
  ];

  await db.insert(speechHistory).values(
    historySeeds.map((h) => ({
      userId: user.id,
      textId: h.text.id,
      title: h.text.title,
      content: h.text.content,
      engine: h.engine,
      voiceLabel: h.voiceLabel,
      wordCount: h.text.wordCount,
      durationSec: Math.round(h.text.wordCount / 2.3),
      createdAt: new Date(now - h.hoursAgo * 3600000),
    })),
  );
}

export function ensureSeeded(): Promise<void> {
  if (!globalForSeed.__gooyaSeedPromise) {
    globalForSeed.__gooyaSeedPromise = runSeed().catch((err) => {
      console.error("Database bootstrap failed:", err);
      if (dbMode === "postgres") {
        console.error("💡 PostgreSQL در دسترس نیست. برای اجرا بدون PostgreSQL از «npm run local» استفاده کنید (دیتابیس داخلی در پوشهٔ data/).");
      }
      globalForSeed.__gooyaSeedPromise = undefined;
      throw err;
    });
  }
  return globalForSeed.__gooyaSeedPromise;
}
