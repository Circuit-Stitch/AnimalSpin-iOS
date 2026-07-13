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
// `@unchecked Sendable`: the iOS SDK marks `AVSpeechSynthesizerDelegate` as `Sendable`, so adopting
// it (below) makes the compiler treat this class as `Sendable` and flag its non-Sendable
// `synthesizer` (and any future non-Sendable member). We opt out of the auto-check because we uphold
// the invariant by hand: the engines and the pending pair are only ever touched on the main thread —
// `announce`/`shutdown` are called from the main-thread `MainViewModel`, and the delegate callbacks
// hop to main before reading any state (see the `AVSpeechSynthesizerDelegate` extension).
final class RealAnnouncer: NSObject, Announcer, @unchecked Sendable {
    private let prefs: Preferences
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// The language TTS speaks (device language when shipped + voiced, else English).
    private let language: String

    /// The one utterance whose completion is allowed to trigger a clip, plus that clip. A new tap
    /// replaces this pair, so a *superseded* utterance can never play its clip over the new intro.
    /// We can't trust `stopSpeaking` to reliably deliver `didCancel` (AVFoundation sometimes fires
    /// `didFinish` for a flushed utterance, or delivers it late), so the guard is identity on this
    /// pair — not the delegate callback kind. Touched only on the main thread (announce, shutdown,
    /// and the main-dispatched delegate callbacks).
    private var pendingUtterance: AVSpeechUtterance?
    private var pendingClip: AnimalSound?

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

        // Silence whatever the previous tap started — the recorded clip *and* any in-flight
        // speech — so a rapid re-tap restarts the intro cleanly instead of layering sounds.
        // Dropping the pending pair here means a superseded utterance's late `didFinish` finds no
        // match and never plays its clip (the barking-over-the-voice bug).
        player?.stop()
        // Flush unconditionally: `stopSpeaking` on an idle synthesizer is a documented no-op, and
        // flushing every tap guarantees a rapid re-tap cuts off and *restarts* the intro rather
        // than queueing a second one behind the first.
        synthesizer.stopSpeaking(at: .immediate)
        pendingUtterance = nil
        pendingClip = nil

        // TTS intro disabled by the parent → skip straight to the clip.
        guard prefs.ttsEnabled else {
            playClip(sound)
            return
        }

        let phrase = Localization.phrase(sound.animal.ttsKey, language: language)
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.rate = SpeechTuning.rate(forSpeedMultiplier: prefs.voiceSpeed)
        utterance.pitchMultiplier = SpeechTuning.pitchMultiplier(for: prefs.voicePitch)
        utterance.voice = resolvedVoice()

        pendingUtterance = utterance
        pendingClip = sound
        Log.tts.debug("speak \(phrase, privacy: .public)")
        synthesizer.speak(utterance)
    }

    func shutdown() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        player = nil
        pendingUtterance = nil
        pendingClip = nil
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
        // These callbacks aren't guaranteed on the main thread; hop there so reading/mutating the
        // pending pair never races with `announce`. Only the *current* utterance plays its clip —
        // a superseded one (a rapid re-tap already moved the pending pair on) is dropped.
        DispatchQueue.main.async { [weak self] in
            guard let self, utterance === self.pendingUtterance, let sound = self.pendingClip else { return }
            self.pendingUtterance = nil
            self.pendingClip = nil
            self.playClip(sound)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, utterance === self.pendingUtterance else { return }
            self.pendingUtterance = nil
            self.pendingClip = nil
        }
    }
}
