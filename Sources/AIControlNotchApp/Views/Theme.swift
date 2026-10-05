import AppKit
import AIControlNotchCore
import SwiftUI

/// Mockup tokens (OKLCH converted to sRGB) and motion curves.
enum Theme {
    static let notch = Color.black
    static let danger = Color(red: 0.987, green: 0.345, blue: 0.334)
    static let warn = Color(red: 0.959, green: 0.743, blue: 0.309)
    static let ok = Color(red: 0.462, green: 0.810, blue: 0.543)
    static let track = Color(red: 0.981, green: 0.973, blue: 0.960).opacity(0.11)
    static let ink = Color(red: 0.960, green: 0.953, blue: 0.943)
    static let ink2 = Color(red: 0.692, green: 0.680, blue: 0.660)
    static let ink3 = Color(red: 0.466, green: 0.455, blue: 0.436)
    static let line = Color(red: 0.966, green: 0.975, blue: 0.988).opacity(0.09)
    static let shadow = Color(red: 0.004, green: 0.013, blue: 0.034)

    static func curve(_ duration: Double, reduceMotion: Bool = false) -> Animation {
        let ease = NotchMotion.curve
        return .timingCurve(ease.x1, ease.y1, ease.x2, ease.y2, duration: reduceMotion ? 0.001 : duration)
    }

    /// The model's accent: Claude clay, Codex green, or the color set in `providers.json`.
    static func accent(_ descriptor: ProviderDescriptor) -> Color {
        guard let rgb = HexColor.components(descriptor.accentHex) else { return ink2 }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    static func usage(_ descriptor: ProviderDescriptor, danger isDanger: Bool) -> Color {
        isDanger ? danger : accent(descriptor)
    }

    static func dot(_ tone: DotTone) -> Color {
        switch tone {
        case .ok: ok
        case .warn: warn
        case .danger: danger
        case .stale: ink3
        }
    }

    /// CSS weights (400–700) mapped onto SF Pro.
    static func font(_ size: CGFloat, _ weight: Int = 400) -> Font {
        let nsWeight: NSFont.Weight = switch weight {
        case ..<450: .regular
        case ..<550: .medium
        case ..<625: .semibold
        case ..<675: NSFont.Weight(0.35)
        default: .bold
        }
        return Font(NSFont.systemFont(ofSize: size, weight: nsWeight) as CTFont)
    }
}
