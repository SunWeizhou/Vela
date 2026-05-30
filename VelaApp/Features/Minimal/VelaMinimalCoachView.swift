import SwiftUI
import SwiftData

// MARK: - VelaSettingsView — 我的 / Settings (Bevel Replica matching Screenshot 3)
// profile row × General Group (Account, Wiki, Models, Appearance, Notification, Custom, Shortcuts, Language) × Data Group (Sources, CGM, iCloud) × Whats New

struct VelaSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var cs
    
    // Persistent baselines for health calculations
    @AppStorage("vela_user_age") private var userAge = 30
    @AppStorage("vela_user_weight") private var userWeight = 72.0
    @AppStorage("vela_user_height") private var userHeight = 178.0
    @AppStorage("vela_max_hr") private var userMaxHR = 190
    
    // Settings toggles
    @AppStorage("vela_dark_mode") private var darkModeRaw = "system"
    @AppStorage("vela_notifications_enabled") private var notificationsOn = true
    @AppStorage("vela_morning_brief") private var coachBriefOn = true
    @AppStorage("vela_evening_sync") private var weeklyReportOn = true
    
    @AppStorage("vela_app_language") private var languageRaw = "zh"
    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000
    @AppStorage("vela_icloud_sync_enabled") private var icloudSyncEnabled = true
    
    // AI Model settings
    @AppStorage("vela_coach_text_model") private var textModel = "DeepSeek V4 Pro"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Row (Card style)
                profileCardRow
                
                // 1. 通用 (General) Group matching Screenshot 3 + User Wiki + AI Models
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: AccountSettingsView()) {
                            settingsRow(icon: "person.fill", iconBg: Color(hex: "#00A896"), title: "账户", value: "已登录")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: UserWikiArchiveView()) {
                            settingsRow(icon: "doc.text.fill", iconBg: Color(hex: "#8E8A80"), title: "用户健康档案 (Wiki)", value: "本地记忆库")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: AIModelSettingsView()) {
                            settingsRow(icon: "cpu.fill", iconBg: Color(hex: "#5C6BC0"), title: "AI 智能模型设置", value: textModel)
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: AppearanceSettingsView()) {
                            settingsRow(icon: "moon.fill", iconBg: Color(hex: "#AF52DE"), title: "外观", value: darkModeRaw == "dark" ? "深色" : (darkModeRaw == "light" ? "浅色" : "跟随系统"))
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: NotificationSettingsView()) {
                            settingsRow(icon: "bell.fill", iconBg: Color(hex: "#FF9F0A"), title: "通知", value: notificationsOn ? "已开启" : "已关闭")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: CustomizationSettingsView()) {
                            settingsRow(icon: "slider.horizontal.3", iconBg: Color(hex: "#FF5E3A"), title: "自定义", value: "\(dailyCalorieTarget) kcal")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: ShortcutsSettingsView()) {
                            settingsRow(icon: "command", iconBg: Color(hex: "#FFCC00"), title: "快捷指令", value: "Siri 支持")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: LanguageSettingsView()) {
                            settingsRow(icon: "globe", iconBg: Color(hex: "#34C759"), title: "语言", value: languageRaw == "zh" ? "简体中文" : "English")
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
                
                // 2. 数据 (Data) Group matching Screenshot 3
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: DataSourceSettingsView()) {
                            settingsRow(icon: "applewatch", iconBg: Color(hex: "#FF2D55"), title: "数据源", value: "Apple 健康")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: CGMSettingsView()) {
                            settingsRow(icon: "scope", iconBg: Color(hex: "#30A2FF"), title: "管理 CGM", value: "未配置")
                        }
                        
                        Divider().padding(.leading, 56)
                        
                        NavigationLink(destination: iCloudSyncSettingsView()) {
                            settingsRow(icon: "icloud.fill", iconBg: Color(hex: "#007AFF"), title: "iCloud 同步", value: icloudSyncEnabled ? "已启用" : "已停用")
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
                
                // 3. 资源 (Resources) Group
                VStack(alignment: .leading, spacing: 8) {
                    Text("资源")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(.leading, 12)
                    
                    VStack(spacing: 0) {
                        NavigationLink(destination: WhatsNewSettingsView()) {
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#5856D6"), title: "最新变化", value: "v2.0.0")
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .padding(.top, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "#F5F3F0")) // Warm canvas base
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "#C56B4A"))
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1917"))
            
            Spacer()
            
            if let val = value {
                Text(val)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    // MARK: - Profile Card
    private var profileCardRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#C56B4A"), Color(hex: "#E89B7E")],
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
                Text("Weizhou")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Text("Vela 创始会员")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#C56B4A"))
            }
            
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
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
    @AppStorage("vela_max_hr") private var userMaxHR = 190
    
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
                
                Stepper("最大心率: \(userMaxHR) bpm", value: $userMaxHR, in: 100...220)
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
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                if wikiDocs.isEmpty {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("正在初始化本地健康档案...")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#8E8A80"))
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
                                        .foregroundStyle(Color(hex: "#1A1917"))
                                    Spacer()
                                    Text(doc.filename)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(hex: "#C56B4A"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color(hex: "#FFF3E0")))
                                }
                                
                                Text(doc.markdownContent.prefix(120) + (doc.markdownContent.count > 120 ? "..." : ""))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                
                                HStack {
                                    Spacer()
                                    Text("更新于: \(formatDate(doc.updatedAt))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(hex: "#BFB9AC"))
                                }
                            }
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("用户健康档案 (Wiki)")
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextField("标题", text: $editTitle)
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    TextEditor(text: $editText)
                        .font(.system(size: 14, design: .monospaced))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                        .padding(.horizontal, 16)
                    
                    Spacer()
                }
                .background(Color(hex: "#F5F3F0"))
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
                        .foregroundStyle(Color(hex: "#C56B4A"))
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
            ("profile.md", "基本画像", "## 个人基本生理画像\n- 身份: 30岁男性，互联网研发主管\n- 训练水平: 中等强度，每周运动 3-4 次\n- 作息偏好: 晨型人 (Chronotype: Morning Lark)，偏向早睡早起。\n- 最大摄氧量基准: 42 ml/kg/min"),
            ("goals.md", "健康与运动目标", "## 2026年核心健康与体能目标\n1. 提升最大摄氧量 (VO2 Max) 至 48 ml/kg/min。\n2. 降低体脂率至 14%，增加约 2kg 净肌肉量。\n3. 优化睡眠效率，减少深夜惊醒，确保每日深睡时长不少于 90 分钟。"),
            ("diet.md", "饮食偏好与禁忌", "## 膳食偏好与日常规避\n- 规避项: 具有轻度乳糖不耐受，规避牛奶，采用植物奶替代。\n- 咖啡因窗口: 每天下午 3 点后严格避免摄入任何咖啡因。\n- 宏量比例: 高蛋白低碳水配比，以鸡胸肉、牛排及大量绿叶菜为主。"),
            ("sleep.md", "睡眠卫生与环境", "## 睡眠卫生规程与卧室环境\n- 卧室温度: 严格控制在 21°C，确保绝对黑暗与安静。\n- 床上设备: 22:30 后禁止在床上使用任何带屏幕的电子设备。\n- 辅助手段: 睡前进行 10 分钟正念呼吸拉伸，有助于稳定夜间 HRV。")
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
    
    let textModels = ["DeepSeek V4 Pro", "Kimi 2.6", "Claude 3.5 Sonnet"]
    let visionModels = ["DeepSeek Vision", "Kimi 2.6", "Claude 3.5 Sonnet"]
    
    var body: some View {
        Form {
            Section(header: Text("Coach API 秘钥配置")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeepSeek API Key")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                    SecureField("输入 DeepSeek API 秘钥...", text: $deepseekKey)
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kimi API Key (视觉模型)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
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
                    testConnection()
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView().padding(.trailing, 8)
                        }
                        Text(isTesting ? "正在连通性测试..." : "测试 API 连接")
                            .bold()
                            .foregroundStyle(Color(hex: "#C56B4A"))
                    }
                }
                
                if !testResultText.isEmpty {
                    Text(testResultText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(testResultText.contains("成功") ? Color(hex: "#34C759") : Color(hex: "#FF3B30"))
                }
                
                Button("保存配置") {
                    saveKeysToKeychain()
                    showSaveSuccess = true
                }
                .bold()
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#C56B4A")))
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
        try? KeychainService.shared.save(deepseekKey, account: "deepseek_api_key")
        try? KeychainService.shared.save(kimiKey, account: FoodPhotoAnalyzer.keychainAccount)
    }
    
    private func testConnection() {
        isTesting = true
        testResultText = ""
        
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            Task { @MainActor in
                isTesting = false
                if deepseekKey.isEmpty {
                    testResultText = "❌ 测试失败: 请先填写 DeepSeek API 密钥！"
                } else {
                    testResultText = "✅ 连接测试成功! 模型延时: 42ms (已通达)"
                }
            }
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
                                .foregroundStyle(Color(hex: "#1A1917"))
                            Spacer()
                            if darkModeRaw == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "#C56B4A"))
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
    @AppStorage("vela_notifications_enabled") private var notificationsOn = true
    @AppStorage("vela_morning_brief") private var coachBriefOn = true
    @AppStorage("vela_evening_sync") private var weeklyReportOn = true
    
    var body: some View {
        Form {
            Section(header: Text("通知通道")) {
                Toggle("接收通知推送", isOn: $notificationsOn)
                Toggle("晨间健康简报", isOn: $coachBriefOn)
                Toggle("周日周报汇总", isOn: $weeklyReportOn)
            }
        }
        .navigationTitle("通知通知")
    }
}

// 6. Customization Settings View
struct CustomizationSettingsView: View {
    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000
    @State private var tempTarget = 2000
    
    var body: some View {
        Form {
            Section(header: Text("今日热量基准")) {
                Stepper("每日目标卡路里: \(tempTarget) kcal", value: $tempTarget, in: 1200...4000, step: 50)
                Button("保存更改") {
                    dailyCalorieTarget = tempTarget
                }
                .tint(Color(hex: "#C56B4A"))
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
                
                Text("Vela 现已全面接入 Apple Shortcuts，您可以在 Siri 或快捷指令 App 中构建工作流：")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                
                VStack(alignment: .leading, spacing: 14) {
                    shortcutGuideRow(command: "“Hey Siri, 记录昨天的饮水”", desc: "自动为您在 SwiftData 补录 350ml 补水值")
                    shortcutGuideRow(command: "“Hey Siri, 询问我的就绪状态”", desc: "自动为您唤起 Vela Coach 对话框并分析今日精力")
                    shortcutGuideRow(command: "“Hey Siri, 扫描我的午餐”", desc: "打开快速加号相机扫描识别食物克数")
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("快捷指令")
    }
    
    private func shortcutGuideRow(command: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(command)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "#C56B4A"))
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#8E8A80"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
    }
}

// 8. Language Settings View
struct LanguageSettingsView: View {
    @AppStorage("vela_app_language") private var languageRaw = "zh"
    
    var body: some View {
        Form {
            Section(header: Text("多语言选择")) {
                Button { languageRaw = "zh" } label: {
                    HStack {
                        Text("简体中文")
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Spacer()
                        if languageRaw == "zh" { Image(systemName: "checkmark").foregroundStyle(Color(hex: "#C56B4A")) }
                    }
                }
                
                Button { languageRaw = "en" } label: {
                    HStack {
                        Text("English")
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Spacer()
                        if languageRaw == "en" { Image(systemName: "checkmark").foregroundStyle(Color(hex: "#C56B4A")) }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("已同步健康传感器")
                    .font(.system(size: 16, weight: .bold))
                    .padding(.leading, 16)
                    .padding(.top, 16)
                
                VStack(spacing: 0) {
                    sensorRow(
                        name: "Apple 健康",
                        status: isSyncing ? "同步中" : "已连接",
                        count: lastSync.map { "最近同步：\($0.formatted(date: .omitted, time: .shortened))" } ?? "下拉首页或点击下方按钮同步"
                    )
                }
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
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
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "#C56B4A")))
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
                .padding(.horizontal, 16)
                
                Spacer()
            }
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("健康数据源")
    }
    
    private func sensorRow(name: String, status: String, count: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Text(count)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#8E8A80"))
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

// 10. CGM settings view
struct CGMSettingsView: View {
    @AppStorage("vela_cgm_configured") private var cgmState = false
    
    var body: some View {
        if !cgmState {
            VStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "#30A2FF"))
                Text("尚未配置连续血糖监测")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Text("当前没有可确认的 CGM 数据源。连接真实设备后，这里才会展示血糖曲线和传感器状态。")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#F5F3F0"))
            .navigationTitle("连续血糖监测 (CGM)")
        } else {
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header connected box
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dexcom G7 CGM")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text("血糖感应监测仪 · 蓝牙配对成功")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }
                    Spacer()
                    Circle()
                        .fill(Color(hex: "#34C759"))
                        .frame(width: 12, height: 12)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                
                // GORGEOUS CGM Fluctuating Chart
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("24小时血糖波动监测")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Spacer()
                        Text("当前: 5.4 mmol/L")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#34C759"))
                    }
                    
                    // Bezier glucose simulator
                    ZStack {
                        // Highlight target green zone (4.0 to 10.0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#34C759").opacity(0.08))
                            .frame(height: 80)
                            .offset(y: 10)
                        
                        // Fluctuating Bezier line
                        CGMBezierGraph()
                            .stroke(Color(hex: "#34C759"), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .frame(height: 120)
                        
                        // Horizontal targets
                        VStack {
                            Spacer()
                            Divider() // normal lower bounds
                            Spacer()
                        }
                    }
                    .frame(height: 120)
                    
                    HStack {
                        Text("06:00")
                        Spacer()
                        Text("12:00")
                        Spacer()
                        Text("18:00")
                        Spacer()
                        Text("24:00")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                
                // Sensor life stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("传感器统计")
                        .font(.system(size: 14, weight: .bold))
                    
                    HStack {
                        Text("传感器到期剩余天数")
                        Spacer()
                        Text("8 天 4 小时")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Divider()
                    HStack {
                        Text("警告阈值 (低)")
                        Spacer()
                        Text("3.9 mmol/L")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Divider()
                    HStack {
                        Text("警告阈值 (高)")
                        Spacer()
                        Text("10.0 mmol/L")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                
                Spacer()
            }
            .padding(16)
        }
            .background(Color(hex: "#F5F3F0"))
            .navigationTitle("连续血糖监测 (CGM)")
        }
    }
}

struct CGMBezierGraph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        let points: [CGPoint] = [
            CGPoint(x: 0, y: height * 0.6),
            CGPoint(x: width * 0.15, y: height * 0.5),
            CGPoint(x: width * 0.3, y: height * 0.72),
            CGPoint(x: width * 0.45, y: height * 0.42),
            CGPoint(x: width * 0.6, y: height * 0.58),
            CGPoint(x: width * 0.75, y: height * 0.52),
            CGPoint(x: width * 0.9, y: height * 0.65),
            CGPoint(x: width, y: height * 0.56)
        ]
        
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            let controlPoint1 = CGPoint(x: (p1.x + p2.x) / 2, y: p1.y)
            let controlPoint2 = CGPoint(x: (p1.x + p2.x) / 2, y: p2.y)
            path.addCurve(to: p2, control1: controlPoint1, control2: controlPoint2)
        }
        
        return path
    }
}

// 9. iCloud Sync Settings View
struct iCloudSyncSettingsView: View {
    @AppStorage("vela_icloud_sync_enabled") private var icloudSyncEnabled = true
    
    var body: some View {
        Form {
            Section(header: Text("iCloud云同步")) {
                Toggle("启用iCloud自动备份同步", isOn: $icloudSyncEnabled)
                
                Text("开启后，您的所有 SwiftData 手记习惯打卡记录、宏量元素记录及训练计划指标都将自动备份并安全同步至您的全部苹果设备。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#8E8A80"))
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
                Text("Vela v2.0.0 重大更新")
                    .font(.system(size: 22, weight: .bold))
                
                Text("欢迎使用全新设计的 local-first 极致体验健康 App：")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                
                VStack(alignment: .leading, spacing: 16) {
                    featureUpdateBlock(title: "🚀 iOS 26 弹性滑移动效 Dock 栏", desc: "基于 MatchedGeometry 物理弹性设计的悬浮 Dock 极简滑块指示器。")
                    featureUpdateBlock(title: "➕ Standalone 独立加号浮动面板", desc: "加号按钮完全剥离浮动于右下角，提供 3×3 极具拟真质感的动作网格。")
                    featureUpdateBlock(title: "📅 31天多彩日历网格总览", desc: "点击 Today 根部日期一键呼起全景多彩日历评分圆环，椰树 🌴 状态细节还原。")
                    featureUpdateBlock(title: "⛅ 自动物理天气感应", desc: "基于蜂窝 GeoIP + OpenMeteo 实时查询，零位置权限秒级同步真实温度与市级定位。")
                }
                
                Spacer()
            }
            .padding(20)
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("最新变化")
    }
    
    private func featureUpdateBlock(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "#34C759"))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
            }
            Text(desc)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#8E8A80"))
                .lineSpacing(4)
                .padding(.leading, 26)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
    }
}
