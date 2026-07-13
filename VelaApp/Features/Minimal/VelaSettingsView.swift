import SwiftUI
import SwiftData

struct VelaSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var cs
    
    // Settings toggles
    @AppStorage("vela_dark_mode") private var darkModeRaw = "system"
    @AppStorage("agent_abnormal_metric_alerts") private var abnormalMetricAlertsOn = true
    @AppStorage("agent_morning_brief_alerts") private var morningBriefOn = true
    @AppStorage("agent_bedtime_reminders") private var bedtimeRemindersOn = true
    
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000
    @AppStorage(SleepTargetSettings.hoursKey) private var sleepTargetHours = SleepTargetSettings.defaultHours
    @AppStorage("vela_coach_personality") private var coachPersonalityRaw = CoachPersonality.guardian.rawValue
    
    // AI Model settings
    @AppStorage("vela_coach_text_model") private var textModel = "DeepSeek V4 Pro"

    private var currentCoachPersonalityName: String {
        CoachPersonality(rawValue: coachPersonalityRaw)?.displayName ?? CoachPersonality.guardian.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileCardRow

                settingsGroup(title: "个人与教练") {
                    VStack(spacing: 0) {
                        NavigationLink(destination: AccountSettingsView()) {
                            settingsRow(icon: "person.fill", iconBg: Color(hex: "#00A896"), title: "账户", value: "本机资料")
                        }
                        settingsDivider
                        NavigationLink(destination: UserWikiArchiveView()) {
                            settingsRow(icon: "doc.text.fill", iconBg: VelaTheme.muted, title: "健康档案", value: "本地长期记忆")
                        }
                        settingsDivider
                        NavigationLink(destination: AIModelSettingsView()) {
                            settingsRow(icon: "cpu.fill", iconBg: Color(hex: "#5C6BC0"), title: "AI 模型", value: textModel)
                        }
                        settingsDivider
                        NavigationLink(destination: CoachPersonalitySettingsView()) {
                            settingsRow(icon: "brain.head.profile", iconBg: Color(hex: "#FF5E3A"), title: "教练风格", value: currentCoachPersonalityName)
                        }
                        settingsDivider
                        NavigationLink(destination: AgentAutomationSettingsView()) {
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#B8843E"), title: "主动智能", value: "已配置")
                        }
                    }
                }

                settingsGroup(title: "使用偏好") {
                    VStack(spacing: 0) {
                        NavigationLink(destination: AppearanceSettingsView()) {
                            settingsRow(icon: "moon.fill", iconBg: Color(hex: "#AF52DE"), title: "外观", value: darkModeRaw == "dark" ? "深色" : (darkModeRaw == "light" ? "浅色" : "跟随系统"))
                        }
                        settingsDivider
                        NavigationLink(destination: NotificationSettingsView()) {
                            settingsRow(
                                icon: "bell.fill",
                                iconBg: Color(hex: "#FF9F0A"),
                                title: "通知",
                                value: abnormalMetricAlertsOn || morningBriefOn || bedtimeRemindersOn ? "已配置" : "已关闭"
                            )
                        }
                        settingsDivider
                        NavigationLink(destination: CustomizationSettingsView()) {
                            settingsRow(icon: "slider.horizontal.3", iconBg: VelaTheme.accent, title: "健康目标", value: "\(dailyCalorieTarget) kcal · \(SleepTargetSettings.displayHours(sleepTargetHours))")
                        }
                        settingsDivider
                        NavigationLink(destination: LanguageSettingsView()) {
                            settingsRow(
                                icon: "globe",
                                iconBg: Color(hex: "#34C759"),
                                title: "语言",
                                value: AppLanguage(rawValue: languageRaw)?.displayName ?? AppLanguage.simplifiedChinese.displayName
                            )
                        }
                        settingsDivider
                        NavigationLink(destination: ShortcutsSettingsView()) {
                            settingsRow(icon: "command", iconBg: Color(hex: "#B8843E"), title: "快捷指令", value: "已接入")
                        }
                    }
                }

                settingsGroup(title: "数据与隐私") {
                    VStack(spacing: 0) {
                        NavigationLink(destination: DataSourceSettingsView()) {
                            settingsRow(icon: "applewatch", iconBg: Color(hex: "#FF2D55"), title: "数据源", value: "Apple 健康")
                        }
                        settingsDivider
                        NavigationLink(destination: CGMSettingsView()) {
                            settingsRow(icon: "scope", iconBg: Color(hex: "#30A2FF"), title: "管理 CGM", value: "Apple 健康")
                        }
                        settingsDivider
                        NavigationLink(destination: DataCoverageView()) {
                            settingsRow(icon: "waveform.path.ecg.rectangle", iconBg: VelaTheme.accent, title: "数据可信度", value: "信号质量")
                        }
                        settingsDivider
                        NavigationLink(destination: HealthDataResyncSettingsView()) {
                            settingsRow(icon: "arrow.clockwise.icloud.fill", iconBg: Color(hex: "#30A2FF"), title: "健康数据重同步", value: "最近 90 天")
                        }
                        settingsDivider
                        NavigationLink(destination: TrustCenterView()) {
                            settingsRow(icon: "checkmark.shield.fill", iconBg: VelaTheme.recoveryColor, title: "信任中心", value: "权限与运行日志")
                        }
                        settingsDivider
                        NavigationLink(destination: PrivacyDataControlsView()) {
                            settingsRow(icon: "lock.shield.fill", iconBg: Color(hex: "#5856D6"), title: "隐私与数据控制", value: "导出 / 删除")
                        }
                        settingsDivider
                        NavigationLink(destination: ExportDataSettingsView()) {
                            settingsRow(icon: "square.and.arrow.up.fill", iconBg: VelaTheme.muted, title: "数据导出", value: "本地资料")
                        }

                        if VelaCapabilityAvailability.cloudKitSyncEnabled {
                            settingsDivider
                            NavigationLink(destination: iCloudSyncSettingsView()) {
                                settingsRow(icon: "icloud.fill", iconBg: VelaTheme.accent, title: "iCloud 同步", value: "已接入")
                            }
                        }
                    }
                }

                settingsGroup(title: "关于") {
                    VStack(spacing: 0) {
                        NavigationLink(destination: WhatsNewSettingsView()) {
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#5856D6"), title: "最新变化", value: "更新记录")
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
            }
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.muted)
                .padding(.leading, 12)

            content()
                .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
                )
        }
        .padding(.horizontal, 16)
    }

    private var settingsDivider: some View {
        Divider().padding(.leading, 60)
    }
    
    private func settingsRow(icon: String, iconBg: Color, title: String, value: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(VelaTheme.fg)
            
            Spacer()
            
            if let val = value {
                Text(val)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
    
    private var profileCardRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(VelaTheme.accent.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("本机健康资料")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("本机优先存储")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
            }
            
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

enum VelaCapabilityAvailability {
    static let cloudKitSyncEnabled = false
}

struct AppearanceSettingsView: View {
    @AppStorage("vela_dark_mode") private var darkModeRaw = "system"
    
    var body: some View {
        Form {
            Section(header: Text("主题选择")) {
                ForEach(["system", "light", "dark"], id: \.self) { mode in
                    Button {
                        darkModeRaw = mode
                    } label: {
                        HStack {
                            Text(mode == "dark" ? "深色" : (mode == "light" ? "浅色" : "跟随系统"))
                                .foregroundStyle(VelaTheme.fg)
                            Spacer()
                            if darkModeRaw == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(VelaTheme.accent)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("外观主题")
    }
}

struct NotificationSettingsView: View {
    @AppStorage("agent_abnormal_metric_alerts") private var abnormalMetricAlertsOn = true
    @AppStorage("agent_morning_brief_alerts") private var morningBriefOn = true
    @AppStorage("agent_bedtime_reminders") private var bedtimeRemindersOn = true
    @AppStorage("agent_bedtime_hour") private var bedtimeHour = 22
    @AppStorage("agent_bedtime_minute") private var bedtimeMinute = 0
    @State private var authorizationMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("通知通道")) {
                Toggle("异常指标提醒", isOn: $abnormalMetricAlertsOn)
                    .onChange(of: abnormalMetricAlertsOn) { _, newValue in
                        NotificationService.shared.abnormalMetricAlertsEnabled = newValue
                        requestAuthorizationIfNeeded(enabled: newValue)
                    }
                Toggle("晨间健康简报", isOn: $morningBriefOn)
                    .onChange(of: morningBriefOn) { _, newValue in
                        NotificationService.shared.morningBriefAlertsEnabled = newValue
                        requestAuthorizationIfNeeded(enabled: newValue)
                    }
                Toggle("睡前提醒", isOn: $bedtimeRemindersOn)
                    .onChange(of: bedtimeRemindersOn) { _, newValue in
                        NotificationService.shared.bedtimeRemindersEnabled = newValue
                        requestAuthorizationIfNeeded(enabled: newValue)
                    }
            }

            Section(header: Text("睡前提醒时间")) {
                Picker("小时", selection: $bedtimeHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(String(format: "%02d", hour)).tag(hour)
                    }
                }
                Picker("分钟", selection: $bedtimeMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute)).tag(minute)
                    }
                }
                .onChange(of: bedtimeHour) { _, _ in
                    NotificationService.shared.scheduleBedtimeReminder()
                }
                .onChange(of: bedtimeMinute) { _, _ in
                    NotificationService.shared.scheduleBedtimeReminder()
                }
            }

            if !authorizationMessage.isEmpty {
                Section {
                    Text(authorizationMessage)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("通知")
    }

    private func requestAuthorizationIfNeeded(enabled: Bool) {
        guard enabled else { return }
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            authorizationMessage = granted ? "系统通知权限已开启。" : "系统通知权限未开启，请在系统设置中允许 Vela 通知。"
        }
    }
}

struct CustomizationSettingsView: View {
    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000
    @AppStorage(SleepTargetSettings.hoursKey) private var sleepTargetHours = SleepTargetSettings.defaultHours
    @State private var tempTarget = 2000
    
    var body: some View {
        Form {
            Section(header: Text("今日热量基准")) {
                Stepper("每日目标卡路里: \(tempTarget) kcal", value: $tempTarget, in: 1200...4000, step: 50)
                Button("保存更改") {
                    dailyCalorieTarget = tempTarget
                }
                .tint(VelaTheme.accent)
            }

            Section(header: Text("睡眠目标")) {
                Picker("每晚目标时长", selection: $sleepTargetHours) {
                    ForEach(SleepTargetSettings.availableHours, id: \.self) { hours in
                        Text(SleepTargetSettings.displayHours(hours)).tag(hours)
                    }
                }

                Text("该目标会用于睡眠评分和睡眠详情展示。")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .onAppear {
            tempTarget = dailyCalorieTarget
        }
        .navigationTitle("自定义健康基准")
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Siri 快捷指令与语音集成")
                    .font(.system(size: 20, weight: .bold))
                
                Text("以下快捷指令已通过 App Intents 接入，可在快捷指令 App 或 Siri 中使用：")
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 14) {
                    shortcutGuideRow(command: "查看 Vela 今日状态", desc: "打开首页查看今日恢复、睡眠和训练负荷。")
                    shortcutGuideRow(command: "询问 Vela 就绪状态", desc: "打开 Coach 并分析今天最重要的行动建议。")
                    shortcutGuideRow(command: "用 Vela 扫描餐食", desc: "打开餐食拍照分析入口。")
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("快捷指令")
    }
    
    private func shortcutGuideRow(command: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
    }
}

struct LanguageSettingsView: View {
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    
    var body: some View {
        Form {
            Section {
                Button { languageRaw = AppLanguage.simplifiedChinese.rawValue } label: {
                    HStack {
                        Text("简体中文")
                            .foregroundStyle(VelaTheme.fg)
                        Spacer()
                        if languageRaw == AppLanguage.simplifiedChinese.rawValue { Image(systemName: "checkmark").foregroundStyle(VelaTheme.accent) }
                    }
                }
                
                Button { languageRaw = AppLanguage.english.rawValue } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("English")
                                .foregroundStyle(VelaTheme.fg)
                            Text("Beta · 部分页面仍为中文")
                                .font(.caption)
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer()
                        if languageRaw == AppLanguage.english.rawValue { Image(systemName: "checkmark").foregroundStyle(VelaTheme.accent) }
                    }
                }
            } header: {
                Text("多语言选择")
            } footer: {
                Text("切换后重新打开 Vela 生效。English 正在持续完善，核心健康与训练页面目前以简体中文体验最佳。")
            }
        }
        .navigationTitle("应用语言")
    }
}
