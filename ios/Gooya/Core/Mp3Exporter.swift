import Foundation

/// ساخت فایل MP3 از کل متن با موتور نیورال (فقط آنلاین؛ مثل نسخهٔ اندروید)
enum Mp3Exporter {
    static func render(text: String, settings: VoiceSettings) async throws -> Data {
        let p = settings.persona
        let segments = Segmenter.segment(text, pauseScale: settings.pauseScale * p.pauseScale)
        var out = Data()
        for seg in segments {
            try Task.checkCancellation()
            let spoken = Diacritizer.prepareForEngine(seg.text)
            if spoken.isEmpty { continue }
            let part = try await EdgeTts.synthesize(
                text: spoken,
                voice: p.neuralVoice,
                rate: Personas.neuralRate(p, settings.rate),
                pitch: Personas.neuralPitch(p, settings.pitch))
            out.append(part)
        }
        if out.isEmpty { throw EdgeTtsError.noAudio }
        return out
    }

    static func write(_ data: Data, name: String) throws -> URL {
        let safe = name.replacingOccurrences(of: #"[\\/:*?"<>|]"#, with: "-", options: .regularExpression)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safe + ".mp3")
        try data.write(to: url, options: .atomic)
        return url
    }
}
