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

    // Claude.ai-inspired warm paper background layers from Stitch.
    static let background = adaptiveColor(
        light: UIColor(red: 0.969, green: 0.945, blue: 0.902, alpha: 1),
        dark: UIColor(red: 0.090, green: 0.075, blue: 0.059, alpha: 1)
    )
    static let backgroundSecondary = adaptiveColor(
        light: UIColor(red: 0.937, green: 0.902, blue: 0.847, alpha: 1),
        dark: UIColor(red: 0.129, green: 0.106, blue: 0.086, alpha: 1)
    )
    static let backgroundTertiary = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.992, blue: 0.973, alpha: 1),
        dark: UIColor(red: 0.165, green: 0.137, blue: 0.110, alpha: 1)
    )
    static let surface = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.992, blue: 0.973, alpha: 0.92),
        dark: UIColor(red: 0.129, green: 0.106, blue: 0.086, alpha: 0.94)
    )
    static let elevatedSurface = adaptiveColor(
        light: UIColor(red: 0.984, green: 0.969, blue: 0.933, alpha: 0.98),
        dark: UIColor(red: 0.165, green: 0.137, blue: 0.110, alpha: 0.98)
    )
    static let stroke = adaptiveColor(
        light: UIColor(red: 0.871, green: 0.824, blue: 0.757, alpha: 1),
        dark: UIColor(red: 0.251, green: 0.212, blue: 0.176, alpha: 1)
    )

    // Card design tokens
    static let cardBackground = adaptiveColor(
        light: UIColor(red: 1.000, green: 0.992, blue: 0.973, alpha: 0.92),
        dark: UIColor(red: 0.129, green: 0.106, blue: 0.086, alpha: 0.94)
    )
    static let heroCardBackground = adaptiveColor(
        light: UIColor(red: 0.984, green: 0.969, blue: 0.933, alpha: 0.98),
        dark: UIColor(red: 0.165, green: 0.137, blue: 0.110, alpha: 0.98)
    )
    static let cardShadowColor = adaptiveColor(
        light: UIColor(white: 0.0, alpha: 0.055),
        dark: UIColor(white: 0.0, alpha: 0.32)
    )
    static let innerGlowOpacity: Double = 0.06
    static let primaryText = adaptiveColor(
        light: UIColor(red: 0.169, green: 0.141, blue: 0.106, alpha: 1),
        dark: UIColor(red: 0.957, green: 0.922, blue: 0.867, alpha: 1)
    )
    static let secondaryText = adaptiveColor(
        light: UIColor(red: 0.400, green: 0.357, blue: 0.294, alpha: 1),
        dark: UIColor(red: 0.804, green: 0.749, blue: 0.682, alpha: 1)
    )
    static let mutedText = adaptiveColor(
        light: UIColor(red: 0.569, green: 0.522, blue: 0.463, alpha: 1),
        dark: UIColor(red: 0.620, green: 0.565, blue: 0.498, alpha: 1)
    )

    static let inverseText = adaptiveColor(
        light: UIColor.white,
        dark: UIColor.black
    )
    static let subtleFill = adaptiveColor(
        light: UIColor(red: 0.937, green: 0.902, blue: 0.847, alpha: 0.72),
        dark: UIColor(red: 0.251, green: 0.212, blue: 0.176, alpha: 0.72)
    )
    static let strongControl = adaptiveColor(
        light: UIColor(red: 0.169, green: 0.141, blue: 0.106, alpha: 1),
        dark: UIColor(red: 0.957, green: 0.922, blue: 0.867, alpha: 1)
    )
    static let tabBarBackground = adaptiveColor(
        light: UIColor(red: 0.969, green: 0.945, blue: 0.902, alpha: 0.94),
        dark: UIColor(red: 0.090, green: 0.075, blue: 0.059, alpha: 0.96)
    )

    // Accent
    static let accent = adaptiveColor(
        light: UIColor(red: 0.718, green: 0.392, blue: 0.271, alpha: 1),
        dark: UIColor(red: 0.816, green: 0.518, blue: 0.384, alpha: 1)
    )

    // Metric colors from Stitch: calm and clinical, not neon.
    static let sleep = adaptiveColor(
        light: UIColor(red: 0.435, green: 0.451, blue: 0.659, alpha: 1),
        dark: UIColor(red: 0.604, green: 0.620, blue: 0.820, alpha: 1)
    )
    static let strain = adaptiveColor(
        light: UIColor(red: 0.722, green: 0.420, blue: 0.294, alpha: 1),
        dark: UIColor(red: 0.871, green: 0.580, blue: 0.455, alpha: 1)
    )
    static let recovery = adaptiveColor(
        light: UIColor(red: 0.373, green: 0.549, blue: 0.451, alpha: 1),
        dark: UIColor(red: 0.553, green: 0.718, blue: 0.612, alpha: 1)
    )
    static let stress = adaptiveColor(
        light: UIColor(red: 0.663, green: 0.337, blue: 0.396, alpha: 1),
        dark: UIColor(red: 0.820, green: 0.518, blue: 0.576, alpha: 1)
    )
    static let energy = adaptiveColor(
        light: UIColor(red: 0.725, green: 0.518, blue: 0.180, alpha: 1),
        dark: UIColor(red: 0.902, green: 0.690, blue: 0.353, alpha: 1)
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
                ? UIColor(red: 0.090, green: 0.075, blue: 0.059, alpha: 1)
                : UIColor(red: 0.969, green: 0.945, blue: 0.902, alpha: 1)
        }
    }

    static var tabBarSelectedUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.816, green: 0.518, blue: 0.384, alpha: 1)
                : UIColor(red: 0.718, green: 0.392, blue: 0.271, alpha: 1)
        }
    }

    static var tabBarNormalUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.620, green: 0.565, blue: 0.498, alpha: 1)
                : UIColor(red: 0.569, green: 0.522, blue: 0.463, alpha: 1)
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
