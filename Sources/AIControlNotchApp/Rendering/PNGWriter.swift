import AppKit
import SwiftUI

/// Writes a SwiftUI view to disk as PNG (headless, no window needed).
@MainActor
enum PNGWriter {
    enum Failure: Error {
        case renderFailed(String)
    }

    static func write<V: View>(_ view: V, to url: URL, scale: CGFloat) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage else { throw Failure.renderFailed(url.lastPathComponent) }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw Failure.renderFailed(url.lastPathComponent)
        }
        try data.write(to: url, options: .atomic)
    }
}
