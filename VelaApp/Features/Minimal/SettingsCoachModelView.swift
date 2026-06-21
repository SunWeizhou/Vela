import SwiftUI
import SwiftData
import Charts

struct AIModelSettingsView: View {
    @AppStorage("vela_coach_text_model") private var textModel = "DeepSeek V4 Pro"
    @AppStorage("vela_coach_vision_model") private var visionModel = "Kimi 2.6"
    @State private var deepseekKey = ""
    @State private var kimiKey = ""
    @State private var isTesting = false
    @State private var testResultText = ""
    @State private var showSaveSuccess = false
    
    let textModels = DeepSeekTextModel.allCases.map(\.rawValue)
    let visionModels = ["Kimi 2.6"]
    
    var body: some View {
        Form {
            Section(header: Text("模型连接配置")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeepSeek 密钥")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    SecureField("输入 DeepSeek 密钥...", text: $deepseekKey)
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kimi 密钥（图片识别）")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    SecureField("输入 Kimi 密钥...", text: $kimiKey)
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("大语言模型选择")) {
                Picker("对话文本模型", selection: $textModel) {
                    ForEach(textModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                
                Picker("图像视觉模型", selection: $visionModel) {
                    ForEach(visionModels, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
            }
            
            Section(header: Text("连接测试与保存")) {
                Button {
                    Task {
                        await testConnection()
                    }
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().padding(.trailing, 8)
                        }
                        Text(isTesting ? "正在测试连接..." : "测试模型连接")
                            .bold()
                            .foregroundStyle(VelaTheme.accent)
                    }
                }
                
                if !testResultText.isEmpty {
                    Text(testResultText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(testResultText.contains("成功") ? Color(hex: "#34C759") : Color(hex: "#FF3B30"))
                }
                
                Button("保存配置") {
                    saveKeysToKeychain()
                }
                .bold()
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 22).fill(VelaTheme.accent))
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            loadKeysFromKeychain()
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("好") {}
        } message: {
            Text("模型密钥与模型选择已安全写入系统钥匙串和本机设置。")
        }
        .navigationTitle("AI 模型设置")
    }
    
    private func loadKeysFromKeychain() {
        if let dsKey = try? KeychainService.shared.read(account: "deepseek_api_key") {
            deepseekKey = dsKey
        }
        if let kmKey = try? KeychainService.shared.read(account: FoodPhotoAnalyzer.keychainAccount) {
            kimiKey = kmKey
        }
    }
    
    private func saveKeysToKeychain() {
        do {
            let trimmedDeepSeekKey = deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedKimiKey = kimiKey.trimmingCharacters(in: .whitespacesAndNewlines)
 
            if trimmedDeepSeekKey.isEmpty {
                KeychainService.shared.delete(account: "deepseek_api_key")
            } else {
                try KeychainService.shared.save(trimmedDeepSeekKey, account: "deepseek_api_key")
            }
 
            if trimmedKimiKey.isEmpty {
                KeychainService.shared.delete(account: FoodPhotoAnalyzer.keychainAccount)
            } else {
                try KeychainService.shared.save(trimmedKimiKey, account: FoodPhotoAnalyzer.keychainAccount)
            }
            showSaveSuccess = true
        } catch {
            testResultText = "保存失败: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func testConnection() async {
        let key = deepseekKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            testResultText = "测试失败：请先填写 DeepSeek 密钥。"
            return
        }
 
        isTesting = true
        testResultText = ""
        defer { isTesting = false }
 
        do {
            let startedAt = Date()
            _ = try await DeepSeekProvider(
                apiKey: key,
                model: DeepSeekTextModel(displayName: textModel).apiIdentifier
            ).complete(
                request: LLMRequest(
                    systemPrompt: "You are testing a private health app provider connection.",
                    userPrompt: "请用一句简短中文确认连接成功。",
                    contextJSON: "{}"
                )
            )
            let latencyMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
            testResultText = "连接测试成功。模型延时: \(latencyMilliseconds)ms"
        } catch {
            testResultText = "连接测试失败: \(error.localizedDescription)"
        }
    }
}

struct DataSourceSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @State private var isSyncing = false
    @State private var lastSync: Date?
    @State private var authErrorMessage: String?
    @State private var successTier: HealthPermissionTier?
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("连接 Apple 健康")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.leading, 16)
                    .padding(.top, 16)
 
                Text("按用途逐步授权。Vela 只读取你允许的数据，并用于生成恢复、训练负荷和长期趋势参考。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
 
                VStack(spacing: 12) {
                    tierRequestCard(
                        tier: .core,
                        title: "基础健康信号",
                        desc: "睡眠、HRV、静息心率、日常心率、呼吸、步数和训练记录。",
                        impact: "用于判断今天是否适合训练，以及恢复分数是否可信。",
                        action: "授权基础数据",
                        color: Color(hex: "#FF2D55")
                    )
 
                    tierRequestCard(
                        tier: .enhanced,
                        title: "体能与身体组成",
                        desc: "最大摄氧量、体重、体脂率、去脂体重、血氧和腕温。",
                        impact: "用于长期趋势、体能变化和恢复异常解释。",
                        action: "授权体能数据",
                        color: Color(hex: "#AF52DE")
                    )
 
                    tierRequestCard(
                        tier: .advanced,
                        title: "营养与进阶指标",
                        desc: "血糖、血压、水分、膳食摄入、步态稳定性、正念和睡眠呼吸事件。",
                        impact: "用于解释能量、压力、睡眠质量和训练波动来源。",
                        action: "授权进阶数据",
                        color: Color(hex: "#30A2FF")
                    )
                }
                .padding(.horizontal, 16)
 
                if let authErrorMessage {
                    Text(authErrorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }
 
                if let successTier {
                    Text("已向系统请求\(authorizationTierTitle(successTier))。")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#34C759"))
                        .padding(.horizontal, 16)
                }
 
                Text("已同步健康传感器")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.leading, 16)
                
                VStack(spacing: 0) {
                    sensorRow(
                        name: "Apple 健康",
                        status: appleHealthStatus,
                        count: appleHealthDetail
                    )
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                .padding(.horizontal, 16)
 
                Button {
                    Task {
                        isSyncing = true
                        await dashboardVM.refresh(modelContext: modelContext)
                        lastSync = Date()
                        isSyncing = false
                    }
                } label: {
                    HStack {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "正在同步..." : "立即同步 Apple 健康")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.accent))
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("健康数据源")
    }
 
    private func tierRequestCard(
        tier: HealthPermissionTier,
        title: String,
        desc: String,
        impact: String,
        action: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(color.opacity(0.12)))
 
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
 
                Spacer()
            }
 
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(2)
 
            Text(impact)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(2)
 
            Button {
                Task {
                    do {
                        authErrorMessage = nil
                        successTier = nil
                        try await HealthAuthorizationService().requestAuthorization(tier: tier)
                        successTier = tier
                    } catch {
                        authErrorMessage = "权限授权失败：\(error.localizedDescription)"
                    }
                }
            } label: {
                Text(action)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
    }
 
    private var appleHealthStatus: String {
        if isSyncing { return "同步中" }
        switch dashboardVM.dashboard.source {
        case .healthKit: return "已同步"
        case .cache: return "已读取缓存"
        case .empty: return "待同步"
        case .preview: return "模拟数据"
        }
    }
 
    private var appleHealthDetail: String {
        switch dashboardVM.dashboard.source {
        case .healthKit:
            return lastSync.map { "最近同步：\($0.formatted(date: .omitted, time: .shortened))" }
                ?? "已读取 Apple 健康 data"
        case .cache:
            return "正在显示最近一次 Apple 健康快照"
        case .empty:
            return "未读取到可用健康数据"
        case .preview:
            return "当前为调试模拟数据"
        }
    }
 
    private func authorizationTierTitle(_ tier: HealthPermissionTier) -> String {
        switch tier {
        case .core:
            return "基础健康信号授权"
        case .enhanced:
            return "体能与身体组成授权"
        case .advanced:
            return "营养与进阶指标授权"
        }
    }
    
    private func sensorRow(name: String, status: String, count: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(count)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
            Spacer()
            Text(status)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#34C759"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

struct HealthDataResyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: VelaServices
    @State private var isSyncing = false
    @State private var statusMessage = ""
 
    var body: some View {
        Form {
            Section {
                Text("重新读取并计算最近 90 天 Apple 健康数据。该操作会刷新已有缓存，适合补授权、换设备或发现旧数据未更新后使用。")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.muted)
 
                Button {
                    resync()
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Label("重新同步最近 90 天", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isSyncing)
            }
 
            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("健康数据重同步")
    }
 
    private func resync() {
        isSyncing = true
        statusMessage = "正在重新同步..."
        Task { @MainActor in
            await services.syncCoordinator.run(source: .healthKit, force: true) {
                do {
                    try await HealthKitSyncEngine(
                        queryService: services.queryService,
                        modelContext: modelContext
                    ).syncPastDays(90, forceRefreshRecentDays: 90)
                    statusMessage = "最近 90 天健康数据已重新同步。"
                } catch {
                    statusMessage = "重新同步失败：\(error.localizedDescription)"
                }
            }
            isSyncing = false
        }
    }
}

struct CGMSettingsSummary {
    let readings: [BloodGlucoseReading]
 
    init(readings: [BloodGlucoseReading]) {
        self.readings = readings.sorted { $0.date < $1.date }
    }
 
    var latestReading: BloodGlucoseReading? { readings.last }
    var readingCount: Int { readings.count }
    var hasReadings: Bool { !readings.isEmpty }
}

struct CGMSettingsView: View {
    @State private var readings: [BloodGlucoseReading] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
 
    private var summary: CGMSettingsSummary {
        CGMSettingsSummary(readings: readings)
    }
 
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourceCard
 
                if isLoading {
                    ProgressView("正在读取 Apple 健康血糖数据...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage {
                    emptyCard(message: errorMessage)
                } else if summary.hasReadings {
                    latestReadingCard
                    trendCard
                } else {
                    emptyCard(message: "Apple 健康中暂未读取到血糖样本。授权高级健康数据后，如果你的 CGM 已将记录写入 Apple 健康，趋势会自动出现在这里。")
                }
 
                Button {
                    Task { await requestAccessAndReload() }
                } label: {
                    Label("请求权限并刷新", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: "#30A2FF"))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(20)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("连续血糖监测 (CGM)")
        .task {
            await reload()
        }
    }
 
    private var sourceCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 30))
                .foregroundStyle(Color(hex: "#30A2FF"))
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#30A2FF").opacity(0.12))
                )
 
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple 健康 CGM 数据")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("读取已同步到 Apple 健康的血糖样本")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }
 
    private var latestReadingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最新血糖")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
 
            if let latest = summary.latestReading {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(latest.milligramsPerDeciliter.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                    Text("mg/dL")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                }
 
                Text("最近更新 \(latest.date.formatted(date: .abbreviated, time: .shortened)) · 近 14 天共 \(summary.readingCount) 条")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }
 
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近 14 天趋势")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
 
            Chart(summary.readings) { reading in
                LineMark(
                    x: .value("时间", reading.date),
                    y: .value("血糖", reading.milligramsPerDeciliter)
                )
                .foregroundStyle(Color(hex: "#30A2FF"))
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
 
                PointMark(
                    x: .value("时间", reading.date),
                    y: .value("血糖", reading.milligramsPerDeciliter)
                )
                .foregroundStyle(Color(hex: "#30A2FF"))
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 190)
        }
        .padding(16)
        .background(cardBackground)
    }
 
    private func emptyCard(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.triangle")
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: "#30A2FF"))
            Text("等待血糖数据")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
            Text(message)
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }
 
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
    }
 
    @MainActor
    private func requestAccessAndReload() async {
        isLoading = true
        do {
            try await HealthAuthorizationService().requestAuthorization(tier: .advanced)
            await reload()
        } catch {
            errorMessage = "无法读取 Apple 健康血糖数据：\(error.localizedDescription)"
            isLoading = false
        }
    }
 
    @MainActor
    private func reload() async {
        isLoading = true
        errorMessage = nil
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now
 
        do {
            readings = try await HealthKitQueryService().bloodGlucoseSamples(
                in: DateRangeQuery(start: start, end: now)
            )
        } catch {
            errorMessage = "无法读取 Apple 健康血糖数据：\(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct CoachPersonalitySettingsView: View {
    @AppStorage("vela_coach_personality") private var coachPersonalityRaw = CoachPersonality.guardian.rawValue
    @State private var selectedPersonality: CoachPersonality = .guardian
 
    var body: some View {
        Form {
            Section(header: Text("选择教练风格")) {
                ForEach(CoachPersonality.allCases) { personality in
                    Button {
                        selectedPersonality = personality
                        coachPersonalityRaw = personality.rawValue
                        CoachPersonality.current = personality
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: personality.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 28, height: 28)
                                .background(personality.tint)
                                .clipShape(Circle())
 
                            VStack(alignment: .leading, spacing: 4) {
                                Text(personality.displayName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text(personality.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VelaTheme.muted)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            if selectedPersonality == personality {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("AI 教练风格")
        .onAppear {
            selectedPersonality = CoachPersonality(rawValue: coachPersonalityRaw) ?? .guardian
        }
    }
}

struct AgentAutomationSettingsView: View {
    @StateObject private var agentConfig = AutoAgentConfig.shared
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    
    private var isChinese: Bool {
        AppLanguage(rawValue: languageRaw)?.isChinese ?? true
    }
    
    var body: some View {
        Form {
            Section(header: Text("自动任务执行")) {
                ForEach(agentConfig.skillList(isChinese: isChinese)) { skill in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: skill.icon)
                                .font(.body)
                                .foregroundStyle(VelaTheme.accent)
                                .frame(width: 28)
 
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isChinese ? skill.name : skill.enName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text(skill.schedule)
                                    .font(.caption2)
                                    .foregroundStyle(VelaTheme.muted)
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
 
                        Text(isChinese ? skill.description : skill.enDescription)
                            .font(.caption)
                            .foregroundStyle(VelaTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Agent 自动化技能")
    }
}
