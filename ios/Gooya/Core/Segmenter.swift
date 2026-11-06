import Foundation

struct Segment: Identifiable, Equatable {
    enum Kind { case sentence, clause, line, paragraph }

    let index: Int
    let text: String
    /// مکث بعد از این قطعه (میلی‌ثانیه)
    let pauseAfter: Int
    let kind: Kind

    var id: Int { index }
}

/// متن را به قطعه‌های قابل‌خواندن تبدیل می‌کند و برای هر قطعه مکث مناسب (مثل گویندهٔ انسانی) تعیین می‌کند.
enum Segmenter {
    private static let pPeriod = 620, pExclaim = 700, pQuestion = 720, pEllipsis = 950, pComma = 300
    private static let pSemicolon = 420, pColon = 450, pLine = 560, pVerse = 700, pParagraph = 1050, pForced = 160

    private static let sentenceRx = RX.make(#"[^.!?؟…]+[.!?؟…]+[»”"'’›‟„)}\]）】〕〉》」』]*|[^.!?؟…]+$"#)
    private static let clauseRx = RX.make(#"[^،,؛;:]+(?:[،,؛;:]+|$)"#)
    private static let paragraphSplit = RX.make(#"\n\s*\n+"#)
    private static let wordSplit = RX.make(#"[\s\u200C]+"#)
    private static let hasAlnum = RX.make(#"[\p{L}\p{N}]"#)

    private static func terminalPause(_ sentence: String) -> Int {
        let s = sentence.trimmed
        if s.isEmpty { return 0 }
        if s.hasSuffix("...") || s.hasSuffix("…") { return pEllipsis }
        guard let last = s.unicodeScalars.last?.value else { return 0 }
        switch last {
        case 0x2E: return pPeriod                 // .
        case 0x21: return pExclaim                // !
        case 0x3F, 0x061F: return pQuestion       // ? ؟
        case 0x060C, 0x2C: return pComma          // ، ,
        case 0x061B, 0x3B: return pSemicolon      // ؛ ;
        case 0x3A: return pColon                  // :
        default: return 0
        }
    }

    private static func findAll(_ rx: NSRegularExpression, _ text: String) -> [String] {
        var out = rx.allMatches(in: text).map { $0.trimmed }.filter { !$0.isEmpty }
        if out.isEmpty && !text.trimmed.isEmpty { out.append(text.trimmed) }
        return out
    }

    private static func splitLong(_ sentence: String, maxChars: Int) -> [String] {
        if sentence.lengthU16 <= maxChars { return [sentence] }
        let clauses = findAll(clauseRx, sentence)
        var merged: [String] = []
        var buffer = ""
        for clause in clauses {
            if buffer.isEmpty {
                buffer = clause
            } else if (buffer + " " + clause).lengthU16 <= maxChars {
                buffer = buffer + " " + clause
            } else {
                merged.append(buffer)
                buffer = clause
            }
        }
        if !buffer.isEmpty { merged.append(buffer) }

        var result: [String] = []
        for piece in merged {
            if piece.lengthU16 <= maxChars {
                result.append(piece)
                continue
            }
            var cur = ""
            for w in piece.components(separatedBy: " ") {
                if (cur + " " + w).trimmed.lengthU16 > maxChars && !cur.isEmpty {
                    result.append(cur.trimmed)
                    cur = w
                } else {
                    cur = cur + " " + w
                }
            }
            if !cur.trimmed.isEmpty { result.append(cur.trimmed) }
        }
        return result
    }

    static func segment(_ input: String, pauseScale: Double, maxChars: Int = 220) -> [Segment] {
        var segments: [Segment] = []
        let text = Diacritizer.normalize(input).trimmed
        if text.isEmpty { return segments }

        let paragraphs = paragraphSplit.splitParts(text)
        for (pIdx, paragraph) in paragraphs.enumerated() {
            let lines = paragraph.components(separatedBy: "\n").map { $0.trimmed }.filter { !$0.isEmpty }
            var looksLikePoem = lines.count >= 2
            for l in lines where Diacritizer.strip(l).lengthU16 > 90 {
                looksLikePoem = false
                break
            }

            for (lIdx, line) in lines.enumerated() {
                let sentences = findAll(sentenceRx, line)
                for (sIdx, sentence) in sentences.enumerated() {
                    let pieces = splitLong(sentence, maxChars: maxChars)
                    for (pcIdx, piece) in pieces.enumerated() {
                        let isLastPiece = pcIdx == pieces.count - 1
                        let isLastSentence = sIdx == sentences.count - 1
                        let isLastLine = lIdx == lines.count - 1
                        let isLastParagraph = pIdx == paragraphs.count - 1

                        var pause = terminalPause(piece)
                        var kind = Segment.Kind.sentence
                        if !isLastPiece {
                            pause = pause != 0 ? pause : pForced
                            kind = .clause
                        } else if isLastSentence {
                            if isLastLine {
                                pause = max(pause, pParagraph)
                                kind = .paragraph
                            } else {
                                pause = max(pause, looksLikePoem ? pVerse : pLine)
                                kind = .line
                            }
                        } else {
                            pause = pause != 0 ? pause : pPeriod
                        }
                        if isLastParagraph && isLastLine && isLastSentence && isLastPiece { pause = 0 }

                        segments.append(Segment(index: segments.count, text: piece,
                                                pauseAfter: Int((Double(pause) * pauseScale).rounded()), kind: kind))
                    }
                }
            }
        }
        return segments
    }

    static func countWords(_ text: String) -> Int {
        var n = 0
        for w in wordSplit.splitParts(Diacritizer.strip(text)) where hasAlnum.has(in: w) { n += 1 }
        return n
    }

    static func faNum(_ n: Int) -> String { faNum(String(n)) }

    static func faNum(_ s: String) -> String {
        String(s.unicodeScalars.map { c -> Character in
            if c.value >= 0x30 && c.value <= 0x39 {
                return Character(UnicodeScalar(0x06F0 + (c.value - 0x30))!)
            }
            return Character(c)
        })
    }
}
