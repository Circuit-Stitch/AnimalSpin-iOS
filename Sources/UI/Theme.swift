import SwiftUI
import UIKit

/// App theme colors, tuned for WCAG-AA contrast in *both* light and dark appearances.
///
/// The original fixed brand purple (#6200EE) reads well on light surfaces (~7:1) but collapses to
/// ~2.8:1 on the dark canvas, which is why the old Settings screen was hard to read. These colors
/// are appearance-aware: dark mode swaps in the lighter Material counterpart (#BB86FC). Applied
/// app-wide via `.tint` (see `RootView`), so every tinted control, the navigation-bar back button,
/// and the Save button inherit an accent that clears AA everywhere.
extension Color {
    /// Brand purple, per-appearance. Light: #6200EE (the Android brand primary). Dark: #BB86FC
    /// (its dark-theme counterpart). Both clear 4.5:1 as label text on their mode's grouped
    /// background and ≥3:1 as a control fill/boundary.
    static let brandAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .brandPurpleDark : .brandPurpleLight
    })

    /// The label color to place *on top of* `brandAccent` (the Save button fill): white on the
    /// dark light-mode purple, black on the light dark-mode purple — ≥7:1 either way. (Needed
    /// because `.borderedProminent` hard-codes a white label, which would fail on the light dark-
    /// mode purple.)
    static let onBrandAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
    })

    /// A de-emphasized text color that still clears WCAG-AA 4.5:1 in *both* appearances. The system
    /// `.secondary` label drops to ~3.4:1 on light backgrounds (white cells and the #F2F2F7 grouped
    /// page), which fails AA for normal-size text; these grays compute to ~6–7:1 on their mode's
    /// surfaces. Used for the slider value readout and the credits footer.
    static let secondaryAA = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.68, alpha: 1.0)   // ≈ #ADADAD on black ≈ 8:1
            : UIColor(white: 0.35, alpha: 1.0)   // ≈ #595959 on white ≈ 7:1, on #F2F2F7 ≈ 6.3:1
    })

    /// The fixed launch-screen purple (#6200EE), used as the grid's cell placeholder before its
    /// photo finishes decoding (see `AnimalImageStore`). Deliberately *not* appearance-aware: it
    /// matches the universal `LaunchBackground` asset the storyboard uses, so a cell reads as the
    /// launch screen dissolving into the photo rather than a flash of a different color.
    static let launchBackground = Color(uiColor: .brandPurpleLight)
}

private extension UIColor {
    static let brandPurpleLight = UIColor(red: 0x62 / 255.0, green: 0x00 / 255.0, blue: 0xEE / 255.0, alpha: 1.0)
    static let brandPurpleDark = UIColor(red: 0xBB / 255.0, green: 0x86 / 255.0, blue: 0xFC / 255.0, alpha: 1.0)
}
