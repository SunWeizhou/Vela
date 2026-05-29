import SwiftUI
import UIKit

enum VelaTheme {
    static let cornerRadiusCard: CGFloat = 20
    static let cornerRadiusTile: CGFloat = 14
    static let screenPadding: CGFloat = 20

    private static func adaptiveColor(
        light: UIColor,
        dark: UIColor
    ) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // Stitch Vitals Minimalist cool glass background layers.
    static let background = adaptiveColor(
        light: UIColor(red: 0.976, green: 0.976, blue: 1.000, alpha: 1),
        dark: UIColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1)
    )
    static let backgroundSecondary = adaptiveColor(
        light: UIColor(red: 0.945, green: 0.953, blue: 1.000, alpha: 1),
        dark: UIColor(red: 0.090, green: 0.106, blue: 0.133, alpha: 1)
    )
    static let backgroundTertiary = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.141, blue: 0.176, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.70),
        dark: UIColor(red: 0.125, green: 0.141, blue: 0.176, alpha: 0.70)
    )
    static let elevatedSurface = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.82),
        dark: UIColor(red: 0.165, green: 0.188, blue: 0.239, alpha: 0.82)
    )
    static let stroke = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.55),
        dark: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.10)
    )

    // Card design tokens
    static let cardBackground = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.70),
        dark: UIColor(red: 0.125, green: 0.141, blue: 0.176, alpha: 0.70)
    )
    static let heroCardBackground = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.82),
        dark: UIColor(red: 0.165, green: 0.188, blue: 0.239, alpha: 0.82)
    )
    static let cardShadowColor = adaptiveColor(
        light: UIColor(white: 0.0, alpha: 0.045),
        dark: UIColor(white: 0.0, alpha: 0.36)
    )
    static let innerGlowOpacity: Double = 0.06
    static let primaryText = adaptiveColor(
        light: UIColor(red: 0.082, green: 0.110, blue: 0.157, alpha: 1),
        dark: UIColor(red: 0.925, green: 0.941, blue: 1.000, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: UIColor(red: 0.259, green: 0.278, blue: 0.325, alpha: 1),
        dark: UIColor(red: 0.760, green: 0.784, blue: 0.840, alpha: 1)
    )
    static let mutedText = adaptiveColor(
        light: UIColor(red: 0.447, green: 0.467, blue: 0.518, alpha: 1),
        dark: UIColor(red: 0.620, green: 0.651, blue: 0.714, alpha: 1)
    )

    static let inverseText = adaptiveColor(
        light: UIColor.white,
        dark: UIColor.black
    )
    static let subtleFill = adaptiveColor(
        light: UIColor(red: 0.910, green: 0.933, blue: 1.000, alpha: 0.72),
        dark: UIColor(red: 0.188, green: 0.212, blue: 0.267, alpha: 0.72)
    )
    static let strongControl = adaptiveColor(
        light: UIColor(red: 0.000, green: 0.345, blue: 0.737, alpha: 1),
        dark: UIColor(red: 0.678, green: 0.776, blue: 1.000, alpha: 1)
    )
    static let tabBarBackground = adaptiveColor(
        light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.26),
        dark: UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.40)
    )

    // Accent
    static let accent = adaptiveColor(
        light: UIColor(red: 0.000, green: 0.345, blue: 0.737, alpha: 1),
        dark: UIColor(red: 0.678, green: 0.776, blue: 1.000, alpha: 1)
    )

    // Metric colors from Stitch: calm and clinical, not neon.
    static let sleep = adaptiveColor(
        light: UIColor(red: 0.035, green: 0.357, blue: 0.749, alpha: 1),
        dark: UIColor(red: 0.678, green: 0.776, blue: 1.000, alpha: 1)
    )
    static let strain = adaptiveColor(
        light: UIColor(red: 0.298, green: 0.290, blue: 0.792, alpha: 1),
        dark: UIColor(red: 0.761, green: 0.757, blue: 1.000, alpha: 1)
    )
    static let recovery = adaptiveColor(
        light: UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1),
        dark: UIColor(red: 0.396, green: 0.859, blue: 0.482, alpha: 1)
    )
    static let stress = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.231, blue: 0.188, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.455, blue: 0.420, alpha: 1)
    )
    static let energy = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.800, blue: 0.000, alpha: 1),
        dark: UIColor(red: 1.000, green: 0.843, blue: 0.180, alpha: 1)
    )

    // Glow variants for ring shadows
    static let accentGlow = accent.opacity(0.24)
    static let sleepGlow = sleep.opacity(0.24)
    static let strainGlow = strain.opacity(0.24)
    static let recoveryGlow = recovery.opacity(0.24)
    static let stressGlow = stress.opacity(0.24)
    static let energyGlow = energy.opacity(0.24)

    static func glow(for tint: Color) -> Color {
        switch tint {
        case accent: return accentGlow
        case sleep: return sleepGlow
        case strain: return strainGlow
        case recovery: return recoveryGlow
        case stress: return stressGlow
        case energy: return energyGlow
        default: return tint.opacity(0.35)
        }
    }

    static var tabBarBackgroundUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 0.40)
                : UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.26)
        }
    }

    static var tabBarSelectedUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.678, green: 0.776, blue: 1.000, alpha: 1)
                : UIColor(red: 0.000, green: 0.345, blue: 0.737, alpha: 1)
        }
    }

    static var tabBarNormalUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.620, green: 0.651, blue: 0.714, alpha: 1)
                : UIColor(red: 0.447, green: 0.467, blue: 0.518, alpha: 1)
        }
    }

    static var tabBarShadowUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.08)
                : UIColor(white: 0.0, alpha: 0.06)
        }
    }
}
