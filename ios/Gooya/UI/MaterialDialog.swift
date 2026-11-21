import SwiftUI

// MARK: - دیالوگ معلق وسط صفحه (MaterialAlertDialog اندروید)
// به‌جای .sheet (کشویی از پایین)، دیالوگ روی همان صفحه و وسط آن می‌نشیند؛ پشتش تیره می‌شود،
// لمس بیرونش آن را می‌بندد و با باز شدن کیبورد بالا می‌آید.

private struct DialogDismissKey: EnvironmentKey { static let defaultValue: () -> Void = {} }
private struct DialogMaxHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 600 }

extension EnvironmentValues {
    /// بستن دیالوگ جاری (جایگزین \.dismiss برای دیالوگ‌های معلق)
    var dialogDismiss: () -> Void {
        get { self[DialogDismissKey.self] }
        set { self[DialogDismissKey.self] = newValue }
    }
    /// بیشترین ارتفاعی که کارت دیالوگ می‌تواند بگیرد (بیشتر از آن اسکرول می‌شود)
    var dialogMaxHeight: CGFloat {
        get { self[DialogMaxHeightKey.self] }
        set { self[DialogMaxHeightKey.self] = newValue }
    }
}

private struct DialogHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// محتوای دیالوگ: به اندازهٔ محتوا بلند می‌شود و فقط اگر از صفحه بلندتر شد اسکرول می‌کند.
struct DialogScroll<Content: View>: View {
    @Environment(\.dialogMaxHeight) private var maxHeight
    @State private var height: CGFloat = 0
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ScrollView {
            content.background(
                GeometryReader { g in
                    Color.clear.preference(key: DialogHeightKey.self, value: g.size.height)
                }
            )
        }
        .frame(height: height > 0 ? min(height, maxHeight) : maxHeight)
        .opacity(height > 0 ? 1 : 0)
        .onPreferenceChange(DialogHeightKey.self) { height = $0 }
    }
}

struct MaterialDialogHost<Content: View>: View {
    let onDismiss: () -> Void
    let content: Content

    init(onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                content
                    .frame(maxWidth: 440)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.surfaceHigh))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 6)
                    .padding(.horizontal, 24)
                    .environment(\.dialogMaxHeight, max(200, geo.size.height - 48))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dialogDismiss, onDismiss)
        .transition(.opacity)
    }
}

extension View {
    /// جایگزین .sheet(isPresented:) برای دیالوگ معلق وسط صفحه
    func materialDialog<Content: View>(isPresented: Binding<Bool>,
                                       @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay {
            if isPresented.wrappedValue {
                MaterialDialogHost(onDismiss: { isPresented.wrappedValue = false }) { content() }
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresented.wrappedValue)
    }

    /// جایگزین .sheet(item:) برای دیالوگ معلق وسط صفحه
    func materialDialog<Item: Identifiable, Content: View>(item: Binding<Item?>,
                                                           @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        overlay {
            if let value = item.wrappedValue {
                MaterialDialogHost(onDismiss: { item.wrappedValue = nil }) { content(value) }
                    .id(value.id)
            }
        }
        .animation(.easeOut(duration: 0.18), value: item.wrappedValue?.id as AnyHashable?)
    }
}
