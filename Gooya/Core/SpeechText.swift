import Foundation

/// تبدیل نمادها و علائم به متن قابل‌خواندن (٪ @ € * + − × ÷ = و ...). اگر چیزی برای خواندن نماند، "" برمی‌گرداند.
enum SpeechText {
    private static let operandBefore = #"[\p{L}\p{N})]"#
    private static let operandAfter = #"[\p{L}\p{N}(]"#
    private static let digit = #"[\p{N}]"#

    private static let bidi = RX.make(#"[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069\u200B\uFEFF]"#)
    private static let emptyBrackets = RX.make(#"[(\[{（【][^\p{L}\p{N}]*[)\]}）】]"#)
    private static let percent = RX.make(#"\s*[%٪]"#)
    private static let euroPrefix = RX.make(#"€\s*(\p{N}[\p{N}٬,.٫]*)"#)
    private static let euroSuffix = RX.make(#"(\p{N})\s*€"#)
    private static let cPlus = RX.make(#"(?<![\p{L}\p{N}])C(?=\+\+)"#)
    private static let cSharp = RX.make(#"(?<![\p{L}\p{N}])C#"#)
    private static let trailingPlus = RX.make(#"(?<=[\p{L}\p{N}])\+{1,3}(?![\p{L}\p{N}(+])"#)
    private static let latinWords = RX.make(#"(?<![\p{L}\p{N}])(pro|max|ultra|plus|mini|lite)(?![\p{L}\p{N}])"#, [.caseInsensitive])
    private static let multiply = RX.make(#"(?<="# + operandBefore + #")\s*[*×✕✖]\s*(?="# + operandAfter + #")"#)
    private static let plus = RX.make(#"(?<="# + operandBefore + #")\s*\+\s*(?="# + operandAfter + #")"#)
    private static let leadingPlus = RX.make(#"(?<![\p{L}\p{N})+])\+(?=\p{N})"#)
    private static let minusSpaced = RX.make(#"(?<="# + operandBefore + #")\s+[-–—]\s+(?="# + operandAfter + #")"#)
    private static let minusSign = RX.make(#"(?<="# + operandBefore + #")\s*−\s*(?="# + operandAfter + #")"#)
    private static let negative = RX.make(#"(?<![\p{L}\p{N})])[-−](?="# + digit + #")"#)
    private static let divideSpaced = RX.make(#"(?<="# + operandBefore + #")\s+/\s+(?="# + operandAfter + #")"#)
    private static let power = RX.make(#"(?<="# + operandBefore + #")\^(?="# + operandAfter + #")"#)
    private static let less = RX.make(#"(?<="# + digit + #")\s*<\s*(?="# + digit + #")"#)
    private static let greater = RX.make(#"(?<="# + digit + #")\s*>\s*(?="# + digit + #")"#)
    private static let junk = RX.make(#"[^\p{L}\p{M}\p{N}\s\u200C.,،؛;:!?؟…]"#)
    private static let repeatStop = RX.make(#"([.!?؟])\1{3,}"#)
    private static let repeatSoft = RX.make(#"([،,؛;:])(?:\s*[،,؛;:])+"#)
    private static let commaBeforeStop = RX.make(#"[،,]\s*([.!?؟:؛;])"#)
    private static let spaceBeforePunct = RX.make(#"\s+([،,؛;:!?؟.…])"#)
    private static let leadingPunct = RX.make(#"^[\s.,،؛;:!?؟…]+"#)
    private static let manySpaces = RX.make(#"[ \t]{2,}"#)
    private static let hasSpeakableRx = RX.make(#"[\p{L}\p{N}]"#)

    static func hasSpeakable(_ s: String) -> Bool { hasSpeakableRx.has(in: s) }

    /// هر + چسبیده به آخر کلمه («pro+»، «C++») می‌شود «پلاس».
    private static func replaceTrailingPlus(_ s: String) -> String {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in trailingPlus.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            out += String(repeating: " پلاس", count: m.range.length) + " "
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    /// کلمات لاتین رایج در نام گوشی و محصول
    private static func replaceLatinWords(_ s: String) -> String {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in latinWords.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let word = ns.substring(with: m.range).lowercased()
            switch word {
            case "pro": out += "پرو"
            case "max": out += "مکس"
            case "ultra": out += "اولترا"
            case "plus": out += "پلاس"
            case "mini": out += "مینی"
            default: out += "لایت"
            }
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }

    static func speakable(_ input: String) -> String {
        if input.isEmpty { return "" }
        var s = bidi.replace(in: input, with: "")

        s = emptyBrackets.replace(in: s, with: " ")

        s = percent.replace(in: s, with: " درصد ")
        // علامت $ خوانده نمی‌شود (معمولاً کنارش «دلار» نوشته می‌شود)؛ در مرحلهٔ حذف علائم پاک می‌شود
        s = euroPrefix.replace(in: s, with: "$1 یورو ")
        s = euroSuffix.replace(in: s, with: "$1 یورو ")
        s = s.replacingOccurrences(of: "€", with: " یورو ").replacingOccurrences(of: "£", with: " پوند ")

        s = s.replacingOccurrences(of: "@", with: " اَت ساین ")

        s = cPlus.replace(in: s, with: "سی")
        s = cSharp.replace(in: s, with: "سی شارپ ")
        s = replaceTrailingPlus(s)
        s = replaceLatinWords(s)

        s = multiply.replace(in: s, with: " ضربدر ")
        s = plus.replace(in: s, with: " بعلاوه ")
        s = leadingPlus.replace(in: s, with: " پلاس ")
        s = minusSpaced.replace(in: s, with: " منهای ")
        s = minusSign.replace(in: s, with: " منهای ")
        s = negative.replace(in: s, with: " منفی ")
        s = divideSpaced.replace(in: s, with: " تقسیم بر ")
        s = s.replacingOccurrences(of: "÷", with: " تقسیم بر ")
        s = power.replace(in: s, with: " به توان ")
        s = less.replace(in: s, with: " کوچکتر از ")
        s = greater.replace(in: s, with: " بزرگتر از ")
        s = s.replacingOccurrences(of: "≤", with: " کوچکتر یا مساوی ")
            .replacingOccurrences(of: "≥", with: " بزرگتر یا مساوی ")
            .replacingOccurrences(of: "≠", with: " نامساوی ")
            .replacingOccurrences(of: "≈", with: " تقریباً ")
            .replacingOccurrences(of: "±", with: " مثبت منفی ")
            .replacingOccurrences(of: "√", with: " جذر ")
        s = s.replacingOccurrences(of: "=", with: " مساوی ")

        s = s.replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: "[", with: " ")
            .replacingOccurrences(of: "{", with: " ")
            .replacingOccurrences(of: ")", with: "،")
            .replacingOccurrences(of: "]", with: "،")
            .replacingOccurrences(of: "}", with: "،")

        s = junk.replace(in: s, with: " ")

        s = repeatStop.replace(in: s, with: "$1")
        s = repeatSoft.replace(in: s, with: "$1")
        s = commaBeforeStop.replace(in: s, with: "$1")
        s = manySpaces.replace(in: s, with: " ")
        s = spaceBeforePunct.replace(in: s, with: "$1")
        s = leadingPunct.replace(in: s, with: "")
        s = s.trimmed

        return hasSpeakable(s) ? s : ""
    }
}
