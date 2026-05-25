import SwiftData
import SwiftUI
import UniformTypeIdentifiers



struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var agentConfig = AutoAgentConfig.shared
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_sleep_target_hours") private var sleepTargetHours: Double = 7.5
    @AppStorage("vela_coach_personality") private var coachPersonalityRaw = CoachPersonality.guardian.rawValue
    @State private var selectedPersonality: CoachPersonality = .guardian
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var exportData: Data?

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .english
    }

    private var coachPersonality: CoachPersonality {
        CoachPersonality(rawValue: coachPersonalityRaw) ?? .guardian
    }

    private var coachPersonalityDescription: String {
        switch coachPersonality {
        case .dataNerd:
            return language.isChinese
                ? "用数据说话。详细分析每个指标、趋势和相关性。适合喜欢深度分析的你。"
                : "Data-driven. Detailed analysis of every metric, trend, and correlation. For those who love deep analysis."
        case .guardian:
            return language.isChinese
                ? "安全第一。优先考虑休息和恢复，温和地推动你进步。适合需要平衡的你。"
                : "Safety first. Prioritizes rest and recovery, gently nudges progress. For those who need balance."
        case .friend:
            return language.isChinese
                ? "温暖支持。庆祝每一次进步，在低谷时给你鼓励。适合需要陪伴感的你。"
                : "Warm and supportive. Celebrates every win, encourages during setbacks. For those who need companionship."
        case .commander:
            return language.isChinese
                ? "简短直接。给出明确的行动清单，不废话。适合需要纪律感的你。"
                : "Short and direct. Clear action items. No fluff. For those who need discipline."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SectionHeader(
                            title: language.isChinese ? "设置" : "Settings",
                            subtitle: language.isChinese ? "AI、语言和隐私的本地优先配置。" : "Local-first configuration for AI and privacy."
                        )

                        // Biological Age & Lab Records Dashboard
                        NavigationLink {
                            BiologyView()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(VelaTheme.accent.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: "drop.fill")
                                            .font(.body)
                                            .foregroundStyle(VelaTheme.accent)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.isChinese ? "生理与生物年龄" : "Biology & Biological Age")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VelaTheme.primaryText)
                                    Text(language.isChinese ? "计算你的生物学年龄，管理血检与可穿戴生理指标。" : "Calibrate Biological Age, manage lab records & wearable physiology.")
                                        .font(.caption)
                                        .foregroundStyle(VelaTheme.secondaryText)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.footnote.bold())
                                    .foregroundStyle(VelaTheme.mutedText)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .fill(VelaTheme.cardBackground.opacity(0.4))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .stroke(VelaTheme.stroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)


                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "语言" : "Language", systemImage: "globe")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        Picker(language.isChinese ? "应用语言" : "App Language", selection: $languageRaw) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(language.isChinese ? "中文模式会影响设置页、Coach 交互和 AI 分析输出。" : "Language changes Settings, Coach interactions, and AI analysis output.")
                            .font(.footnote)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    .cardSurface()

                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "DeepSeek 提供商" : "DeepSeek Provider", systemImage: "key.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        SecureField("DeepSeek API Key", text: $viewModel.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .fill(VelaTheme.elevatedSurface)
                            )
                            .foregroundStyle(VelaTheme.primaryText)

                        HStack(spacing: 10) {
                            Button {
                                viewModel.saveKey()
                            } label: {
                                Label(language.isChinese ? "保存" : "Save", systemImage: "lock.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(VelaTheme.accent)

                            Button {
                                Task { await viewModel.testConnection() }
                            } label: {
                                Label(language.isChinese ? "测试" : "Test", systemImage: "bolt.horizontal.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isTesting)
                        }

                        if !viewModel.statusMessage.isEmpty {
                            Text(viewModel.statusMessage)
                                .font(.footnote)
                                .foregroundStyle(viewModel.isError ? VelaTheme.stress : VelaTheme.secondaryText)
                        }
                    }
                    .cardSurface()

                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "Kimi 视觉提供商" : "Kimi Vision Provider", systemImage: "camera.macro")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        Text(language.isChinese
                            ? "用于 Coach 的食物照片识别。普通健康对话仍使用 DeepSeek。"
                            : "Used only for Coach food photo recognition. Regular health chat still uses DeepSeek.")
                            .font(.footnote)
                            .foregroundStyle(VelaTheme.secondaryText)

                        SecureField("Kimi / Moonshot API Key", text: $viewModel.kimiApiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .fill(VelaTheme.elevatedSurface)
                            )
                            .foregroundStyle(VelaTheme.primaryText)

                        Button {
                            viewModel.saveKimiKey()
                        } label: {
                            Label(language.isChinese ? "保存 Kimi Key" : "Save Kimi Key", systemImage: "lock.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VelaTheme.accent)

                        if !viewModel.kimiStatusMessage.isEmpty {
                            Text(viewModel.kimiStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(viewModel.isKimiError ? VelaTheme.stress : VelaTheme.secondaryText)
                        }
                    }
                    .cardSurface()

                    // Sleep target
                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "睡眠目标" : "Sleep Target", systemImage: "moon.zzz.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        HStack {
                            Text(language.isChinese ? "每晚目标时长" : "Target per night")
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                            Spacer()
                            Picker("", selection: $sleepTargetHours) {
                                ForEach(5...10, id: \.self) { h in
                                    Text("\(h)h").tag(Double(h))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(VelaTheme.accent)
                        }

                        Text(language.isChinese
                            ? "用于睡眠评分计算。低于目标会降低评分，高于目标不额外加分。"
                            : "Used for sleep scoring. Below target reduces score; above target doesn't add extra points.")
                            .font(.caption)
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                    .cardSurface()

                    // AI Coach personality
                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "AI 教练风格" : "AI Coach Style", systemImage: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        Picker(language.isChinese ? "教练风格" : "Coach Personality", selection: $selectedPersonality) {
                            ForEach(CoachPersonality.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedPersonality) { _, new in
                            coachPersonalityRaw = new.rawValue
                        }

                        Text(coachPersonalityDescription)
                            .font(.caption)
                            .foregroundStyle(VelaTheme.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .cardSurface()

                    // ── Agent Skills ──
                    agentSkillsSection

                    // ── Notifications ──
                    notificationsSection

                    PlaceholderInsightCard(
                        title: language.isChinese ? "隐私" : "Privacy",
                        bodyText: language.isChinese ? "健康数据保留在设备本地。主动生成报告时，结构化摘要、评分原因、日记和用户 Wiki 片段会发送给 DeepSeek；食物照片识别时，照片会发送给 Kimi/Moonshot 视觉模型。" : "Health data stays on-device. When you explicitly generate reports, structured summaries, score reasons, journal notes, and selected user wiki text are sent to DeepSeek; food photos are sent to Kimi/Moonshot only for vision analysis."
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Label(language.isChinese ? "数据导出" : "Data Export", systemImage: "square.and.arrow.up.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        Text(language.isChinese ? "导出健康摘要和日记记录的 JSON 文件。数据不会离开设备。" : "Export health summaries and journal entries as a JSON file. Data never leaves your device.")
                            .font(.footnote)
                            .foregroundStyle(VelaTheme.secondaryText)

                        Button {
                            exportData = viewModel.exportHealthData(modelContext: modelContext)
                            showExporter = true
                        } label: {
                            Label(language.isChinese ? "导出健康数据 (JSON)" : "Export Health Data (JSON)", systemImage: "doc.text.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(VelaTheme.accent)
                    }
                    .cardSurface()
                    .fileExporter(
                        isPresented: $showExporter,
                        document: exportData.flatMap { JSONExportDocument(data: $0) },
                        contentType: .json,
                        defaultFilename: "vela_health_export_\(Date().formatted(.iso8601).prefix(10)).json"
                    ) { result in
                        if case .failure(let error) = result {
                            viewModel.statusMessage = error.localizedDescription
                        }
                    }

                    PlaceholderInsightCard(
                        title: language.isChinese ? "用户 Wiki" : "User Wiki",
                        bodyText: language.isChinese ? "Coach 会把对话中稳定的偏好和背景摘要追加到本地 notes.md，供后续分析读取。" : "Coach appends stable preferences and context from chat into local notes.md for future analysis."
                    )

                    NavigationLink {
                        TrustCenterView()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title3)
                                .foregroundStyle(VelaTheme.energy)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.isChinese ? "信任中心" : "Trust Center")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(VelaTheme.primaryText)
                                Text(language.isChinese ? "Agent 运行历史与状态" : "Agent run history and status")
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.surface))
                    }
                }
                .padding(VelaTheme.screenPadding)
            }
        }
        .navigationTitle("")
        .onAppear {
            selectedPersonality = CoachPersonality(rawValue: coachPersonalityRaw) ?? .guardian
        }
    }
}

    // MARK: - Agent Skills Section

    private var agentSkillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(language.isChinese ? "Agent 技能" : "Agent Skills", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(VelaTheme.primaryText)

            Text(language.isChinese
                ? "Vela 可以自动执行定时任务，分析你的数据并更新档案。"
                : "Vela can run scheduled tasks automatically, analyzing your data and updating your profile.")
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)

            ForEach(agentConfig.skillList(isChinese: language.isChinese)) { skill in
                skillToggleRow(skill)
            }
        }
        .cardSurface()
    }

    private func skillToggleRow(_ skill: AgentSkillInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: skill.icon)
                    .font(.body)
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.isChinese ? skill.name : skill.enName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(skill.schedule)
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { skill.isEnabled },
                    set: { new in
                        var config = agentConfig
                        config[keyPath: skill.configKey] = new
                    }
                ))
                .labelsHidden()
                .tint(VelaTheme.accent)
            }

            Text(language.isChinese ? skill.description : skill.enDescription)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(language.isChinese ? "通知" : "Notifications", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundStyle(VelaTheme.primaryText)

            Text(language.isChinese
                ? "接收异常指标提醒、晨间简报和就寝提醒。"
                : "Receive alerts for abnormal metrics, morning briefs, and bedtime reminders.")
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)

            // Permission status and request button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.isChinese ? "通知权限" : "Notification Permission")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(notificationStatusText)
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }
                Spacer()
                Button(language.isChinese ? "授权" : "Authorize") {
                    Task {
                        let granted = await NotificationService.shared.requestAuthorization()
                        if granted {
                            NotificationService.shared.scheduleBedtimeReminder()
                        }
                        await checkNotificationStatus()
                    }
                }
                .buttonStyle(.bordered)
                .tint(VelaTheme.accent)
                .disabled(notificationAuthorized)
            }

            Divider().background(VelaTheme.stroke)

            // Abnormal metric alerts toggle
            notificationToggleRow(
                title: language.isChinese ? "异常指标提醒" : "Abnormal Metric Alerts",
                description: language.isChinese
                    ? "HRV、RHR、恢复评分、压力指数异常时推送通知。"
                    : "Notify when HRV, RHR, recovery score, or stress index are abnormal.",
                icon: "exclamationmark.triangle.fill",
                isOn: $agentConfig.abnormalMetricAlerts
            )
            .onChange(of: agentConfig.abnormalMetricAlerts) { _, newValue in
                NotificationService.shared.abnormalMetricAlertsEnabled = newValue
            }

            // Morning brief alerts toggle
            notificationToggleRow(
                title: language.isChinese ? "晨间简报提醒" : "Morning Brief Alerts",
                description: language.isChinese
                    ? "晨间简报生成后推送通知。"
                    : "Notify when your morning brief is ready.",
                icon: "sunrise.fill",
                isOn: $agentConfig.morningBriefAlerts
            )
            .onChange(of: agentConfig.morningBriefAlerts) { _, newValue in
                NotificationService.shared.morningBriefAlertsEnabled = newValue
            }

            // Bedtime reminder toggle
            notificationToggleRow(
                title: language.isChinese ? "就寝提醒" : "Bedtime Reminder",
                description: language.isChinese
                    ? "每天在设定的就寝时间前发送提醒。"
                    : "Send a daily reminder at your scheduled bedtime.",
                icon: "moon.zzz.fill",
                isOn: $agentConfig.bedtimeReminders
            )
            .onChange(of: agentConfig.bedtimeReminders) { _, newValue in
                NotificationService.shared.bedtimeRemindersEnabled = newValue
            }

            // Bedtime picker (only shown when bedtime reminders are enabled)
            if agentConfig.bedtimeReminders {
                HStack {
                    Text(language.isChinese ? "就寝时间" : "Bedtime")
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                var comps = DateComponents()
                                comps.hour = agentConfig.bedtimeHour
                                comps.minute = agentConfig.bedtimeMinute
                                return Calendar.current.date(from: comps) ?? Date()
                            },
                            set: { date in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                                agentConfig.bedtimeHour = comps.hour ?? 22
                                agentConfig.bedtimeMinute = comps.minute ?? 30
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(VelaTheme.accent)
                    .onChange(of: agentConfig.bedtimeHour) { _, _ in
                        NotificationService.shared.scheduleBedtimeReminder()
                    }
                    .onChange(of: agentConfig.bedtimeMinute) { _, _ in
                        NotificationService.shared.scheduleBedtimeReminder()
                    }
                }

                // Progress check-in toggle
                notificationToggleRow(
                    title: language.isChinese ? "进度检查" : "Progress Check-in",
                    description: language.isChinese
                        ? "每日中午推送，提醒记录饮食、训练和感受。"
                        : "Daily midday reminder to log meals, training, and how you're feeling.",
                    icon: "checkmark.circle.fill",
                    isOn: $agentConfig.progressCheckins
                )
                if agentConfig.progressCheckins {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                var comps = DateComponents()
                                comps.hour = agentConfig.progressCheckinHour
                                return Calendar.current.date(from: comps) ?? Date()
                            },
                            set: { date in
                                agentConfig.progressCheckinHour = Calendar.current.component(.hour, from: date)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden().tint(VelaTheme.accent)
                }

                // Weekly summary toggle
                notificationToggleRow(
                    title: language.isChinese ? "周报总结" : "Weekly Summary",
                    description: language.isChinese
                        ? "每周一早上推送上周健康数据总结。"
                        : "Weekly summary of your health data, every Monday morning.",
                    icon: "chart.bar.doc.horizontal.fill",
                    isOn: $agentConfig.weeklySummary
                )
                if agentConfig.weeklySummary {
                    HStack {
                        Picker(language.isChinese ? "星期" : "Day", selection: $agentConfig.weeklySummaryDay) {
                            Text(language.isChinese ? "周一" : "Mon").tag(2)
                            Text(language.isChinese ? "周日" : "Sun").tag(1)
                        }.pickerStyle(.segmented)
                        DatePicker(
                            "",
                            selection: Binding(
                                get: {
                                    var comps = DateComponents()
                                    comps.hour = agentConfig.weeklySummaryHour
                                    return Calendar.current.date(from: comps) ?? Date()
                                },
                                set: { date in
                                    agentConfig.weeklySummaryHour = Calendar.current.component(.hour, from: date)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden().tint(VelaTheme.accent)
                    }
                }
            }
        }
        .cardSurface()
        .task {
            await checkNotificationStatus()
        }
    }

    @State private var notificationAuthorized = false

    private var notificationStatusText: String {
        if notificationAuthorized {
            return language.isChinese ? "已授权" : "Authorized"
        } else {
            return language.isChinese ? "未授权 — 点击授权以启用通知" : "Not authorized — tap to enable"
        }
    }

    private func checkNotificationStatus() async {
        let status = await NotificationService.shared.checkAuthorizationStatus()
        notificationAuthorized = status == .authorized || status == .provisional
    }

    private func notificationToggleRow(title: String, description: String, icon: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(VelaTheme.accent)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey = ""
    @Published var kimiApiKey = ""
    @Published var statusMessage = ""
    @Published var kimiStatusMessage = ""
    @Published var isTesting = false
    @Published var isError = false
    @Published var isKimiError = false

    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    private let kimiApiKeyAccount = FoodPhotoAnalyzer.keychainAccount

    init() {
        do {
            apiKey = try keychain.read(account: apiKeyAccount) ?? ""
            statusMessage = apiKey.isEmpty ? L10n.t("No API key saved.", "还没有保存 API Key。") : L10n.t("API key is saved in Keychain.", "API Key 已保存在 Keychain。")
            kimiApiKey = try keychain.read(account: kimiApiKeyAccount) ?? ""
            kimiStatusMessage = kimiApiKey.isEmpty ? L10n.t("No Kimi API key saved.", "还没有保存 Kimi API Key。") : L10n.t("Kimi API key is saved in Keychain.", "Kimi API Key 已保存在 Keychain。")
        } catch {
            statusMessage = L10n.t("Could not read Keychain item.", "无法读取 Keychain。")
            kimiStatusMessage = L10n.t("Could not read Keychain item.", "无法读取 Keychain。")
            isError = true
            isKimiError = true
        }
    }

    func saveKey() {
        do {
            let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                keychain.delete(account: apiKeyAccount)
                statusMessage = L10n.t("API key removed.", "API Key 已移除。")
            } else {
                try keychain.save(trimmed, account: apiKeyAccount)
                statusMessage = L10n.t("API key saved in Keychain.", "API Key 已保存在 Keychain。")
            }
            isError = false
        } catch {
            statusMessage = L10n.t("Could not save API key.", "无法保存 API Key。")
            isError = true
        }
    }

    func saveKimiKey() {
        do {
            let trimmed = kimiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                keychain.delete(account: kimiApiKeyAccount)
                kimiStatusMessage = L10n.t("Kimi API key removed.", "Kimi API Key 已移除。")
            } else {
                try keychain.save(trimmed, account: kimiApiKeyAccount)
                kimiStatusMessage = L10n.t("Kimi API key saved in Keychain.", "Kimi API Key 已保存在 Keychain。")
            }
            isKimiError = false
        } catch {
            kimiStatusMessage = L10n.t("Could not save Kimi API key.", "无法保存 Kimi API Key。")
            isKimiError = true
        }
    }

    func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        do {
            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let provider = DeepSeekProvider(apiKey: key)
            _ = try await provider.complete(
                request: LLMRequest(
                    systemPrompt: "You are testing a private health app provider connection.",
                    userPrompt: L10n.t("Reply with a short confirmation.", "请用一句简短中文确认连接成功。"),
                    contextJSON: "{}"
                )
            )
            statusMessage = L10n.t("DeepSeek connection succeeded.", "DeepSeek 连接成功。")
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    func exportHealthData(modelContext: ModelContext) -> Data? {
        let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(90, endingAt: Date(), calendar: .current)
        let records = (try? repo.fetch(in: range)) ?? []

        let exportRecords: [[String: Any]] = records.map { record in
            [
                "date": record.date.formatted(.iso8601),
                "sleep_score": record.sleepScore as Any,
                "recovery_score": record.recoveryScore as Any,
                "strain_score": record.strainScore as Any,
                "stress_index": record.stressIndex as Any,
                "morning_energy": record.morningEnergy as Any,
                "current_energy": record.currentEnergy as Any
            ]
        }

        let export: [String: Any] = [
            "app": "Vela",
            "export_date": Date().formatted(.iso8601),
            "config_version": VelaAppMetadata.configVersion,
            "record_count": exportRecords.count,
            "records": exportRecords
        ]

        return try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }
}

// MARK: - JSONExportDocument

struct JSONExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
