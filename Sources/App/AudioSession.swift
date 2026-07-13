import AVFoundation

/// Manages the shared audio session. `.playback` makes the app audible even when the hardware
/// mute switch is on — the desired behaviour for a toddler soundboard, and the closest match to
/// the Android app playing on the media stream.
enum AudioSession {
    /// Set the category at launch. This alone does NOT interrupt other apps' audio — only
    /// *activation* does — so the parent's music/podcast keeps playing until the first tap.
    static func configureForPlayback() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            Log.audio.error("audio session category failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Activate the session, called lazily on every announce. This defers taking audio focus to
    /// the first actual sound (so opening the app doesn't kill background audio — matching
    /// Android's per-playback focus), and re-activates a session the system deactivated after an
    /// interruption (incoming call, Siri, alarm), so later taps keep working.
    static func activate() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Log.audio.error("audio session activate failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
