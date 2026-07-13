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

    /// The section header for the legacy Mac synthesizer voices. English-only novelties, so a
    /// hardcoded label is fine (and it names Apple's own retro Mac feature); kept out of the
    /// generated `Localizable.xcstrings` on purpose.
    static let retroSectionName = "Retro Mac"

    /// Installed offline voices for the spoken language, grouped-ready. Country voices come first
    /// (grouped by displayed country name), then the "Retro Mac" novelties as their own trailing
    /// section; within each group, sorted by name — so the visible order is deterministic.
    private static func loadVoices(language: String) -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { SpeechLanguage.matches($0.language, language) }
            .map { voice in
                let retro = isRetroMacVoice(voice)
                return VoiceOption(
                    id: voice.identifier,
                    region: retro ? retroSectionName : regionName(for: voice.language),
                    quality: qualityLabel(voice.quality),
                    name: voice.name,
                    isRetro: retro
                )
            }
            .sorted { a, b in
                if a.isRetro != b.isRetro { return !a.isRetro }   // country groups first, Retro Mac last
                return (a.region, a.name) < (b.region, b.name)
            }
    }

    /// The classic System-7-era Mac speech voices (Albert, Zarvox, Bad News, Bahh, Trinoids, …) all
    /// live under the legacy `com.apple.speech.synthesis.voice.` identifier namespace, unlike the
    /// modern regional voices (`com.apple.voice.…`). They're English-only fun extras, so we surface
    /// them in a dedicated section instead of burying them under "United States".
    private static func isRetroMacVoice(_ voice: AVSpeechSynthesisVoice) -> Bool {
        voice.identifier.hasPrefix("com.apple.speech.synthesis.voice.")
    }

    /// The localized *country* name for a voice's BCP-47 tag (e.g. "en-AU" → "Australia"), used as
    /// the group header. Every voice in this list speaks the same resolved language, so leading with
    /// the language ("English (Australia)", "English (India)", …) just repeats a word down the whole
    /// screen — the country alone is the useful, non-redundant grouping. Falls back to the full
    /// language display name when a tag carries no region.
    private static func regionName(for languageTag: String) -> String {
        if let code = Locale(identifier: languageTag).region?.identifier,
           let country = Locale.current.localizedString(forRegionCode: code) {
            return country
        }
        return Locale.current.localizedString(forIdentifier: languageTag) ?? languageTag
    }

    private static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Standard"
        }
    }

    /// id = the persisted voice identifier, region = group header (country, or "Retro Mac"),
    /// name = friendly leaf label, isRetro = a legacy Mac synthesizer voice (sorts into its own
    /// trailing section).
    struct VoiceOption: Identifiable, Hashable {
        let id: String
        let region: String
        let quality: String
        let name: String
        let isRetro: Bool

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
