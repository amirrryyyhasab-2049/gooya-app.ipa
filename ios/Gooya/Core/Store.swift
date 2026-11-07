import Foundation
import SwiftUI

// MARK: - مدل‌ها (معادل جدول‌های texts / dictionary / history اندروید)

struct TextDoc: Identifiable, Codable, Equatable {
    var id: Int
    var title: String
    var content: String
    var favorite: Bool
    var wordCount: Int
    var updatedAt: Date
}

struct DictEntry: Identifiable, Codable, Equatable {
    var id: Int
    var word: String
    var diacritized: String
    var note: String
    var updatedAt: Date
}

struct HistoryItem: Identifiable, Codable, Equatable {
    var id: Int
    var title: String
    var content: String
    var voiceLabel: String
    var online: Bool
    var wordCount: Int
    var durationMs: Int
    var createdAt: Date
}

private struct StoreFile: Codable {
    var texts: [TextDoc]
    var dictionary: [DictEntry]
    var history: [HistoryItem]
    var nextId: Int
}

/// ذخیرهٔ محلی (فایل JSON در Application Support)
@MainActor
final class Store: ObservableObject {
    @Published private(set) var texts: [TextDoc] = []
    @Published private(set) var dictionary: [DictEntry] = []
    @Published private(set) var history: [HistoryItem] = []
    private var nextId = 1

    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("gooya-data.json")
        if let data = try? Data(contentsOf: fileURL),
           let file = try? JSONDecoder().decode(StoreFile.self, from: data) {
            texts = file.texts
            dictionary = file.dictionary
            history = file.history
            nextId = file.nextId
        } else {
            seed()
            save()
        }
        sortAll()
    }

    // MARK: ابزار

    static func autoTitle(_ title: String, _ content: String) -> String {
        let t = title.trimmed
        if !t.isEmpty { return t }
        let clean = content.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return clean.lengthU16 > 48 ? String(clean.prefix(48)) + "…" : clean
    }

    static func snippet(_ text: String, max: Int) -> String {
        let clean = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return clean.lengthU16 > max ? String(clean.prefix(max)) + "…" : clean
    }

    private func newId() -> Int {
        defer { nextId += 1 }
        return nextId
    }

    private func sortAll() {
        texts.sort { a, b in
            if a.favorite != b.favorite { return a.favorite && !b.favorite }
            return a.updatedAt > b.updatedAt
        }
        dictionary.sort { $0.updatedAt > $1.updatedAt }
        history.sort { $0.createdAt > $1.createdAt }
        if history.count > 200 { history = Array(history.prefix(200)) }
    }

    private func save() {
        let file = StoreFile(texts: texts, dictionary: dictionary, history: history, nextId: nextId)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func seed() {
        let now = Date()
        for (i, t) in SeedData.texts.enumerated() {
            texts.append(TextDoc(id: newId(), title: t.title, content: t.content, favorite: i < 2,
                                 wordCount: Segmenter.countWords(t.content),
                                 updatedAt: now.addingTimeInterval(-Double(SeedData.texts.count - i) * 86_400)))
        }
        for d in SeedData.dictionary {
            dictionary.append(DictEntry(id: newId(), word: d.word, diacritized: d.diacritized, note: d.note, updatedAt: now))
        }
    }

    // MARK: متن‌ها

    @discardableResult
    func insertText(title: String, content: String) -> Int {
        let id = newId()
        texts.append(TextDoc(id: id, title: Store.autoTitle(title, content), content: content, favorite: false,
                             wordCount: Segmenter.countWords(content), updatedAt: Date()))
        sortAll(); save()
        return id
    }

    func updateText(id: Int, title: String, content: String) {
        guard let i = texts.firstIndex(where: { $0.id == id }) else { return }
        texts[i].title = Store.autoTitle(title, content)
        texts[i].content = content
        texts[i].wordCount = Segmenter.countWords(content)
        texts[i].updatedAt = Date()
        sortAll(); save()
    }

    func toggleFavorite(id: Int) {
        guard let i = texts.firstIndex(where: { $0.id == id }) else { return }
        texts[i].favorite.toggle()
        sortAll(); save()
    }

    func deleteText(id: Int) {
        texts.removeAll { $0.id == id }
        save()
    }

    // MARK: واژه‌نامه

    func dictionaryMap() -> [String: String] {
        var map: [String: String] = [:]
        for d in dictionary { map[d.word] = d.diacritized }
        return map
    }

    func upsertDictionary(word: String, diacritized: String, note: String) {
        dictionary.removeAll { $0.word == word }
        dictionary.append(DictEntry(id: newId(), word: word, diacritized: diacritized, note: note, updatedAt: Date()))
        sortAll(); save()
    }

    func updateDictionary(id: Int, word: String, diacritized: String, note: String) {
        dictionary.removeAll { $0.id == id }
        upsertDictionary(word: word, diacritized: diacritized, note: note)
    }

    func deleteDictionary(id: Int) {
        dictionary.removeAll { $0.id == id }
        save()
    }

    // MARK: تاریخچه

    func addHistory(title: String, content: String, voiceLabel: String, online: Bool, durationMs: Int) {
        history.append(HistoryItem(id: newId(), title: Store.autoTitle(title, content), content: content,
                                   voiceLabel: voiceLabel, online: online,
                                   wordCount: Segmenter.countWords(content), durationMs: durationMs, createdAt: Date()))
        sortAll(); save()
    }

    func deleteHistory(id: Int) {
        history.removeAll { $0.id == id }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }
}

// MARK: - تنظیمات و پیش‌نویس (معادل Prefs اندروید)

@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var online: Bool { didSet { defaults.set(online, forKey: "online") } }
    @Published var personaId: String { didSet { defaults.set(personaId, forKey: "persona") } }
    @Published var rate: Double { didSet { defaults.set(rate, forKey: "rate") } }
    @Published var pitch: Double { didSet { defaults.set(pitch, forKey: "pitch") } }
    @Published var pauseScale: Double { didSet { defaults.set(pauseScale, forKey: "pause") } }

    var draft: String {
        get { defaults.string(forKey: "draft") ?? "" }
        set { defaults.set(newValue, forKey: "draft") }
    }

    init() {
        let d = UserDefaults.standard
        online = d.object(forKey: "online") as? Bool ?? true
        personaId = Personas.get(d.string(forKey: "persona") ?? Personas.defaultId).id
        rate = AppSettings.snap(d.object(forKey: "rate") as? Double ?? 1.0, 0.6, 1.4, 0.05)
        pitch = AppSettings.snap(d.object(forKey: "pitch") as? Double ?? 1.0, 0.7, 1.3, 0.05)
        pauseScale = AppSettings.snap(d.object(forKey: "pause") as? Double ?? 1.0, 0.5, 2.0, 0.1)
    }

    static func snap(_ value: Double, _ from: Double, _ to: Double, _ step: Double) -> Double {
        let v = min(to, max(from, value))
        let snapped = from + ((v - from) / step).rounded() * step
        return min(to, max(from, (snapped * 100).rounded() / 100))
    }

    var voice: VoiceSettings {
        VoiceSettings(online: online, personaId: personaId, rate: rate, pitch: pitch, pauseScale: pauseScale)
    }
}

// MARK: - وضعیت کلی برنامه (صفحهٔ فعال، منو، پیام‌های کوتاه)

enum Screen: String, CaseIterable, Identifiable {
    case studio, texts, dictionary, history, help
    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: return "استودیو گفتار"
        case .texts: return "متن‌های من"
        case .dictionary: return "واژه‌نامهٔ تلفظ"
        case .history: return "تاریخچه"
        case .help: return "راهنما"
        }
    }

    var icon: String {
        switch self {
        case .studio: return "mic.fill"
        case .texts: return "note.text"
        case .dictionary: return "book.fill"
        case .history: return "clock.arrow.circlepath"
        case .help: return "questionmark.circle"
        }
    }
}

struct StudioRequest: Equatable {
    var content: String
    var title: String
    var textId: Int?
}

@MainActor
final class AppModel: ObservableObject {
    @Published var screen: Screen = .studio
    @Published var drawerOpen = false
    @Published var studioRequest: StudioRequest?
    @Published var toastText: String?
    private var toastTask: Task<Void, Never>?

    func openStudio(content: String, title: String, textId: Int?) {
        studioRequest = StudioRequest(content: content, title: title, textId: textId)
        screen = .studio
    }

    func toast(_ message: String) {
        toastText = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if Task.isCancelled { return }
            self?.toastText = nil
        }
    }
}
