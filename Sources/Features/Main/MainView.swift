import SwiftUI

/// The main screen: a full-bleed grid of animal photos. Tapping one plays it. Drawing a square
/// anywhere opens Settings (see `squareToUnlock`). Ported from the Android `MainScreen`.
struct MainView: View {
    let onSettings: () -> Void
    @State private var viewModel = MainViewModel()
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass

    var body: some View {
        GeometryReader { proxy in
            grid(in: proxy.size)
        }
        .ignoresSafeArea()
        .squareToUnlock(perform: onSettings)
        .toolbar(.hidden, for: .navigationBar)
    }

    /// True on a full-screen iPad canvas (both size classes regular). There every animal tiles the
    /// screen at once; a phone — or a narrow iPad multitasking slice — keeps the taller, scrollable
    /// big-cell layout instead.
    private var fillsScreen: Bool { hSizeClass == .regular && vSizeClass == .regular }

    private func grid(in size: CGSize) -> some View {
        let count = Animal.allCases.count
        // iPad: tile the whole screen (a divisor of `count` columns → no blank cell, near-square
        // photos). Phone: fat ~200pt columns that scroll. See `GridLayout`.
        let columns = fillsScreen ? GridLayout.fillingColumns(for: size, count: count)
                                  : GridLayout.scrollingColumns(forWidth: size.width)
        let rows = max(Int((Double(count) / Double(columns)).rounded(.up)), 1)
        let cellWidth = size.width / CGFloat(columns)

        // iPad: even rows fill top-to-bottom with no gap or scroll. Phone: square, finger-big cells.
        let cellHeight = fillsScreen ? size.height / CGFloat(rows) : cellWidth
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: columns)

        return ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 0) {
                ForEach(Animal.allCases) { animal in
                    cell(animal, height: cellHeight)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)   // don't bounce/scroll when the rows already fit
    }

    private func cell(_ animal: Animal, height: CGFloat) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Image(animal.imageName)
                    .resizable()
                    .scaledToFill()   // ContentScale.Crop
            }
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { viewModel.play(animal) }
            .accessibilityLabel(animal.displayName)
            .accessibilityAddTraits(.isButton)
    }
}
