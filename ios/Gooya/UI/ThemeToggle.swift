import SwiftUI
import UIKit

// MARK: - مدیریت تم روشن/تاریک

/// انتخاب کاربر در UserDefaults ذخیره می‌شود. اولین اجرا از حالت فعلی سیستم شروع می‌کند.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published private(set) var isDark: Bool
    private var animating = false
    private let key = "gooya.theme.isDark"

    private init() {
        if let saved = UserDefaults.standard.object(forKey: key) as? Bool {
            isDark = saved
        } else {
            isDark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
    }

    /// تغییر تم؛ با انیمیشن «موج دایره‌ای» از محل دکمه (یا محو شدن ساده اگر Reduce Motion روشن باشد)
    func toggle(from origin: CGPoint) {
        guard !animating else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        let window = Self.keyWindow()
        let snapshot = window?.snapshotView(afterScreenUpdates: false)

        isDark.toggle()
        UserDefaults.standard.set(isDark, forKey: key)

        guard let window = window, let snapshot = snapshot else { return }
        animating = true
        snapshot.frame = window.bounds
        window.addSubview(snapshot)

        let finish = { [weak self] in
            snapshot.removeFromSuperview()
            self?.animating = false
        }

        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseInOut,
                           animations: { snapshot.alpha = 0 },
                           completion: { _ in finish() })
            return
        }

        // نمای قدیمی روی صفحه می‌ماند و یک «سوراخ» دایره‌ای از دکمه باز می‌شود که تم تازه را نشان می‌دهد
        let bounds = window.bounds
        let maxRadius = hypot(max(origin.x, bounds.width - origin.x), max(origin.y, bounds.height - origin.y)) + 8
        func path(radius: CGFloat) -> CGPath {
            let p = UIBezierPath(rect: bounds)
            p.append(UIBezierPath(arcCenter: origin, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true))
            return p.cgPath
        }
        let mask = CAShapeLayer()
        mask.fillRule = .evenOdd
        mask.path = path(radius: maxRadius)
        snapshot.layer.mask = mask

        CATransaction.begin()
        CATransaction.setCompletionBlock(finish)
        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = path(radius: 0.5)
        anim.toValue = path(radius: maxRadius)
        anim.duration = 0.55
        anim.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.0, 1.0)
        mask.add(anim, forKey: "reveal")
        CATransaction.commit()
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - آیکون خورشید و ماه (تبدیل نرم با چرخش، مقیاس و محو شدن)

struct SunMoonIcon: View {
    let isDark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sunColor = Color(fixedHex: 0xFCD34D)
    private let moonColor = Color(fixedHex: 0xE0E7FF)

    var body: some View {
        ZStack {
            sun
                .opacity(isDark ? 0 : 1)
                .rotationEffect(.degrees(reduceMotion ? 0 : (isDark ? 90 : 0)))
                .scaleEffect(reduceMotion ? 1 : (isDark ? 0.4 : 1))
            moon
                .opacity(isDark ? 1 : 0)
                .rotationEffect(.degrees(reduceMotion ? 0 : (isDark ? 0 : -90)))
                .scaleEffect(reduceMotion ? 1 : (isDark ? 1 : 0.4))
        }
        .frame(width: 26, height: 26)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.5, dampingFraction: 0.72),
                   value: isDark)
    }

    /// خورشید: هستهٔ گرد و هشت پرتوی ظریف
    private var sun: some View {
        ZStack {
            Circle().fill(sunColor).frame(width: 10, height: 10)
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(sunColor)
                    .frame(width: 2, height: 4)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
    }

    /// ماه: هلال با دو ستارهٔ کوچک
    private var moon: some View {
        ZStack {
            Circle()
                .fill(moonColor)
                .frame(width: 18, height: 18)
                .mask(
                    ZStack {
                        Rectangle().fill(Color.black)
                        Circle().fill(Color.black)
                            .frame(width: 15, height: 15)
                            .offset(x: 6, y: -5)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .offset(x: -1, y: 1)
            Circle().fill(moonColor).frame(width: 3, height: 3).offset(x: 7, y: -6)
            Circle().fill(moonColor.opacity(0.75)).frame(width: 2, height: 2).offset(x: 10, y: -1)
        }
    }
}

// MARK: - دکمهٔ تغییر تم (گوشهٔ بالا-چپ نوار بالا)

struct ThemeToggleButton: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        GeometryReader { geo in
            Button {
                let f = geo.frame(in: .global)
                theme.toggle(from: CGPoint(x: f.midX, y: f.midY))
            } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.12))
                    SunMoonIcon(isDark: theme.isDark)
                }
                .frame(width: 40, height: 40)
                .contentShape(Circle())
            }
            .buttonStyle(PressStateStyle(shape: Circle(), layer: .white, pressedOpacity: 0.16))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel(theme.isDark ? "تغییر به حالت روشن" : "تغییر به حالت تاریک")
    }
}
