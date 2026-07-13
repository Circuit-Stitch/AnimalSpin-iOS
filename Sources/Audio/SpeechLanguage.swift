import AVFoundation

/// Resolves which language the app actually speaks in.
enum SpeechLanguage {
    /// Languages we ship translations for (mirror the localizations in Localizable.xcstrings).
    /// Add a code here when you add a translation, or that locale keeps speaking English.
    static let supported: Set<String> = [
        "en", "es", "fr", "de", "pt", "it", "hi", "id", "ja",
        "ru", "ko", "tr", "vi", "th", "pl", "nl", "ar",
    ]

    /// Prefer the device language, but only when we ship a translation for it (so the spoken
    /// text exists) AND an installed voice can speak it — otherwise fall back to English. The
    /// recorded animal clip plays regardless, so playback never fully fails. Mirrors the
    /// Android `resolveTtsLocale`.
    static func resolved() -> String {
        // Consider only the device's primary language, like Android's `Locale.getDefault()` —
        // if it isn't shipped, or has no installed voice, fall straight back to English rather
        // than reaching for a lower-priority preferred language the user didn't put first.
        guard let tag = Locale.preferredLanguages.first else { return "en" }
        let code = languageCode(fromTag: tag)
        if supported.contains(code), hasVoice(for: code) {
            return code
        }
        return "en"
    }

    /// True when at least one installed voice speaks `code` (e.g. an "en-US" voice for "en").
    static func hasVoice(for code: String) -> Bool {
        AVSpeechSynthesisVoice.speechVoices().contains { matches($0.language, code) }
    }

    /// Whether a BCP-47 voice tag ("en-US") belongs to a bare language code ("en").
    static func matches(_ voiceLanguage: String, _ code: String) -> Bool {
        voiceLanguage == code || voiceLanguage.hasPrefix(code + "-")
    }

    private static func languageCode(fromTag tag: String) -> String {
        Locale(identifier: tag).language.languageCode?.identifier
            ?? String(tag.prefix(2)).lowercased()
    }
}
