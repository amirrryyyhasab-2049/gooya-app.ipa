import SwiftUI

/// نوار علامت‌های اعراب (DiacriticBar اندروید): اسکرول افقی که همیشه از لبهٔ راست (فتحه) شروع می‌شود.
struct DiacriticKeyBar: View {
    let onInsert: (String) -> Void

    init(inserter: TextInserter) { onInsert = { inserter.insert($0) } }
    init(onInsert: @escaping (String) -> Void) { self.onInsert = onInsert }

    private static let keys: [(String, String)] = [
        ("\u{064E}", "اَ  فتحه"),
        ("\u{0650}", "اِ  کسره"),
        ("\u{064F}", "اُ  ضمه"),
        ("\u{0651}", "ـّ  تشدید"),
        ("\u{0652}", "ـْ  سکون"),
        ("\u{064B}", "ـاً  تنوین"),
        ("\u{200C}", "نیم‌فاصله")
    ]

    private static let firstID = "diacritic-first"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<Self.keys.count, id: \.self) { i in
                        Button {
                            onInsert(Self.keys[i].0)
                        } label: {
                            Text(Self.keys[i].1)
                                .font(.vazir(13))
                                .foregroundColor(.indigo600)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .overlay(Capsule().stroke(Color(hex: 0x79747E), lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(i == 0 ? Self.firstID : "diacritic-\(i)")
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async { proxy.scrollTo(Self.firstID) }
            }
        }
    }
}
