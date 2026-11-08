import SwiftUI
import UIKit

// MARK: - دکمه‌های سبک Material 3

enum GButtonKind {
    case filled(Color)
    case tonal
    case text(Color)
    case outlined(foreground: Color, border: Color)
}

struct GButton: View {
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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

/// چیپ (Chip در Material)
struct ChipView: View {
    let label: String
    var selected: Bool = false
    var fill: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.vazir(14))
                .foregroundColor(selected ? .tonalFg : .onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill ?? (selected ? Color.tonalBg : Color.white)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? Color.clear : Color.outline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - چینش جریانی (ChipGroup)؛ از راست شروع می‌شود

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4
    var rightToLeft: Bool = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var width: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            width = max(width, x - spacing)
        }
        let finalWidth = proposal.width.map { $0.isFinite ? $0 : width } ?? width
        return CGSize(width: finalWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > bounds.width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            let px = rightToLeft ? bounds.maxX - x - size.width : bounds.minX + x
            s.place(at: CGPoint(x: px, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - اسلایدر سفارشی (مثل Slider متریال: ردیف فعال/غیرفعال، دستگیره و هالهٔ لمس)

struct GSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 0
    var active: Color
    var inactive: Color
    var thumb: Color
    var trackHeight: CGFloat = 4
    var thumbRadius: CGFloat = 10
    var haloRadius: CGFloat = 20
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var dragging = false
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        GeometryReader { geo in
            let rtl = layoutDirection == .rightToLeft
            let trackW = max(1, geo.size.width - thumbRadius * 2)
            let span = range.upperBound - range.lowerBound
            let frac = span > 0 ? min(1, max(0, (value - range.lowerBound) / span)) : 0
            let activeW = CGFloat(frac) * trackW
            let thumbX = rtl ? geo.size.width - thumbRadius - activeW : thumbRadius + activeW
            let activeX = rtl ? geo.size.width - thumbRadius - activeW / 2 : thumbRadius + activeW / 2
            let cy = geo.size.height / 2

            ZStack {
                Capsule().fill(inactive)
                    .frame(width: trackW, height: trackHeight)
                    .position(x: geo.size.width / 2, y: cy)
                Capsule().fill(active)
                    .frame(width: max(0.5, activeW), height: trackHeight)
                    .position(x: activeX, y: cy)
                if dragging {
                    Circle().fill(thumb.opacity(0.2))
                        .frame(width: haloRadius * 2, height: haloRadius * 2)
                        .position(x: thumbX, y: cy)
                }
                Circle().fill(thumb)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .position(x: thumbX, y: cy)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !dragging {
                            dragging = true
                            onEditingChanged(true)
                        }
                        update(x: g.location.x, width: geo.size.width, rtl: rtl)
                    }
                    .onEnded { g in
                        update(x: g.location.x, width: geo.size.width, rtl: rtl)
                        dragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(height: max(32, haloRadius * 2))
    }

    private func update(x: CGFloat, width: CGFloat, rtl: Bool) {
        let trackW = max(1, width - thumbRadius * 2)
        var f = Double((x - thumbRadius) / trackW)
        f = min(1, max(0, f))
        if rtl { f = 1 - f }
        let span = range.upperBound - range.lowerBound
        var v = range.lowerBound + f * span
        if step > 0 {
            v = range.lowerBound + ((v - range.lowerBound) / step).rounded() * step
        }
        v = (min(range.upperBound, max(range.lowerBound, v)) * 10_000).rounded() / 10_000
        if v != value { value = v }
    }
}

// MARK: - ویرایشگر متن چندخطی (UITextView) با درج در محل مکان‌نما و متن راهنما

final class TextInserter {
    weak var textView: UITextView?

    func insert(_ string: String) {
        guard let tv = textView else { return }
        tv.becomeFirstResponder()
        tv.insertText(string)
    }
}

/// کادر ورودی چندخطی؛ متن راهنما با SwiftUI رسم می‌شود تا همیشه دیده شود
struct GooyaTextView: View {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat = 18
    var lineMultiple: CGFloat = 1.7
    var minHeight: CGFloat = 200
    var inserter: TextInserter? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            GooyaTextViewRepresentable(text: $text, fontSize: fontSize, lineMultiple: lineMultiple,
                                       minHeight: minHeight, inserter: inserter)
            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .font(.vazir(fontSize))
                    .foregroundColor(.slate400)
                    .lineSpacing(fontSize * (lineMultiple - 1))
                    .multilineTextAlignment(.leading)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct GooyaTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineMultiple: CGFloat
    var minHeight: CGFloat
    var inserter: TextInserter?

    private var attributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = fontSize * (lineMultiple - 1)
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        return [.font: UIFont.vazir(fontSize),
                .foregroundColor: UIColor(hex: 0x0F172A),
                .paragraphStyle: style]
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tv.textContainer.lineFragmentPadding = 0
        tv.semanticContentAttribute = .forceRightToLeft
        tv.textAlignment = .right
        tv.autocorrectionType = .no
        tv.typingAttributes = attributes
        tv.attributedText = NSAttributedString(string: text, attributes: attributes)
        inserter?.textView = tv
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        inserter?.textView = tv
        if tv.text != text {
            tv.attributedText = NSAttributedString(string: text, attributes: attributes)
            tv.typingAttributes = attributes
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(minHeight, fit.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GooyaTextViewRepresentable

        init(_ parent: GooyaTextViewRepresentable) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// MARK: - نمای خواندن: متن پیوسته با هایلایت قطعهٔ فعال و لمس هر قطعه (مثل ClickableSpan اندروید)

extension NSAttributedString.Key {
    static let gooyaSegment = NSAttributedString.Key("gooya.segment")
}

struct ReaderTextView: UIViewRepresentable {
    var segments: [Segment]
    var currentIndex: Int
    var active: Bool
    var onTap: (Int) -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.semanticContentAttribute = .forceRightToLeft
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tv.addGestureRecognizer(tap)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        tv.attributedText = build()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fit.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func build() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 17 * 0.9
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        for seg in segments {
            let isActive = active && seg.index == currentIndex
            let isDone = active && seg.index < currentIndex
            var attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.vazir(17, bold: isActive),
                .foregroundColor: isDone ? UIColor(hex: 0x94A3B8) : UIColor(hex: 0x334155),
                .paragraphStyle: style,
                .gooyaSegment: seg.index
            ]
            if isActive { attrs[.backgroundColor] = UIColor(hex: 0xC7D2FE) }
            result.append(NSAttributedString(string: seg.text, attributes: attrs))
            let sep: String
            switch seg.kind {
            case .paragraph: sep = "\n\n"
            case .line: sep = "\n"
            default: sep = " "
            }
            result.append(NSAttributedString(string: sep, attributes: [.font: UIFont.vazir(17), .paragraphStyle: style]))
        }
        return result
    }

    final class Coordinator: NSObject {
        var parent: ReaderTextView

        init(_ parent: ReaderTextView) { self.parent = parent }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let tv = gesture.view as? UITextView else { return }
            var point = gesture.location(in: tv)
            point.x -= tv.textContainerInset.left
            point.y -= tv.textContainerInset.top
            let index = tv.layoutManager.characterIndex(for: point, in: tv.textContainer,
                                                        fractionOfDistanceBetweenInsertionPoints: nil)
            guard index < tv.textStorage.length else { return }
            if let seg = tv.textStorage.attribute(.gooyaSegment, at: index, effectiveRange: nil) as? Int {
                parent.onTap(seg)
            }
        }
    }
}

// MARK: - اشتراک‌گذاری فایل (منوی استاندارد iOS؛ از بالاترین ViewController نمایش داده می‌شود)

enum ShareHelper {
    @MainActor
    static func present(_ url: URL) -> Bool {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var top = window.rootViewController else { return false }
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 1, height: 1)
        top.present(vc, animated: true)
        return true
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - نوار علامت‌های اعراب (DiacriticBar اندروید)

struct DiacriticBar: View {
    let inserter: TextInserter

    private static let keys: [(String, String)] = [
        ("\u{064E}", "اَ  فتحه"),
        ("\u{0650}", "اِ  کسره"),
        ("\u{064F}", "اُ  ضمه"),
        ("\u{0651}", "ـّ  تشدید"),
        ("\u{0652}", "ـْ  سکون"),
        ("\u{064B}", "ـاً  تنوین"),
        ("\u{200C}", "نیم‌فاصله")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<Self.keys.count, id: \.self) { i in
                    Button {
                        inserter.insert(Self.keys[i].0)
                    } label: {
                        Text(Self.keys[i].1)
                            .font(.vazir(13))
                            .foregroundColor(.indigo600)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .overlay(Capsule().stroke(Color(hex: 0x79747E), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


// MARK: - فیلد تک‌خطی راست‌به‌چپ (UITextField)

struct GooyaTextField: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 16

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        tf.defaultTextAttributes = [.font: UIFont.vazir(fontSize),
                                    .foregroundColor: UIColor(hex: 0x0F172A),
                                    .paragraphStyle: style]
        tf.textAlignment = .right
        tf.semanticContentAttribute = .forceRightToLeft
        tf.autocorrectionType = .no
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        tf.text = text
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        if tf.text != text { tf.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 240, height: 48)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: GooyaTextField

        init(_ parent: GooyaTextField) { self.parent = parent }

        @objc func changed(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
