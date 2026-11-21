import SwiftUI

/// دیالوگ «نمونه متن» مثل MaterialAlertDialog با setItems در اندروید:
/// عنوان و ردیف‌ها راست‌چین، پس‌زمینهٔ surfaceHigh، گوشهٔ گرد، بدون دکمهٔ Cancel انگلیسی؛
/// لمس بیرون دیالوگ آن را می‌بندد.
struct SampleDialog: View {
    let title: String
    let items: [String]
    let onPick: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.vazir(22, bold: true))
                    .foregroundColor(.slate900)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                ForEach(0..<items.count, id: \.self) { i in
                    Button { onPick(i) } label: {
                        Text(items[i])
                            .font(.vazir(16))
                            .foregroundColor(.slate900)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .padding(.horizontal, 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SampleRowStyle())
                }
                Spacer().frame(height: 12)
            }
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.surfaceHigh))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 40)
            .frame(maxWidth: 440)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .transition(.opacity)
    }
}

/// حالت فشردن ردیف (مثل ریپل)
private struct SampleRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.08) : Color.clear)
    }
}
