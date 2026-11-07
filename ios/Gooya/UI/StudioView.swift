import SwiftUI
import AVFoundation

/// صفحهٔ استودیو گفتار؛ ترتیب و ظاهر مطابق fragment_studio.xml اندروید:
/// کارت ویرایشگر ← پخش‌کنندهٔ تیره ← نمای خواندن ← گوینده ← موتور صدا و لحن
struct StudioView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var store: Store
    @StateObject private var engine = SpeechEngine()

    @State private var text = ""
    @State private var title = ""
    @State private var sourceTextId: Int? = nil
    @State private var segments: [Segment] = []
    @State private var statsText = ""
    @State private var previewCount = 0
    @State private var hasMarks = false
    @State private var seekValue = 0.0
    @State private var seeking = false
    @State private var keepProgress = false
    @State private var showDiacriticBar = false
    @State private var unknownWords: [String] = []
    @State private var showSamples = false
    @State private var showSave = false
    @State private var dictSheet: DictSheetData? = nil
    @State private var shareItem: ShareItem? = nil
    @State private var exporting = false
    @State private var inserter = TextInserter()

    private struct StatsKey: Hashable {
        let text: String
        let title: String
        let pause: Double
        let rate: Double
        let persona: String
    }

    private var persona: Persona { Personas.get(settings.personaId) }

    private var seekMax: Double {
        let count = engine.status == .idle ? previewCount : engine.total
        return Double(max(1, count - 1))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                editorCard
                playerCard
                if !segments.isEmpty { readerCard }
                voiceCard
                engineCard
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { setup() }
        .onDisappear {
            if sourceTextId == nil { settings.draft = text }
            engine.stop()
        }
        .task(id: StatsKey(text: text, title: title, pause: settings.pauseScale, rate: settings.rate, persona: settings.personaId)) {
            do { try await Task.sleep(nanoseconds: 250_000_000) } catch { return }
            updateStats()
        }
        .onChange(of: text) { newValue in
            hasMarks = Diacritizer.hasDiacritics(newValue)
            if sourceTextId == nil { settings.draft = newValue }
        }
        .onChange(of: engine.currentIndex) { newValue in
            keepProgress = false
            if !seeking && newValue >= 0 { seekValue = Double(newValue) }
        }
        .onChange(of: engine.status) { newValue in
            if newValue == .idle && !keepProgress { seekValue = 0 }
        }
        .onChange(of: engine.notice) { newValue in
            if let n = newValue { model.toast(n) }
        }
        .confirmationDialog("نمونه متن", isPresented: $showSamples, titleVisibility: .visible) {
            ForEach(0..<SeedData.samples.count, id: \.self) { i in
                Button(SeedData.samples[i].title) { loadSample(i) }
            }
        }
        .sheet(isPresented: $showSave) {
            TextEditSheet(heading: sourceTextId != nil ? "به‌روزرسانی متن" : "ذخیرهٔ متن", title: title, content: text) { newTitle, content in
                if let id = sourceTextId {
                    store.updateText(id: id, title: newTitle, content: content)
                    model.toast("متن به‌روزرسانی شد.")
                } else {
                    sourceTextId = store.insertText(title: newTitle, content: content)
                    model.toast("متن ذخیره شد.")
                }
                title = Store.autoTitle(newTitle, content)
                text = content
            }
        }
        .sheet(item: $dictSheet) { data in
            DictEditSheet(data: data) {
                unknownWords.removeAll { $0 == data.word }
                model.toast("به واژه‌نامه اضافه شد. دوباره «اعراب‌گذاری خودکار» را بزنید.")
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
        }
    }

    // MARK: - کارت ویرایشگر

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    GButton(title: "اعراب‌گذاری خودکار", icon: "plus", kind: .filled(.emerald600)) { runDiacritize() }
                    if hasMarks {
                        GButton(title: "حذف اعراب", kind: .text(.indigo600)) { text = Diacritizer.strip(text) }
                    }
                    GButton(title: "⌨️", kind: .tonal) { showDiacriticBar.toggle() }
                    GButton(title: "نمونه متن", kind: .tonal) { showSamples = true }
                    GButton(title: "ذخیرهٔ متن", kind: .tonal) { saveTapped() }
                    GButton(title: "پاک کردن", kind: .text(.slate500)) { clearAll() }
                }
            }

            if showDiacriticBar {
                DiacriticBar(inserter: inserter).padding(.top, 4)
            }

            GooyaTextView(text: $text,
                          placeholder: "متن فارسی خود را این‌جا بنویسید یا بچسبانید… (بدون محدودیت واژه)",
                          inserter: inserter)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.slate50))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slate200, lineWidth: 1))
                .padding(.top, 8)

            Text(statsText)
                .font(.vazir(12))
                .foregroundColor(.slate500)
                .padding(.top, 8)

            if !unknownWords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("این واژه‌ها در واژه‌نامه نبودند؛ برای تلفظ دقیق روی هرکدام بزنید:")
                        .font(.vazir(12))
                        .foregroundColor(.amber800)
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(unknownWords, id: \.self) { w in
                            ChipView(label: w + " +", fill: .white) {
                                dictSheet = DictSheetData(word: w, diacritized: w)
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.amber100))
                .padding(.top, 8)
            }
        }
        .gooyaCard(padding: 12)
    }

    // MARK: - پخش‌کننده (bg_player)

    private var isActive: Bool { engine.status == .loading || engine.status == .playing }

    private var statusText: String {
        if seeking {
            return "رفتن به قطعهٔ \(Segmenter.faNum(Int(seekValue) + 1)) از \(Segmenter.faNum(Int(seekMax) + 1))"
        }
        switch engine.status {
        case .idle: return "آماده برای خواندن"
        case .loading: return "در حال آماده‌سازی صدا…"
        case .playing: return "در حال خواندن قطعهٔ \(Segmenter.faNum(engine.currentIndex + 1)) از \(Segmenter.faNum(engine.total))"
        case .paused: return "مکث شده"
        }
    }

    private var engineBadge: String {
        let online = engine.status == .idle ? settings.online : engine.onlineMode
        return online ? "نیورال · آنلاین" : "صدای دستگاه · آفلاین"
    }

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button { playPauseTapped() } label: {
                    Image(systemName: isActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(Color.violet600))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("پخش")

                Button { engine.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .disabled(engine.status == .idle)
                .opacity(engine.status == .idle ? 0.5 : 1)
                .padding(.leading, 8)
                .accessibilityLabel("توقف")

                VStack(alignment: .leading, spacing: 2) {
                    Text(persona.label + " — " + persona.tagline)
                        .font(.vazir(15, bold: true))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.vazir(12))
                        .foregroundColor(.navSubtitle)
                    Text(engineBadge)
                        .font(.vazir(11))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.133))
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 14)
            }

            GSlider(value: $seekValue, range: 0...seekMax, step: 1,
                    active: .progressGreen, inactive: Color.white.opacity(0.2), thumb: .progressGreen,
                    trackHeight: 6, thumbRadius: 8, haloRadius: 14) { editing in
                seeking = editing
                if !editing { keepProgress = true; startPlayback(Int(seekValue)) }
            }
            .padding(.top, 4)

            if let error = engine.errorMessage {
                Text("⚠️ " + error)
                    .font(.vazir(13))
                    .foregroundColor(Color(hex: 0xFECDD3))
                    .lineSpacing(6)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xF43F5E, opacity: 0.2))
                    .padding(.top, 10)
            }

            GButton(title: exporting ? "در حال ساخت فایل صوتی…" : "ذخیره / اشتراک MP3",
                    icon: "square.and.arrow.up",
                    kind: .outlined(foreground: .white, border: Color.white.opacity(0.33)),
                    enabled: !exporting, fullWidth: true) { exportMp3() }
                .padding(.top, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(playerGradient))
    }

    // MARK: - نمای خواندن

    private var readerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("نمای خواندن (برای شروع از هر قطعه روی آن بزنید)")
                .font(.vazir(12))
                .foregroundColor(.slate500)
            ReaderTextView(segments: segments, currentIndex: engine.currentIndex,
                           active: engine.status != .idle) { index in startPlayback(index) }
        }
        .gooyaCard()
    }

    // MARK: - گوینده

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("گوینده")
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Personas.all) { p in
                    ChipView(label: p.label, selected: p.id == settings.personaId) { settings.personaId = p.id }
                }
            }
            Text(persona.descriptionText)
                .font(.vazir(13))
                .foregroundColor(.slate500)
                .lineSpacing(5)
            GButton(title: "▶ پیش‌نمایش صدا", kind: .tonal) { preview() }
        }
        .gooyaCard()
    }

    // MARK: - موتور صدا و لحن

    private var hasDeviceVoice: Bool { AVSpeechSynthesisVoice(language: "fa-IR") != nil }

    private var engineHint: String {
        if settings.online { return "کیفیت بالا با دو صدای طبیعی مرد و زن؛ به اینترنت نیاز دارد." }
        return hasDeviceVoice
            ? "صدای فارسی روی این دستگاه یافت شد؛ بدون اینترنت کار می‌کند."
            : "صدای فارسی روی این دستگاه نصب نیست (راهنما را ببینید). در این حالت از موتور آنلاین استفاده می‌شود."
    }

    private var rateLabel: String {
        let word = settings.rate < 0.85 ? "شمرده" : (settings.rate > 1.15 ? "تند" : "عادی")
        return "سرعت: \(word) ×\(Segmenter.faNum(String(format: "%.2f", settings.rate)))"
    }

    private var pitchLabel: String {
        let word = settings.pitch < 0.9 ? "بم" : (settings.pitch > 1.1 ? "زیر" : "طبیعی")
        return "زیر و بمی: \(word)"
    }

    private var pauseLabel: String {
        let word = settings.pauseScale < 0.8 ? "کوتاه" : (settings.pauseScale > 1.3 ? "بلند" : "طبیعی")
        return "مکث‌ها: \(word) ×\(Segmenter.faNum(String(format: "%.1f", settings.pauseScale)))"
    }

    private func segmentButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.vazir(14, bold: true))
                .foregroundColor(selected ? .tonalFg : .indigo600)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(selected ? Color.tonalBg : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func materialSlider(_ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double) -> some View {
        GSlider(value: value, range: range, step: step,
                active: .indigo600, inactive: .indigo100, thumb: .indigo600,
                trackHeight: 4, thumbRadius: 10, haloRadius: 20)
    }

    private var engineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("موتور صدا و لحن")

            HStack(spacing: 0) {
                segmentButton("☁️ نیورال (آنلاین)", selected: settings.online) { settings.online = true }
                Rectangle().fill(Color(hex: 0x79747E)).frame(width: 1)
                segmentButton("📱 صدای دستگاه", selected: !settings.online) { settings.online = false }
            }
            .frame(height: 40)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(hex: 0x79747E), lineWidth: 1))
            .padding(.top, 8)

            Text(engineHint)
                .font(.vazir(12))
                .foregroundColor(.slate500)
                .lineSpacing(5)
                .padding(.top, 6)

            Text(rateLabel).font(.vazir(14)).foregroundColor(.slate700).padding(.top, 12)
            materialSlider($settings.rate, 0.6...1.4, 0.05)
            Text(pitchLabel).font(.vazir(14)).foregroundColor(.slate700)
            materialSlider($settings.pitch, 0.7...1.3, 0.05)
            Text(pauseLabel).font(.vazir(14)).foregroundColor(.slate700)
            materialSlider($settings.pauseScale, 0.5...2.0, 0.1)
        }
        .gooyaCard()
    }

    // MARK: - منطق

    private func setup() {
        if let r = model.studioRequest {
            text = r.content
            title = r.title
            sourceTextId = r.textId
            model.studioRequest = nil
        } else if text.isEmpty {
            text = settings.draft
        }
        hasMarks = Diacritizer.hasDiacritics(text)
        engine.onComplete = { online, ms in
            let p = Personas.get(settings.personaId)
            store.addHistory(title: title, content: text.trimmed, voiceLabel: "\(p.name) — \(p.tagline)",
                             online: online, durationMs: ms)
            model.toast("خواندن متن به پایان رسید ✨")
        }
    }

    private func updateStats() {
        let p = persona
        let preview = Segmenter.segment(text, pauseScale: settings.pauseScale * p.pauseScale)
        previewCount = preview.count
        let est = Segmenter.estimateSeconds(preview, rate: settings.rate * p.rate)
        var s = "\(Segmenter.faNum(Segmenter.countWords(text))) واژه · \(Segmenter.faNum(text.lengthU16)) نویسه · "
        s += "\(Segmenter.faNum(preview.count)) قطعه · زمان تقریبی: \(Segmenter.formatDuration(est))"
        if !title.isEmpty { s += " · " + title }
        statsText = s
    }

    private func playPauseTapped() {
        switch engine.status {
        case .idle: startPlayback(0)
        case .paused: engine.resume()
        case .loading, .playing: engine.pause()
        }
    }

    private func startPlayback(_ startIndex: Int) {
        let t = text.trimmed
        if t.isEmpty {
            model.toast("ابتدا متنی بنویسید یا بچسبانید.")
            return
        }
        let p = persona
        let built = Segmenter.segment(t, pauseScale: settings.pauseScale * p.pauseScale)
        if built.isEmpty {
            keepProgress = false
            model.toast("متنی برای خواندن پیدا نشد.")
            return
        }
        segments = built
        let start = max(0, min(startIndex, built.count - 1))
        seekValue = Double(start)
        engine.play(built, settings: settings.voice, startIndex: start)
    }

    private func preview() {
        let p = persona
        engine.play(Segmenter.segment(p.sample, pauseScale: settings.pauseScale * p.pauseScale),
                    settings: settings.voice, startIndex: 0)
    }

    private func runDiacritize() {
        if text.trimmed.isEmpty {
            model.toast("متنی برای اعراب‌گذاری وجود ندارد.")
            return
        }
        let r = Shared.diacritizer.diacritize(text, userDictionary: store.dictionaryMap())
        text = r.text
        model.toast("\(Segmenter.faNum(r.markedWords)) از \(Segmenter.faNum(r.totalWords)) واژه اعراب‌گذاری شد.")
        unknownWords = Array(r.unknownWords.prefix(14))
    }

    private func loadSample(_ index: Int) {
        engine.stop()
        text = SeedData.samples[index].content
        title = SeedData.samples[index].title
        sourceTextId = nil
        unknownWords = []
    }

    private func saveTapped() {
        if text.trimmed.isEmpty {
            model.toast("متنی برای ذخیره وجود ندارد.")
            return
        }
        showSave = true
    }

    private func clearAll() {
        engine.stop()
        text = ""
        title = ""
        sourceTextId = nil
        unknownWords = []
        segments = []
    }

    private func exportMp3() {
        let t = text.trimmed
        if t.isEmpty {
            model.toast("متنی برای تبدیل وجود ندارد.")
            return
        }
        if !settings.online {
            model.toast("ساخت فایل MP3 فقط با موتور نیورال (آنلاین) ممکن است.")
            return
        }
        exporting = true
        let snapshot = settings.voice
        let fileTitle = title.isEmpty ? "gooya" : title
        Task { @MainActor in
            do {
                let data = try await Mp3Exporter.render(text: t, settings: snapshot)
                let url = try Mp3Exporter.write(data, name: fileTitle)
                exporting = false
                model.toast("فایل ذخیره شد: " + url.lastPathComponent)
                shareItem = ShareItem(url: url)
            } catch {
                exporting = false
                model.toast("ساخت فایل ناموفق بود: " + error.localizedDescription)
            }
        }
    }
}
