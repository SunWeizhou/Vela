import Charts
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum VelaCapabilityAvailability {
    static let cloudKitSyncEnabled = false
}

// MARK: - VelaSettingsView — 我的 / Settings (Bevel Replica matching Screenshot 3)

struct VelaSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var cs
    
    // Persistent baselines for health calculations
    @AppStorage("vela_user_age") private var userAge = 30
    @AppStorage("vela_user_weight") private var userWeight = 72.0
    @AppStorage("vela_user_height") private var userHeight = 178.0
    
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
            VStack(spacing: 20) {
                // Profile Row (Card style)
                profileCardRow
                
                // 1. 通用 (General) Group matching Screenshot 3 + User Wiki + AI Models + Coach Style + Agent Automation
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(VelaTheme.muted)
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: AccountSettingsView()) {
                            settingsRow(icon: "person.fill", iconBg: Color(hex: "#00A896"), title: "账户", value: "本机资料")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: UserWikiArchiveView()) {
                            settingsRow(icon: "doc.text.fill", iconBg: VelaTheme.muted, title: "用户健康档案 (Wiki)", value: "本地记忆库")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: AIModelSettingsView()) {
                            settingsRow(icon: "cpu.fill", iconBg: Color(hex: "#5C6BC0"), title: "AI 智能模型设置", value: textModel)
                        }
                        
                        Divider().padding(.leading, 56)

                        NavigationLink(destination: CoachPersonalitySettingsView()) {
                            settingsRow(icon: "brain.head.profile", iconBg: Color(hex: "#FF5E3A"), title: "教练风格", value: currentCoachPersonalityName)
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: AgentAutomationSettingsView()) {
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#FFCC00"), title: "Agent 自动技能", value: "已配置")
                        }

                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: AppearanceSettingsView()) {
                            settingsRow(icon: "moon.fill", iconBg: Color(hex: "#AF52DE"), title: "外观", value: darkModeRaw == "dark" ? "深色" : (darkModeRaw == "light" ? "浅色" : "跟随系统"))
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: NotificationSettingsView()) {
                            settingsRow(
                                icon: "bell.fill",
                                iconBg: Color(hex: "#FF9F0A"),
                                title: "通知",
                                value: abnormalMetricAlertsOn || morningBriefOn || bedtimeRemindersOn ? "已配置" : "已关闭"
                            )
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: CustomizationSettingsView()) {
                            settingsRow(icon: "slider.horizontal.3", iconBg: Color(hex: "#FF5E3A"), title: "自定义", value: "\(dailyCalorieTarget) kcal · \(SleepTargetSettings.displayHours(sleepTargetHours))")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: ShortcutsSettingsView()) {
                            settingsRow(icon: "command", iconBg: Color(hex: "#FFCC00"), title: "快捷指令", value: "已接入")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: LanguageSettingsView()) {
                            settingsRow(
                                icon: "globe",
                                iconBg: Color(hex: "#34C759"),
                                title: "语言",
                                value: AppLanguage(rawValue: languageRaw)?.displayName ?? AppLanguage.simplifiedChinese.displayName
                            )
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
                
                // 2. 数据 (Data) Group matching Screenshot 3
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(VelaTheme.muted)
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: DataSourceSettingsView()) {
                            settingsRow(icon: "applewatch", iconBg: Color(hex: "#FF2D55"), title: "数据源", value: "Apple 健康")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: CGMSettingsView()) {
                            settingsRow(icon: "scope", iconBg: Color(hex: "#30A2FF"), title: "管理 CGM", value: "Apple 健康")
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: DataCoverageView()) {
                            settingsRow(icon: "waveform.path.ecg.rectangle", iconBg: Color(hex: "#5C6BC0"), title: "数据覆盖", value: "信号质量")
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: HealthDataResyncSettingsView()) {
                            settingsRow(icon: "arrow.clockwise.icloud.fill", iconBg: Color(hex: "#30A2FF"), title: "健康数据重同步", value: "最近 90 天")
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: TrustCenterView()) {
                            settingsRow(icon: "checkmark.shield.fill", iconBg: Color(hex: "#34C759"), title: "信任中心", value: "运行日志")
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: ExportDataSettingsView()) {
                            settingsRow(icon: "square.and.arrow.up.fill", iconBg: VelaTheme.muted, title: "数据导出", value: "JSON 格式")
                        }
                        
                        if VelaCapabilityAvailability.cloudKitSyncEnabled {
                            Divider().padding(.leading, 56)
 
                            NavigationLink(destination: iCloudSyncSettingsView()) {
                                settingsRow(icon: "icloud.fill", iconBg: VelaTheme.accent, title: "iCloud 同步", value: "已接入")
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
                
                // 3. 资源 (Resources) Group
                VStack(alignment: .leading, spacing: 8) {
                    Text("资源")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(VelaTheme.muted)
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: WhatsNewSettingsView()) {
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#5856D6"), title: "最新变化", value: "v0.1.0")
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
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
    
    // MARK: - Row builder
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
    
    // MARK: - Profile Card
    private var profileCardRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [VelaTheme.accent, Color(hex: "#64D2FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("本机健康资料")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("Local-first 存储")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
            }
            
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

// ==========================================
// MARK: - GENERAL SUBVIEWS IMPLEMENTATIONS
// ==========================================

// 1. Account Settings View
struct AccountSettingsView: View {
    @AppStorage("vela_user_age") private var userAge = 30
    @AppStorage("vela_user_weight") private var userWeight = 72.0
    @AppStorage("vela_user_height") private var userHeight = 178.0
    @AppStorage("vela_max_hr") private var userMaxHR = 0

    private var inferredMaxHR: Int {
        Int(UserProfileSettings.inferredMaxHeartRate(age: userAge))
    }

    private var displayedMaxHR: Int {
        userMaxHR >= 100 ? userMaxHR : inferredMaxHR
    }

    private var maxHeartRateBinding: Binding<Int> {
        Binding(
            get: { displayedMaxHR },
            set: { userMaxHR = $0 }
        )
    }
    
    var body: some View {
        Form {
            Section(header: Text("生理特征指标")) {
                Stepper("年龄: \(userAge) 岁", value: $userAge, in: 10...100)
                
                HStack {
                    Text("体重")
                    Spacer()
                    TextField("体重", value: $userWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                }
                
                HStack {
                    Text("身高")
                    Spacer()
                    TextField("身高", value: $userHeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("cm")
                }
                
                Stepper("最大心率: \(displayedMaxHR) bpm", value: maxHeartRateBinding, in: 100...240)

                Button("使用年龄推断值（\(inferredMaxHR) bpm）") {
                    userMaxHR = 0
                }
            }
        }
        .navigationTitle("账户与特征基准")
    }
}

// 2. User Wiki Archive View (Pristine markdown local memory editor)
struct UserWikiArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserWikiDocumentRecord.updatedAt, order: .reverse)
    private var wikiDocs: [UserWikiDocumentRecord]
    
    @State private var selectedDoc: UserWikiDocumentRecord?
    @State private var showEditor = false
    @State private var editText = ""
    @State private var editTitle = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("你的健康画像与个人背景 (Coach 的本地记忆知识库)")
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.muted)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                if wikiDocs.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("正在初始化本地健康档案...")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .onAppear {
                        initializeDefaultWikiDocs()
                    }
                } else {
                    ForEach(wikiDocs) { doc in
                        Button {
                            selectedDoc = doc
                            editTitle = doc.title
                            editText = doc.markdownContent
                            showEditor = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(doc.title)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(VelaTheme.fg)
                                    Spacer()
                                    Text(doc.filename)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(VelaTheme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(VelaTheme.accent.opacity(0.12)))
                                }
                                
                                Text(doc.markdownContent.prefix(120) + (doc.markdownContent.count > 120 ? "..." : ""))
                                    .font(.system(size: 13))
                                    .foregroundStyle(VelaTheme.muted)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Spacer()
                                    Text("更新于: \(formatDate(doc.updatedAt))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: "#C7C7CC"))
                                }
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("用户健康档案 (Wiki)")
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextField("标题", text: $editTitle)
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.secondaryGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    TextEditor(text: $editText)
                        .font(.system(size: 14, design: .monospaced))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.secondaryGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .background(VelaTheme.systemGroupedBackground)
                .navigationTitle("编辑档案")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showEditor = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            saveDocEdits()
                            showEditor = false
                        }
                        .bold()
                        .foregroundStyle(VelaTheme.accent)
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func saveDocEdits() {
        guard let doc = selectedDoc else { return }
        doc.title = editTitle
        doc.markdownContent = editText
        doc.updatedAt = Date()
        try? modelContext.save()
        
        // Synchronize with flat files
        try? WikiFileService.updateSection(filename: doc.filename, content: editText, mode: .replace)
    }
    
    private func initializeDefaultWikiDocs() {
        let docs = [
            ("profile.md", "基本画像", "## 个人基本生理画像\n- 年龄: 待补充\n- 训练水平: 待补充\n- 作息偏好: 待补充\n- 最大摄氧量基准: 待补充"),
            ("goals.md", "健康与运动目标", "## 健康与体能目标\n- 待补充"),
            ("diet.md", "饮食偏好与禁忌", "## 膳食偏好与日常规避\n- 饮食偏好: 待补充\n- 过敏或不耐受: 待补充\n- 咖啡因窗口: 待补充"),
            ("sleep.md", "睡眠卫生与环境", "## 睡眠卫生规程与卧室环境\n- 卧室环境: 待补充\n- 睡前习惯: 待补充")
        ]
        
        for (filename, title, content) in docs {
            let doc = UserWikiDocumentRecord(filename: filename, title: title, markdownContent: content)
            modelContext.insert(doc)
            // Synchronize with flat files
            try? WikiFileService.updateSection(filename: filename, content: content, mode: .replace)
        }
        try? modelContext.save()
    }
}

// 3. AI Model Settings View
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
            Section(header: Text("Coach API 秘钥配置")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeepSeek API Key")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    SecureField("输入 DeepSeek API 秘钥...", text: $deepseekKey)
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kimi API Key (视觉模型)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    SecureField("输入 Kimi API 秘钥...", text: $kimiKey)
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
                        Text(isTesting ? "正在连通性测试..." : "测试 API 连接")
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
            Text("API 密钥与模型选择已安全写入 Keychain 与 App 存储中。")
        }
        .navigationTitle("AI 智能模型设置")
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
            testResultText = "测试失败: 请先填写 DeepSeek API 密钥。"
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

// 4. Appearance Theme View
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

// 5. Notification Settings View
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

// 6. Customization Settings View
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

// 7. Siri Shortcuts View
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

// 8. Language Settings View
struct LanguageSettingsView: View {
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    
    var body: some View {
        Form {
            Section(header: Text("多语言选择")) {
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
                        Text("English")
                            .foregroundStyle(VelaTheme.fg)
                        Spacer()
                        if languageRaw == AppLanguage.english.rawValue { Image(systemName: "checkmark").foregroundStyle(VelaTheme.accent) }
                    }
                }
            }
        }
        .navigationTitle("应用语言")
    }
}

// 9. Data Sources Settings View
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
                // Tier Permissions Request Cards
                Text("健康数据权限请求")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.leading, 16)
                    .padding(.top, 16)

                VStack(spacing: 12) {
                    tierRequestCard(
                        tier: .core,
                        title: "1. 核心权限 (Core)",
                        desc: "睡眠分析、心率变异性(HRV)、静息心率、日常心率、呼吸频率、活动能量、日常训练、步数、体能训练。",
                        color: Color(hex: "#FF2D55")
                    )

                    tierRequestCard(
                        tier: .enhanced,
                        title: "2. 增强权限 (Enhanced)",
                        desc: "最大摄氧量(VO2Max)、体重、体脂率、去脂体重、血氧饱和度、腕部温度。",
                        color: Color(hex: "#AF52DE")
                    )

                    tierRequestCard(
                        tier: .advanced,
                        title: "3. 高级权限 (Advanced)",
                        desc: "血糖检测(CGM)、收缩压/舒张压、膳食水分、膳食摄入(能量、蛋白质、碳水、脂肪)、步态与步行稳定性、正念专注时间、睡眠呼吸紊乱(iOS 18+)。",
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
                    Text("成功向系统请求 \(successTier == .core ? "核心" : (successTier == .enhanced ? "增强" : "高级")) 权限！")
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

    private func tierRequestCard(tier: HealthPermissionTier, title: String, desc: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    Task {
                        do {
                            authErrorMessage = nil
                            successTier = nil
                            try await HealthAuthorizationService().requestAuthorization(tier: tier)
                            successTier = tier
                        } catch {
                            authErrorMessage = "权限授权失败: \(error.localizedDescription)"
                        }
                    }
                } label: {
                    Text("请求授权")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(color))
                }
                .buttonStyle(.plain)
            }

            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(2)
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
                ?? "已读取 Apple 健康数据"
        case .cache:
            return "正在显示最近一次 Apple 健康快照"
        case .empty:
            return "未读取到可用健康数据"
        case .preview:
            return "当前为调试模拟数据"
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
            do {
                try await HealthKitSyncEngine(
                    queryService: HealthKitQueryService(),
                    modelContext: modelContext
                ).syncPastDays(90, forceRefreshRecentDays: 90)
                statusMessage = "最近 90 天健康数据已重新同步。"
            } catch {
                statusMessage = "重新同步失败：\(error.localizedDescription)"
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

// 10. CGM settings view
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

// 9. iCloud Sync Settings View
struct iCloudSyncSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("iCloud云同步")) {
                Text("尚未接入")
                    .font(.system(size: 15, weight: .bold))

                Text("当前版本只使用本机 SwiftData 存储，尚未配置 CloudKit 同步。接入并验证跨设备合并策略前，不会展示自动备份开关。")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .navigationTitle("iCloud 同步")
    }
}

// 10. Whats New View
struct WhatsNewSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Vela v0.1.0 当前能力")
                    .font(.system(size: 22, weight: .bold))
                
                Text("当前版本已实现以下 local-first 能力：")
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 16) {
                    featureUpdateBlock(title: "弹性滑动 Dock 栏", desc: "基于 MatchedGeometry 的悬浮 Dock 滑块指示器。")
                    featureUpdateBlock(title: "快捷录入面板", desc: "加号面板提供餐食、活动、Coach 与处方入口。")
                    featureUpdateBlock(title: "健康日历总览", desc: "点击首页日期查看每日评分历史。")
                    featureUpdateBlock(title: "天气同步", desc: "基于 GeoIP 与 OpenMeteo 查询温度和城市，不申请精确位置权限。")
                    featureUpdateBlock(title: "食品条码查询", desc: "扫描包装条码后从 Open Food Facts 获取营养数据，并在保存前确认。")
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("最新变化")
    }
    
    private func featureUpdateBlock(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#34C759"))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(4)
                .padding(.leading, 26)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
    }
}

// MARK: - CoachPersonalitySettingsView

struct CoachPersonalitySettingsView: View {
    @AppStorage("vela_coach_personality") private var coachPersonalityRaw = CoachPersonality.guardian.rawValue
    @State private var selectedPersonality: CoachPersonality = .guardian

    var body: some View {
        Form {
            Section(header: Text("选择教练风格 (Coach Style)")) {
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

// MARK: - AgentAutomationSettingsView

struct AgentAutomationSettingsView: View {
    @StateObject private var agentConfig = AutoAgentConfig.shared
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    
    private var isChinese: Bool {
        AppLanguage(rawValue: languageRaw)?.isChinese ?? true
    }
    
    var body: some View {
        Form {
            Section(header: Text("Agent 技能自动执行")) {
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

// MARK: - ExportDataSettingsView

struct ExportDataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var exportData: Data?
    @State private var statusMessage = ""
    @State private var isError = false
    
    var body: some View {
        Form {
            Section(header: Text("数据导出与备份")) {
                Text("Vela 始终秉持 Local-first 理念，你的所有健康数据都保留在设备本地。为了数据迁移或备份，你可以将健康摘要与日志导出为 JSON 文件。数据在导出过程中不会离开你的设备。")
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.muted)
                    .padding(.vertical, 4)
                
                Button {
                    exportData = exportHealthData(modelContext: modelContext)
                    if exportData != nil {
                        showExporter = true
                    } else {
                        statusMessage = "生成导出数据失败。"
                        isError = true
                    }
                } label: {
                    Label("导出本地健康数据 (JSON)", systemImage: "doc.text.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.accent))
                }
                .buttonStyle(.plain)
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(isError ? .red : .green)
                }
            }
        }
        .navigationTitle("数据导出")
        .fileExporter(
            isPresented: $showExporter,
            document: exportData.flatMap { JSONExportDocument(data: $0) },
            contentType: .json,
            defaultFilename: "vela_health_export_\(Date().formatted(.iso8601).prefix(10)).json"
        ) { result in
            switch result {
            case .success(let url):
                statusMessage = "导出成功至: \(url.lastPathComponent)"
                isError = false
            case .failure(let error):
                statusMessage = "导出失败: \(error.localizedDescription)"
                isError = true
            }
        }
    }
    
    private func exportHealthData(modelContext: ModelContext) -> Data? {
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
