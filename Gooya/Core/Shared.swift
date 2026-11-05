import Foundation

/// نمونهٔ مشترک اعراب‌گذار (واژه‌نامه فقط یک بار از بسته خوانده می‌شود)
enum Shared {
    static let diacritizer = Diacritizer(lexicon: Lexicon.loadBundled(), verbs: Lexicon.verbs)
}
