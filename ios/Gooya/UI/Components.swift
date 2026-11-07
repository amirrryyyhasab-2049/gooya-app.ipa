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
                if let icon = icon {
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
                .foregroundColor(.slate700)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fill ?? (selected ? Color.indigo100 : Color.slate100)))
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
        return CGSize(width: width, height: y + lineHeight)
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

struct GooyaTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var fontSize: CGFloat = 18
    var lineMultiple: CGFloat = 1.7
    var minHeight: CGFloat = 200
    var inserter: TextInserter? = nil

    private var attributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = fontSize * (lineMultiple - 1)
        style.alignment = .natural
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
        tv.autocorrectionType = .no
        tv.typingAttributes = attributes
        tv.attributedText = NSAttributedString(string: text, attributes: attributes)

        let label = UILabel()
        label.text = placeholder
        label.font = UIFont.vazir(fontSize)
        label.textColor = UIColor(hex: 0x94A3B8)
        label.numberOfLines = 0
        label.textAlignment = .natural
        label.semanticContentAttribute = .forceRightToLeft
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = !text.isEmpty
        tv.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: tv.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 14),
            label.widthAnchor.constraint(equalTo: tv.widthAnchor, constant: -28)
        ])
        context.coordinator.placeholderLabel = label
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
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(minHeight, fit.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GooyaTextView
        weak var placeholderLabel: UILabel?

        init(_ parent: GooyaTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
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
        style.alignment = .natural
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

// MARK: - اشتراک‌گذاری فایل

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
