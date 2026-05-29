import SwiftUI
import UIKit

enum VelaTheme {

    // MARK: - Hex → UIColor Helper

    private static func hexColor(_ hex: String) -> UIColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        return UIColor(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    private static func adaptiveColor(lightHex: String, darkHex: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? hexColor(darkHex) : hexColor(lightHex)
        })
    }

    // MARK: - Canvas / Background

    /// Warm off-white canvas (light) / deep warm black (dark)
    static let background = adaptiveColor(lightHex: "#F5F3F0", darkHex: "#100F0D")

    /// MD3 surface (same as background at the lowest level)
    static let surface = adaptiveColor(lightHex: "#F5F3F0", darkHex: "#100F0D")

    // MARK: - Surface Containers

    /// Primary card surface — clean white / near-black
    static let surfaceContainerLowest = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#0A0908")

    /// Slightly elevated surface for nested or hero cards
    static let surfaceContainerLow = adaptiveColor(lightHex: "#F8F7F4", darkHex: "#161512")

    static let surfaceContainer = adaptiveColor(lightHex: "#F2F0ED", darkHex: "#1C1B18")

    static let surfaceContainerHigh = adaptiveColor(lightHex: "#EDEBE7", darkHex: "#24221E")

    static let surfaceContainerHighest = adaptiveColor(lightHex: "#E8E5E0", darkHex: "#2E2B25")

    // MARK: - On-Surface (Text)

    /// Primary text — near-black warmth / warm parchment
    static let onSurface = adaptiveColor(lightHex: "#1A1917", darkHex: "#F2EFE8")

    /// Secondary text — descriptions, metadata, labels
    static let onSurfaceVariant = adaptiveColor(lightHex: "#6E6A63", darkHex: "#A09B92")

    /// Tertiary text — timestamps, captions, tertiary labels
    static let muted = adaptiveColor(lightHex: "#A09B92", darkHex: "#7A756E")

    // MARK: - Outlines

    /// Hairline card borders — 0.5pt
    static let outline = adaptiveColor(lightHex: "#E8E4DD", darkHex: "#2E2B25")

    /// Stronger borders for focused states, input fields
    static let outlineVariant = adaptiveColor(lightHex: "#D5D0C8", darkHex: "#3E3B35")

    // MARK: - Primary (Clay / Brand)

    /// Primary CTAs, brand identity, active states
    static let primary = adaptiveColor(lightHex: "#C56B4A", darkHex: "#D48463")
    static let primaryContainer = adaptiveColor(lightHex: "#F5E8E0", darkHex: "#4A2215")
    static let onPrimary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onPrimaryContainer = adaptiveColor(lightHex: "#7A3D2A", darkHex: "#E8CFC3")

    // MARK: - Secondary (Sage / Recovery)

    /// Recovery, readiness, positive health indicators
    static let secondary = adaptiveColor(lightHex: "#5B8C6F", darkHex: "#73A385")
    static let secondaryContainer = adaptiveColor(lightHex: "#E0F0E5", darkHex: "#1F3D2A")
    static let onSecondary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onSecondaryContainer = adaptiveColor(lightHex: "#1F3D2A", darkHex: "#C2DFC9")

    // MARK: - Tertiary (Indigo / Sleep)

    /// Sleep metrics, circadian context
    static let tertiary = adaptiveColor(lightHex: "#6B6FA0", darkHex: "#8588B8")
    static let tertiaryContainer = adaptiveColor(lightHex: "#E6E7F5", darkHex: "#2A2D52")
    static let onTertiary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onTertiaryContainer = adaptiveColor(lightHex: "#2A2D52", darkHex: "#CDCFEA")

    // MARK: - Quaternary (Amber / Strain)

    /// Training load, exertion, energy expenditure
    static let quaternary = adaptiveColor(lightHex: "#B8843E", darkHex: "#D0A050")
    static let quaternaryContainer = adaptiveColor(lightHex: "#FDF0DB", darkHex: "#4A3010")
    static let onQuaternary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onQuaternaryContainer = adaptiveColor(lightHex: "#4A3010", darkHex: "#FDF0DB")

    // MARK: - Quinary (Rose / Stress)

    /// Stress indicators, sympathetic load, warnings
    static let quinary = adaptiveColor(lightHex: "#A85260", darkHex: "#C4707A")
    static let quinaryContainer = adaptiveColor(lightHex: "#FAE5E8", darkHex: "#4A1A25")
    static let onQuinary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onQuinaryContainer = adaptiveColor(lightHex: "#4A1A25", darkHex: "#FAE5E8")

    // MARK: - Senary (Gold / Energy)

    /// Energy bank, vitality, readiness
    static let senary = adaptiveColor(lightHex: "#C4952E", darkHex: "#DCB048")
    static let senaryContainer = adaptiveColor(lightHex: "#FDF4DB", darkHex: "#4A3510")
    static let onSenary = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#FFFFFF")
    static let onSenaryContainer = adaptiveColor(lightHex: "#4A3510", darkHex: "#FDF4DB")

    // MARK: - Error

    static let error = adaptiveColor(lightHex: "#BA1A1A", darkHex: "#FFB4AB")
    static let errorContainer = adaptiveColor(lightHex: "#FFDAD6", darkHex: "#93000A")
    static let onError = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#690005")
    static let onErrorContainer = adaptiveColor(lightHex: "#410002", darkHex: "#FFDAD6")

    // MARK: - Inverse

    static let inverseSurface = adaptiveColor(lightHex: "#1C1B18", darkHex: "#F2EFE8")
    static let inverseOnSurface = adaptiveColor(lightHex: "#F2EFE8", darkHex: "#1C1B18")
    static let inversePrimary = adaptiveColor(lightHex: "#D48463", darkHex: "#C56B4A")

    // MARK: - Semantic Aliases

    static let recovery = secondary
    static let sleep = tertiary
    static let strain = quaternary
    static let stress = quinary
    static let energy = senary

    // MARK: - Glass Effect Opacity Constants

    /// Floating controls: white @ 60% (light), #1C1B18 @ 55% (dark)
    static let glassFloatingLight = Color(white: 1.0, opacity: 0.60)
    static let glassFloatingDark = adaptiveColor(lightHex: "#1C1B18", darkHex: "#1C1B18").opacity(0.55)

    /// Overlays & sheets: white @ 40% (light), #1C1B18 @ 35% (dark)
    static let glassOverlayLight = Color(white: 1.0, opacity: 0.40)
    static let glassOverlayDark = adaptiveColor(lightHex: "#1C1B18", darkHex: "#1C1B18").opacity(0.35)

    // MARK: - Design Tokens

    static let cornerRadiusCard: CGFloat = 20
    static let cornerRadiusHero: CGFloat = 24
    static let cornerRadiusTile: CGFloat = 16
    static let cornerRadiusFull: CGFloat = 9999

    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let cardGap: CGFloat = 16

    // MARK: - Typography

    /// 34pt bold monospaced — hero readiness score, biological age
    static var heroMetric: Font { .system(size: 34, weight: .bold, design: .monospaced) }

    /// 22pt semibold — screen headers
    static var pageTitle: Font { .system(size: 22, weight: .semibold) }

    /// 20pt semibold monospaced — secondary metric values
    static var metricValue: Font { .system(size: 20, weight: .semibold, design: .monospaced) }

    /// 17pt semibold — card headings, section labels
    static var cardTitle: Font { .system(size: 17, weight: .semibold) }

    // MARK: - Glow Variants (Backward Compat)

    static let accentGlow = primary.opacity(0.24)
    static let primaryGlow = primary.opacity(0.24)
    static let secondaryGlow = secondary.opacity(0.24)
    static let tertiaryGlow = tertiary.opacity(0.24)
    static let quaternaryGlow = quaternary.opacity(0.24)
    static let quinaryGlow = quinary.opacity(0.24)
    static let senaryGlow = senary.opacity(0.24)

    static let recoveryGlow = recovery.opacity(0.24)
    static let sleepGlow = sleep.opacity(0.24)
    static let strainGlow = strain.opacity(0.24)
    static let stressGlow = stress.opacity(0.24)
    static let energyGlow = energy.opacity(0.24)

    static func glow(for tint: Color) -> Color {
        switch tint {
        case primary, accent: return primaryGlow
        case secondary, recovery: return secondaryGlow
        case tertiary, sleep: return tertiaryGlow
        case quaternary, strain: return quaternaryGlow
        case quinary, stress: return quinaryGlow
        case senary, energy: return senaryGlow
        default: return tint.opacity(0.35)
        }
    }

    // MARK: - Backward Compatibility Aliases

    /// @deprecated Use `onSurface` instead
    static let primaryText = onSurface

    /// @deprecated Use `onSurfaceVariant` instead
    static let secondaryText = onSurfaceVariant

    /// @deprecated Use `muted` instead
    static let mutedText = muted

    /// @deprecated Use `primary` instead
    static let accent = primary

    /// @deprecated Use `primary` instead
    static let strongControl = primary

    /// @deprecated Use `outline` instead
    static let stroke = outline

    /// @deprecated Use `surfaceContainerLowest` instead
    static let cardBackground = surfaceContainerLowest

    /// @deprecated Use `surfaceContainerLow` instead
    static let elevatedSurface = surfaceContainerLow

    /// @deprecated Use `surfaceContainerLow` instead
    static let heroCardBackground = surfaceContainerLow

    /// @deprecated Use `surfaceContainer` instead
    static let backgroundSecondary = surfaceContainer

    /// @deprecated Use `surfaceContainerHighest` for the lightest/darkest variant
    static let backgroundTertiary = surfaceContainerHighest

    /// Shadow color for cards — subtle in light, slightly stronger in dark
    static let cardShadowColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.20)
            : UIColor(white: 0, alpha: 0.045)
    })

    static let innerGlowOpacity: Double = 0.06

    /// @deprecated Use `inverseOnSurface` instead
    static let inverseText = adaptiveColor(lightHex: "#FFFFFF", darkHex: "#000000")

    /// @deprecated Used for subtle fills — now uses on-surface-variant at 12% opacity
    static let subtleFill = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 0, alpha: 0.06)
    })

    /// @deprecated Tab bar background — glass-like semitransparent
    static let tabBarBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 0, blue: 0, alpha: 0.40)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 0.26)
    })

    // MARK: - Tab Bar UIKit Colors (Backward Compat)

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
                ? hexColor("#D48463")
                : hexColor("#C56B4A")
        }
    }

    static var tabBarNormalUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? hexColor("#A09B92")
                : hexColor("#6E6A63")
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
