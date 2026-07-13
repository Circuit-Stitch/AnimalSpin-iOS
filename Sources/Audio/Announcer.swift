import AVFoundation

/// Speaks an animal's name (when enabled), then plays a recorded clip. This seam keeps
/// `MainViewModel` free of the speech/audio engines so it stays unit-testable (tests supply a
/// fake). Mirrors the Android `Announcer` interface.
///
/// Main-actor isolated: the speech/audio engines and the pending-pair state are UI-thread state,
/// so the whole seam lives on the main actor. A conforming class is therefore *implicitly*
/// `Sendable`, which is what lets `RealAnnouncer` adopt the (now `Sendable`)
/// `AVSpeechSynthesizerDelegate` with no `@unchecked Sendable`.
@MainActor
protocol Announcer: AnyObject {
    /// Speak the animal's name (when TTS is enabled), then play `sound`'s recorded clip.
    func announce(_ sound: AnimalSound)
    /// Release the speech + audio engines. Call from the owner's *explicit* teardown (e.g. a
    /// scene-phase change), not from `deinit`: a `@MainActor` type's `deinit` is `nonisolated`
    /// and can't touch main-actor state, and the AV engines stop themselves on dealloc anyway —
    /// so teardown belongs at an explicit lifecycle point, not tucked into deallocation.
    func shutdown()
}

/// The real adapter: owns an `AVSpeechSynthesizer` + `AVAudioPlayer`. Settings are re-read from
/// prefs on every `announce`, so changes saved in Settings apply immediately with no lifecycle
/// plumbing (this is the design that fixed the Android app's old "Save does nothing" bug). The
/// spoken language is resolved once at init and the phrase is always read in that language, so
/// the voice and the text never disagree.
///
// `@MainActor`: the iOS SDK marks `AVSpeechSynthesizerDelegate` as `Sendable`, so adopting it
// (below) requires this class to be `Sendable`. A `@MainActor` class is *implicitly* `Sendable` —
// no `@unchecked` escape hatch, and no warning on the non-Sendable `synthesizer`/`player`, because
// the compiler now knows every one of those stored properties is only ever touched on the main
// actor. `announce`/`shutdown` are main-actor methods; the delegate callbacks are `nonisolated`
// and hop onto the main actor before touching any state (see the delegate extension below).
@MainActor
final class RealAnnouncer: NSObject, Announcer {
    private let prefs: Preferences
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// The language TTS speaks (device language when shipped + voiced, else English).
    private let language: String

    /// The fallback voice for the spoken language, resolved once. `speechVoices()` enumerates
    /// *every* installed system voice (can be 100+) and the installed set can't change mid-session,
    /// so we compute this once instead of re-enumerating on every tap. A user-picked voice still
    /// resolves live in `resolvedVoice()` (constructing one voice by id is cheap), preserving the
    /// "a saved Settings change applies on the next tap" design.
    private lazy var defaultVoice: AVSpeechSynthesisVoice? =
        AVSpeechSynthesisVoice.speechVoices().first { SpeechLanguage.matches($0.language, language) }

    /// The one utterance whose completion is allowed to trigger a clip, plus that clip. A new tap
    /// replaces this pair, so a *superseded* utterance can never play its clip over the new intro.
    /// We can't trust `stopSpeaking` to reliably deliver `didCancel` (AVFoundation sometimes fires
    /// `didFinish` for a flushed utterance, or delivers it late), so the guard is identity on this
    /// pair — not the delegate callback kind. Touched only on the main actor (announce, shutdown,
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
    /// there's no saved match, use the cached first installed voice for the spoken language.
    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let id = prefs.selectedVoiceId,
           let voice = AVSpeechSynthesisVoice(identifier: id),
           SpeechLanguage.matches(voice.language, language) {
            return voice
        }
        return defaultVoice
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

// The delegate requirements are `nonisolated` — AVFoundation invokes them from its own queue, off
// the main actor — so we mark them `nonisolated` and hop onto the main actor inside. The hop is
// `DispatchQueue.main.async` + `MainActor.assumeIsolated`, chosen deliberately:
//   * We must actually hop — the callbacks genuinely arrive off-main — which rules out a bare
//     `assumeIsolated` (it would trap when we're not already on main).
//   * `DispatchQueue.main.async` preserves the exact prior semantics: work is enqueued FIFO on the
//     main queue and runs in submission order relative to `announce`'s own main-thread work. That
//     ordering is what the pending-pair identity guard relies on. `Task { @MainActor in … }` would
//     add an executor hop with a weaker ordering guarantee against that non-`Task` work, so it's
//     the wrong tool here despite being the "obvious" async spelling.
//   * Once the block is demonstrably running on the main queue, `MainActor.assumeIsolated` hands the
//     compiler the main-actor guarantee for free — so the closure can touch the isolated pending
//     pair with zero `@unchecked` and zero data-race risk.
// We capture the utterance's `ObjectIdentifier` (which is `Sendable`) rather than the non-Sendable
// `AVSpeechUtterance` itself, so nothing non-Sendable crosses the `@Sendable` `async` boundary.
extension RealAnnouncer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let finished = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self,
                      let pending = self.pendingUtterance, ObjectIdentifier(pending) == finished,
                      let sound = self.pendingClip else { return }
                self.pendingUtterance = nil
                self.pendingClip = nil
                self.playClip(sound)
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let cancelled = ObjectIdentifier(utterance)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self,
                      let pending = self.pendingUtterance, ObjectIdentifier(pending) == cancelled else { return }
                self.pendingUtterance = nil
                self.pendingClip = nil
            }
        }
    }
}
