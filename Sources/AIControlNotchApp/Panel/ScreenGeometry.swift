import AppKit

/// Finds the built-in display and the size of its camera housing.
@MainActor
enum ScreenGeometry {
    static let fallbackNotchWidth: CGFloat = 190
    static let minimumHeight: CGFloat = 24

    /// The screen with a notch (non-zero top safe area), else the main screen.
    static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    static func notchSize(on screen: NSScreen?) -> CGSize {
        guard let screen else { return CGSize(width: fallbackNotchWidth, height: minimumHeight) }
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            return CGSize(width: right.minX - left.maxX, height: top)
        }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return CGSize(width: fallbackNotchWidth, height: max(minimumHeight, menuBar))
    }
}
