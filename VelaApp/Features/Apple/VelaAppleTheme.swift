import SwiftUI
import UIKit

// MARK: - VelaTheme — Apple Design System Tokens
// Replaces VelaTheme.swift. Apple's neutral palette + single #0071e3 blue accent.

enum VelaTheme {

    // MARK: - Hex Helper

    private static func hexColor(_ hex: String) -> UIColor {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        return UIColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: CGFloat(a)/255)
    }

    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? hexColor(dark) : hexColor(light) })
    }

    // MARK: - Surface Foundations

    /// Main background — white (#ffffff) / black (#000000)
    static let background = adaptive("#FFFFFF", "#000000")

    /// Grouped background — Apple pale gray (#f5f5f7) / near-black (#1C1C1E)
    static let groupedBg = adaptive("#F5F5F7", "#1C1C1E")

    /// Card surface — white (#ffffff) / dark graphite (#2C2C2E)
    static let surface = adaptive("#FFFFFF", "#2C2C2E")

    /// Secondary surface — near-white (#FBFBFD) / slightly elevated (#1C1C1E)
    static let elevatedSurface = adaptive("#FBFBFD", "#2C2C2E")

    /// Lowest surface — pure white / deepest (#1A1A1C)
    static let surfaceContainerLowest = adaptive("#FFFFFF", "#1A1A1C")

    /// Slightly elevated
    static let surfaceContainerLow = adaptive("#FBFBFD", "#242426")

    /// Mid step
    static let surfaceContainer = adaptive("#F5F5F7", "#2C2C2E")

    /// Higher step for hero cards
    static let surfaceContainerHigh = adaptive("#F0F0F2", "#343436")

    /// Highest elevation
    static let surfaceContainerHighest = adaptive("#EBEBED", "#3A3A3C")

    // MARK: - Text Ramp

    /// Primary text — #1D1D1F (near-black ink) / #F5F5F7 (warm white)
    static let onSurface = adaptive("#1D1D1F", "#F5F5F7")

    /// Secondary — #6E6E73 (neutral gray) / #A1A1A6
    static let onSurfaceVariant = adaptive("#6E6E73", "#A1A1A6")

    /// Tertiary / muted — #86868B / #6E6E73
    static let muted = adaptive("#86868B", "#6E6E73")

    /// Quaternary — #A1A1A6 / #48484A
    static let quaternaryText = adaptive("#A1A1A6", "#48484A")

    // MARK: - Borders

    /// Soft border — #D2D2D7 / #38383A
    static let outline = adaptive("#D2D2D7", "#38383A")

    /// Stronger border — #86868B / #545458
    static let outlineVariant = adaptive("#86868B", "#545458")

    // MARK: - Accent — Apple single blue #0071E3

    static let primary       = adaptive("#0071E3", "#2997FF")
    static let primaryHover  = adaptive("#0077ED", "#4DA8FF")
    static let primaryActive = adaptive("#0066CC", "#0071E3")

    static let accent        = primary
    static let accentHover   = primaryHover
    static let accentActive  = primaryActive

    static let onPrimary     = adaptive("#FFFFFF", "#FFFFFF")
    static let primaryContainer   = adaptive("#E8F2FD", "#00254D")
    static let onPrimaryContainer = primary

    // MARK: - Semantic Colors (data viz only — balanced for iOS clarity)
    static let recovery = adaptive("#22C55E", "#30D158")    // green
    static let sleep    = adaptive("#5856D6", "#7A79F2")    // indigo
    static let strain   = adaptive("#FF9500", "#FF9F0A")    // orange
    static let stress   = adaptive("#FF3B30", "#FF453A")    // red
    static let energy   = adaptive("#FFCC00", "#FFD60A")    // yellow

    // Semantic containers
    static let recoveryContainer = adaptive("#E8F8ED", "#1A3A24")
    static let sleepContainer    = adaptive("#EDEDFA", "#1E1E40")
    static let strainContainer   = adaptive("#FFF4E5", "#3D2800")
    static let stressContainer   = adaptive("#FFECEB", "#3D0505")
    static let energyContainer   = adaptive("#FFF9E0", "#3D3200")

    static let onRecovery  = adaptive("#FFFFFF", "#FFFFFF")
    static let onSleep     = adaptive("#FFFFFF", "#FFFFFF")
    static let onStrain    = adaptive("#FFFFFF", "#FFFFFF")
    static let onStress    = adaptive("#FFFFFF", "#FFFFFF")
    static let onEnergy    = adaptive("#FFFFFF", "#FFFFFF")

    static let onRecoveryContainer = recovery
    static let onSleepContainer    = sleep
    static let onStrainContainer   = strain
    static let onStressContainer   = stress
    static let onEnergyContainer   = energy

    // Old semantic alias compat
    static let secondary = recovery
    static let tertiary = sleep
    static let quaternary = strain
    static let quinary = stress
    static let senary = energy

    static let secondaryContainer = recoveryContainer
    static let tertiaryContainer = sleepContainer
    static let quaternaryContainer = strainContainer
    static let quinaryContainer = stressContainer
    static let senaryContainer = energyContainer

    static let onSecondary = onRecovery
    static let onTertiary = onSleep
    static let onQuaternary = onStrain
    static let onQuinary = onStress
    static let onSenary = onEnergy

    static let onSecondaryContainer = onRecoveryContainer
    static let onTertiaryContainer = onSleepContainer
    static let onQuaternaryContainer = onStrainContainer
    static let onQuinaryContainer = onStressContainer
    static let onSenaryContainer = onEnergyContainer

    // MARK: - Error
    static let error = adaptive("#FF3B30", "#FF453A")
    static let errorContainer = adaptive("#FFECEB", "#3D0505")
    static let onError = adaptive("#FFFFFF", "#FFFFFF")
    static let onErrorContainer = adaptive("#CC0000", "#FF6961")

    // MARK: - Inverse
    static let inverseSurface = adaptive("#1D1D1F", "#F5F5F7")
    static let inverseOnSurface = adaptive("#F5F5F7", "#1D1D1F")
    static let inversePrimary = adaptive("#FFFFFF", "#000000")

    // MARK: - Glow / Shadow
    static let glowRecovery = recovery.opacity(0.24)
    static let glowSleep    = sleep.opacity(0.24)
    static let glowStrain   = strain.opacity(0.24)
    static let glowStress   = stress.opacity(0.24)
    static let glowEnergy   = energy.opacity(0.24)
    static let accentGlow   = accent.opacity(0.24)
    static let primaryGlow  = primary.opacity(0.24)
    static let secondaryGlow = recovery.opacity(0.24)
    static let tertiaryGlow  = sleep.opacity(0.24)
    static let quaternaryGlow = strain.opacity(0.24)
    static let quinaryGlow   = stress.opacity(0.24)
    static let senaryGlow    = energy.opacity(0.24)
    static let recoveryGlow = recovery.opacity(0.24)
    static let sleepGlow    = sleep.opacity(0.24)
    static let strainGlow   = strain.opacity(0.24)
    static let stressGlow   = stress.opacity(0.24)
    static let energyGlow   = energy.opacity(0.24)

    static func glow(for color: Color) -> Color { color.opacity(0.24) }

    static let cardShadowColor = Color.black.opacity(0.04)
    static let innerGlowOpacity: Double = 0.06

    // MARK: - Spacing
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let space2XL: CGFloat = 24
    static let space3XL: CGFloat = 32
    static let space4XL: CGFloat = 48

    // MARK: - Radius
    static let radiusSM: CGFloat   = 8
    static let radiusMD: CGFloat   = 12
    static let radiusLG: CGFloat   = 18
    static let radiusCard: CGFloat  = 18
    static let radiusHero: CGFloat  = 20
    static let radiusPill: CGFloat  = 980

    // MARK: - Screen / Layout
    static let screenPadding: CGFloat = 20
    static let sectionGap:    CGFloat = 32
    static let cardGap:       CGFloat = 16

    // MARK: - Typography
    static let heroMetric: Font   = .system(size: 34, weight: .bold, design: .default)
    static let pageTitle: Font    = .system(size: 28, weight: .bold, design: .default)
    static let sectionTitle: Font  = .system(size: 22, weight: .semibold, design: .default)
    static let metricValue: Font  = .system(size: 20, weight: .semibold, design: .default)
    static let cardTitle: Font    = .system(size: 17, weight: .semibold, design: .default)
    static let bodyFont: Font     = .system(size: 17, weight: .regular, design: .default)
    static let captionFont: Font  = .system(size: 14, weight: .regular, design: .default)
    static let microFont: Font    = .system(size: 12, weight: .regular, design: .default)

    // MARK: - Misc
    static let subtleFill = Color(white: 0).opacity(0.06)
    static let strongControl = accent

    // MARK: - Deprecated compat aliases (all existing views reference these)
    static let primaryText = onSurface
    static let secondaryText = onSurfaceVariant
    static let mutedText = muted
    static let stroke = outline
    static let cardBackground = surfaceContainerLowest
    static let heroCardBackground = surfaceContainerLow
    static let backgroundSecondary = groupedBg
    static let backgroundTertiary = surfaceContainerHigh
    static let inverseText = inverseOnSurface

    static let tabBarBackground = adaptive("#FFFFFF", "#1C1C1E").opacity(0.72)
    static let tabBarBackgroundUIColor = hexColor("#FFFFFF").withAlphaComponent(0.72)
    static let tabBarSelectedUIColor = hexColor("#0071E3")
    static let tabBarNormalUIColor = hexColor("#86868B")
    static let tabBarShadowUIColor = UIColor.black.withAlphaComponent(0.08)
}
