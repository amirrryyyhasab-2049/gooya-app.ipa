import Foundation

/// اعراب‌گذاری خودکار متن فارسی.
/// اولویت: واژه‌نامهٔ شخصی ← واژه‌نامهٔ پایه ← صرف فعل ← پسوندها. واژه‌هایی که از قبل اعراب دارند دست‌نخورده می‌مانند.
final class Diacritizer {
    struct Result {
        let text: String
        let totalWords: Int
        let markedWords: Int
        let unknownWords: [String]
    }

    static let zwnj = "\u{200C}"

    private static let diacritics = RX.make(#"[\u064B-\u0652\u0670]"#)
    private static let wordRx = RX.make(#"[\u0621-\u064A\u066E-\u06D3\u200C\u064B-\u0652\u0670]+"#)
    private static let hasLetter = RX.make(#"[\u0621-\u064A\u066E-\u06D3]"#)
    private static let spacesRx = RX.make(#"[ \t\u00A0]+"#)
    private static let spaceBeforePunct = RX.make(#" ?([،؛؟!,.:;])"#)
    private static let invisible = RX.make(#"[\u200B\uFEFF]"#)
    private static let quotes = RX.make(#"[«»“”"'‹›`‟]"#)
    private static let manySpaces = RX.make(#" {2,}"#)

    private static let pastEndings: [String: String] = [
        "": "",
        "م": "\u{064E}م",
        "ی": "ی",
        "یم": "یم",
        "ید": "ید",
        "ند": "\u{064E}ند",
        "ه": "ه",
        "ن": "\u{064E}ن",
        "ه\u{200C}ام": "ه\u{200C}اَم",
        "ه\u{200C}ای": "ه\u{200C}ای",
        "ه\u{200C}ایم": "ه\u{200C}ایم",
        "ه\u{200C}اید": "ه\u{200C}اید",
        "ه\u{200C}اند": "ه\u{200C}اَند"
    ]

    private static let presentEndings: [String: String] = [
        "م": "\u{064E}م",
        "ی": "ی",
        "د": "\u{064E}د",
        "یم": "یم",
        "ید": "ید",
        "ند": "\u{064E}ند"
    ]

    private static let suffixes: [(String, String)] = [
        ("هایشان", "هایِشان"), ("هایتان", "هایِتان"), ("هایمان", "هایِمان"), ("هایی", "هایی"),
        ("هایش", "هایَش"), ("هایت", "هایَت"), ("هایم", "هایَم"), ("های", "هایِ"), ("ها", "ها"),
        ("ترین", "تَرین"), ("تری", "تَری"), ("تر", "تَر"),
        ("شان", "\u{0650}شان"), ("تان", "\u{0650}تان"), ("مان", "\u{0650}مان"),
        ("ان", "ان"), ("یی", "یی"), ("ای", "ای"),
        ("ش", "\u{064E}ش"), ("ت", "\u{064E}ت"), ("م", "\u{064E}م"), ("ی", "ی")
    ]

    private enum Kind { case none, dur, neg, negDur, subj }

    private static let prefixes: [(raw: String, voc: String, kind: Kind)] = [
        ("", "", .none),
        ("نمی\u{200C}", "نِمی\u{200C}", .negDur),
        ("نمی", "نِمی\u{200C}", .negDur),
        ("می\u{200C}", "می\u{200C}", .dur),
        ("می", "می\u{200C}", .dur),
        ("ن", "نَ", .neg),
        ("ب", "", .subj)
    ]

    private let lexicon: [String: String]
    private let verbs: [Verb]

    init(lexicon: [String: String], verbs: [Verb]) {
        self.lexicon = lexicon
        self.verbs = verbs
    }

    // MARK: ابزار ایستا

    static func strip(_ text: String) -> String {
        diacritics.replace(in: text, with: "")
    }

    static func hasDiacritics(_ text: String) -> Bool {
        diacritics.has(in: text)
    }

    static func normalize(_ text: String) -> String {
        var s = text
            .replacingOccurrences(of: "ي", with: "ی", options: .literal)
            .replacingOccurrences(of: "ك", with: "ک", options: .literal)
            .replacingOccurrences(of: "ۀ", with: "هٔ", options: .literal)
            .replacingOccurrences(of: "ـ", with: "", options: .literal)
            .replacingOccurrences(of: "\r\n", with: "\n", options: .literal)
            .replacingOccurrences(of: "\r", with: "\n", options: .literal)
        s = spacesRx.replace(in: s, with: " ")
        s = spaceBeforePunct.replace(in: s, with: "$1")
        return s
    }

    /// متن را برای ارسال به موتور گفتار آماده می‌کند
    static func prepareForEngine(_ text: String) -> String {
        var s = normalize(text)
        s = invisible.replace(in: s, with: "")
        s = quotes.replace(in: s, with: " ")
        s = s.replacingOccurrences(of: "\u{2026}", with: "...", options: .literal)
        s = manySpaces.replace(in: s, with: " ").trimmed
        return SpeechText.speakable(s)
    }

    // MARK: اعراب‌گذاری

    func diacritize(_ input: String, userDictionary: [String: String] = [:]) -> Result {
        let text = Diacritizer.normalize(input)
        let ns = text as NSString
        var out = ""
        var last = 0
        var total = 0
        var marked = 0
        var unknown: [String] = []

        for m in Diacritizer.wordRx.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            last = m.range.location + m.range.length
            let token = ns.substring(with: m.range)
            var replacement = token
            if token != Diacritizer.zwnj && Diacritizer.hasLetter.has(in: token) {
                total += 1
                if Diacritizer.hasDiacritics(token) {
                    marked += 1
                } else if let resolved = resolveWord(token, userDictionary) {
                    if resolved != token { marked += 1 }
                    replacement = resolved
                } else if token.lengthU16 > 2 && unknown.count < 40 && !unknown.contains(token) {
                    unknown.append(token)
                }
            }
            out += replacement
        }
        out += ns.substring(from: last)
        return Result(text: out, totalWords: total, markedWords: marked, unknownWords: unknown)
    }

    private func lookupBase(_ base: String, _ dict: [String: String]) -> String? {
        dict[base] ?? lexicon[base]
    }

    private func resolveWord(_ token: String, _ dict: [String: String]) -> String? {
        if let direct = lookupBase(token, dict) { return direct }
        if let verb = conjugate(token) { return verb }

        for (raw, voc) in Diacritizer.suffixes {
            for joiner in [Diacritizer.zwnj, ""] {
                let full = joiner + raw
                if token.lengthU16 > full.lengthU16 + 1 && token.hasSuffixU16(full) {
                    let base = token.dropLastU16(full.lengthU16)
                    if let baseVoc = lookupBase(base, dict) {
                        let endsWithHe = base.hasSuffixU16("ه")
                        let startsWithMark = voc.hasPrefixU16("\u{064E}") || voc.hasPrefixU16("\u{0650}")
                        var suffixVoc = voc
                        if joiner == Diacritizer.zwnj && startsWithMark {
                            suffixVoc = voc.dropFirstU16(1)
                        } else if endsWithHe && joiner.isEmpty && voc.hasPrefixU16("\u{0650}") {
                            suffixVoc = Diacritizer.zwnj + voc.dropFirstU16(1)
                        } else if endsWithHe && joiner.isEmpty && voc.hasPrefixU16("\u{064E}") {
                            suffixVoc = Diacritizer.zwnj + "ا" + voc
                        }
                        return baseVoc + joiner + suffixVoc
                    }
                }
            }
        }
        return nil
    }

    private func conjugate(_ token: String) -> String? {
        for p in Diacritizer.prefixes {
            if !p.raw.isEmpty && !token.hasPrefixU16(p.raw) { continue }
            let rest = token.dropFirstU16(p.raw.lengthU16)
            if rest.isEmpty { continue }
            let preferPresent = p.kind == .dur || p.kind == .negDur || p.kind == .subj

            for v in verbs {
                var past: String?
                var present: String?
                if p.kind != .subj && rest.hasPrefixU16(v.past) {
                    if let e = Diacritizer.pastEndings[rest.dropFirstU16(v.past.lengthU16)] {
                        past = p.voc + v.pastV + e
                    }
                }
                if rest.hasPrefixU16(v.pres) {
                    if let e = Diacritizer.presentEndings[rest.dropFirstU16(v.pres.lengthU16)] {
                        present = (p.kind == .subj ? v.b : p.voc) + v.presV + e
                    }
                }
                let matched = preferPresent ? (present ?? past) : (past ?? present)
                if let m = matched { return m }

                if p.kind == .subj || p.kind == .neg {
                    let impRaw = v.imp ?? v.pres
                    let impVoc = v.impV ?? v.presV
                    if rest == impRaw { return (p.kind == .subj ? v.b : p.voc) + impVoc }
                }
            }
        }
        return nil
    }
}
