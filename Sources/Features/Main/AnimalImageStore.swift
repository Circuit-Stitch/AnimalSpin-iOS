import SwiftUI
import UIKit

/// Pre-decodes the 24 animal photos off the main thread so the grid's first frame is never blocked
/// on image decode.
///
/// `Image(name)` decodes an asset lazily, on the main thread, at draw time — and because
/// `MainView`'s screen-filling iPad grid shows all 24 cells at once (the `ScrollView` measures full
/// content, defeating `LazyVGrid` laziness), every photo decodes up front on the main actor during
/// the first render. NOTE: measured, that decode is only ~16ms for the whole 24-photo set (they're
/// ~500px JPGs, ~23 MB decoded) — one frame, *not* the launch bottleneck. The perceived ~0.5–1s
/// launch is iOS process launch + the SpringBoard open animation + SwiftUI's first render, which
/// this does not touch (and which the launch screen already masks). So this is robustness/polish,
/// not a load-time fix: it keeps the first frame off the decode path, reveals photos progressively,
/// and leaves headroom if the roster or image sizes ever grow.
///
/// Each asset is loaded and force-decoded on the cooperative thread pool, then the ready `UIImage`
/// is published back on the main actor; `MainView` renders `Image(uiImage:)` over a purple
/// placeholder that matches the launch screen, so cells dissolve in rather than flashing.
///
/// Main-actor isolated (SwiftUI-owned `@State`, mutated only from the main actor). The decode runs
/// in a `nonisolated` function and the freshly-made, never-shared image is `sending` back — no
/// `@unchecked Sendable`, clean under `SWIFT_STRICT_CONCURRENCY = complete`.
@Observable
@MainActor
final class AnimalImageStore {
    private var images: [Animal: UIImage] = [:]

    /// Guards `start()` against re-running when the grid reappears (e.g. back from Settings). Not
    /// view state, so it stays out of observation.
    @ObservationIgnored private var started = false

    /// The decoded photo for `animal`, or `nil` until its background decode finishes.
    func image(for animal: Animal) -> UIImage? { images[animal] }

    /// Kicks off the background decode of all 24 photos. Idempotent: call it from a `.task` that
    /// may fire again on reappear — already-decoded images stay cached and no work repeats. Each
    /// decode is an unstructured `Task` so a photo pops in the instant it's ready (rather than
    /// waiting for the whole set) and so navigating away mid-decode doesn't cancel it.
    func start() {
        guard !started else { return }
        started = true
        for animal in Animal.allCases {
            Task { await load(animal) }
        }
    }

    private func load(_ animal: Animal) async {
        guard let decoded = await Self.decode(named: animal.imageName) else { return }
        images[animal] = decoded
    }

    /// Loads the asset and forces its decode off the main actor. Runs on the cooperative thread
    /// pool; `byPreparingForDisplay()` (iOS 15+) returns a fresh, never-shared image, so it's
    /// `sending` back to the main actor without tripping Sendable diagnostics.
    private nonisolated static func decode(named name: String) async -> sending UIImage? {
        guard let image = UIImage(named: name) else { return nil }
        return await image.byPreparingForDisplay()
    }
}
