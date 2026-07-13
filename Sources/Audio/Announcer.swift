import AVFoundation

/// Speaks an animal's name (when enabled), then plays a recorded clip. This seam keeps
/// `MainViewModel` free of the speech/audio engines so it stays unit-testable (tests supply a
/// fake). Mirrors the Android `Announcer` interface.
protocol Announcer: AnyObject {
    /// Speak the animal's name (when TTS is enabled), then play `sound`'s recorded clip.
    func announce(_ sound: AnimalSound)
    /// Release the speech + audio engines. Call from the owner's teardown. (Named `shutdown`
    /// rather than `release` because `release` collides with NSObject's reserved ObjC selector.)
    func shutdown()
}

/// The real adapter: owns an `AVSpeechSynthesizer` + `AVAudioPlayer`. Settings are re-read from
/// prefs on every `announce`, so changes saved in Settings apply immediately with no lifecycle
/// plumbing (this is the design that fixed the Android app's old "Save does nothing" bug). The
/// spoken language is resolved once at init and the phrase is always read in that language, so
/// the voice and the text never disagree.
final class RealAnnouncer: NSObject, Announcer {
    private let prefs: Preferences
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// The language TTS speaks (device language when shipped + voiced, else English).
    private let language: String

    /// Clip to play when a given utterance finishes, keyed by utterance identity — so a
    /// *flushed* previous utterance (which fires `didCancel`, not `didFinish`) never plays its
    /// clip. Touched only on the main thread (announce + delegate callbacks).
    private var pendingClips: [ObjectIdentifier: AnimalSound] = [:]

    init(prefs: Preferences = Preferences()) {
        self.prefs = prefs
        self.language = SpeechLanguage.resolved()
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ sound: AnimalSound) {
        // Take audio focus now (not at launch), and recover a session the system deactivated
        // after an interruption — so every tap reliably makes sound.
        AudioSession.activate()
        player?.stop()

        // TTS intro disabled by the parent → skip straight to the clip.
        guard prefs.ttsEnabled else {
            playClip(sound)
            return
        }

        // Flush any in-flight speech. This fires `didCancel` for it, dropping its pending clip
        // so only the newest tap's clip ever plays.
        synthesizer.stopSpeaking(at: .immediate)

        let phrase = Localization.phrase(sound.animal.ttsKey, language: language)
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = SpeechTuning.rate(forSpeedMultiplier: prefs.voiceSpeed)
        utterance.pitchMultiplier = SpeechTuning.pitchMultiplier(for: prefs.voicePitch)
        utterance.voice = resolvedVoice()

        pendingClips[ObjectIdentifier(utterance)] = sound
        Log.tts.debug("speak \(phrase, privacy: .public)")
        synthesizer.speak(utterance)
    }

    func shutdown() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        pendingClips.removeAll()
    }

    /// Only honour a saved voice from the language we're speaking — otherwise a leftover voice
    /// for another language would silently switch the engine's language (mirrors Android). When
    /// there's no saved match, use the first installed voice for the spoken language.
    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let id = prefs.selectedVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: id),
           SpeechLanguage.matches(voice.language, language) {
            return voice
        }
        return AVSpeechSynthesisVoice.speechVoices()
            .first { SpeechLanguage.matches($0.language, language) }
    }

    private func playClip(_ sound: AnimalSound) {
        guard let url = Bundle.main.url(forResource: sound.clip, withExtension: "mp3") else {
            Log.audio.error("missing clip \(sound.clip, privacy: .public)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            Log.audio.error("clip playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension RealAnnouncer: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if let sound = pendingClips.removeValue(forKey: ObjectIdentifier(utterance)) {
            playClip(sound)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        pendingClips.removeValue(forKey: ObjectIdentifier(utterance))
    }
}
