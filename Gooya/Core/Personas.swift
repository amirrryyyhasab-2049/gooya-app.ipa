import Foundation

struct Persona: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let descriptionText: String
    let emoji: String
    let female: Bool
    /// ضریب سرعت پایه
    let rate: Double
    /// جابه‌جایی زیر و بمی موتور نیورال (هرتز)
    let neuralPitchHz: Int
    /// زیر و بمی پایهٔ موتور دستگاه
    let devicePitch: Double
    /// ضریب مکث پایه
    let pauseScale: Double
    let colorHex: UInt32
    let sample: String

    var neuralVoice: String { female ? Personas.voiceFemale : Personas.voiceMale }
    var label: String { emoji + " " + name }
}

/// تنظیمات انتخابی کاربر
struct VoiceSettings: Equatable {
    var online = true
    var personaId = Personas.defaultId
    var rate = 1.0
    var pitch = 1.0
    var pauseScale = 1.0

    var persona: Persona { Personas.get(personaId) }
}

enum Personas {
    static let voiceMale = "fa-IR-FaridNeural"
    static let voiceFemale = "fa-IR-DilaraNeural"
    static let defaultId = "arman"

    static let all: [Persona] = [
        Persona(id: "arman", name: "آرمان", tagline: "مرد مهربان و روان", descriptionText: "صدایی گرم، آرام و شمرده؛ مناسب مقاله، نامه و متن‌های روزمره.", emoji: "🧔🏻", female: false, rate: 0.96, neuralPitchHz: 0, devicePitch: 0.95, pauseScale: 1.0, colorHex: 0x6366F1, sample: "سلام! من آرمان هستم. خوشحالم که متن شما را با آرامش و شمرده می‌خوانم."),
        Persona(id: "ava", name: "آوا", tagline: "زن مهربان و آرام", descriptionText: "لطیف، صمیمی و دلنشین؛ عالی برای داستان، پیام‌های شخصی و لالایی.", emoji: "👩🏻", female: true, rate: 0.90, neuralPitchHz: -2, devicePitch: 1.10, pauseScale: 1.2, colorHex: 0xEC4899, sample: "سلام، من آوا هستم. با صدایی آرام و مهربان همراه شما خواهم بود."),
        Persona(id: "ravi", name: "راوی کلاسیک", tagline: "گرم، عمیق و شمرده", descriptionText: "لحن روایتگران قدیمی رادیو و سینما؛ باوقار و تأثیرگذار برای متن‌های ادبی.", emoji: "🎙️", female: false, rate: 0.86, neuralPitchHz: -10, devicePitch: 0.80, pauseScale: 1.35, colorHex: 0xF59E0B, sample: "شبی از شب‌های دور، در شهری که نامش را کسی به یاد نمی‌آورد، داستان ما آغاز شد."),
        Persona(id: "khabar", name: "گویندهٔ خبر", tagline: "رسا، شفاف و حرفه‌ای", descriptionText: "واضح و پرانرژی با آهنگ خبری؛ مناسب اطلاعیه، خبر و متن‌های رسمی.", emoji: "📰", female: false, rate: 1.05, neuralPitchHz: 2, devicePitch: 1.00, pauseScale: 0.85, colorHex: 0x0EA5E9, sample: "به گزارش خبرگزاری گویا، نسل تازه‌ای از دستیارهای صوتی فارسی امروز رونمایی شد."),
        Persona(id: "ghesegoo", name: "قصه‌گو", tagline: "گرم و صمیمی برای داستان", descriptionText: "با حس و حال و مکث‌های داستانی؛ عالی برای کودکان و کتاب صوتی.", emoji: "📖", female: true, rate: 0.88, neuralPitchHz: 4, devicePitch: 1.20, pauseScale: 1.3, colorHex: 0x10B981, sample: "یکی بود، یکی نبود. زیر گنبد کبود، خرگوش کوچکی بود که عاشق ستاره‌ها بود."),
        Persona(id: "mostanad", name: "راوی مستند", tagline: "جدی، عمیق و باوقار", descriptionText: "لحن مستندهای طبیعت و تاریخ؛ آرام و پرابهت.", emoji: "🎬", female: false, rate: 0.92, neuralPitchHz: -6, devicePitch: 0.85, pauseScale: 1.15, colorHex: 0x475569, sample: "در دامنهٔ کوه رحمت، ویرانه‌هایی ایستاده‌اند که روزگاری قلب یک امپراتوری بودند."),
        Persona(id: "sher", name: "شعرخوان", tagline: "آرام با مکث‌های موزون", descriptionText: "برای غزل و شعر؛ آهسته، با وزن و سکوت‌های معنادار بین مصراع‌ها.", emoji: "🪶", female: true, rate: 0.80, neuralPitchHz: -1, devicePitch: 1.05, pauseScale: 1.6, colorHex: 0xA21CAF, sample: "یوسف گم‌گشته بازآید به کنعان، غم مخور. کلبهٔ احزان شود روزی گلستان، غم مخور."),
        Persona(id: "podcast", name: "پادکست", tagline: "صمیمی و پرانرژی", descriptionText: "لحن گفت‌وگویی و زنده؛ مناسب پادکست و محتوای آموزشی.", emoji: "🎧", female: false, rate: 1.00, neuralPitchHz: 3, devicePitch: 1.05, pauseScale: 0.95, colorHex: 0x65A30D, sample: "سلام به همهٔ شنونده‌های عزیز! امروز می‌خواهیم دربارهٔ یک موضوع جذاب صحبت کنیم.")
    ]

    static func get(_ id: String) -> Persona {
        all.first { $0.id == id } ?? all[0]
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, v)) }

    /// پارامترهای موتور نیورال، مثلاً rate="-5%" و pitch="+2Hz"
    static func neuralRate(_ p: Persona, _ rate: Double) -> String {
        let pct = Int(((clamp(p.rate * rate, 0.5, 1.8) - 1) * 100).rounded())
        return "\(pct >= 0 ? "+" : "")\(pct)%"
    }

    static func neuralPitch(_ p: Persona, _ pitch: Double) -> String {
        let hz = Int((Double(p.neuralPitchHz) + (pitch - 1) * 40).rounded())
        return "\(hz >= 0 ? "+" : "")\(hz)Hz"
    }

    /// پارامترهای صدای دستگاه (AVSpeechSynthesizer)
    static func deviceRateFactor(_ p: Persona, _ rate: Double) -> Double { clamp(p.rate * rate, 0.5, 2.0) }
    static func devicePitch(_ p: Persona, _ pitch: Double) -> Double { clamp(p.devicePitch * pitch, 0.5, 2.0) }
}
