import Foundation

/// The animals shown in the grid, in display order. This is the source of truth for content,
/// mirroring the Android `enum class Animal`: each case binds an image and a spoken phrase,
/// and its recorded clips live in the generated `AnimalSounds` catalog.
///
/// The 24 active cases match the Android app exactly (its "on ice"/"ponytail" animals — held
/// out for want of clean CC0 audio — are likewise omitted here). Each case's `rawValue` is its
/// image-asset name and the stem of its localization key, so adding an animal is data-only:
/// add a case, drop in the image asset, add its `tts_<name>_says` string and its clip rows.
enum Animal: String, CaseIterable, Identifiable {
    case bear, cat, chicken, cicada, cow, cricket, crow, dog, donkey, duck
    case frog, goat, goose, horse, hyena, lion, monkey, owl, parrot, peacock
    case pig, sheep, squirrel, tiger

    var id: String { rawValue }

    /// Image-asset name (Assets.xcassets), e.g. `cat`.
    var imageName: String { rawValue }

    /// Localization key for the spoken intro ("a cat says"), e.g. `tts_cat_says`.
    var ttsKey: String { "tts_\(rawValue)_says" }

    /// Human-readable name for accessibility (VoiceOver), e.g. `Cat`.
    var displayName: String { rawValue.capitalized }

    /// Recorded clip resource names (mp3, without extension) for this animal.
    var soundClips: [String] { AnimalSounds.clips[self] ?? [] }
}
