import SwiftUI
import UIKit

// MARK: - VelaTheme — Signal Intelligence Design Tokens
// Cool neutral surfaces, one recognizable brand accent, and restrained
// health-state color. The UI should feel analytical without becoming clinical.

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

    private static func adaptiveUIColor(_ light: String, _ dark: String) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? hex(dark) : hex(light) }
    }

    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(adaptiveUIColor(light, dark))
    }

    // MARK: - Surface

    static let backgroundUIColor = adaptiveUIColor("#F4F6FA", "#080A0F")
    static let bg            = Color(backgroundUIColor)
    static let systemGroupedBackground = bg
    static let secondaryGroupedBackground = adaptive("#E9EDF5", "#121620")
    static let tertiaryGroupedBackground = adaptive("#DEE4EE", "#1B2230")
    static let surface       = adaptive("#F4F6FA", "#080A0F")
    static let cardBg        = adaptive("#FFFFFF", "#121620")
    static let elevatedBg    = adaptive("#E9EDF5", "#1B2230")
    static let groupedBg     = bg

    // MARK: - iOS 26 Glassmorphic Tokens
    static let glassCardBgAdaptive   = adaptive("#FFFFFF", "#121620")
    static let glassCardStrokeColor  = adaptive("#FFFFFF", "#FFFFFF")
    static let glassAccentGlow       = adaptive("#5664E8", "#7F8CFF").opacity(0.18)
    static let glassRecoveryGlow     = adaptive("#159A7B", "#4DD6AD").opacity(0.16)
    static let glassSleepGlow        = adaptive("#6B5EDB", "#A99DFF").opacity(0.16)
    static let glassStressGlow       = adaptive("#D64D72", "#FF7C9B").opacity(0.16)
    static let glassEnergyGlow       = adaptive("#C88A18", "#F2BC4D").opacity(0.16)


    // MARK: - Foreground

    static let fg            = Color(uiColor: .label)
    static let fg2           = Color(uiColor: .secondaryLabel)
    static let muted         = Color(uiColor: .secondaryLabel)
    static let meta          = Color(uiColor: .tertiaryLabel)

    // MARK: - Accent

    /// Vela Signal Blue: recognizable, calm, and separate from health states.
    static let accent        = adaptive("#5664E8", "#7F8CFF")
    static let accentOn      = adaptive("#FFFFFF", "#FFFFFF")
    static let accentHover   = adaptive("#4654D7", "#96A0FF")
    static let accentActive  = adaptive("#3543C1", "#6573ED")

    // MARK: - Borders

    static let border        = Color(uiColor: .separator)
    static let borderSoft    = Color(uiColor: .separator).opacity(0.45)
    static let separator     = Color(uiColor: .separator)
    static let separatorSoft = Color(uiColor: .separator).opacity(0.38)

    // MARK: - Semantic Colors

    static let success       = Color(uiColor: .systemGreen)
    static let warn          = Color(uiColor: .systemOrange)
    static let danger        = Color(uiColor: .systemRed)

    /// 负荷 Strain — amber/blue accent
    static let strainColor   = adaptive("#E56B32", "#FF9565")
    /// 恢复 Recovery — sage/green
    static let recoveryColor = adaptive("#168B70", "#4DD0AA")
    /// 睡眠 Sleep — indigo
    static let sleepColor    = adaptive("#685BC7", "#A99DFF")
    /// 压力 Stress — rose/red
    static let stressColor   = adaptive("#C94E70", "#FF7C9B")
    /// 能量 Energy — gold
    static let energyColor   = adaptive("#B47C18", "#F2BC4D")

    // MARK: - Typography

    static let fontDisplay: Font.Design = .default
    static let fontBody: Font.Design     = .default
    static let fontMono: Font.Design     = .monospaced

    static func largeTitle() -> Font   { .largeTitle.weight(.bold) }
    static func title1() -> Font       { .title.weight(.bold) }
    static func title2() -> Font       { .title2.weight(.semibold) }
    static func title3() -> Font       { .title3.weight(.semibold) }
    static func headline() -> Font     { .headline }
    static func body() -> Font         { .body }
    static func callout() -> Font      { .callout }
    static func subheadline() -> Font  { .subheadline }
    static func footnote() -> Font     { .footnote }
    static func caption1() -> Font     { .caption }
    static func caption2() -> Font     { .caption2 }
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
    static let radiusLg: CGFloat   = 14
    static let radiusCardLarge: CGFloat = 22
    static let radiusFeature: CGFloat = 28
    static let radiusXl: CGFloat   = 28
    static let radiusPill: CGFloat = 980

    static let fillSoft = adaptive("#5664E81A", "#FFFFFF16")

    static func captionLarge() -> Font { .system(size: 14, weight: .regular, design: .default) }

    // MARK: - Shadow

    static func cardShadow(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.black.opacity(0.34) : Color(hex: "#25304F").opacity(0.07)
    }

    static func nativeShadow(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.clear : Color(hex: "#25304F").opacity(0.025)
    }

    // MARK: - Animation

    static let fast = 0.15
    static let standard = 0.22
    static let ease = UnitCurve.easeInOut
    static let snappy = Animation.snappy(duration: 0.28, extraBounce: 0.02)
    static let smooth = Animation.smooth(duration: 0.32)
    static let press = Animation.easeOut(duration: 0.16)

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

// MARK: - Design System Namespaces

extension VelaTheme {
    enum gradient {
        static let recovery = LinearGradient(colors: [recoveryColor.opacity(0.8), recoveryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let sleep = LinearGradient(colors: [sleepColor.opacity(0.8), sleepColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let strain = LinearGradient(colors: [strainColor.opacity(0.8), strainColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let stress = LinearGradient(colors: [stressColor.opacity(0.8), stressColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let energy = LinearGradient(colors: [energyColor.opacity(0.8), energyColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let accentGrad = LinearGradient(colors: [accent.opacity(0.8), accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    enum icon {
        static let recovery = "heart.text.square.fill"
        static let sleep = "bed.double.fill"
        static let strain = "bolt.fill"
        static let stress = "waveform.path.ecg"
        static let energy = "battery.100"
        static let coach = "brain.head.profile"
        static let training = "figure.strengthtraining.traditional"
        static let settings = "gearshape.fill"
        static let journal = "book.closed.fill"
        static let vitals = "heart.fill"
        static let history = "clock.arrow.circlepath"
        static let add = "plus.circle.fill"
        static let arrowRight = "chevron.right"
        static let arrowLeft = "chevron.left"
        static let info = "info.circle"
        static let warning = "exclamationmark.triangle.fill"
    }
}



// MARK: - Haptic Feedback Helper

enum VelaHaptic {
    @MainActor static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    @MainActor static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    @MainActor static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    @MainActor static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    @MainActor static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
