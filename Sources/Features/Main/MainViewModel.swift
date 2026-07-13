import Foundation

/// On tap, picks a *random* recorded clip for the animal and hands it to the `Announcer`, which
/// speaks the animal's name (when enabled) then plays the clip. The speech/audio engines live
/// behind the `Announcer` seam, so this stays a plain, unit-testable object (tests pass a fake).
/// Mirrors the Android `MainViewModel`.
///
/// Main-actor isolated: it's owned by SwiftUI `@State` and only ever driven from the view (the main
/// actor), and it calls the main-actor `Announcer`.
@MainActor
final class MainViewModel {
    private let announcer: Announcer

    // The default announcer is built in the body, not as a default-argument expression: a default
    // argument is evaluated in a `nonisolated` context, where it can't call the `@MainActor`
    // `RealAnnouncer.init`. Passing `nil` and constructing here keeps the "no argument → real
    // announcer" ergonomics while satisfying isolation.
    init(announcer: Announcer? = nil) {
        self.announcer = announcer ?? RealAnnouncer()
    }

    func play(_ animal: Animal) {
        guard let clip = animal.soundClips.randomElement() else { return }
        announcer.announce(AnimalSound(animal: animal, clip: clip))
    }

    // No `deinit`-based teardown: a `@MainActor` type's `deinit` is `nonisolated` and can't call the
    // main-actor `announcer.shutdown()`, and the AV engines stop themselves on dealloc. This
    // view-model is the app-lifetime root and never actually deinits; if a shorter-lived owner ever
    // needs deterministic teardown, call `announcer.shutdown()` from an explicit lifecycle hook
    // (e.g. `scenePhase` → `.background`) rather than reintroducing it here.
}
