import AIControlNotchCore
import SwiftUI

/// Draws parsed SVG path data scaled from its square viewBox.
struct SVGShape: Shape {
    let commands: [SVGCommand]
    let viewBox: CGFloat

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / viewBox
        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: scale, y: scale)
        return commands.reduce(into: Path()) { path, command in
            switch command {
            case let .move(point): path.move(to: point.applying(transform))
            case let .line(point): path.addLine(to: point.applying(transform))
            case let .quad(control, point): path.addQuadCurve(to: point.applying(transform), control: control.applying(transform))
            case let .cubic(c1, c2, point):
                path.addCurve(to: point.applying(transform), control1: c1.applying(transform), control2: c2.applying(transform))
            case .close: path.closeSubpath()
            }
        }
    }
}

enum Glyphs {
    static let claude = parse(LogoPaths.claude)
    static let openAI = parse(LogoPaths.openAI)
    /// The mockup's "renova" icon, a 12-unit stroked arrow.
    static let reset = parse("M2.2 6.2A3.8 3.8 0 1 0 3.4 3.4M2.4 1.6v2.3h2.3")

    private static func parse(_ data: String) -> [SVGCommand] {
        (try? SVGPath.parse(data)) ?? []
    }
}

/// Official marks for the built-ins (Claude in brand clay, OpenAI in white);
/// a monogram in the model's accent for everything added by script.
struct LogoView: View {
    let provider: ProviderID
    let size: CGFloat
    @Environment(\.providerCatalog) private var catalog

    var body: some View {
        let descriptor = catalog.descriptor(provider)
        switch descriptor.logo {
        case .claude:
            glyph(Glyphs.claude, color: Theme.accent(descriptor), label: "Claude")
        case .openAI:
            glyph(Glyphs.openAI, color: Theme.ink, label: "OpenAI")
        case let .monogram(letter):
            Monogram(letter: letter, color: Theme.accent(descriptor), size: size)
                .accessibilityLabel(descriptor.displayName)
        }
    }

    private func glyph(_ commands: [SVGCommand], color: Color, label: String) -> some View {
        SVGShape(commands: commands, viewBox: LogoPaths.viewBox)
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityLabel(label)
    }
}

/// A rounded tile with the model's first letter, cut out in the notch's black.
struct Monogram: View {
    static let cornerRatio: CGFloat = 0.3
    static let letterRatio: CGFloat = 0.7

    let letter: String
    let color: Color
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * Self.cornerRatio, style: .continuous)
            .fill(color)
            .overlay(
                Text(letter)
                    .font(.system(size: size * Self.letterRatio, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.notch)
                    .minimumScaleFactor(0.5)
            )
            .frame(width: size, height: size)
    }
}

private struct ProviderCatalogKey: EnvironmentKey {
    static let defaultValue = ProviderCatalog.builtIn
}

extension EnvironmentValues {
    /// Names, accents and logos of the models on screen.
    var providerCatalog: ProviderCatalog {
        get { self[ProviderCatalogKey.self] }
        set { self[ProviderCatalogKey.self] = newValue }
    }
}

struct ResetIcon: View {
    static let viewBox: CGFloat = 12
    let size: CGFloat

    var body: some View {
        SVGShape(commands: Glyphs.reset, viewBox: Self.viewBox)
            .stroke(Theme.ink3, style: StrokeStyle(lineWidth: 1.5 * size / Self.viewBox, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

struct Dot: View {
    static let size: CGFloat = 7
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: Self.size, height: Self.size)
    }
}
