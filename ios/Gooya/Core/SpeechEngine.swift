import Foundation
import AVFoundation

/// پخش‌کنندهٔ قطعه‌به‌قطعه: صدای آنلاین (نیورال) یا صدای خود دستگاه.
/// قطعهٔ خالی یا خراب رد می‌شود و بقیهٔ متن خوانده می‌شود.
@MainActor
final class SpeechEngine: ObservableObject {
    enum Status { case idle, loading, playing, paused }

    @Published private(set) var status: Status = .idle
    @Published private(set) var currentIndex = -1
    @Published private(set) var total = 0
    @Published var notice: String?
    @Published var errorMessage: String?

    private var generation = 0
    private var paused = false
    private var player: AVAudioPlayer?
    private var runTask: Task<Void, Never>?
    private var cache: [String: Data] = [:]
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var onlineMode = true

    private let synthesizer = AVSpeechSynthesizer()
    private let deviceDelegate = DeviceSpeechDelegate()

    init() {
        synthesizer.delegate = deviceDelegate
    }

    // MARK: کنترل‌ها

    func play(_ segments: [Segment], settings: VoiceSettings, startIndex: Int = 0) {
        halt()
        let gen = generation
        paused = false
        errorMessage = nil
        notice = nil
        total = segments.count
        currentIndex = max(0, min(startIndex, max(0, segments.count - 1)))
        status = .loading
        onlineMode = settings.online
        activateAudioSession()
        let start = currentIndex
        runTask = Task { [self] in
            if settings.online {
                await runOnline(gen: gen, segments: segments, settings: settings, from: start)
            } else {
                await runDevice(gen: gen, segments: segments, settings: settings, from: start)
            }
        }
    }

    func pause() {
        guard status == .playing || status == .loading else { return }
        paused = true
        player?.pause()
        if !onlineMode { synthesizer.pauseSpeaking(at: .word) }
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        paused = false
        player?.play()
        if !onlineMode { synthesizer.continueSpeaking() }
        status = .playing
    }

    func stop() {
        halt()
        status = .idle
        currentIndex = -1
        paused = false
    }

    /// همهٔ کارهای در حال انجام را لغو می‌کند
    private func halt() {
        generation += 1
        runTask?.cancel()
        runTask = nil
        player?.stop()
        player = nil
        synthesizer.stopSpeaking(at: .immediate)
        for task in inFlight.values { task.cancel() }
        inFlight.removeAll()
    }

    private func alive(_ gen: Int) -> Bool {
        gen == generation && !Task.isCancelled
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
    }

    private func finish() {
        status = .idle
        currentIndex = -1
        paused = false
    }

    // MARK: موتور آنلاین

    private func runOnline(gen: Int, segments: [Segment], settings: VoiceSettings, from start: Int) async {
        var consecutiveFailures = 0
        var skippedNoticeShown = false
        var i = start

        while i < segments.count {
            if !alive(gen) { return }
            await waitWhilePaused(gen)
            if !alive(gen) { return }
            let seg = segments[i]
            currentIndex = i

            if Diacritizer.prepareForEngine(seg.text).isEmpty {
                await sleepPause(min(seg.pauseAfter, 250), gen)
                i += 1
                continue
            }
            for j in (i + 1)...(i + 2) where j < segments.count {
                prefetch(segments[j], settings)
            }

            let data: Data
            do {
                data = try await fetchWithRetry(seg, settings)
                consecutiveFailures = 0
            } catch {
                if !alive(gen) { return }
                let m = error.localizedDescription
                let connectionProblem = m.contains("403") || m.contains("resolve") || m.contains("Internet")
                    || m.contains("connect") || m.contains("network") || m.contains("زمان انتظار")
                    || (error as? URLError) != nil
                consecutiveFailures += 1
                if !connectionProblem && consecutiveFailures < 3 {
                    if !skippedNoticeShown {
                        skippedNoticeShown = true
                        notice = "یک بخش قابل‌خواندن نبود و رد شد."
                    }
                    await sleepPause(min(seg.pauseAfter, 250), gen)
                    i += 1
                    continue
                }
                if hasDeviceVoice {
                    notice = "موتور آنلاین در دسترس نبود؛ ادامه با صدای دستگاه."
                    onlineMode = false
                    await runDevice(gen: gen, segments: segments, settings: settings, from: i)
                } else {
                    errorMessage = friendly(error)
                    finish()
                }
                return
            }

            if !alive(gen) { return }
            await waitWhilePaused(gen)
            if !alive(gen) { return }
            status = .playing
            do {
                try await playData(data, gen)
            } catch {
                if !alive(gen) { return }
                cache[cacheKey(seg, settings)] = nil
                if !skippedNoticeShown {
                    skippedNoticeShown = true
                    notice = "یک بخش پخش نشد و رد شد."
                }
            }
            if !alive(gen) { return }
            await sleepPause(seg.pauseAfter, gen)
            i += 1
        }

        if alive(gen) { finish() }
    }

    private func playData(_ data: Data, _ gen: Int) async throws {
        let p = try AVAudioPlayer(data: data)
        player = p
        p.prepareToPlay()
        p.play()
        while alive(gen) && (p.isPlaying || paused) {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        if player === p { player = nil }
    }

    private func waitWhilePaused(_ gen: Int) async {
        while paused && alive(gen) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func sleepPause(_ ms: Int, _ gen: Int) async {
        var remaining = ms
        while remaining > 0 && alive(gen) {
            let step = min(50, remaining)
            try? await Task.sleep(nanoseconds: UInt64(step) * 1_000_000)
            if !paused { remaining -= step }
        }
    }

    // MARK: دریافت صدا و کش

    private func cacheKey(_ seg: Segment, _ s: VoiceSettings) -> String {
        let p = s.persona
        return "\(p.neuralVoice)|\(Personas.neuralRate(p, s.rate))|\(Personas.neuralPitch(p, s.pitch))|\(seg.text)"
    }

    private func makeTask(_ seg: Segment, _ s: VoiceSettings) -> Task<Data, Error> {
        let p = s.persona
        let spoken = Diacritizer.prepareForEngine(seg.text)
        let voice = p.neuralVoice
        let rate = Personas.neuralRate(p, s.rate)
        let pitch = Personas.neuralPitch(p, s.pitch)
        return Task { try await EdgeTts.synthesize(text: spoken, voice: voice, rate: rate, pitch: pitch) }
    }

    private func prefetch(_ seg: Segment, _ s: VoiceSettings) {
        let key = cacheKey(seg, s)
        if cache[key] != nil || inFlight[key] != nil { return }
        if Diacritizer.prepareForEngine(seg.text).isEmpty { return }
        inFlight[key] = makeTask(seg, s)
    }

    private func fetch(_ seg: Segment, _ s: VoiceSettings) async throws -> Data {
        let key = cacheKey(seg, s)
        if let hit = cache[key] { return hit }
        let task = inFlight[key] ?? makeTask(seg, s)
        inFlight[key] = task
        do {
            let data = try await task.value
            inFlight[key] = nil
            cache[key] = data
            if cache.count > 80, let anyKey = cache.keys.first { cache[anyKey] = nil }
            return data
        } catch {
            inFlight[key] = nil
            throw error
        }
    }

    private func fetchWithRetry(_ seg: Segment, _ s: VoiceSettings) async throws -> Data {
        do {
            return try await fetch(seg, s)
        } catch {
            if Task.isCancelled { throw error }
            return try await fetch(seg, s)
        }
    }

    // MARK: موتور دستگاه

    private var hasDeviceVoice: Bool {
        AVSpeechSynthesisVoice(language: "fa-IR") != nil
    }

    private func runDevice(gen: Int, segments: [Segment], settings: VoiceSettings, from start: Int) async {
        guard let voice = AVSpeechSynthesisVoice(language: "fa-IR") else {
            errorMessage = "صدای فارسی روی این دستگاه نصب نیست. «صدای آنلاین» را روشن کنید."
            finish()
            return
        }
        status = .playing
        let p = settings.persona
        var i = start
        while i < segments.count {
            if !alive(gen) { return }
            await waitWhilePaused(gen)
            if !alive(gen) { return }
            let seg = segments[i]
            currentIndex = i
            let spoken = Diacritizer.prepareForEngine(seg.text)
            if !spoken.isEmpty {
                let u = AVSpeechUtterance(string: spoken)
                u.voice = voice
                let factor = Personas.deviceRateFactor(p, settings.rate)
                u.rate = Float(min(Double(AVSpeechUtteranceMaximumSpeechRate),
                                   max(Double(AVSpeechUtteranceMinimumSpeechRate),
                                       Double(AVSpeechUtteranceDefaultSpeechRate) * factor)))
                u.pitchMultiplier = Float(Personas.devicePitch(p, settings.pitch))
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    deviceDelegate.onFinish = { cont.resume() }
                    synthesizer.speak(u)
                }
            }
            if !alive(gen) { return }
            await sleepPause(seg.pauseAfter, gen)
            i += 1
        }
        if alive(gen) { finish() }
    }

    // MARK: پیام خطا

    private func friendly(_ error: Error) -> String {
        let m = error.localizedDescription
        if m.contains("403") {
            return "سرویس صدای نیورال دسترسی را رد کرد (۴۰۳). ساعت و تاریخ گوشی را روی «خودکار» بگذارید؛ اگر مشکل ادامه داشت «صدای آنلاین» را خاموش کنید."
        }
        if m.contains("زمان انتظار") { return m }
        return "دریافت صدا ناموفق بود: " + m
    }
}

final class DeviceSpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let cb = onFinish
        onFinish = nil
        cb?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let cb = onFinish
        onFinish = nil
        cb?()
    }
}
