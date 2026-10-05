import AIControlNotchCore
import SwiftUI

/// `--render-icon <dir>`: writes AppIcon.iconset (16 to 1024 px) for `iconutil`.
@MainActor
enum IconRenderer {
    static let sizes = [16, 32, 128, 256, 512]

    static func render(to directory: URL) throws {
        let iconset = directory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for size in sizes {
            for scale in [1, 2] {
                let suffix = scale == 2 ? "@2x" : ""
                let url = iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
                try PNGWriter.write(AppIconView(), to: url, scale: CGFloat(size * scale) / AppIconView.canvas)
            }
        }
    }
}

/// A dark tile with the notch and the two rulers of the open panel.
struct AppIconView: View {
    static let canvas: CGFloat = 1024
    static let tile: CGFloat = 824
    static let tileRadius: CGFloat = 186

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.16, green: 0.155, blue: 0.15), Color(red: 0.075, green: 0.072, blue: 0.07)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: Self.tile, height: Self.tile)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            VStack(spacing: 0) {
                NotchShape(width: 420, height: 120, radius: 52)
                    .fill(Color.black)
                    .frame(width: Self.tile, height: 120)
                    .overlay(alignment: .top) {
                        HStack {
                            Circle().fill(Theme.accent(.claude)).frame(width: 40, height: 40)
                            Spacer()
                            Circle().fill(Theme.accent(.codex)).frame(width: 40, height: 40)
                        }
                        .frame(width: 330, height: 120)
                    }
                Spacer()
                IconRuler(filled: 6, partial: 0.4, color: Theme.accent(.claude))
                Spacer().frame(height: 64)
                IconRuler(filled: 9, partial: 0.1, color: Theme.danger)
                Spacer()
                Spacer().frame(height: 120)
            }
            .frame(width: Self.tile, height: Self.tile)
            .clipShape(RoundedRectangle(cornerRadius: Self.tileRadius, style: .continuous))
        }
        .frame(width: Self.canvas, height: Self.canvas)
    }
}

private struct IconRuler: View {
    let filled: Int
    let partial: Double
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<10, id: \.self) { index in
                let fill = index < filled ? 1 : (index == filled ? partial : 0)
                ZStack(alignment: .leading) {
                    Theme.track
                    color.frame(width: 46 * fill)
                }
                .frame(width: 46, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}
