import SwiftUI

// MARK: - بازخورد لمس مثل ریپل Material (state layer ۱۲٪)

/// هنگام فشردن، یک لایهٔ نیمه‌شفاف هم‌رنگ محتوا روی شکل دکمه می‌آید و نرم محو می‌شود
/// (در اندروید هر MaterialButton، FAB و آیتم لیست چنین ریپلی دارد؛ ButtonStyle.plain هیچ بازخوردی نمی‌دهد).
struct PressStateStyle<S: Shape>: ButtonStyle {
    let shape: S
    var layer: Color = .black
    var pressedOpacity: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .overlay(shape.fill(layer.opacity(configuration.isPressed ? pressedOpacity : 0)).allowsHitTesting(false))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// مثل GButton (دکمه‌های سبک Material 3) ولی با بازخورد لمس
struct MButton: View {
    let title: String
    var icon: String? = nil
    var playGlyph: Bool = false
    var kind: GButtonKind = .tonal
    var fontSize: CGFloat = 14
    var enabled: Bool = true
    var fullWidth: Bool = false
    let action: () -> Void

    private var foreground: Color {
        switch kind {
        case .filled: return .white
        case .tonal: return .tonalFg
        case .text(let c): return c
        case .outlined(let f, _): return f
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if playGlyph {
                    PlayShape().fill(foreground).frame(width: fontSize + 8, height: fontSize + 8)
                } else if let icon = icon {
                    Image(systemName: icon).font(.system(size: fontSize + 2, weight: .semibold))
                }
                Text(title).font(.vazir(fontSize, bold: true)).lineLimit(1)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(buttonBackground)
            .overlay(buttonBorder)
        }
        .buttonStyle(PressStateStyle(shape: Capsule(), layer: foreground))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    @ViewBuilder private var buttonBackground: some View {
        switch kind {
        case .filled(let c): Capsule().fill(c)
        case .tonal: Capsule().fill(Color.tonalBg)
        default: Color.clear
        }
    }

    @ViewBuilder private var buttonBorder: some View {
        if case .outlined(_, let b) = kind {
            Capsule().stroke(b, lineWidth: 1)
        }
    }
}

// MARK: - دیالوگ تأیید (MaterialAlertDialog با پیام)؛ جایگزین .alert سیستمی

struct ConfirmDialog: View {
    @Environment(\.dialogDismiss) private var dismiss
    let title: String
    let message: String
    var confirmTitle: String = "حذف"
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.vazir(20, bold: true)).foregroundColor(.slate900)
            Text(message)
                .font(.vazir(15))
                .foregroundColor(.onSurfaceVariant)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                MButton(title: confirmTitle, kind: .filled(.rose600)) { onConfirm(); dismiss() }
                MButton(title: "انصراف", kind: .text(.indigo600)) { dismiss() }
                Spacer()
            }
        }
        .padding(24)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
