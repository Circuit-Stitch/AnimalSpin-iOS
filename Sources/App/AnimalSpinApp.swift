import SwiftUI

/// Animal Spin — an offline toy for toddlers. Tap an animal → a voice speaks its name
/// (Text-to-Speech) → a random recorded animal sound plays. No internet, no ads, no tracking.
///
/// iOS port of the Android app (github.com/Circuit-Stitch/AnimalSpin): SwiftUI + MVVM,
/// AVSpeechSynthesizer for the spoken intro and AVAudioPlayer for the recorded clips.
@main
struct AnimalSpinApp: App {

    #if DEBUG
    // DEBUG-only: lets the screenshot harness pin orientation (see `ScreenshotOrientationDelegate`).
    @UIApplicationDelegateAdaptor(ScreenshotOrientationDelegate.self) private var appDelegate
    #endif

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

#if DEBUG
import UIKit

/// DEBUG-only orientation control for the App Store screenshot harness. Passing `-forceLandscape`
/// pins the app to landscape so `xcrun simctl io screenshot` captures the landscape iPad layout
/// deterministically — the simulator's physical orientation is unreliable under headless
/// automation and silently reverts to portrait between launches. No effect in Release (the
/// adaptor isn't compiled) and none at runtime unless the launch argument is present.
final class ScreenshotOrientationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if ProcessInfo.processInfo.arguments.contains("-forceLandscape") { return .landscape }
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}
#endif
