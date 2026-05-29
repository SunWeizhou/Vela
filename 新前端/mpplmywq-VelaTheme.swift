import SwiftUI

enum VelaTheme {
    static let cornerRadiusCard: CGFloat = 20
    static let cornerRadiusTile: CGFloat = 14
    static let screenPadding: CGFloat = 20

    // Background layers
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let elevatedSurface = Color(red: 0.14, green: 0.14, blue: 0.16)
    static let stroke = Color.white.opacity(0.08)

    // Card design tokens
    static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let heroCardBackground = Color(red: 0.10, green: 0.10, blue: 0.13)
    static let cardShadowColor = Color.black.opacity(0.3)
    static let innerGlowOpacity: Double = 0.06
    static let primaryText = Color(red: 0.95, green: 0.95, blue: 0.93)
    static let secondaryText = Color(red: 0.60, green: 0.60, blue: 0.58)
    static let mutedText = Color(red: 0.42, green: 0.42, blue: 0.40)

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
}
