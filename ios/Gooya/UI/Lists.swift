import SwiftUI
import AVFoundation

// MARK: - ابزار مشترک صفحه‌های فهرستی (fragment_list.xml)

enum Fmt {
    private static let dateOnlyFmt: DateFormatter = make(time: false)
    private static let dateTimeFmt: DateFormatter = make(time: true)

    private static func make(time: Bool) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fa_IR")
        f.calendar = Calendar(identifier: .persian)
        f.dateStyle = .medium
        f.timeStyle = time ? .short : .none
        return f
    }

    static func date(_ d: Date) -> String { dateOnlyFmt.string(from: d) }
    static func dateTime(_ d: Date) -> String { dateTimeFmt.string(from: d) }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        VStack(spacing: 0) {
            Text(icon).font(.system(size: 44))
            Text(title)
                .font(.vazir(18, bold: true))
                .foregroundColor(.slate900)
                .padding(.top, 12)
            Text(desc)
                .font(.vazir(14))
                .foregroundColor(.slate500)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 6)
        }
        .padding(32)
    }
}

/// دکمهٔ شناور (FloatingActionButton)
struct FabButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.indigo600))
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("افزودن")
        .padding(20)
    }
}

// MARK: - متن‌های من

struct TextsView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store
    @State private var creating = false
    @State private var editing: TextDoc? = nil
    @State private var deleting: TextDoc? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.texts) { doc in row(doc) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            if store.texts.isEmpty {
                EmptyState(icon: "📝", title: "هنوز متنی ذخیره نکرده‌اید",
                           desc: "متن‌های پرکاربردتان را ذخیره کنید تا با یک ضربه پخش شوند.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            FabButton { creating = true }
        }
        .sheet(isPresented: $creating) {
            TextEditSheet(heading: "متن جدید", title: "", content: "") { t, c in
                store.insertText(title: t, content: c)
            }
        }
        .sheet(item: $editing) { doc in
            TextEditSheet(heading: "ویرایش متن", title: doc.title, content: doc.content) { t, c in
                store.updateText(id: doc.id, title: t, content: c)
            }
        }
        .alert("حذف متن", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("انصراف", role: .cancel) { deleting = nil }
            Button("حذف", role: .destructive) {
                if let d = deleting { store.deleteText(id: d.id) }
                deleting = nil
            }
        } message: {
            Text("«" + (deleting?.title ?? "") + "» حذف شود؟")
        }
    }

    private func row(_ doc: TextDoc) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(doc.title)
                    .font(.vazir(16, bold: true))
                    .foregroundColor(.slate900)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { store.toggleFavorite(id: doc.id) } label: {
                    Text(doc.favorite ? "★" : "☆")
                        .font(.system(size: 24))
                        .foregroundColor(doc.favorite ? Color(hex: 0xF59E0B) : .slate400)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            Text(Store.snippet(doc.content, max: 160))
                .font(.vazir(13))
                .foregroundColor(.slate500)
                .lineSpacing(5)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            Text("\(Segmenter.faNum(doc.wordCount)) واژه · \(Fmt.date(doc.updatedAt))")
                .font(.vazir(12))
                .foregroundColor(.slate400)
                .padding(.top, 6)
            HStack(spacing: 0) {
                GButton(title: "▶  پخش در استودیو", kind: .filled(.indigo600), fontSize: 13, fullWidth: true) {
                    model.openStudio(content: doc.content, title: doc.title, textId: doc.id)
                }
                GButton(title: "ویرایش", kind: .text(.indigo600)) { editing = doc }
                GButton(title: "حذف", kind: .text(.rose600)) { deleting = doc }
            }
            .padding(.top, 8)
        }
        .gooyaCard(padding: 14)
    }
}

// MARK: - واژه‌نامهٔ تلفظ

struct DictionaryView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store
    @EnvironmentObject var settings: AppSettings
    @StateObject private var engine = SpeechEngine()
    @State private var sheet: DictSheetData? = nil
    @State private var deleting: DictEntry? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.dictionary) { entry in row(entry) }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            if store.dictionary.isEmpty {
                EmptyState(icon: "🔤", title: "واژه‌نامه خالی است",
                           desc: "واژه‌هایی مثل «عصبانی» یا «گل» را با اعراب درست ثبت کنید تا گوینده هرگز اشتباه نخواند.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            FabButton { sheet = DictSheetData() }
        }
        .onDisappear { engine.stop() }
        .onChange(of: engine.notice) { newValue in
            if let n = newValue { model.toast(n) }
        }
        .sheet(item: $sheet) { data in
            DictEditSheet(data: data) {}
        }
        .alert("حذف واژه", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("انصراف", role: .cancel) { deleting = nil }
            Button("حذف", role: .destructive) {
                if let d = deleting { store.deleteDictionary(id: d.id) }
                deleting = nil
            }
        } message: {
            Text("«" + (deleting?.word ?? "") + "» از واژه‌نامه حذف شود؟")
        }
    }

    private func listen(_ text: String) {
        var s = settings.voice
        s.rate = min(s.rate, 0.9)
        engine.play(Segmenter.segment(text, pauseScale: 1.0), settings: s, startIndex: 0)
    }

    private func row(_ e: DictEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(e.word)
                    .font(.vazir(16))
                    .foregroundColor(.slate700)
                Text("←")
                    .font(.vazir(16))
                    .foregroundColor(.slate400)
                    .padding(.horizontal, 10)
                Text(e.diacritized)
                    .font(.vazir(22, bold: true))
                    .foregroundColor(.emerald600)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !e.note.isEmpty {
                Text(e.note)
                    .font(.vazir(12))
                    .foregroundColor(.slate500)
                    .padding(.top, 4)
            }
            HStack(spacing: 0) {
                GButton(title: "🔊 بشنو", kind: .tonal) { listen(e.diacritized) }
                GButton(title: "ویرایش", kind: .text(.indigo600)) {
                    sheet = DictSheetData(entryId: e.id, word: e.word, diacritized: e.diacritized, note: e.note)
                }
                GButton(title: "حذف", kind: .text(.rose600)) { deleting = e }
                Spacer()
            }
            .padding(.top, 6)
        }
        .gooyaCard(padding: 14)
    }
}

// MARK: - تاریخچه

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var store: Store
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                if !store.history.isEmpty {
                    GButton(title: "پاک‌کردن همه", kind: .text(.rose600)) { confirmClear = true }
                        .padding(.leading, 8)
                        .padding(.top, 4)
                }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.history) { item in row(item) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
            }
            if store.history.isEmpty {
                EmptyState(icon: "🕘", title: "تاریخچه خالی است",
                           desc: "وقتی متنی را تا پایان بشنوید، این‌جا ثبت می‌شود.")
            }
        }
        .alert("پاک‌کردن تاریخچه", isPresented: $confirmClear) {
            Button("انصراف", role: .cancel) {}
            Button("پاک‌کردن همه", role: .destructive) { store.clearHistory() }
        } message: {
            Text("تمام موارد تاریخچه حذف می‌شوند. متن‌های ذخیره‌شده دست‌نخورده می‌مانند.")
        }
    }

    private func row(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(item.title)
                .font(.vazir(16, bold: true))
                .foregroundColor(.slate900)
                .lineLimit(1)
            Text("\(item.voiceLabel) · \(Segmenter.faNum(item.wordCount)) واژه · \(Segmenter.formatDuration(Double(item.durationMs) / 1000.0)) · \(Fmt.dateTime(item.createdAt))")
                .font(.vazir(12))
                .foregroundColor(.slate500)
                .padding(.top, 4)
            HStack(spacing: 0) {
                GButton(title: "▶  پخش دوباره", kind: .tonal) {
                    model.openStudio(content: item.content, title: item.title, textId: nil)
                }
                GButton(title: "حذف", kind: .text(.rose600)) { store.deleteHistory(id: item.id) }
                Spacer()
            }
            .padding(.top, 8)
        }
        .gooyaCard(padding: 14)
    }
}

// MARK: - راهنما

struct HelpView: View {
    @EnvironmentObject var model: AppModel

    private let helpBody = """
    گویا متن فارسی را جمله‌به‌جمله و با مکث‌های طبیعی می‌خواند.

    ☁️ موتور نیورال (آنلاین): دو صدای طبیعی مرد (فرید) و زن (دیلارا) با بالاترین کیفیت. به اینترنت نیاز دارد و ۸ گویندهٔ برنامه با تنظیم لحن، سرعت و مکث روی همین دو صدا ساخته می‌شوند.

    📱 صدای دستگاه (آفلاین): از موتور گفتار خود آیفون استفاده می‌کند. توجه: ممکن است روی آیفون شما صدای فارسی نصب نباشد؛ در این صورت از موتور نیورال (آنلاین) استفاده کنید. صداهای نصب‌شده را می‌توانید در تنظیمات ← دسترسی‌پذیری ← محتوای گفتاری ← صداها ببینید.

    ◌َ اعراب‌گذاری خودکار: دکمهٔ سبز، فتحه/کسره/ضمه را با واژه‌نامهٔ داخلی، صرف فعل‌ها و واژه‌نامهٔ شخصی شما روی واژه‌ها می‌گذارد تا «عَصَبانی» هرگز «عُصبانی» خوانده نشود. واژه‌های ناشناخته را می‌توانید با یک ضربه به واژه‌نامه اضافه کنید.

    💾 ذخیره / اشتراک MP3: کل متن را با صدای انتخابی به فایل MP3 تبدیل می‌کند و امکان اشتراک‌گذاری (مثلاً در تلگرام) می‌دهد.
    """

    private var statusText: String {
        AVSpeechSynthesisVoice(language: "fa-IR") != nil
            ? "✅ موتور گفتار دستگاه از فارسی پشتیبانی می‌کند؛ حالت «صدای دستگاه» بدون اینترنت کار می‌کند."
            : "ℹ️ این آیفون صدای فارسی ندارد. از موتور نیورال (آنلاین) استفاده کنید."
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(helpBody)
                    .font(.vazir(15))
                    .foregroundColor(.slate700)
                    .lineSpacing(10)
                    .gooyaCard()
                    .padding(.bottom, 4)

                GButton(title: "تنظیمات گفتار دستگاه", kind: .filled(.indigo600), fullWidth: true) { openSettings() }
                GButton(title: "نصب دادهٔ صدا", kind: .tonal, fullWidth: true) {
                    model.toast("تنظیمات ← دسترسی‌پذیری ← محتوای گفتاری ← صداها")
                    openSettings()
                }

                Text(statusText)
                    .font(.vazir(13))
                    .foregroundColor(.slate500)
                    .lineSpacing(6)
                    .padding(.top, 12)
            }
            .padding(16)
        }
    }
}
