import Foundation

enum EdgeTtsError: LocalizedError {
    case http(Int)
    case timeout
    case noAudio
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "HTTP \(code)"
        case .timeout: return "زمان انتظار پاسخ موتور صدا تمام شد."
        case .noAudio: return "موتور صدا پاسخی برنگرداند."
        case .failed(let m): return m
        }
    }
}

/// اتصال WebSocket به سرویس صدای نیورال (غیررسمی). توکن نسخهٔ ۲ و ترفند اصلاح ساعت پیاده شده است.
enum EdgeTts {
    private static let token = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private static let chromium = "143.0.3650.75"
    private static let baseURL = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"

    private static let lock = NSLock()
    private static var clockSkew: Int64 = 0
    private static var skewAdjusted = false

    private static func getSkew() -> Int64 {
        lock.lock(); defer { lock.unlock() }
        return clockSkew
    }

    private static func setSkew(_ v: Int64) {
        lock.lock(); defer { lock.unlock() }
        clockSkew = v
        skewAdjusted = true
    }

    private static func takeSkewAdjusted() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let was = skewAdjusted
        skewAdjusted = false
        return was
    }

    /// متن را به MP3 تبدیل می‌کند. اگر سرور ۴۰۳ بدهد و ساعت گوشی اختلاف داشته باشد، یک بار با ساعت اصلاح‌شده دوباره امتحان می‌کند.
    static func synthesize(text: String, voice: String, rate: String, pitch: String, timeout: TimeInterval = 25) async throws -> Data {
        do {
            return try await synthesizeOnce(text: text, voice: voice, rate: rate, pitch: pitch, timeout: timeout)
        } catch EdgeTtsError.http(let code) where code == 403 && takeSkewAdjusted() {
            return try await synthesizeOnce(text: text, voice: voice, rate: rate, pitch: pitch, timeout: timeout)
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
        return f.string(from: Date())
    }

    private static func escapeXml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func muid() -> String {
        String((0..<32).map { _ in "0123456789ABCDEF".randomElement()! })
    }

    private static func parseHttpDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f.date(from: s)
    }

    private static func synthesizeOnce(text: String, voice: String, rate: String, pitch: String, timeout: TimeInterval) async throws -> Data {
        let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let gec = SecMsGec.generate(unixSeconds: Int64(Date().timeIntervalSince1970) + getSkew())

        var comps = URLComponents(string: baseURL)!
        comps.queryItems = [
            URLQueryItem(name: "TrustedClientToken", value: token),
            URLQueryItem(name: "Sec-MS-GEC", value: gec),
            URLQueryItem(name: "Sec-MS-GEC-Version", value: "2-" + chromium),
            URLQueryItem(name: "ConnectionId", value: requestId)
        ]
        var request = URLRequest(url: comps.url!)
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(chromium.split(separator: ".")[0]).0.0.0 Safari/537.36 Edg/\(chromium.split(separator: ".")[0]).0.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("muid=\(muid());", forHTTPHeaderField: "Cookie")

        let config = "X-Timestamp:\(timestamp())\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n"
            + #"{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}"#

        let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='fa-IR'>"
            + "<voice name='\(voice)'><prosody pitch='\(pitch)' rate='\(rate)' volume='+0%'>\(escapeXml(text))</prosody></voice></speak>"
        let body = "X-RequestId:\(requestId)\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:\(timestamp())Z\r\nPath:ssml\r\n\r\n" + ssml

        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        do {
            let audio: Data = try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    try await task.send(.string(config))
                    try await task.send(.string(body))
                    var audio = Data()
                    while true {
                        let message = try await task.receive()
                        switch message {
                        case .string(let s):
                            if s.contains("Path:turn.end") { return audio }
                        case .data(let d):
                            if d.count < 2 { continue }
                            let base = d.startIndex
                            let headerLength = (Int(d[base]) << 8) | Int(d[base + 1])
                            if 2 + headerLength > d.count { continue }
                            let headerData = d.subdata(in: (base + 2)..<(base + 2 + headerLength))
                            let header = String(decoding: headerData, as: UTF8.self)
                            if header.contains("Path:audio") {
                                audio.append(d.subdata(in: (base + 2 + headerLength)..<d.endIndex))
                            }
                        @unknown default:
                            break
                        }
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw EdgeTtsError.timeout
                }
                let first = try await group.next()!
                group.cancelAll()
                return first
            }
            task.cancel(with: .goingAway, reason: nil)
            if audio.isEmpty { throw EdgeTtsError.noAudio }
            return audio
        } catch {
            let response = task.response as? HTTPURLResponse
            task.cancel(with: .goingAway, reason: nil)
            if let response = response, response.statusCode != 101, response.statusCode != 200 {
                if response.statusCode == 403,
                   let dateString = response.value(forHTTPHeaderField: "Date"),
                   let server = parseHttpDate(dateString) {
                    setSkew(Int64(server.timeIntervalSince1970) - Int64(Date().timeIntervalSince1970))
                }
                throw EdgeTtsError.http(response.statusCode)
            }
            if let e = error as? EdgeTtsError { throw e }
            throw EdgeTtsError.failed(error.localizedDescription)
        }
    }
}
