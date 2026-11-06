import Foundation

// MARK: - کمک‌کنندهٔ رشته (محاسبهٔ طول و برش بر پایهٔ UTF-16 تا با نسخهٔ اندروید یکسان باشد)

extension String {
    var lengthU16: Int { utf16.count }

    func hasPrefixU16(_ p: String) -> Bool {
        let a = utf16, b = p.utf16
        if b.count > a.count { return false }
        return a.starts(with: b)
    }

    func hasSuffixU16(_ s: String) -> Bool {
        let a = Array(utf16), b = Array(s.utf16)
        if b.count > a.count { return false }
        return Array(a[(a.count - b.count)...]) == b
    }

    func dropFirstU16(_ n: Int) -> String {
        String(decoding: Array(utf16.dropFirst(n)), as: UTF16.self)
    }

    func dropLastU16(_ n: Int) -> String {
        String(decoding: Array(utf16.dropLast(n)), as: UTF16.self)
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - عبارت‌های باقاعده

enum RX {
    static func make(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            fatalError("الگوی نامعتبر: \(pattern)")
        }
    }
}

extension NSRegularExpression {
    private func fullRange(_ s: String) -> NSRange {
        NSRange(location: 0, length: (s as NSString).length)
    }

    func replace(in s: String, with template: String) -> String {
        stringByReplacingMatches(in: s, options: [], range: fullRange(s), withTemplate: template)
    }

    func allMatches(in s: String) -> [String] {
        let ns = s as NSString
        return matches(in: s, options: [], range: fullRange(s)).map { ns.substring(with: $0.range) }
    }

    func has(in s: String) -> Bool {
        firstMatch(in: s, options: [], range: fullRange(s)) != nil
    }

    /// مثل split در جاوا: قطعه‌ها بین تطابق‌ها؛ قطعه‌های خالیِ انتها حذف می‌شوند.
    func splitParts(_ s: String) -> [String] {
        let ns = s as NSString
        var parts: [String] = []
        var last = 0
        for m in matches(in: s, options: [], range: fullRange(s)) {
            parts.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            last = m.range.location + m.range.length
        }
        parts.append(ns.substring(from: last))
        while let l = parts.last, l.isEmpty { parts.removeLast() }
        return parts
    }
}
