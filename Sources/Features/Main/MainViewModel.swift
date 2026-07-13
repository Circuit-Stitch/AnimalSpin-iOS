import Foundation

/// On tap, picks a *random* recorded clip for the animal and hands it to the `Announcer`, which
/// speaks the animal's name (when enabled) then plays the clip. The speech/audio engines live
/// behind the `Announcer` seam, so this stays a plain, unit-testable object (tests pass a fake).
/// Mirrors the Android `MainViewModel`.
final class MainViewModel {
    private let announcer: Announcer

    init(announcer: Announcer = RealAnnouncer()) {
        self.announcer = announcer
    }

    func play(_ animal: Animal) {
        guard let clip = animal.soundClips.randomElement() else { return }
        announcer.announce(AnimalSound(animal: animal, clip: clip))
    }

    deinit {
        announcer.shutdown()
    }
}
