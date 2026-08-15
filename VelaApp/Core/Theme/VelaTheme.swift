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

    // MARK: - Vela Rhythm Identity

    /// A warmer, quieter canvas for Vela's decision surfaces. The product uses
    /// this instead of generic grouped gray so health guidance reads as one
    /// continuous environment rather than a dashboard made of cards.
    static let rhythmCanvas       = adaptive("#F2F5F1", "#07100E")
    static let rhythmCanvasRaised = adaptive("#F8FAF7", "#0D1815")
    static let rhythmInk          = adaptive("#10201C", "#EDF7F2")
    static let rhythmInkSecondary = adaptive("#53655F", "#9DB0A9")
    static let rhythmMist         = adaptive("#D8E7DF", "#19352C")
    static let rhythmGlow         = adaptive("#75D6A7", "#52E0A2")
    static let rhythmDeepUIColor = adaptiveUIColor("#0D6B50", "#65E6B2")
    static let rhythmDeep         = Color(rhythmDeepUIColor)
    /// rhythmDeep 实底上的文字色：浅色模式白字（#0D6B50 上 ≈5.4:1）；
    /// 深色模式 rhythmDeep 是亮薄荷绿，白字对比度仅 ~1.7:1，改用深墨字（≈7:1）。
    static let rhythmDeepOnUIColor = adaptiveUIColor("#FFFFFF", "#10201C")
    static let rhythmDeepOn        = Color(rhythmDeepOnUIColor)
    static let rhythmWarm         = adaptive("#E6C98A", "#C9A85F")

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
    // tertiaryLabel 在暖灰绿画布上对比度仅 ~1.9:1（WCAG 不达标），
    // 用自适配色保证至少 4.5:1。
    static let meta          = adaptive("#6B726D", "#A6B0AA")

    // MARK: - Accent

    /// Vela 品牌绿:可识别、代表健康,与健康状态色中的「好」一致。
    static let accent        = adaptive("#17A35C", "#3FC97F")
    // 暗色下白字压在亮绿 #3FC97F 上仅 2.13:1，改用深墨（同 rhythmDeepOn 思路）。
    static let accentOn      = adaptive("#FFFFFF", "#10201C")
    static let accentHover   = adaptive("#148F4F", "#5FD98F")
    static let accentActive  = adaptive("#0C7A44", "#2FA96A")

    // MARK: - Brand (Vela 活力绿)

    /// 品牌主色:健康/恢复/活力,与警告色天然区分。
    static let brand       = adaptive("#17A35C", "#3FC97F")
    /// 渐变起点(品牌亮绿)
    static let brandBright = adaptive("#46C87E", "#5FD98F")
    /// 按压态/深色文字
    static let brandDeep   = adaptive("#0C7A44", "#2FA96A")
    /// 浅绿填充底(头像底/徽章/建议块)
    static let brandSoft   = adaptive("#E3F2EA", "#16301F")

    // MARK: - State Colors (G1: 颜色只表达「好不好」,不装饰)

    /// 状态:好(=品牌绿)
    static let stateGood     = adaptive("#17A35C", "#3FC97F")
    /// 状态:注意(暖橙)
    static let stateModerate = adaptive("#E8A23C", "#F2B45C")
    /// 状态:差(玫红)
    static let statePoor     = adaptive("#E2607A", "#FF8299")

    /// 状态→颜色(G1)。视图统一经此取色,不要直接散落使用 stateGood/Moderate/Poor。
    static func color(for state: MetricState) -> Color {
        switch state {
        case .good: return stateGood
        case .moderate: return stateModerate
        case .poor: return statePoor
        }
    }

    // MARK: - Semantic Palette (硬编码收敛映射)

    /// 系统绿(成功/达标态)
    static let systemGreen   = adaptive("#34C759", "#30D158")
    /// 系统橙(警示/需注意态)
    static let systemOrange  = adaptive("#FF9F0A", "#FFB340")
    /// 系统红(错误/差态)
    static let systemRed     = adaptive("#FF3B30", "#FF453A")
    /// 系统黄(提醒)
    static let systemYellow  = adaptive("#FFB74D", "#FFD60A")
    /// 系统粉(压力/标记)
    static let systemPink    = adaptive("#FF2D55", "#FF375F")
    /// 中性深灰(次级文字/图标)
    static let inkGray       = adaptive("#7E7A70", "#9AA0A8")
    /// 近黑文字(标题/正文)
    static let inkDark       = adaptive("#161512", "#F2F4F8")
    /// 浅灰(提示/分隔)
    static let mistGray      = adaptive("#BFB9AC", "#6E766F")
    /// 冷蓝(信息/链接)
    static let infoBlue      = adaptive("#30A2FF", "#5AB0FF")
    /// 靛蓝(睡眠/深度)
    static let indigo        = adaptive("#5C6BC0", "#8B9BFF")
    /// 品牌叶绿(徽章/状态)
    static let brandLeaf     = adaptive("#5B8C6F", "#73A385")
    /// 睡眠主题浅色文字(睡眠小部件专用)
    static let sleepText     = adaptive("#F2EFE8", "#161512")
    /// 发丝灰(描边/分隔)
    static let hairline      = adaptive("#E5E5EA", "#3A4048")

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

    // MARK: - Layout & Spacing
    //
    // These values are the frozen geometry contract for the Bevel-parity
    // interface. Feature views should consume these tokens instead of
    // introducing one-off card insets or hit targets.

    static let space1: CGFloat  = 4
    static let space2: CGFloat  = 8
    static let space3: CGFloat  = 12
    static let space4: CGFloat  = 16
    static let space5: CGFloat  = 20
    static let space6: CGFloat  = 24
    static let space8: CGFloat  = 32
    static let space12: CGFloat = 48
    static let inlineGap: CGFloat = 8
    static let cardGap: CGFloat = 12
    static let sectionGap: CGFloat = 24
    static let compactCardPadding: CGFloat = 14
    static let cardPadding: CGFloat = 18
    static let pagePadding: CGFloat = 20
    static let minimumHitTarget: CGFloat = 44
    static let circularControlSize: CGFloat = 44
    static let bottomContentClearance: CGFloat = 104
    static let tabBarHeight: CGFloat = 84

    // MARK: - Radius

    static let radiusSm: CGFloat   = 8
    static let radiusMd: CGFloat   = 12
    static let radiusLg: CGFloat   = 18
    static let radiusCardLarge: CGFloat = 22
    static let radiusFeature: CGFloat = 28
    static let radiusXl: CGFloat   = 28
    static let radiusSheet: CGFloat = 32
    static let radiusPill: CGFloat = 980

    static let fillSoft = adaptive("#5664E81A", "#FFFFFF16")

    static func captionLarge() -> Font { .system(size: 14, weight: .regular, design: .default) }
    static func pageTitle() -> Font { .system(.title2, design: .default, weight: .bold) }
    static func metricHeroValue() -> Font {
        .system(size: 48, weight: .semibold, design: .rounded).monospacedDigit()
    }
    static func cardValue() -> Font {
        .system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    }
    /// 旗舰大数字(就绪度等),SF Rounded,等宽。
    static func displayValue() -> Font {
        .system(size: 60, weight: .bold, design: .rounded).monospacedDigit()
    }
    /// 体征大卡数值。
    static func vitalValue() -> Font {
        .system(size: 24, weight: .bold, design: .rounded).monospacedDigit()
    }

    // MARK: - Shadow

    static func cardShadow(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.black.opacity(0.34) : Color(hex: "#25304F").opacity(0.07)
    }

    static func nativeShadow(_ cs: ColorScheme) -> Color {
        cs == .dark ? Color.clear : Color(hex: "#25304F").opacity(0.025)
    }

    // MARK: - Animation

    static let fast = 0.12
    static let standard = 0.22
    static let reducedMotionDuration = 0.18
    static let ease = UnitCurve.easeInOut
    /// Critically damped by default: responsive, interruptible, and free of decorative bounce.
    static let responsiveSpring = Animation.spring(
        response: 0.34,
        dampingFraction: 1.0,
        blendDuration: 0.08
    )
    /// Reserved for interactions that inherit momentum from a drag or flick.
    static let momentumSpring = Animation.spring(
        response: 0.34,
        dampingFraction: 0.82,
        blendDuration: 0.08
    )
    static let snappy = responsiveSpring
    static let smooth = Animation.spring(
        response: 0.40,
        dampingFraction: 1.0,
        blendDuration: 0.10
    )
    static let press = Animation.easeOut(duration: fast)

    static func interfaceAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: reducedMotionDuration) : responsiveSpring
    }

    /// Data visualizations should update immediately when motion is reduced.
    static func dataAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : responsiveSpring
    }

    // MARK: - Ring Sizes

    static let ringLg: CGFloat  = 120
    static let ringMd: CGFloat  = 72
    static let ringSm: CGFloat  = 48
}

enum VelaMetricDomain: String, CaseIterable {
    case strain
    case recovery
    case sleep
    case stress
    case energy
    case neutral

    var color: Color {
        switch self {
        case .strain: VelaTheme.strainColor
        case .recovery: VelaTheme.recoveryColor
        case .sleep: VelaTheme.sleepColor
        case .stress: VelaTheme.stressColor
        case .energy: VelaTheme.energyColor
        case .neutral: VelaTheme.accent
        }
    }

    var systemImage: String {
        switch self {
        case .strain: VelaTheme.icon.strain
        case .recovery: VelaTheme.icon.recovery
        case .sleep: VelaTheme.icon.sleep
        case .stress: VelaTheme.icon.stress
        case .energy: VelaTheme.icon.energy
        case .neutral: "waveform.path.ecg"
        }
    }
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
