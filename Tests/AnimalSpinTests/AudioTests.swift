import XCTest
import AVFoundation
@testable import AnimalSpin

/// Verifies the audio pipeline: every clip is a valid, decodable file; the announce path runs
/// without TTS; and the Android→AVFoundation rate/pitch mapping is correct.
final class AudioTests: XCTestCase {

    func testEveryClipIsDecodable() throws {
        for animal in Animal.allCases {
            for clip in animal.soundClips {
                let url = try XCTUnwrap(
                    Bundle.main.url(forResource: clip, withExtension: "mp3"),
                    "missing \(clip).mp3"
                )
                // AVAudioPlayer parses the file header; a throw means a corrupt/invalid clip.
                XCTAssertNoThrow(try AVAudioPlayer(contentsOf: url), "undecodable clip \(clip)")
            }
        }
    }

    // `RealAnnouncer` is `@MainActor`, so constructing and driving it must happen on the main actor.
    @MainActor
    func testAnnouncerPlaysClipWithoutTTS() {
        // Isolated prefs store with TTS off → announce takes the synchronous clip path.
        let suite = "AnimalSpinTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)
        prefs.ttsEnabled = false

        let announcer = RealAnnouncer(prefs: prefs)
        // Should create and start an AVAudioPlayer for a real clip without crashing.
        announcer.announce(AnimalSound(animal: .cat, clip: Animal.cat.soundClips.first!))
        announcer.shutdown()
    }

    func testSpeechRateMapsAroundPlatformDefault() {
        // 1.0 multiplier == the platform's normal rate.
        XCTAssertEqual(SpeechTuning.rate(forSpeedMultiplier: 1.0), AVSpeechUtteranceDefaultSpeechRate, accuracy: 0.0001)
        // Faster than the max clamps to the engine maximum.
        XCTAssertEqual(SpeechTuning.rate(forSpeedMultiplier: 10.0), AVSpeechUtteranceMaximumSpeechRate, accuracy: 0.0001)
        // 2.0 is faster than 1.0.
        XCTAssertGreaterThan(SpeechTuning.rate(forSpeedMultiplier: 2.0), SpeechTuning.rate(forSpeedMultiplier: 1.0))
    }

    func testPitchMapsThroughAndClamps() {
        XCTAssertEqual(SpeechTuning.pitchMultiplier(for: 1.0), 1.0, accuracy: 0.0001)  // normal
        XCTAssertEqual(SpeechTuning.pitchMultiplier(for: 5.0), 2.0, accuracy: 0.0001)  // clamp high
        XCTAssertEqual(SpeechTuning.pitchMultiplier(for: 0.1), 0.5, accuracy: 0.0001)  // clamp low
    }

    func testVoicePrefRoundTrips() {
        let suite = "AnimalSpinTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = Preferences(defaults: defaults)

        // Defaults match the Android app (1.0 pitch/speed, TTS on).
        XCTAssertEqual(prefs.voicePitch, 1.0, accuracy: 0.0001)
        XCTAssertEqual(prefs.voiceSpeed, 1.0, accuracy: 0.0001)
        XCTAssertTrue(prefs.ttsEnabled)
        XCTAssertNil(prefs.selectedVoiceId)

        prefs.voicePitch = 1.5
        prefs.ttsEnabled = false
        prefs.selectedVoiceId = "com.apple.voice.test"
        XCTAssertEqual(Preferences(defaults: defaults).voicePitch, 1.5, accuracy: 0.0001)
        XCTAssertFalse(Preferences(defaults: defaults).ttsEnabled)
        XCTAssertEqual(Preferences(defaults: defaults).selectedVoiceId, "com.apple.voice.test")
    }
}
