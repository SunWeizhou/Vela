import SwiftUI

// MARK: - VelaTheme — Apple Design System Tokens
// Chinese default, English fallback. Dark mode adaptive. SF Pro typography.

enum VelaTheme {

    // MARK: - Hex Helper

    private static func hex(_ value: String) -> UIColor {
        let hex = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
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
        Color(UIColor { $0.userInterfaceStyle == .dark ? hex(dark) : hex(light) })
    }

    // MARK: - Surface

    static let bg            = adaptive("#F5F3F0", "#100F0D")
    static let surface       = adaptive("#F2F0ED", "#1C1B18")
    static let cardBg        = adaptive("#FFFFFF", "#0A0908")
    static let elevatedBg    = adaptive("#F8F7F4", "#161512")
    static let groupedBg     = adaptive("#F5F3F0", "#100F0D")

    // MARK: - Foreground

    static let fg            = adaptive("#1A1917", "#F2EFE8")
    static let fg2           = adaptive("#6E6A63", "#BFB9AC")
    static let muted         = adaptive("#8E8A80", "#7E7A70")
    static let meta          = adaptive("#BFB9AC", "#6E6A63")

    // MARK: - Accent

    static let accent        = adaptive("#C56B4A", "#D48463")
    static let accentOn      = adaptive("#FFFFFF", "#FFFFFF")
    static let accentHover   = adaptive("#D48463", "#E8CFC3")
    static let accentActive  = adaptive("#A35338", "#BD7051")

    // MARK: - Borders

    static let border        = adaptive("#D5D0C8", "#444038")
    static let borderSoft    = adaptive("#E8E4DD", "#2E2B25")

    // MARK: - Semantic Colors

    static let success       = Color(hex: "#5B8C6F")
    static let warn          = Color(hex: "#B8843E")
    static let danger        = Color(hex: "#A85260")

    /// 负荷 Strain — amber
    static let strainColor   = adaptive("#B8843E", "#D0A050")
    /// 恢复 Recovery — sage
    static let recoveryColor = adaptive("#5B8C6F", "#73A385")
    /// 睡眠 Sleep — indigo
    static let sleepColor    = adaptive("#6B6FA0", "#8588B8")
    /// 压力 Stress — rose
    static let stressColor   = adaptive("#A85260", "#C4707A")
    /// 能量 Energy — gold
    static let energyColor   = adaptive("#C4952E", "#DCB048")

    // MARK: - Typography

    static let fontDisplay: Font.Design = .default
    static let fontBody: Font.Design     = .default
    static let fontMono: Font.Design     = .monospaced

    static func largeTitle() -> Font   { .system(size: 34, weight: .bold, design: .default) }
    static func title1() -> Font       { .system(size: 28, weight: .bold, design: .default) }
    static func title2() -> Font       { .system(size: 22, weight: .semibold, design: .default) }
    static func title3() -> Font       { .system(size: 20, weight: .semibold, design: .default) }
    static func headline() -> Font     { .system(size: 17, weight: .semibold, design: .default) }
    static func body() -> Font         { .system(size: 17, weight: .regular, design: .default) }
    static func callout() -> Font      { .system(size: 16, weight: .regular, design: .default) }
    static func subheadline() -> Font  { .system(size: 15, weight: .regular, design: .default) }
    static func footnote() -> Font     { .system(size: 13, weight: .regular, design: .default) }
    static func caption1() -> Font     { .system(size: 12, weight: .regular, design: .default) }
    static func caption2() -> Font     { .system(size: 11, weight: .regular, design: .default) }
    static func monoCaption() -> Font  { .system(size: 12, weight: .regular, design: .monospaced) }
    static func monoValue() -> Font    { .system(size: 15, weight: .medium, design: .monospaced) }

    // MARK: - Spacing (8px grid)

    static let space1: CGFloat  = 4
    static let space2: CGFloat  = 8
    static let space3: CGFloat  = 12
    static let space4: CGFloat  = 16
    static let space5: CGFloat  = 20
    static let space6: CGFloat  = 24
    static let space8: CGFloat  = 32
    static let space12: CGFloat = 48
    static let cardGap: CGFloat = 14
    static let pagePadding: CGFloat = 20
    static let tabBarHeight: CGFloat = 84

    // MARK: - Radius

    static let radiusSm: CGFloat   = 8
    static let radiusMd: CGFloat   = 12
    static let radiusLg: CGFloat   = 18
    static let radiusXl: CGFloat   = 24
    static let radiusPill: CGFloat = 980

    // MARK: - Shadow

    static func cardShadow(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.04)
    }

    // MARK: - Animation

    static let fast = 0.15
    static let standard = 0.22
    static let ease = UnitCurve.easeInOut

    // MARK: - Ring Sizes

    static let ringLg: CGFloat  = 120
    static let ringMd: CGFloat  = 72
    static let ringSm: CGFloat  = 48
}

// MARK: - Color hex convenience

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:  (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Localization Helper (Chinese default, English fallback)

enum VelaLoc {

    // Tab bar
    static var tabToday: LocalizedStringKey    { "今日" }
    static var tabJournal: LocalizedStringKey  { "手记" }
    static var tabTraining: LocalizedStringKey { "训练" }
    static var tabVitals: LocalizedStringKey   { "体征" }
    static var tabPlus: LocalizedStringKey     { "更多" }

    // Common
    static var cancel: LocalizedStringKey     { "取消" }
    static var done: LocalizedStringKey       { "完成" }
    static var setup: LocalizedStringKey      { "设置" }
    static var comingSoon: LocalizedStringKey { "即将推出" }

    // Today
    static var readiness: LocalizedStringKey    { "就绪度" }
    static var strain: LocalizedStringKey       { "负荷" }
    static var recovery: LocalizedStringKey     { "恢复" }
    static var sleep: LocalizedStringKey        { "睡眠" }
    static var stress: LocalizedStringKey       { "压力" }
    static var energy: LocalizedStringKey       { "能量" }
    static var nutrition: LocalizedStringKey    { "营养" }
    static var coachInsight: LocalizedStringKey { "教练洞察" }
    static var todayPlan: LocalizedStringKey    { "今日计划" }
    static var askCoach: LocalizedStringKey     { "问 Coach" }

    // Vitals
    static var hrv: LocalizedStringKey            { "心率变异性" }
    static var rhr: LocalizedStringKey            { "静息心率" }
    static var spo2: LocalizedStringKey           { "血氧饱和度" }
    static var temperature: LocalizedStringKey    { "手腕温度" }
    static var bloodPressure: LocalizedStringKey  { "血压" }
    static var dataFreshness: LocalizedStringKey  { "数据已同步" }
    static var latest: LocalizedStringKey         { "最新" }
    static var hoursAgo: LocalizedStringKey       { "小时前" }
    static var needSetup: LocalizedStringKey      { "需要设置" }
    static var connectDevice: LocalizedStringKey  { "连接设备以获取数据" }

    // Training
    static var trainingWindow: LocalizedStringKey   { "训练窗口" }
    static var adaptiveTraining: LocalizedStringKey { "自适应训练" }
    static var originalPlan: LocalizedStringKey     { "原始计划" }
    static var adaptedPlan: LocalizedStringKey      { "调整后" }
    static var upcoming: LocalizedStringKey         { "即将进行" }
    static var noWorkoutsToday: LocalizedStringKey  { "今日无训练计划" }

    // Journal
    static var todayNote: LocalizedStringKey    { "今日记录" }
    static var writeNote: LocalizedStringKey    { "写手记…" }
    static var symptoms: LocalizedStringKey     { "症状" }
    static var mood: LocalizedStringKey         { "心情" }
    static var diet: LocalizedStringKey         { "饮食" }
    static var trainingNote: LocalizedStringKey { "训练备注" }
    static var noEntries: LocalizedStringKey    { "暂无手记" }

    // Coach
    static var coachTitle: LocalizedStringKey   { "Vela Coach" }
    static var coachOnline: LocalizedStringKey  { "基于今日数据分析中" }
    static var coachWelcome: LocalizedStringKey { "你的 AI 身体智能代理。可以讨论训练、恢复、睡眠、营养，我会根据你的健康数据给出个性化建议。" }
    static var newChat: LocalizedStringKey      { "新建对话" }

    // Settings
    static var settings: LocalizedStringKey      { "我的" }
    static var healthData: LocalizedStringKey    { "健康数据源" }
    static var notifications: LocalizedStringKey { "通知" }
    static var appearance: LocalizedStringKey    { "外观" }
    static var privacy: LocalizedStringKey       { "隐私" }
    static var about: LocalizedStringKey         { "关于" }
    static var language: LocalizedStringKey      { "语言" }
    static var theme: LocalizedStringKey         { "主题" }

    // Plus actions
    static var recordDiet: LocalizedStringKey     { "记录饮食" }
    static var writeJournal: LocalizedStringKey   { "写手记" }
    static var recordWeightBP: LocalizedStringKey { "记录体重血压" }
    static var scanFood: LocalizedStringKey       { "扫描食物" }
    static var recordWeight: LocalizedStringKey   { "记录体重/血压" }
    static var foodScan: LocalizedStringKey       { "食物扫描" }

    // Evidence
    static var evidenceChain: LocalizedStringKey   { "证据链" }
    static var limitingFactors: LocalizedStringKey { "限制因素" }
    static var relatedWorkouts: LocalizedStringKey { "关联训练" }

    // Data coverage
    static var dataCoverage: LocalizedStringKey { "数据覆盖" }
    static var trustCenter: LocalizedStringKey  { "信任中心" }
    static var memoryInbox: LocalizedStringKey  { "记忆收件箱" }
}

// MARK: - Backward Compatibility Aliases

extension VelaTheme {
    // Old surface names → new
    static let background = bg
    static let surfaceContainerLowest = cardBg
    static let surfaceContainerLow = elevatedBg
    static let surfaceContainer = surface
    static let surfaceContainerHigh = elevatedBg
    static let surfaceContainerHighest = cardBg
    static let elevatedSurface = elevatedBg

    // Old text names → new
    static let onSurface = fg
    static let onSurfaceVariant = fg2
    static let quaternaryText = meta
    static let primaryText = fg
    static let secondaryText = fg2
    static let mutedText = muted

    // Old border names → new
    static let outline = borderSoft
    static let outlineVariant = border
    static let stroke = borderSoft

    // Old semantic → new
    static let recovery = recoveryColor
    static let sleep = sleepColor
    static let strain = strainColor
    static let stress = stressColor
    static let energy = energyColor
    static let error = danger

    // Old containers
    static let recoveryContainer = recoveryColor.opacity(0.12)
    static let sleepContainer = sleepColor.opacity(0.12)
    static let strainContainer = strainColor.opacity(0.12)
    static let stressContainer = stressColor.opacity(0.12)
    static let energyContainer = energyColor.opacity(0.12)
    static let errorContainer = danger.opacity(0.12)

    // Old on-colors
    static let onRecovery = Color.white
    static let onSleep = Color.white
    static let onStrain = Color.white
    static let onStress = Color.white
    static let onEnergy = Color.white
    static let onError = Color.white
    static let onPrimary = Color.white

    // Old glows
    static let glowRecovery = recoveryColor.opacity(0.24)
    static let glowSleep = sleepColor.opacity(0.24)
    static let glowStrain = strainColor.opacity(0.24)
    static let glowStress = stressColor.opacity(0.24)
    static let glowEnergy = energyColor.opacity(0.24)
    static let accentGlow = accent.opacity(0.24)
    static let primaryGlow = accent.opacity(0.24)
    static let secondaryGlow = recoveryColor.opacity(0.24)
    static let tertiaryGlow = sleepColor.opacity(0.24)
    static let quaternaryGlow = strainColor.opacity(0.24)
    static let quinaryGlow = stressColor.opacity(0.24)
    static let senaryGlow = energyColor.opacity(0.24)
    static let recoveryGlow = recoveryColor.opacity(0.24)
    static let sleepGlow = sleepColor.opacity(0.24)
    static let strainGlow = strainColor.opacity(0.24)
    static let stressGlow = stressColor.opacity(0.24)
    static let energyGlow = energyColor.opacity(0.24)

    static func glow(for color: Color) -> Color { color.opacity(0.24) }

    // Old spacing → new
    static let spaceXXS: CGFloat = 2
    static let spaceXS: CGFloat = 4
    static let spaceSM: CGFloat = 8
    static let spaceMD: CGFloat = 12
    static let spaceLG: CGFloat = 16
    static let spaceXL: CGFloat = 20
    static let space2XL: CGFloat = 24
    static let space3XL: CGFloat = 32
    static let space4XL: CGFloat = 48

    // Old radius → new
    static let radiusCard: CGFloat = 18
    static let radiusHero: CGFloat = 20
    static let radiusLG: CGFloat = 18
    static var cornerRadiusCard: CGFloat { radiusCard }
    static var cornerRadiusTile: CGFloat { 14 }
    static var cornerRadiusHero: CGFloat { radiusHero }

    // Old layout
    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 32

    // Old typography (static properties for backward compat)
    static let heroMetric: Font = .system(size: 34, weight: .bold, design: .default)
    static let pageTitle: Font = .system(size: 28, weight: .bold, design: .default)
    static let sectionTitle: Font = .system(size: 22, weight: .semibold, design: .default)
    static let metricValue: Font = .system(size: 20, weight: .semibold, design: .default)
    static let cardTitle: Font = .system(size: 17, weight: .semibold, design: .default)
    static let bodyFont: Font = .system(size: 17, weight: .regular, design: .default)
    static let captionFont: Font = .system(size: 14, weight: .regular, design: .default)
    static let microFont: Font = .system(size: 12, weight: .regular, design: .default)

    // Old misc
    static let subtleFill = Color(white: 0).opacity(0.06)
    static let strongControl = accent
    static let cardBackground = cardBg
    static let heroCardBackground = elevatedBg
    static let backgroundSecondary = groupedBg
    static let backgroundTertiary = cardBg
    static let inverseSurface = fg
    static let inverseOnSurface = bg
    static let inversePrimary = Color.white
    static let inverseText = bg
    static let cardShadowColor = Color.black.opacity(0.04)
    static let innerGlowOpacity: Double = 0.06

    // Old primary aliases
    static let primary = accent
    static let primaryHover = accentHover
    static let primaryActive = accentActive
    static let primaryContainer = accent.opacity(0.12)
    static let onPrimaryContainer = accent

    // Old secondary/tertiary aliases
    static let secondary = recoveryColor
    static let tertiary = sleepColor
    static let quaternary = strainColor
    static let quinary = stressColor
    static let senary = energyColor
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
    static let onSecondaryContainer = recoveryColor
    static let onTertiaryContainer = sleepColor
    static let onQuaternaryContainer = strainColor
    static let onQuinaryContainer = stressColor
    static let onSenaryContainer = energyColor
    static let onRecoveryContainer = recoveryColor
    static let onSleepContainer = sleepColor
    static let onStrainContainer = strainColor
    static let onStressContainer = stressColor
    static let onEnergyContainer = energyColor
    static let onErrorContainer = danger

    // Tab bar compat
    static let tabBarBackground = bg.opacity(0.72)
    static let tabBarBackgroundUIColor = hex("#FFFFFF").withAlphaComponent(0.72)
    static let tabBarSelectedUIColor = hex("#0071E3")
    static let tabBarNormalUIColor = hex("#86868B")
    static let tabBarShadowUIColor = UIColor.black.withAlphaComponent(0.08)
}
