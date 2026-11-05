import Foundation

/// واژه‌نامهٔ پایهٔ اعراب‌گذاری + جدول ستاک فعل‌ها.
/// داده‌های واژه‌نامه از فایل lexicon.txt (داخل بستهٔ اپ) خوانده می‌شوند؛ هر مدخل: واژه=واژهٔ اعراب‌گذاری‌شده
struct Verb {
    let past: String
    let pastV: String
    let pres: String
    let presV: String
    let imp: String?
    let impV: String?
    let b: String
}

enum Lexicon {
    static func normalizeKey(_ word: String) -> String {
        word.replacingOccurrences(of: "ي", with: "ی", options: .literal)
            .replacingOccurrences(of: "ك", with: "ک", options: .literal)
            .replacingOccurrences(of: "ـ", with: "", options: .literal)
    }

    /// خواندن واژه‌نامه از متن (مدخل‌ها با فاصله یا خط جدید جدا شده‌اند)
    static func parse(_ text: String) -> [String: String] {
        var map: [String: String] = [:]
        for entry in text.split(whereSeparator: { $0.isWhitespace }) {
            let e = String(entry)
            guard let idx = e.firstIndex(of: "="), idx != e.startIndex else { continue }
            let bare = normalizeKey(String(e[e.startIndex..<idx]))
            let voc = String(e[e.index(after: idx)...])
            if map[bare] == nil { map[bare] = voc }
            let noZwnj = bare.replacingOccurrences(of: "\u{200C}", with: "", options: .literal)
            if noZwnj != bare && map[noZwnj] == nil { map[noZwnj] = voc }
        }
        return map
    }

    static func loadBundled() -> [String: String] {
        guard let url = Bundle.main.url(forResource: "lexicon", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return parse(text)
    }

    /// ستاک‌های گذشته و حال پرکاربردترین فعل‌های فارسی به همراه اعراب
    static let verbs: [Verb] = [
        Verb(past: "رفت", pastV: "رَفت", pres: "رو", presV: "رَو", imp: "رو", impV: "رو", b: "بُ"),
        Verb(past: "گفت", pastV: "گُفت", pres: "گوی", presV: "گوی", imp: "گو", impV: "گو", b: "بِ"),
        Verb(past: "کرد", pastV: "کَرد", pres: "کن", presV: "کُن", imp: nil, impV: nil, b: "بُ"),
        Verb(past: "شد", pastV: "شُد", pres: "شو", presV: "شَو", imp: "شو", impV: "شو", b: "بِ"),
        Verb(past: "بود", pastV: "بود", pres: "باش", presV: "باش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "داشت", pastV: "داشت", pres: "دار", presV: "دار", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "آمد", pastV: "آمَد", pres: "آی", presV: "آی", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "دید", pastV: "دید", pres: "بین", presV: "بین", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خواند", pastV: "خواند", pres: "خوان", presV: "خوان", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "نوشت", pastV: "نِوِشت", pres: "نویس", presV: "نِویس", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "شنید", pastV: "شِنید", pres: "شنو", presV: "شِنَو", imp: "شنو", impV: "شنو", b: "بِ"),
        Verb(past: "دانست", pastV: "دانِست", pres: "دان", presV: "دان", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خواست", pastV: "خواست", pres: "خواه", presV: "خواه", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "توانست", pastV: "تَوانِست", pres: "توان", presV: "تَوان", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "زد", pastV: "زَد", pres: "زن", presV: "زَن", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خورد", pastV: "خورد", pres: "خور", presV: "خور", imp: nil, impV: nil, b: "بُ"),
        Verb(past: "گرفت", pastV: "گِرِفت", pres: "گیر", presV: "گیر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "داد", pastV: "داد", pres: "ده", presV: "دَه", imp: "ده", impV: "دِه", b: "بِ"),
        Verb(past: "ساخت", pastV: "ساخت", pres: "ساز", presV: "ساز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "یافت", pastV: "یافت", pres: "یاب", presV: "یاب", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "رسید", pastV: "رِسید", pres: "رس", presV: "رِس", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "ماند", pastV: "ماند", pres: "مان", presV: "مان", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "نشست", pastV: "نِشَست", pres: "نشین", presV: "نِشین", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "ایستاد", pastV: "ایستاد", pres: "ایست", presV: "ایست", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "افتاد", pastV: "اُفتاد", pres: "افت", presV: "اُفت", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "برد", pastV: "بُرد", pres: "بر", presV: "بَر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "آورد", pastV: "آوَرد", pres: "آور", presV: "آوَر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "گذاشت", pastV: "گُذاشت", pres: "گذار", presV: "گُذار", imp: nil, impV: nil, b: "بُ"),
        Verb(past: "گذشت", pastV: "گُذَشت", pres: "گذر", presV: "گُذَر", imp: nil, impV: nil, b: "بُ"),
        Verb(past: "پرسید", pastV: "پُرسید", pres: "پرس", presV: "پُرس", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "فهمید", pastV: "فَهمید", pres: "فهم", presV: "فَهم", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خندید", pastV: "خَندید", pres: "خند", presV: "خَند", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خوابید", pastV: "خوابید", pres: "خواب", presV: "خواب", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "دوید", pastV: "دَوید", pres: "دو", presV: "دَو", imp: "دو", impV: "دو", b: "بِ"),
        Verb(past: "پرید", pastV: "پَرید", pres: "پر", presV: "پَر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "فرستاد", pastV: "فِرِستاد", pres: "فرست", presV: "فِرِست", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "پذیرفت", pastV: "پَذیرُفت", pres: "پذیر", presV: "پَذیر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "شناخت", pastV: "شِناخت", pres: "شناس", presV: "شِناس", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "بست", pastV: "بَست", pres: "بند", presV: "بَند", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "خرید", pastV: "خَرید", pres: "خر", presV: "خَر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "فروخت", pastV: "فُروخت", pres: "فروش", presV: "فُروش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "پوشید", pastV: "پوشید", pres: "پوش", presV: "پوش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "کشید", pastV: "کِشید", pres: "کش", presV: "کِش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "سوخت", pastV: "سوخت", pres: "سوز", presV: "سوز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "ریخت", pastV: "ریخت", pres: "ریز", presV: "ریز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "ترسید", pastV: "تَرسید", pres: "ترس", presV: "تَرس", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "چرخید", pastV: "چَرخید", pres: "چرخ", presV: "چَرخ", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "گشت", pastV: "گَشت", pres: "گرد", presV: "گَرد", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "کوشید", pastV: "کوشید", pres: "کوش", presV: "کوش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "لرزید", pastV: "لَرزید", pres: "لرز", presV: "لَرز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "شکست", pastV: "شِکَست", pres: "شکن", presV: "شِکَن", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "انداخت", pastV: "اَنداخت", pres: "انداز", presV: "اَنداز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "گشود", pastV: "گُشود", pres: "گشای", presV: "گُشای", imp: nil, impV: nil, b: "بُ"),
        Verb(past: "پیوست", pastV: "پِیوَست", pres: "پیوند", presV: "پِیوَند", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "نگریست", pastV: "نِگَریست", pres: "نگر", presV: "نِگَر", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "اندیشید", pastV: "اَندیشید", pres: "اندیش", presV: "اَندیش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "پرداخت", pastV: "پَرداخت", pres: "پرداز", presV: "پَرداز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "شمرد", pastV: "شُمُرد", pres: "شمار", presV: "شُمار", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "آموخت", pastV: "آموخت", pres: "آموز", presV: "آموز", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "جنگید", pastV: "جَنگید", pres: "جنگ", presV: "جَنگ", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "رقصید", pastV: "رَقصید", pres: "رقص", presV: "رَقص", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "بخشید", pastV: "بَخشید", pres: "بخش", presV: "بَخش", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "رساند", pastV: "رِساند", pres: "رسان", presV: "رِسان", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "گریست", pastV: "گِریست", pres: "گری", presV: "گِری", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "جست", pastV: "جُست", pres: "جوی", presV: "جوی", imp: "جو", impV: "جو", b: "بِ"),
        Verb(past: "شست", pastV: "شُست", pres: "شوی", presV: "شوی", imp: nil, impV: nil, b: "بِ"),
        Verb(past: "لمس کرد", pastV: "لَمس کَرد", pres: "لمس کن", presV: "لَمس کُن", imp: nil, impV: nil, b: "بُ"),
    ]
}
