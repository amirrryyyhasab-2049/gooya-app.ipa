import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

struct StudioView: View {
    @StateObject private var engine = SpeechEngine()

    @AppStorage("gooya.text") private var text = ""
    @AppStorage("gooya.persona") private var personaId = Personas.defaultId
    @AppStorage("gooya.rate") private var rate = 1.0
    @AppStorage("gooya.pitch") private var pitch = 1.0
    @AppStorage("gooya.pause") private var pauseScale = 1.0
    @AppStorage("gooya.auto") private var autoDiacritics = true
    @AppStorage("gooya.online") private var online = true

    @State private var segments: [Segment] = []
    @State private var previewCount = 0
    @State private var seekValue = 0.0
    @State private var seeking = false
    @State private var info: String?

    private var persona: Persona { Personas.get(personaId) }
    private var accent: Color { Color(hex: persona.colorHex) }

    private var settings: VoiceSettings {
        VoiceSettings(online: online, personaId: personaId, rate: rate, pitch: pitch, pauseScale: pauseScale)
    }

    private var seekMax: Double {
        let count = engine.status == .idle ? previewCount : engine.total
        return Double(max(1, count - 1))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editorSection
                    personaSection
                    tuningSection
                    playerSection
                    readerSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("گویا")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: text) {
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            previewCount = Segmenter.segment(text, pauseScale: 1.0).count
        }
        .onChange(of: engine.currentIndex) { newValue in
            if !seeking && newValue >= 0 { seekValue = Double(newValue) }
        }
    }

    // MARK: بخش‌ها

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("متن شما").font(.headline)
            TextEditor(text: $text)
                .multilineTextAlignment(.trailing)
                .frame(minHeight: 180)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            HStack {
                Button { applyDiacritics() } label: { Label("اعراب‌گذاری متن", systemImage: "textformat.abc") }
                    .buttonStyle(.bordered)
                Button(role: .destructive) { text = ""; info = nil } label: { Label("پاک کردن", systemImage: "trash") }
                    .buttonStyle(.bordered)
                Spacer()
                Text("\(Segmenter.faNum(Segmenter.countWords(text))) واژه")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let info = info {
                Text(info).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var personaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("گوینده").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Personas.all) { p in
                        Button { personaId = p.id } label: {
                            VStack(spacing: 4) {
                                Text(p.emoji).font(.largeTitle)
                                Text(p.name).font(.subheadline.bold())
                                Text(p.tagline).font(.caption2).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 118, height: 112)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 18)
                                .fill(personaId == p.id ? Color(hex: p.colorHex).opacity(0.18) : Color(.secondarySystemGroupedBackground)))
                            .overlay(RoundedRectangle(cornerRadius: 18)
                                .stroke(personaId == p.id ? Color(hex: p.colorHex) : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(persona.descriptionText).font(.footnote).foregroundStyle(.secondary)
            Button { playSample() } label: { Label("شنیدن نمونهٔ صدا", systemImage: "speaker.wave.2.fill") }
                .buttonStyle(.bordered)
                .tint(accent)
        }
    }

    private var tuningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("تنظیمات صدا").font(.headline)
            Toggle("صدای آنلاین (نیورال)", isOn: $online)
            Toggle("اعراب‌گذاری خودکار هنگام خواندن", isOn: $autoDiacritics)
            sliderRow("سرعت", value: $rate, range: 0.5...1.8, display: rate)
            sliderRow("زیر و بمی", value: $pitch, range: 0.7...1.3, display: pitch)
            sliderRow("مکث بین جمله‌ها", value: $pauseScale, range: 0.4...2.0, display: pauseScale)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, display: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(Segmenter.faNum(String(format: "%.2f", display)))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.05).tint(accent)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 20) {
                Button { engine.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color(.tertiarySystemFill)))
                }
                .buttonStyle(.plain)

                Button { playPauseTapped() } label: {
                    Image(systemName: engine.status == .playing || engine.status == .loading ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(accent))
                }
                .buttonStyle(.plain)
            }

            Slider(value: $seekValue, in: 0...seekMax, step: 1, onEditingChanged: { editing in
                seeking = editing
                if editing {
                    if engine.status == .idle { segments = buildSegments() }
                } else {
                    startPlayback(from: Int(seekValue))
                }
            })
            .tint(accent)

            Text(statusText).font(.footnote).foregroundStyle(.secondary)
            if let notice = engine.notice {
                Text(notice).font(.footnote).foregroundStyle(.orange)
            }
            if let error = engine.errorMessage {
                Text("⚠️ " + error).font(.footnote).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var readerSection: some View {
        Group {
            if !segments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("برای شروع از هر جمله، روی آن بزنید").font(.footnote).foregroundStyle(.secondary)
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(segments) { seg in
                            Text(seg.text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(engine.currentIndex == seg.index ? accent.opacity(0.2) : Color.clear))
                                .contentShape(Rectangle())
                                .onTapGesture { startPlayback(from: seg.index) }
                        }
                    }
                }
            }
        }
    }

    // MARK: منطق

    private var statusText: String {
        switch engine.status {
        case .idle: return "آماده"
        case .loading: return "در حال دریافت صدا…"
        case .playing, .paused:
            let state = engine.status == .paused ? "مکث" : "در حال خواندن"
            return "\(state) — قطعهٔ \(Segmenter.faNum(engine.currentIndex + 1)) از \(Segmenter.faNum(engine.total))"
        }
    }

    private func playPauseTapped() {
        switch engine.status {
        case .idle: startPlayback(from: 0)
        case .playing, .loading: engine.pause()
        case .paused: engine.resume()
        }
    }

    private func buildSegments() -> [Segment] {
        let t = text.trimmed
        if t.isEmpty { return [] }
        let body = autoDiacritics ? Shared.diacritizer.diacritize(t).text : t
        return Segmenter.segment(body, pauseScale: pauseScale * persona.pauseScale)
    }

    private func startPlayback(from index: Int) {
        let built = buildSegments()
        if built.isEmpty {
            info = "ابتدا متنی بنویسید."
            return
        }
        segments = built
        let start = max(0, min(index, built.count - 1))
        seekValue = Double(start)
        engine.play(built, settings: settings, startIndex: start)
    }

    private func playSample() {
        let built = Segmenter.segment(persona.sample, pauseScale: persona.pauseScale)
        engine.play(built, settings: settings, startIndex: 0)
    }

    private func applyDiacritics() {
        let t = text.trimmed
        if t.isEmpty { return }
        let r = Shared.diacritizer.diacritize(t)
        text = r.text
        info = "\(Segmenter.faNum(r.markedWords)) از \(Segmenter.faNum(r.totalWords)) واژه اعراب گرفت."
    }
}
