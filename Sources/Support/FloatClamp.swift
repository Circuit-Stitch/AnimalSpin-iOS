import Foundation

extension Comparable {
    /// Clamp a value into a closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Float {
    /// Clamp to the app's voice pitch/speed range (0.5–2.0). A loaded pref outside this range
    /// would crash a SwiftUI `Slider` whose bounds don't contain its value, so coerce on read.
    func clampedToVoiceRange() -> Float { clamped(to: VoiceRange.closed) }
}
