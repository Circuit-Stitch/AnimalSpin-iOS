import Foundation

/// Thin UserDefaults wrapper for all persisted settings — the iOS analogue of the Android
/// `SharedPreferencesProvider`: one store, defaults registered up front, no constructor args
/// (the default `.standard` store needs no context). Value types + `nonmutating` setters let
/// callers hold a `let prefs` and still write through.
struct Preferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.voicePitch: Self.defaultVoicePitch,
            Keys.voiceSpeed: Self.defaultVoiceSpeed,
            Keys.ttsEnabled: true,
        ])
    }

    var voicePitch: Float {
        get { defaults.float(forKey: Keys.voicePitch) }
        nonmutating set { defaults.set(newValue, forKey: Keys.voicePitch) }
    }

    var voiceSpeed: Float {
        get { defaults.float(forKey: Keys.voiceSpeed) }
        nonmutating set { defaults.set(newValue, forKey: Keys.voiceSpeed) }
    }

    var ttsEnabled: Bool {
        get { defaults.bool(forKey: Keys.ttsEnabled) }
        nonmutating set { defaults.set(newValue, forKey: Keys.ttsEnabled) }
    }

    /// `AVSpeechSynthesisVoice.identifier` of the chosen voice, or nil for the system default.
    var selectedVoiceId: String? {
        get { defaults.string(forKey: Keys.selectedVoiceId) }
        nonmutating set { defaults.set(newValue, forKey: Keys.selectedVoiceId) }
    }

    private enum Keys {
        static let voicePitch = "voice_pitch"
        static let voiceSpeed = "voice_speed"
        static let ttsEnabled = "tts_enabled"
        static let selectedVoiceId = "voice_identifier"
    }

    static let defaultVoicePitch: Float = 1.0   // 1.0 = normal TTS pitch
    static let defaultVoiceSpeed: Float = 1.0   // 1.0 = normal TTS rate
}
