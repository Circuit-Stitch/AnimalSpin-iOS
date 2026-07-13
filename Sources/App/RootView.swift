import SwiftUI

/// Two-screen navigation, mirroring the Android `NavHost` ("main" + "settings").
///
/// Settings is intentionally *not* reachable by an on-screen button a toddler could tap.
/// It's opened by the hidden parental gate on `MainView` (draw a square anywhere), and
/// left again via Save (or the navigation back button).
struct RootView: View {
    @State private var showingSettings = Self.startOnSettings

    // DEBUG-only UI-test hook: launch straight into Settings for screenshotting/inspection.
    private static var startOnSettings: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-startOnSettings")
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack {
            MainView(onSettings: { showingSettings = true })
                .navigationDestination(isPresented: $showingSettings) {
                    SettingsView(onDone: { showingSettings = false })
                }
        }
    }
}
