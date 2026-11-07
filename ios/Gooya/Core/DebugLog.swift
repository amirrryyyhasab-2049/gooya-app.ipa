import Foundation

/// گزارش عیب‌یابی سبک: مراحل مهم پخش در فایل gooya-debug.log نوشته می‌شود تا اگر برنامه ناگهان بسته شد،
/// آخرین خط فایل نشان بدهد در کدام مرحله بوده است. از صفحهٔ «راهنما» می‌توان فایل را به اشتراک گذاشت.
enum DebugLog {
    private static let queue = DispatchQueue(label: "gooya.debuglog")

    static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gooya-debug.log")
    }

    static func write(_ message: String) {
        let line = stamp() + " " + message + "\n"
        queue.async { append(line) }
    }

    fileprivate static func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    fileprivate static func append(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        let url = fileURL
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func trimIfNeeded() {
        if let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.size] as? Int, size > 300_000 {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// ثبت خطاهای مرگبار (best-effort): استثنای کشف‌نشده و سیگنال‌های کرش
    static func install() {
        trimIfNeeded()
        write("---- launch ----")
        NSSetUncaughtExceptionHandler { exception in
            DebugLog.append(DebugLog.stamp() + " UNCAUGHT EXCEPTION " + exception.name.rawValue + ": " + (exception.reason ?? "") + "\n"
                            + exception.callStackSymbols.joined(separator: "\n") + "\n")
        }
        for sig in [SIGABRT, SIGILL, SIGSEGV, SIGBUS, SIGTRAP, SIGFPE] {
            signal(sig) { s in
                DebugLog.append(DebugLog.stamp() + " CRASH SIGNAL \(s)\n"
                                + Thread.callStackSymbols.prefix(25).joined(separator: "\n") + "\n")
                signal(s, SIG_DFL)
                raise(s)
            }
        }
    }
}
