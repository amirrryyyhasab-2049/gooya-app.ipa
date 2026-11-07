import SwiftUI

// MARK: - رنگ‌ها (همان colors.xml اندروید)

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    static let indigo600 = Color(hex: 0x4F46E5)
    static let indigo100 = Color(hex: 0xE0E7FF)
    static let indigo900 = Color(hex: 0x312E81)
    static let violet600 = Color(hex: 0x7C3AED)
    static let emerald600 = Color(hex: 0x059669)
    static let emerald100 = Color(hex: 0xD1FAE5)
    static let amber100 = Color(hex: 0xFEF3C7)
    static let amber800 = Color(hex: 0x92400E)
    static let rose600 = Color(hex: 0xE11D48)
    static let slate50 = Color(hex: 0xF8FAFC)
    static let slate100 = Color(hex: 0xF1F5F9)
    static let slate200 = Color(hex: 0xE2E8F0)
    static let slate400 = Color(hex: 0x94A3B8)
    static let slate500 = Color(hex: 0x64748B)
    static let slate700 = Color(hex: 0x334155)
    static let slate900 = Color(hex: 0x0F172A)
    static let playerBg = Color(hex: 0x1E1B4B)
    static let highlight = Color(hex: 0xC7D2FE)
    static let navSubtitle = Color(hex: 0xB4B8E8)
    static let progressGreen = Color(hex: 0x34D399)
    /// کانتینر ثانویهٔ Material 3 (دکمه‌های Tonal و آیتم انتخاب‌شدهٔ منو)
    static let tonalBg = Color(hex: 0xE8DEF8)
    static let tonalFg = Color(hex: 0x1D192B)
    /// سطح‌های بنفش‌رنگ Material 3 (مقادیر واقعی Material 1.11.0 که اندروید استفاده می‌کند)
    static let surfaceLow = Color(hex: 0xF7F2FA)      // کارت‌ها و منوی کشویی (colorSurfaceContainerLow)
    static let surfaceHigh = Color(hex: 0xECE6F0)     // دیالوگ‌ها (colorSurfaceContainerHigh)
    static let surfaceHighest = Color(hex: 0xE6E0E9)  // ردیف غیرفعال اسلایدر (colorSurfaceContainerHighest)
    static let outline = Color(hex: 0x79747E)         // colorOutline
    static let onSurfaceVariant = Color(hex: 0x49454F)
}

/// گرادیان پس‌زمینهٔ پخش‌کننده و هدر منو (bg_player.xml)
let playerGradient = LinearGradient(
    colors: [Color(hex: 0x0F172A), Color(hex: 0x1E1B4B), Color(hex: 0x312E81)],
    startPoint: .bottomLeading, endPoint: .topTrailing)

// MARK: - فونت وزیرمتن (همان فونت اندروید)

extension Font {
    static func vazir(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Vazirmatn-Bold" : "Vazirmatn-Regular", fixedSize: size)
    }
}

extension UIFont {
    static func vazir(_ size: CGFloat, bold: Bool = false) -> UIFont {
        UIFont(name: bold ? "Vazirmatn-Bold" : "Vazirmatn-Regular", size: size)
            ?? (bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size))
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - کارت (Widget.Gooya.Card: گوشهٔ ۲۰، سایهٔ ۱، حاشیهٔ داخلی ۱۶)

struct GooyaCardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.surfaceLow))
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func gooyaCard(padding: CGFloat = 16) -> some View {
        modifier(GooyaCardModifier(padding: padding))
    }
}

/// عنوان بخش (TextAppearance.Gooya.SectionTitle)
struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.vazir(16, bold: true))
            .foregroundColor(.slate900)
    }
}

// MARK: - آیکون‌های پخش (دقیقاً همان مسیرهای vector اندروید: ic_play / ic_pause / ic_stop روی بوم ۲۴×۲۴)

private func glyphPoint(_ rect: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    let s = min(rect.width, rect.height) / 24
    let ox = rect.minX + (rect.width - 24 * s) / 2
    let oy = rect.minY + (rect.height - 24 * s) / 2
    return CGPoint(x: ox + x * s, y: oy + y * s)
}

/// مثلث پخش اندروید: M7.4,5 v14 l11,-7 z
struct PlayShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: glyphPoint(rect, 7.4, 5))
        p.addLine(to: glyphPoint(rect, 7.4, 19))
        p.addLine(to: glyphPoint(rect, 18.4, 12))
        p.closeSubpath()
        return p
    }
}

/// مکث: دو میلهٔ ۴×۱۴
struct PauseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(CGRect(origin: glyphPoint(rect, 6, 5), size: CGSize(width: 4 * min(rect.width, rect.height) / 24, height: 14 * min(rect.width, rect.height) / 24)))
        p.addRect(CGRect(origin: glyphPoint(rect, 14, 5), size: CGSize(width: 4 * min(rect.width, rect.height) / 24, height: 14 * min(rect.width, rect.height) / 24)))
        return p
    }
}

/// توقف: مربع ۱۲×۱۲
struct StopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let u = min(rect.width, rect.height) / 24
        return Path(roundedRect: CGRect(origin: glyphPoint(rect, 6, 6), size: CGSize(width: 12 * u, height: 12 * u)), cornerRadius: 1.5 * u)
    }
}
