//
//  RTLTextEditor.swift
//  Gooya
//
//  ادیتور چندخطی فارسی با جهت پایهٔ RTL.
//  جایگزین TextEditor(text:) برای رفع باگ برعکس بودن نشانگر (caret).
//

import SwiftUI
import UIKit

struct RTLTextEditor: UIViewRepresentable {

    @Binding var text: String

    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label
    var insets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
    var lineSpacing: CGFloat = 4

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.isOpaque = false
        tv.font = font
        tv.textColor = textColor
        tv.textAlignment = .right
        tv.semanticContentAttribute = .forceRightToLeft
        tv.alwaysBounceVertical = true
        tv.keyboardDismissMode = .interactive
        tv.textContainerInset = insets
        tv.textContainer.lineFragmentPadding = 0
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.autocapitalizationType = .none
        tv.adjustsFontForContentSizeCategory = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)

        tv.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle()
        ]
        tv.text = text
        applyParagraphStyle(to: tv)
        context.coordinator.lastText = text
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // فقط وقتی متن از بیرون عوض شده (نمونه متن، اعراب‌گذاری، پاک‌کردن).
        // اگر کاربر در حال تایپ است، دست نزن تا نشانگر نپرد.
        guard context.coordinator.lastText != text else { return }
        context.coordinator.lastText = text

        tv.text = text
        applyParagraphStyle(to: tv)

        // انتهای منطقی متن = سمت چپ در فارسی (جای درست نشانگر)
        let end = (text as NSString).length
        tv.selectedRange = NSRange(location: end, length: 0)
        tv.scrollRangeToVisible(tv.selectedRange)
    }

    func paragraphStyle() -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.baseWritingDirection = .rightToLeft   // ← اصلاح اصلی باگ همین است
        ps.alignment = .right
        ps.lineSpacing = lineSpacing
        return ps
    }

    private func applyParagraphStyle(to tv: UITextView) {
        let full = NSRange(location: 0, length: (tv.text as NSString).length)
        guard full.length > 0 else { return }
        tv.textStorage.addAttributes([.paragraphStyle: paragraphStyle()], range: full)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RTLTextEditor
        var lastText: String = ""
        var needsStyleRefresh = false

        init(_ parent: RTLTextEditor) { self.parent = parent }

        func textView(_ textView: UITextView,
                      shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            // تایپ تک‌کاراکتری و Enter جهت را از typingAttributes ارث می‌برند.
            // فقط Paste یا جایگزینی چندکاراکتری ممکن است استیل بیگانه بیاورد.
            needsStyleRefresh = (text as NSString).length > 1
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            if needsStyleRefresh {
                needsStyleRefresh = false
                let full = NSRange(location: 0, length: (textView.text as NSString).length)
                if full.length > 0 {
                    textView.textStorage.addAttributes(
                        [.paragraphStyle: parent.paragraphStyle()],
                        range: full
                    )
                }
            }
            lastText = textView.text ?? ""
            parent.text = textView.text ?? ""
        }
    }
}
