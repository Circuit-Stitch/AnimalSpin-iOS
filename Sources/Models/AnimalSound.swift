import Foundation

/// A single recorded clip belonging to an animal — the unit handed to the `Announcer`
/// (mirrors the Android `AnimalNoise`: an animal paired with one `@RawRes` clip).
struct AnimalSound: Equatable {
    let animal: Animal
    /// Clip resource name without extension, e.g. `cat_fs1` (bundled as `cat_fs1.mp3`).
    let clip: String
}
