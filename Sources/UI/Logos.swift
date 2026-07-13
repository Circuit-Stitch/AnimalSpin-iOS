import SwiftUI

/// Circuit Stitch mark (brown, works in both light and dark). Rendered from the original Android
/// vector drawable via `VectorPathShape`.
struct CircuitStitchLogo: View {
    var body: some View {
        VectorPathShape(
            pathData: LogoData.circuitStitch,
            viewport: CGSize(width: 100, height: 100),
            translate: CGPoint(x: -83.439354, y: -97.342026)
        )
        .fill(Color(red: 0x9A / 255, green: 0x5A / 255, blue: 0x22 / 255))
    }
}

/// GitHub mark. The source glyph is black; `.primary` makes it adapt (black in light, white in
/// dark) so it stays visible in both appearances.
struct GitHubLogo: View {
    var body: some View {
        VectorPathShape(
            pathData: LogoData.github,
            viewport: CGSize(width: 98, height: 96)
        )
        .fill(Color.primary)
    }
}
