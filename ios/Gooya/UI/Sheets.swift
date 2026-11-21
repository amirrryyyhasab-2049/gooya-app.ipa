import SwiftUI

/// قالب مشترک دیالوگ‌ها (MaterialAlertDialog): عنوان، فیلدها، دکمه‌های انصراف و ذخیره
private struct DialogFrame<Content: View>: View {
    let title: String
    let saveTitle: String
    let error: String?
    let onSave: () -> Void
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(title: String, saveTitle: String = "ذخیره", error: String?, onSave: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.saveTitle = saveTitle
        self.error = error
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // عنوان و دکمه‌ها مثل MaterialAlertDialog: عنوان ۲۴ ساده، دکمه‌های متنی (Text Button) به رنگ primary
                Text(title).font(.vazir(24)).foregroundColor(.slate900)
                content
                if let error = error {
                    Text(error).font(.vazir(13)).foregroundColor(.rose600)
                }
                HStack(spacing: 4) {
                    Spacer()
                    GButton(title: "انصراف", kind: .text(.indigo600)) { dismiss() }
                    GButton(title: saveTitle, kind: .text(.indigo600)) { onSave() }
                }
            }
            .padding(24)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .background(Color.surfaceHigh.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

/// فیلد با برچسب (TextInputLayout)
struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.vazir(12)).foregroundColor(.slate500)
            content
                .padding(.horizontal, 12)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color.outline, lineWidth: 1))
        }
    }
}

/// دیالوگ متن جدید / ویرایش متن / ذخیرهٔ متن (dialog_text)
struct TextEditSheet: View {
    let heading: String
    let onSave: (String, String) -> Void
    @State private var title: String
    @State private var content: String
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(heading: String, title: String, content: String, onSave: @escaping (String, String) -> Void) {
        self.heading = heading
        self.onSave = onSave
        _title = State(initialValue: title)
        _content = State(initialValue: content)
    }

    var body: some View {
        DialogFrame(title: heading, error: error, onSave: save) {
            // مثل dialog_text اندروید: دو فیلد Outlined با برچسب شناور
            OutlinedTextField(label: "عنوان (اختیاری)", text: $title)
            OutlinedTextArea(label: "متن", text: $content)
        }
    }

    private func save() {
        if content.trimmed.isEmpty {
            error = "متن نمی‌تواند خالی باشد."
            return
        }
        onSave(title, content)
        dismiss()
    }
}

/// داده‌ٔ بازکردن دیالوگ واژه‌نامه
struct DictSheetData: Identifiable {
    let id = UUID()
    var entryId: Int? = nil
    var word: String = ""
    var diacritized: String = ""
    var note: String = ""
}

/// دیالوگ افزودن/ویرایش تلفظ واژه (dialog_dict) با نوار علامت‌های اعراب
struct DictEditSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let entryId: Int?
    let onSaved: () -> Void
    @State private var word: String
    @State private var diacritized: String
    @State private var note: String
    @State private var error: String?
    @State private var diaInserter = FieldInserter()

    init(data: DictSheetData, onSaved: @escaping () -> Void) {
        entryId = data.entryId
        self.onSaved = onSaved
        _word = State(initialValue: data.word)
        _diacritized = State(initialValue: data.diacritized.isEmpty ? data.word : data.diacritized)
        _note = State(initialValue: data.note)
    }

    var body: some View {
        DialogFrame(title: entryId == nil ? "افزودن تلفظ به واژه‌نامه" : "ویرایش تلفظ", error: error, onSave: save) {
            // مثل dialog_dict اندروید: فیلدهای Outlined با برچسب شناور؛ «تلفظ درست» سبز، بولد و ۲۲
            OutlinedTextField(label: "واژه (بدون اعراب)", text: $word)
            OutlinedTextField(label: "تلفظ درست (با اعراب)", text: $diacritized,
                              fontSize: 22, bold: true, textColor: UIColor(hex: 0x059669), inserter: diaInserter)
            DiacriticKeyBar(onInsert: { diaInserter.insert($0) })
            OutlinedTextField(label: "یادداشت (اختیاری)", text: $note)
        }
    }

    private func save() {
        let wd = Diacritizer.strip(word.trimmed)
        let dia = diacritized.trimmed
        let nt = note.trimmed
        if wd.isEmpty || dia.isEmpty {
            error = "واژه و تلفظ آن الزامی هستند."
            return
        }
        let zwnj = "\u{200C}"
        if Diacritizer.strip(dia).replacingOccurrences(of: zwnj, with: "") != wd.replacingOccurrences(of: zwnj, with: "") {
            error = "شکل اعراب‌گذاری‌شده باید همان واژه (فقط با علامت‌های اضافه) باشد."
            return
        }
        if let id = entryId {
            store.updateDictionary(id: id, word: wd, diacritized: dia, note: nt)
        } else {
            store.upsertDictionary(word: wd, diacritized: dia, note: nt)
        }
        onSaved()
        dismiss()
    }
}
