import XCTest
import UIKit
@testable import AnimalSpin

/// Guards the data-driven content: every animal has an image, at least one bundled clip, and a
/// localized spoken phrase — the invariants that make "add an animal" a data-only change.
final class AnimalCatalogTests: XCTestCase {

    func testTwentyFourActiveAnimals() {
        XCTAssertEqual(Animal.allCases.count, 24)
    }

    func testEveryAnimalHasAtLeastOneClip() {
        for animal in Animal.allCases {
            XCTAssertFalse(animal.soundClips.isEmpty, "\(animal) has no clips")
        }
    }

    func testEveryClipResourceExistsInBundle() {
        for animal in Animal.allCases {
            for clip in animal.soundClips {
                XCTAssertNotNil(
                    Bundle.main.url(forResource: clip, withExtension: "mp3"),
                    "missing audio resource \(clip).mp3"
                )
            }
        }
    }

    func testAllClipsAreUniqueAndTotal172() {
        let all = Animal.allCases.flatMap(\.soundClips)
        XCTAssertEqual(all.count, 172)
        XCTAssertEqual(Set(all).count, all.count, "duplicate clip references")
    }

    func testEveryAnimalHasAnImageAsset() {
        for animal in Animal.allCases {
            XCTAssertNotNil(UIImage(named: animal.imageName), "missing image asset \(animal.imageName)")
        }
    }

    func testEveryAnimalHasAnEnglishPhrase() {
        for animal in Animal.allCases {
            let phrase = Localization.phrase(animal.ttsKey, language: "en")
            XCTAssertNotEqual(phrase, animal.ttsKey, "no English phrase for \(animal.ttsKey)")
            XCTAssertFalse(phrase.isEmpty)
        }
    }
}
