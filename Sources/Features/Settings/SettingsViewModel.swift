import AVFoundation
import Observation

/// Backs the Settings screen. Reads current prefs, exposes the installed voices for the spoken
/// language (grouped for display), and persists on Save. Mirrors the Android `SettingsViewModel`
/// (voice options come straight from `AVSpeechSynthesisVoice` here rather than round-tripping
/// through prefs).
@Observable
@MainActor
final class SettingsViewModel {
    var ttsEnabled: Bool
    var selectedVoiceId: String?
    var voicePitch: Float
    var voiceSpeed: Float

    let voiceOptions: [VoiceOption]

    private let prefs: Preferences

    init(prefs: Preferences = Preferences()) {
        self.prefs = prefs
        self.ttsEnabled = prefs.ttsEnabled
        // Loaded prefs are coerced into range — an out-of-range value crashes a SwiftUI Slider.
        self.voicePitch = prefs.voicePitch.clampedToVoiceRange()
        self.voiceSpeed = prefs.voiceSpeed.clampedToVoiceRange()

        let options = Self.loadVoices(language: SpeechLanguage.resolved())
        self.voiceOptions = options
        // Only adopt the persisted id if it's actually one of the current options — otherwise a
        // stale id (device language changed since Save, or the voice was uninstalled) would leave
        // the Picker with no matching selection *and* get re-saved on Save, even though playback
        // ignores it. Fall back to the first available voice, matching `RealAnnouncer`.
        if let saved = prefs.selectedVoiceId, options.contains(where: { $0.id == saved }) {
            self.selectedVoiceId = saved
        } else {
            self.selectedVoiceId = options.first?.id
        }
    }

    func save() {
        Log.tts.debug("saving options")
        prefs.voicePitch = voicePitch
        prefs.voiceSpeed = voiceSpeed
        prefs.ttsEnabled = ttsEnabled
        if let id = selectedVoiceId { prefs.selectedVoiceId = id }
    }

    /// Sets the sliders + resets to the default voice; the user still hits Save to persist.
    func applyPreset(_ preset: VoicePreset) {
        voicePitch = preset.pitch
        voiceSpeed = preset.speed
        selectedVoiceId = voiceOptions.first?.id
    }

    /// Installed offline voices for the spoken language, grouped-ready. Sorted by the *displayed*
    /// region name (not the raw BCP-47 code) so the visible group order is deterministic and
    /// matches Android, whose sort key is the same localized display string it groups on.
    private static func loadVoices(language: String) -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { SpeechLanguage.matches($0.language, language) }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    region: Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language,
                    quality: qualityLabel(voice.quality),
                    name: voice.name
                )
            }
            .sorted { ($0.region, $0.name) < ($1.region, $1.name) }
    }

    private static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }

    /// id = the persisted voice identifier, region = group header, name = friendly leaf label.
    struct VoiceOption: Identifiable, Hashable {
        let id: String
        let region: String
        let quality: String
        let name: String

        /// Quality tag only when it's worth flagging — most default voices are "Standard". Uses a
        /// comma (not a "·" glyph) so VoiceOver reads "Samantha, Enhanced" as a natural pause
        /// rather than announcing "middle dot".
        var label: String { quality == "Standard" ? name : "\(name), \(quality)" }
    }

    struct VoicePreset: Identifiable {
        let labelKey: String   // localization key, e.g. "preset_normal"
        let pitch: Float
        let speed: Float
        var id: String { labelKey }
    }

    // pitch/speed only (no fragile per-device voice), kept inside the voice range.
    static let presets = [
        VoicePreset(labelKey: "preset_normal", pitch: 1.0, speed: 1.0),
        VoicePreset(labelKey: "preset_robot", pitch: 0.7, speed: 0.9),
        VoicePreset(labelKey: "preset_chipmunk", pitch: 1.8, speed: 1.3),
    ]
}
