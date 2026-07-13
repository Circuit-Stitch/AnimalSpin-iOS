import SwiftUI

/// Animal Spin — an offline toy for toddlers. Tap an animal → a voice speaks its name
/// (Text-to-Speech) → a random recorded animal sound plays. No internet, no ads, no tracking.
///
/// iOS port of the Android app (github.com/Circuit-Stitch/AnimalSpin): SwiftUI + MVVM,
/// AVSpeechSynthesizer for the spoken intro and AVAudioPlayer for the recorded clips.
@main
struct AnimalSpinApp: App {

    init() {
        // Route recorded clips + TTS through the playback category so a tap always makes
        // sound — even with the ring/silent switch flipped off (this is a soundboard toy).
        AudioSession.configureForPlayback()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Full-screen, chrome-free canvas so a toddler can't wander into system UI —
                // the closest analogue to the Android app's fullscreen/no-action-bar window.
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}
