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

    // Background layers
    static let background = adaptiveColor(
        light: UIColor(red: 0.94, green: 0.95, blue: 0.92, alpha: 1),
        dark: UIColor(red: 0.045, green: 0.052, blue: 0.050, alpha: 1)
    )
    static let backgroundSecondary = adaptiveColor(
        light: UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1),
        dark: UIColor(red: 0.070, green: 0.080, blue: 0.076, alpha: 1)
    )
    static let backgroundTertiary = adaptiveColor(
        light: UIColor(red: 0.99, green: 0.99, blue: 0.97, alpha: 1),
        dark: UIColor(red: 0.085, green: 0.094, blue: 0.090, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: UIColor(white: 1.0, alpha: 0.84),
        dark: UIColor(red: 0.120, green: 0.128, blue: 0.124, alpha: 0.88)
    )
    static let elevatedSurface = adaptiveColor(
        light: UIColor(white: 1.0, alpha: 0.94),
        dark: UIColor(red: 0.155, green: 0.164, blue: 0.158, alpha: 0.94)
    )
    static let stroke = adaptiveColor(
        light: UIColor(white: 0.0, alpha: 0.06),
        dark: UIColor(white: 1.0, alpha: 0.09)
    )

    // Card design tokens
    static let cardBackground = adaptiveColor(
        light: UIColor(white: 1.0, alpha: 0.88),
        dark: UIColor(red: 0.115, green: 0.124, blue: 0.120, alpha: 0.92)
    )
    static let heroCardBackground = adaptiveColor(
        light: UIColor(white: 1.0, alpha: 0.96),
        dark: UIColor(red: 0.145, green: 0.154, blue: 0.149, alpha: 0.96)
    )
    static let cardShadowColor = adaptiveColor(
        light: UIColor(white: 0.0, alpha: 0.08),
        dark: UIColor(white: 0.0, alpha: 0.32)
    )
    static let innerGlowOpacity: Double = 0.06
    static let primaryText = adaptiveColor(
        light: UIColor(red: 0.10, green: 0.11, blue: 0.10, alpha: 1),
        dark: UIColor(red: 0.92, green: 0.94, blue: 0.91, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: UIColor(red: 0.42, green: 0.44, blue: 0.42, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.69, blue: 0.65, alpha: 1)
    )
    static let mutedText = adaptiveColor(
        light: UIColor(red: 0.62, green: 0.64, blue: 0.60, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.52, blue: 0.49, alpha: 1)
    )

    static let inverseText = adaptiveColor(
        light: UIColor.white,
        dark: UIColor.black
    )
    static let subtleFill = adaptiveColor(
        light: UIColor(white: 0.0, alpha: 0.05),
        dark: UIColor(white: 1.0, alpha: 0.08)
    )
    static let strongControl = adaptiveColor(
        light: UIColor(red: 0.08, green: 0.09, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.88, green: 0.96, blue: 0.89, alpha: 1)
    )
    static let tabBarBackground = adaptiveColor(
        light: UIColor(white: 1.0, alpha: 0.94),
        dark: UIColor(red: 0.095, green: 0.105, blue: 0.100, alpha: 0.96)
    )

    // Accent
    static let accent = Color(red: 0.50, green: 0.88, blue: 0.75)

    // Metric colors — more vibrant
    static let sleep = Color(red: 0.55, green: 0.55, blue: 0.98)
    static let strain = Color(red: 0.98, green: 0.45, blue: 0.30)
    static let recovery = Color(red: 0.40, green: 0.90, blue: 0.68)
    static let stress = Color(red: 0.94, green: 0.42, blue: 0.62)
    static let energy = Color(red: 0.95, green: 0.80, blue: 0.28)

    // Glow variants for ring shadows
    static let accentGlow = Color(red: 0.50, green: 0.88, blue: 0.75).opacity(0.35)
    static let sleepGlow = Color(red: 0.55, green: 0.55, blue: 0.98).opacity(0.35)
    static let strainGlow = Color(red: 0.98, green: 0.45, blue: 0.30).opacity(0.35)
    static let recoveryGlow = Color(red: 0.40, green: 0.90, blue: 0.68).opacity(0.35)
    static let stressGlow = Color(red: 0.94, green: 0.42, blue: 0.62).opacity(0.35)
    static let energyGlow = Color(red: 0.95, green: 0.80, blue: 0.28).opacity(0.35)

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
                ? UIColor(red: 0.095, green: 0.105, blue: 0.100, alpha: 1)
                : UIColor(white: 1.0, alpha: 1)
        }
    }

    static var tabBarSelectedUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.88, green: 0.96, blue: 0.89, alpha: 1)
                : UIColor(red: 0.08, green: 0.09, blue: 0.08, alpha: 1)
        }
    }

    static var tabBarNormalUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.52, green: 0.55, blue: 0.52, alpha: 1)
                : UIColor(red: 0.39, green: 0.40, blue: 0.38, alpha: 1)
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
