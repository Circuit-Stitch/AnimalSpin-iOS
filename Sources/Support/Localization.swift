import Foundation

enum Localization {
    /// The localized string for `key` in a *specific* language, independent of the UI locale.
    /// This keeps the spoken phrase in the same language as the chosen TTS voice — the iOS
    /// analogue of the Android app reading strings through a locale-specific `Context`
    /// (`createConfigurationContext`). Falls back to the main bundle (then the key itself).
    static func phrase(_ key: String, language: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
