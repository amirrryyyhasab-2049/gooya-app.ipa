import SwiftUI
import UIKit

/// درج متن (اعراب، نیم‌فاصله) در محل مکان‌نمای یک UITextField (مثل DiacriticBar.insert اندروید)
final class FieldInserter {
    weak var field: UITextField?

    func insert(_ string: String) {
        guard let tf = field else { return }
        tf.becomeFirstResponder()
        tf.insertText(string)
    }
}

/// فیلد تک‌خطی راست‌به‌چپ با گزارش فوکوس (برای برچسب شناور)
struct MaterialUITextField: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var bold: Bool
    var color: UIColor
    var inserter: FieldInserter?
    var onFocusChange: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        let style = NSMutableParagraphStyle()
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        // فیلد تک‌خطی: بدون این، استایل پاراگراف پیش‌فرض (word wrap) متن بلند را می‌شکند و خط دوم
        // چپ‌چین و بیرون از کادر رسم می‌شود (مثل «یادداشت» در عکس). حالا اگر طولانی باشد، انتهایش «…» می‌شود.
        style.lineBreakMode = .byTruncatingTail
        tf.defaultTextAttributes = [.font: UIFont.vazir(fontSize, bold: bold),
                                    .foregroundColor: color,
                                    .paragraphStyle: style]
        tf.textAlignment = .right
        tf.semanticContentAttribute = .forceRightToLeft
        tf.autocorrectionType = .no
        tf.returnKeyType = .done
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        tf.text = text
        inserter?.field = tf
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        context.coordinator.parent = self
        inserter?.field = tf
        if tf.text != text { tf.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 240, height: 56)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaterialUITextField

        init(_ parent: MaterialUITextField) { self.parent = parent }

        @objc func changed(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) { parent.onFocusChange(true) }
        func textFieldDidEndEditing(_ textField: UITextField) { parent.onFocusChange(false) }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// TextInputLayout با سبک OutlinedBox متریال ۳: کادر ۱dp (هنگام فوکوس ۲dp و به رنگ primary)،
/// برچسب داخل کادر که با فوکوس یا وجود متن به لبهٔ بالای کادر می‌رود و کوچک می‌شود.
struct OutlinedTextField: View {
    let label: String
    @Binding var text: String
    var fontSize: CGFloat = 16
    var bold: Bool = false
    var textColor: UIColor = UIColor(hex: 0x1D1B20)
    var inserter: FieldInserter? = nil

    @State private var focused = false

    private var floated: Bool { focused || !text.isEmpty }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(focused ? Color.indigo600 : Color.outline, lineWidth: focused ? 2 : 1)
                .frame(height: 56)

            MaterialUITextField(text: $text, fontSize: fontSize, bold: bold, color: textColor,
                                inserter: inserter, onFocusChange: { focused = $0 })
                .padding(.horizontal, 16)
                .frame(height: 56)

            Text(label)
                .font(.vazir(floated ? 12 : 16))
                .foregroundColor(focused ? .indigo600 : .onSurfaceVariant)
                .padding(.horizontal, floated ? 4 : 0)
                .background(floated ? Color.surfaceHigh : Color.clear)
                .padding(.horizontal, floated ? 12 : 16)
                .offset(y: floated ? -9 : 17)
                .allowsHitTesting(false)
        }
        .frame(height: 56)
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.15), value: floated)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// ادیتور چندخطی دیالوگ‌ها: مثل EditText اندروید با minLines و maxLines؛ تا سقف maxHeight با متن بلند می‌شود،
/// بعد از آن داخل خودش اسکرول می‌کند (عنوان و دکمه‌های دیالوگ از دید بیرون نمی‌روند).
/// از همان GooyaRTLTextView و همان درج امن نویسه‌های پروژه (رفع مشکل نشانگر بعد از اسپیس) استفاده می‌کند.
struct MaterialTextArea: UIViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineMultiple: CGFloat
    var minHeight: CGFloat
    var maxHeight: CGFloat
    var onFocusChange: (Bool) -> Void

    var attributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = fontSize * (lineMultiple - 1)
        style.alignment = .right
        style.baseWritingDirection = .rightToLeft
        let rtl = [NSNumber(value: NSWritingDirection.rightToLeft.rawValue)]
        return [.font: UIFont.vazir(fontSize),
                .foregroundColor: UIColor(hex: 0x0F172A),
                .paragraphStyle: style,
                .writingDirection: rtl]
    }

    func makeUIView(context: Context) -> GooyaRTLTextView {
        let tv = GooyaRTLTextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        tv.textContainer.lineFragmentPadding = 0
        tv.semanticContentAttribute = .forceRightToLeft
        tv.textAlignment = .right
        tv.autocorrectionType = .no
        tv.smartInsertDeleteType = .no
        if #available(iOS 17.0, *) {
            tv.inlinePredictionType = .no
        }
        tv.forcedTypingAttributes = attributes
        tv.typingAttributes = attributes
        tv.attributedText = NSAttributedString(string: text, attributes: attributes)
        tv.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        return tv
    }

    func updateUIView(_ tv: GooyaRTLTextView, context: Context) {
        context.coordinator.parent = self
        tv.forcedTypingAttributes = attributes
        if tv.text != text {
            let oldRange = tv.selectedRange
            let wasEditing = tv.isFirstResponder
            tv.attributedText = NSAttributedString(string: text, attributes: attributes)
            tv.typingAttributes = attributes
            let len = (text as NSString).length
            tv.selectedRange = NSRange(location: wasEditing ? min(oldRange.location, len) : len, length: 0)
        }
        // اگر متن از سقف ارتفاع بلندتر شد، اسکرول داخلی روشن می‌شود
        let width = tv.bounds.width > 0 ? tv.bounds.width : 300
        let fit = tv.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let needsScroll = fit.height > maxHeight
        if tv.isScrollEnabled != needsScroll { tv.isScrollEnabled = needsScroll }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GooyaRTLTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fit = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(maxHeight, max(minHeight, fit.height)))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MaterialTextArea

        init(_ parent: MaterialTextArea) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
        func textViewDidBeginEditing(_ textView: UITextView) { parent.onFocusChange(true) }
        func textViewDidEndEditing(_ textView: UITextView) { parent.onFocusChange(false) }

        /// درج ساده با استیل RTL خودمان (مثل GooyaTextViewRepresentable)؛ حذف و marked text به UIKit سپرده می‌شود.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            guard !text.isEmpty, textView.markedTextRange == nil else { return true }
            textView.textStorage.replaceCharacters(
                in: range, with: NSAttributedString(string: text, attributes: parent.attributes))
            let caret = range.location + (text as NSString).length
            textView.selectedRange = NSRange(location: caret, length: 0)
            textView.typingAttributes = parent.attributes
            textView.scrollRangeToVisible(textView.selectedRange)
            parent.text = textView.text
            return false
        }
    }
}

/// TextInputLayout چندخطی (OutlinedBox): کادر Outlined و برچسب شناور دور MaterialTextArea.
/// مثل dialog_text اندروید: حداقل ۵ خط و حداکثر حدود ۸ خط، بعد اسکرول داخلی.
struct OutlinedTextArea: View {
    let label: String
    @Binding var text: String
    var fontSize: CGFloat = 16
    var lineMultiple: CGFloat = 1.5
    var minHeight: CGFloat = 150
    var maxHeight: CGFloat = 220

    @State private var focused = false

    private var floated: Bool { focused || !text.isEmpty }

    var body: some View {
        MaterialTextArea(text: $text, fontSize: fontSize, lineMultiple: lineMultiple,
                         minHeight: minHeight, maxHeight: maxHeight, onFocusChange: { focused = $0 })
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(focused ? Color.indigo600 : Color.outline, lineWidth: focused ? 2 : 1)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .topLeading) {
                Text(label)
                    .font(.vazir(floated ? 12 : 16))
                    .foregroundColor(focused ? .indigo600 : .onSurfaceVariant)
                    .padding(.horizontal, floated ? 4 : 0)
                    .background(floated ? Color.surfaceHigh : Color.clear)
                    .padding(.horizontal, floated ? 12 : 16)
                    .offset(y: floated ? -9 : 14)
                    .allowsHitTesting(false)
            }
            .padding(.top, 8)
            .animation(.easeOut(duration: 0.15), value: floated)
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}
