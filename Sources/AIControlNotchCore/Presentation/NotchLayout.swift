import CoreGraphics
import Foundation

/// Width, height and bottom corner radius of the black shape.
public struct NotchFrame: Equatable, Sendable {
    public let width: CGFloat
    public let height: CGFloat
    public let radius: CGFloat

    public init(width: CGFloat, height: CGFloat, radius: CGFloat) {
        self.width = width
        self.height = height
        self.radius = radius
    }
}

/// Which shape to size: the open panel depends on how many rows it lists.
public enum NotchShapeKind: Equatable, Sendable {
    case rest
    case open(rows: Int, sections: Int)
    case alert
}

/// Mockup measurements scaled to the real notch.
public struct NotchLayout: Equatable, Sendable {
    public static let earRadius: CGFloat = 9
    public static let rowHeight: CGFloat = 46
    public static let gridTopPadding: CGFloat = 2
    public static let ringSize: CGFloat = 42
    static let restSideWidth: CGFloat = 70
    static let restRadius: CGFloat = 10
    static let openWidth: CGFloat = 672
    static let openRadius: CGFloat = 26
    static let legendBlock: CGFloat = 53
    static let alertWidth: CGFloat = 470
    static let alertRadius: CGFloat = 24
    static let alertGap: CGFloat = 4
    static let alertBottom: CGFloat = 12
    static let shadowMargin: CGFloat = 40

    public let notch: CGSize

    public init(notch: CGSize) {
        self.notch = notch
    }

    public var alertTopPadding: CGFloat { notch.height + Self.alertGap }

    public func frame(for kind: NotchShapeKind) -> NotchFrame {
        switch kind {
        case .rest:
            return NotchFrame(width: notch.width + 2 * Self.restSideWidth, height: notch.height, radius: Self.restRadius)
        case let .open(rows, sections):
            let dividers = CGFloat(max(0, sections - 1))
            let height = notch.height + Self.gridTopPadding + CGFloat(rows) * Self.rowHeight + dividers + Self.legendBlock
            return NotchFrame(width: Self.openWidth, height: height, radius: Self.openRadius)
        case .alert:
            let height = alertTopPadding + Self.ringSize + Self.alertBottom
            return NotchFrame(width: Self.alertWidth, height: height, radius: Self.alertRadius)
        }
    }

    /// The transparent window that holds every state, with room for the shadow.
    public func canvasSize(rows: Int, sections: Int) -> CGSize {
        let open = frame(for: .open(rows: rows, sections: sections))
        let width = max(open.width, frame(for: .rest).width) + 2 * (Self.earRadius + Self.shadowMargin)
        return CGSize(width: width, height: open.height + Self.shadowMargin)
    }

    /// Where the shape (ears included) sits on screen, in AppKit coordinates.
    public func hitRect(for kind: NotchShapeKind, screenFrame: CGRect) -> CGRect {
        let shape = frame(for: kind)
        let width = shape.width + 2 * Self.earRadius
        return CGRect(x: screenFrame.midX - width / 2, y: screenFrame.maxY - shape.height, width: width, height: shape.height)
    }
}
