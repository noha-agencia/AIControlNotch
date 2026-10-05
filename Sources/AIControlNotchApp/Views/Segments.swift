import SwiftUI

/// The 10-cell ruler; each cell fills partially (38% → three full cells and 80% of the fourth).
struct Segments: View {
    static let cell = CGSize(width: 18, height: 10)
    static let spacing: CGFloat = 3
    static let radius: CGFloat = 2.5
    static var width: CGFloat { cell.width * 10 + spacing * 9 }

    let fills: [Double]
    let color: Color

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(fills.indices, id: \.self) { index in
                ZStack(alignment: .leading) {
                    Theme.track
                    color.frame(width: Self.cell.width * fills[index])
                }
                .frame(width: Self.cell.width, height: Self.cell.height)
                .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
            }
        }
    }
}
