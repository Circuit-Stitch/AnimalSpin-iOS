import XCTest
@testable import AnimalSpin

/// Exercises the clip-selection seam offline: with a fake `Announcer` in place, no speech or
/// audio engine is touched, so tapping an animal is a plain assertion. Ported from the Android
/// `MainViewModelTest`.
final class MainViewModelTests: XCTestCase {

    private final class FakeAnnouncer: Announcer {
        private(set) var announced: [AnimalSound] = []
        func announce(_ sound: AnimalSound) { announced.append(sound) }
        func shutdown() {}
    }

    func testPlayAnnouncesAClipBelongingToTheTappedAnimal() {
        let fake = FakeAnnouncer()

        MainViewModel(announcer: fake).play(.cat)

        XCTAssertEqual(fake.announced.count, 1)
        XCTAssertEqual(fake.announced.first?.animal, .cat)
        XCTAssertTrue(Animal.cat.soundClips.contains(fake.announced.first!.clip))
    }

    func testEverySelectedClipBelongsToTheTappedAnimalAcrossManyTaps() {
        let fake = FakeAnnouncer()
        let viewModel = MainViewModel(announcer: fake)

        for _ in 0..<50 { viewModel.play(.dog) }

        XCTAssertEqual(fake.announced.count, 50)
        XCTAssertTrue(fake.announced.allSatisfy { $0.animal == .dog })
        XCTAssertTrue(fake.announced.allSatisfy { Animal.dog.soundClips.contains($0.clip) })
    }
}
