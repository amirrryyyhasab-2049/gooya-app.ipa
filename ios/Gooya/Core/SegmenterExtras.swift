import Foundation

extension Segmenter {
    /// تخمین زمان خواندن (ثانیه): واژه‌ها به‌علاوهٔ مجموع مکث‌ها
    static func estimateSeconds(_ segments: [Segment], rate: Double) -> Double {
        var words = 0
        var pauses = 0
        for s in segments {
            words += countWords(s.text)
            pauses += s.pauseAfter
        }
        return Double(words) / (2.4 * max(0.4, rate)) + Double(pauses) / 1000.0
    }

    static func formatDuration(_ totalSeconds: Double) -> String {
        let s = Int(max(0, totalSeconds.rounded()))
        let m = s / 60
        let r = s % 60
        return m > 0 ? faNum(m) + " دقیقه و " + faNum(r) + " ثانیه" : faNum(r) + " ثانیه"
    }
}
