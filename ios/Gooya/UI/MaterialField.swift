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

/// TextInputLayout چندخطی (OutlinedBox) برای «متن» در دیالوگ متن‌ها: همان GooyaTextView
/// (ادیتور RTL پروژه) با کادر Outlined و برچسب شناور. فوکوس از اعلان‌های UITextView گرفته می‌شود
/// (در این دیالوگ فقط یک ادیتور چندخطی وجود دارد).
struct OutlinedTextArea: View {
    let label: String
    @Binding var text: String
    var fontSize: CGFloat = 16
    var lineMultiple: CGFloat = 1.5
    var minHeight: CGFloat = 150

    @State private var focused = false

    private var floated: Bool { focused || !text.isEmpty }

    var body: some View {
        GooyaTextView(text: $text, placeholder: "", fontSize: fontSize,
                      lineMultiple: lineMultiple, minHeight: minHeight)
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
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidBeginEditingNotification)) { _ in
                focused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidEndEditingNotification)) { _ in
                focused = false
            }
    }
}
