import SwiftUI

/// The main screen: a full-bleed grid of animal photos. Tapping one plays it. Drawing a square
/// anywhere opens Settings (see `squareToUnlock`). Ported from the Android `MainScreen`.
struct MainView: View {
    let onSettings: () -> Void
    @State private var viewModel = MainViewModel()

    var body: some View {
        GeometryReader { proxy in
            grid(in: proxy.size)
        }
        .ignoresSafeArea()
        .squareToUnlock(perform: onSettings)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func grid(in size: CGSize) -> some View {
        // Columns = how many ~200pt cells fit across, min 2 — so cells stay finger-big. Phones
        // get 2 fat columns; tablets get more.
        let columns = max(Int(size.width / 200), 2)
        let rows = max(Int((Double(Animal.allCases.count) / Double(columns)).rounded(.up)), 1)
        let cellWidth = size.width / CGFloat(columns)
        let fitHeight = size.height / CGFloat(rows)

        // If square cells overflow the height by <15%, stretch to fill top-to-bottom (no gap or
        // scroll); a bigger overflow (phones) stays square and scrolls.
        let cellHeight = fitHeight >= cellWidth * 0.85 ? fitHeight : cellWidth
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
