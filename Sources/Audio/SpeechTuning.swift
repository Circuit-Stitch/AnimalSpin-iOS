import AVFoundation

/// The app's device-independent voice range (0.5–2.0 multipliers, 1.0 = normal), matching the
/// Android TextToSpeech convention. Used by the sliders and by `SpeechTuning`.
enum VoiceRange {
    static let min: Float = 0.5
    static let max: Float = 2.0
    static let closed: ClosedRange<Float> = min...max
}

/// Maps the app's voice settings onto AVSpeechUtterance's native ranges.
enum SpeechTuning {
    /// AVSpeechUtterance.rate is *absolute* (0…1, default ≈ 0.5), unlike Android's rate
    /// *multiplier*. Scale around the platform default so 1.0 stays "normal", then clamp to
    /// the engine's supported range.
    static func rate(forSpeedMultiplier multiplier: Float) -> Float {
        (AVSpeechUtteranceDefaultSpeechRate * multiplier)
            .clamped(to: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
    }

    /// AVSpeechUtterance.pitchMultiplier already matches Android's pitch convention
    /// (0.5–2.0, 1.0 = normal), so it passes straight through, clamped to be safe.
    static func pitchMultiplier(for pitch: Float) -> Float {
        pitch.clamped(to: VoiceRange.closed)
    }
}
