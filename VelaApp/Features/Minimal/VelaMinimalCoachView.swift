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
                            settingsRow(icon: "doc.text.fill", iconBg: VelaTheme.muted, title: "健康档案", value: "本地长期记忆")
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

                        NavigationLink(destination: PrivacyDataControlsView()) {
                            settingsRow(icon: "lock.shield.fill", iconBg: Color(hex: "#5856D6"), title: "隐私与数据控制", value: "导出 / 删除")
                        }

                        Divider().padding(.leading, 56)

                        NavigationLink(destination: ExportDataSettingsView()) {
                            settingsRow(icon: "square.and.arrow.up.fill", iconBg: VelaTheme.muted, title: "数据导出", value: "本地资料")
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
                            settingsRow(icon: "sparkles", iconBg: Color(hex: "#5856D6"), title: "最新变化", value: "更新记录")
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
                Text("本机优先存储")
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
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @AppStorage("vela_user_age") private var userAge = 0
    @AppStorage("vela_user_weight") private var userWeight = 0.0
    @AppStorage("vela_user_height") private var userHeight = 0.0
    @AppStorage("vela_max_hr") private var userMaxHR = 0
    @AppStorage("vela_user_biological_sex") private var biologicalSex = ""
    @State private var ageDraft = ""
    @State private var weightDraft = ""
    @State private var heightDraft = ""
    @State private var maxHeartRateDraft = ""
    @State private var validationMessage: String?

    private var storedAge: Int? {
        Int(ageDraft).flatMap { (10...100).contains($0) ? $0 : nil }
    }

    private var inferredMaxHR: Int? {
        storedAge.map { Int(UserProfileSettings.inferredMaxHeartRate(age: $0)) }
    }

    var body: some View {
        Form {
            Section(header: Text("生理特征指标")) {
                HStack {
                    TextField("年龄", text: $ageDraft)
                        .keyboardType(.numberPad)
                    Text("岁")
                }
                HStack {
                    TextField("体重", text: $weightDraft)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                }
                HStack {
                    TextField("身高", text: $heightDraft)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("cm")
                }
                HStack {
                    TextField("最大心率（可选）", text: $maxHeartRateDraft)
                        .keyboardType(.numberPad)
                    Text("bpm")
                }

                Picker("生理性别", selection: $biologicalSex) {
                    Text("未设置").tag("")
                    Text("男性").tag("male")
                    Text("女性").tag("female")
                    Text("其他").tag("other")
                }

                if let inferredMaxHR {
                    Button("使用年龄推断值（\(inferredMaxHR) bpm）") {
                        maxHeartRateDraft = ""
                    }
                } else {
                    Text("填写年龄后可使用年龄推断的最大心率。")
                        .font(.footnote)
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }

            Section {
                Button("应用身体模型") {
                    applyProfile()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
            } footer: {
                Text("已填写的数值优先于缺失字段的 Apple 健康数据；应用后会重新计算训练建议。")
            }
        }
        .navigationTitle("账户与特征基准")
        .onAppear {
            ageDraft = (10...100).contains(userAge) ? String(userAge) : ""
            weightDraft = (25...350).contains(userWeight) ? String(format: "%.1f", userWeight) : ""
            heightDraft = (100...250).contains(userHeight) ? String(format: "%.0f", userHeight) : ""
            maxHeartRateDraft = (100...240).contains(userMaxHR) ? String(userMaxHR) : ""
        }
        .alert("无法应用身体模型", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("好", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private func applyProfile() {
        let parsedAge = ageDraft.isEmpty ? nil : Int(ageDraft)
        let parsedWeight = weightDraft.isEmpty ? nil : Double(weightDraft)
        let parsedHeight = heightDraft.isEmpty ? nil : Double(heightDraft)
        let parsedMaxHeartRate = maxHeartRateDraft.isEmpty ? nil : Int(maxHeartRateDraft)

        guard parsedAge.map({ (10...100).contains($0) }) ?? true,
              parsedWeight.map({ (25...350).contains($0) }) ?? true,
              parsedHeight.map({ (100...250).contains($0) }) ?? true,
              parsedMaxHeartRate.map({ (100...240).contains($0) }) ?? true else {
            validationMessage = "请检查输入范围：年龄 10-100 岁，体重 25-350 kg，身高 100-250 cm，最大心率 100-240 bpm。"
            return
        }

        userAge = parsedAge ?? 0
        userWeight = parsedWeight ?? 0
        userHeight = parsedHeight ?? 0
        userMaxHR = parsedMaxHeartRate ?? 0
        VelaAppState.shared.markLocalDataChanged()
        Task {
            await dashboardVM.refresh(modelContext: modelContext, force: true)
        }
    }
}

// 2. User Wiki Archive View (Pristine markdown local memory editor)
enum EditorMode {
    case form
    case markdown
}

struct ParsedItem: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String
    var isKeyValue: Bool
    
    init(id: UUID = UUID(), key: String, value: String, isKeyValue: Bool) {
        self.id = id
        self.key = key
        self.value = value
        self.isKeyValue = isKeyValue
    }
}

struct UserWikiArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserWikiDocumentRecord.updatedAt, order: .reverse)
    private var wikiDocs: [UserWikiDocumentRecord]
    
    @State private var selectedDoc: UserWikiDocumentRecord?
    @State private var showEditor = false
    @State private var editText = ""
    @State private var editTitle = ""
    
    @State private var editorMode: EditorMode = .form
    @State private var parsedItems: [ParsedItem] = []
    @State private var notesText: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("你的健康画像与个人背景会作为 Coach 的本地长期记忆，用于改善训练、恢复和营养建议。")
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
                        WikiSyncManager.sync(modelContext: modelContext)
                    }
                } else {
                    ForEach(wikiDocs) { doc in
                        Button {
                            selectedDoc = doc
                            editTitle = doc.title
                            editText = doc.markdownContent
                            parseMarkdown(doc.markdownContent)
                            editorMode = .form
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
        .navigationTitle("健康档案")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("返回", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
        .task {
            WikiSyncManager.sync(modelContext: modelContext)
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                VStack(spacing: 0) {
                    Picker("编辑模式", selection: $editorMode) {
                        Text("表单编辑").tag(EditorMode.form)
                        Text("源码编辑").tag(EditorMode.markdown)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    TextField("标题", text: $editTitle)
                        .font(.system(size: 16, weight: .bold))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.secondaryGroupedBackground))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    if editorMode == .form {
                        ScrollView {
                            VStack(spacing: 16) {
                                if parsedItems.isEmpty {
                                    VStack(spacing: 12) {
                                        Text("无结构化项目。")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(VelaTheme.muted)
                                        Text("你可以使用下方按钮添加属性或普通列表项。")
                                            .font(.system(size: 12))
                                            .foregroundStyle(VelaTheme.muted)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.secondaryGroupedBackground))
                                    .padding(.horizontal, 16)
                                } else {
                                    VStack(alignment: .leading, spacing: 14) {
                                        ForEach($parsedItems) { $item in
                                            HStack(spacing: 12) {
                                                Button {
                                                    if let index = parsedItems.firstIndex(where: { $0.id == item.id }) {
                                                        withAnimation {
                                                            _ = parsedItems.remove(at: index)
                                                        }
                                                    }
                                                } label: {
                                                    Image(systemName: "minus.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.plain)
                                                
                                                VStack(alignment: .leading, spacing: 6) {
                                                    if item.isKeyValue {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: "tag.fill")
                                                                .font(.system(size: 11))
                                                                .foregroundStyle(VelaTheme.accent)
                                                            TextField("属性名", text: $item.key)
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundStyle(VelaTheme.accent)
                                                        }
                                                        
                                                        TextField("属性值", text: $item.value)
                                                            .font(.system(size: 14))
                                                            .foregroundStyle(VelaTheme.fg)
                                                            .padding(.leading, 19)
                                                    } else {
                                                        HStack(spacing: 8) {
                                                            Image(systemName: "list.bullet")
                                                                .font(.system(size: 12))
                                                                .foregroundStyle(VelaTheme.muted)
                                                            TextField("列表内容", text: $item.value)
                                                                .font(.system(size: 14))
                                                                .foregroundStyle(VelaTheme.fg)
                                                        }
                                                    }
                                                }
                                                .padding(12)
                                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.cardBg))
                                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                
                                // Buttons to dynamically add elements
                                HStack(spacing: 16) {
                                    Button {
                                        withAnimation {
                                            parsedItems.append(ParsedItem(key: "新属性", value: "", isKeyValue: true))
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("新增属性")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(VelaTheme.accent)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(Capsule().fill(VelaTheme.accent.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        withAnimation {
                                            parsedItems.append(ParsedItem(key: "", value: "新列表项", isKeyValue: false))
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("新增列表项")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(VelaTheme.muted)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 16)
                                        .background(Capsule().fill(VelaTheme.muted.opacity(0.12)))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("其它备注信息 (Markdown)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VelaTheme.muted)
                                    
                                    TextEditor(text: $notesText)
                                        .font(.system(size: 14))
                                        .frame(height: 120)
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.cardBg))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        TextEditor(text: $editText)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.cardBg))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    
                    Spacer(minLength: 16)
                }
                .background(VelaTheme.systemGroupedBackground)
                .navigationTitle("编辑健康档案")
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
    
    private func parseMarkdown(_ text: String) {
        var items: [ParsedItem] = []
        var extraLines: [String] = []
        var hasSkippedPrimaryHeading = false
        
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") {
                if !hasSkippedPrimaryHeading, trimmed.hasPrefix("# "), String(trimmed.dropFirst(2)) == editTitle {
                    hasSkippedPrimaryHeading = true
                    continue
                }
                extraLines.append(line)
                continue
            }
            
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let colonIndex = content.firstIndex(of: ":") {
                    let key = String(content[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    items.append(ParsedItem(key: key, value: value, isKeyValue: true))
                } else if let cnColonIndex = content.firstIndex(of: "：") {
                    let key = String(content[..<cnColonIndex]).trimmingCharacters(in: .whitespaces)
                    let value = String(content[content.index(after: cnColonIndex)...]).trimmingCharacters(in: .whitespaces)
                    items.append(ParsedItem(key: key, value: value, isKeyValue: true))
                } else {
                    items.append(ParsedItem(key: "", value: content, isKeyValue: false))
                }
            } else {
                extraLines.append(trimmed)
            }
        }
        
        self.parsedItems = items
        self.notesText = extraLines.joined(separator: "\n")
    }
    
    private func reconstructMarkdown() -> String {
        var lines: [String] = []
        lines.append("# \(editTitle)")
        lines.append("")
        
        for item in parsedItems {
            if item.isKeyValue {
                lines.append("- \(item.key): \(item.value)")
            } else {
                lines.append("- \(item.value)")
            }
        }
        
        if !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append(notesText)
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func saveDocEdits() {
        guard let doc = selectedDoc else { return }
        
        let finalContent: String
        if editorMode == .form {
            finalContent = reconstructMarkdown()
        } else {
            finalContent = editText
        }
        
        try? WikiFileService.updateSection(filename: doc.filename, content: finalContent, mode: .replace)
        WikiSyncManager.sync(modelContext: modelContext)
    }
    
    private func initializeDefaultWikiDocs() {
        WikiSyncManager.sync(modelContext: modelContext)
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
                ?? "已读取 Apple 健康数据"
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
            Section(header: Text("iCloud 云同步")) {
                Text("尚未接入")
                    .font(.system(size: 15, weight: .bold))

                Text("当前版本只使用本机数据库保存资料，尚未开启 iCloud 跨设备同步。完成合并策略验证前，不会展示自动备份开关。")
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
                
                Text("当前版本已实现以下本机优先能力：")
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 16) {
                    featureUpdateBlock(title: "今日指挥中心", desc: "把准备度、睡眠、恢复、负荷、营养和数据覆盖合成为一个可执行日计划。")
                    featureUpdateBlock(title: "自适应训练座舱", desc: "根据今日计划、局部疲劳和训练记录决定保持、减量、替换或休息。")
                    featureUpdateBlock(title: "Coach 证据边界", desc: "AI 回答会标注数据覆盖状态，缺失健康或训练证据时降低确定性。")
                    featureUpdateBlock(title: "信任中心与隐私控制", desc: "可查看数据覆盖、导出本地资料，并删除对话、记忆、报告和训练记录。")
                    featureUpdateBlock(title: "天气同步", desc: "授权后使用约 3 公里精度获取 Open-Meteo 天气，并缓存位置快照 7 天以减少重复请求。")
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

// MARK: - AgentAutomationSettingsView

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

// MARK: - ExportDataSettingsView

struct PrivacyDataCategory: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var count: Int
    var isExported: Bool
}

enum PrivacyDeletionScope: String, Hashable, CaseIterable {
    case aiHistory
    case localLogs
    case allLocalVelaData
}

struct PrivacyDeleteGroup: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var systemImage: String
    var scope: PrivacyDeletionScope
    var isDestructive: Bool
}

struct PrivacyDataInventoryModel: Hashable {
    var categories: [PrivacyDataCategory]
    var deleteGroups: [PrivacyDeleteGroup]
    var localOnlyNotice: String
    var irreversibleWarning: String

    var exportCategories: [PrivacyDataCategory] {
        categories.filter(\.isExported)
    }

    var totalExportedItems: Int {
        exportCategories.reduce(0) { $0 + $1.count }
    }

    static func build(counts: [String: Int]) -> PrivacyDataInventoryModel {
        let categories = [
            PrivacyDataCategory(
                id: "daily_summaries",
                title: "每日健康摘要",
                detail: "恢复、睡眠、负荷、HRV、静息心率、步数和活动摘要。",
                count: counts["daily_summaries", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "strength_workouts",
                title: "力量训练记录",
                detail: "训练标题、组次、重量、RPE、训练量和本地分析结果。",
                count: counts["strength_workouts", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "journals",
                title: "日记与行为信号",
                detail: "你手动记录的标签、文字备注、数值和单位。",
                count: counts["journals", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "food_logs",
                title: "饮食日志",
                detail: "餐食、营养估算、来源、图片分析摘要和改进建议。",
                count: counts["food_logs", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "biomarkers",
                title: "手动化验指标",
                detail: "你录入的生物标志物、参考范围和来源文件名。",
                count: counts["biomarkers", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "wiki_documents",
                title: "本地 Coach 记忆",
                detail: "Vela 生成或你确认的身体画像、基线和长期偏好。",
                count: counts["wiki_documents", default: 0],
                isExported: true
            ),
            PrivacyDataCategory(
                id: "coach_sessions",
                title: "Coach 对话",
                detail: "本机保存的聊天会话和消息历史。",
                count: counts["coach_sessions", default: 0],
                isExported: false
            ),
            PrivacyDataCategory(
                id: "agent_runs",
                title: "AI 运行日志",
                detail: "Morning Brief、Evening Sync、Coach 工具调用和可审计运行记录。",
                count: counts["agent_runs", default: 0] + counts["agent_artifacts", default: 0],
                isExported: false
            )
        ]

        return PrivacyDataInventoryModel(
            categories: categories,
            deleteGroups: [
                PrivacyDeleteGroup(
                    id: "ai_history",
                    title: "删除 Coach 与 AI 历史",
                    detail: "删除对话、AI 报告、运行日志和 Agent 产物；不会删除健康摘要或训练记录。",
                    systemImage: "sparkles.rectangle.stack.fill",
                    scope: .aiHistory,
                    isDestructive: true
                ),
                PrivacyDeleteGroup(
                    id: "local_logs",
                    title: "删除手动日志",
                    detail: "删除日记、饮食、化验指标和力量训练记录；不会删除 Apple Health 原始数据。",
                    systemImage: "list.bullet.clipboard.fill",
                    scope: .localLogs,
                    isDestructive: true
                ),
                PrivacyDeleteGroup(
                    id: "all_local",
                    title: "清空 Vela 本地数据",
                    detail: "删除 Vela 本机数据库中的摘要、日志、计划、对话、AI 产物和记忆。",
                    systemImage: "trash.fill",
                    scope: .allLocalVelaData,
                    isDestructive: true
                )
            ],
            localOnlyNotice: "Vela 的本地数据库与 Apple Health 原始数据分离。导出或删除 Vela 数据不会删除 Apple Health 中的原始记录。",
            irreversibleWarning: "删除后无法从 Vela 内恢复。建议先导出本地备份。"
        )
    }

    func category(id: String) -> PrivacyDataCategory? {
        categories.first { $0.id == id }
    }
}

@MainActor
enum PrivacyDataInventoryBuilder {
    static func build(modelContext: ModelContext) -> PrivacyDataInventoryModel {
        PrivacyDataInventoryModel.build(counts: [
            "daily_summaries": count(DailyHealthSummaryRecord.self, in: modelContext),
            "strength_workouts": count(StrengthWorkoutRecord.self, in: modelContext),
            "workout_events": count(WorkoutEventRecord.self, in: modelContext),
            "journals": count(JournalEntryRecord.self, in: modelContext),
            "food_logs": count(FoodLogRecord.self, in: modelContext),
            "biomarkers": count(BiomarkerRecord.self, in: modelContext),
            "wiki_documents": count(UserWikiDocumentRecord.self, in: modelContext),
            "coach_sessions": count(CoachSessionRecord.self, in: modelContext),
            "coach_interactions": count(CoachInteractionRecord.self, in: modelContext),
            "coach_artifacts": count(CoachArtifactRecord.self, in: modelContext),
            "ai_reports": count(AIReportRecord.self, in: modelContext),
            "agent_runs": count(AgentRunRecord.self, in: modelContext),
            "agent_artifacts": count(AgentArtifactRecord.self, in: modelContext),
            "training_plans": count(TrainingPlanRecord.self, in: modelContext)
        ])
    }

    private static func count<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) -> Int {
        (try? modelContext.fetch(FetchDescriptor<T>()).count) ?? 0
    }
}

@MainActor
enum PrivacyDataDeletionService {
    static func delete(scope: PrivacyDeletionScope, modelContext: ModelContext) throws -> Int {
        var deleted = 0

        switch scope {
        case .aiHistory:
            deleted += try deleteAll(CoachSessionRecord.self, in: modelContext)
            deleted += try deleteAll(CoachInteractionRecord.self, in: modelContext)
            deleted += try deleteAll(CoachArtifactRecord.self, in: modelContext)
            deleted += try deleteAll(AIReportRecord.self, in: modelContext)
            deleted += try deleteAll(AgentRunRecord.self, in: modelContext)
            deleted += try deleteAll(AgentArtifactRecord.self, in: modelContext)
        case .localLogs:
            deleted += try deleteAll(JournalEntryRecord.self, in: modelContext)
            deleted += try deleteAll(FoodLogRecord.self, in: modelContext)
            deleted += try deleteAll(BiomarkerRecord.self, in: modelContext)
            deleted += try deleteAll(StrengthWorkoutRecord.self, in: modelContext)
            deleted += try deleteAll(WorkoutEventRecord.self, in: modelContext)
            deleted += try deleteAll(TrainingResponseRecord.self, in: modelContext)
        case .allLocalVelaData:
            for scope in [PrivacyDeletionScope.aiHistory, .localLogs] {
                deleted += try delete(scope: scope, modelContext: modelContext)
            }
            deleted += try deleteAll(DailyHealthSummaryRecord.self, in: modelContext)
            deleted += try deleteAll(SleepSummaryRecord.self, in: modelContext)
            deleted += try deleteAll(UserWikiDocumentRecord.self, in: modelContext)
            deleted += try deleteAll(DailyOperatingPlanRecord.self, in: modelContext)
            deleted += try deleteAll(TrainingPlanRecord.self, in: modelContext)
            deleted += try deleteAll(WorkoutTemplateRecord.self, in: modelContext)
            deleted += try deleteAll(OnboardingState.self, in: modelContext)
            deleted += try deleteAll(XunjiDailyCacheRecord.self, in: modelContext)
            deleted += try deleteAll(XunjiWorkoutMirrorRecord.self, in: modelContext)
        }

        try modelContext.save()
        return deleted
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) throws -> Int {
        let records = try modelContext.fetch(FetchDescriptor<T>())
        records.forEach(modelContext.delete)
        return records.count
    }
}

struct PrivacyDataControlsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inventory = PrivacyDataInventoryModel.build(counts: [:])
    @State private var pendingDeleteGroup: PrivacyDeleteGroup?
    @State private var statusMessage = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section("本地优先") {
                Label(inventory.localOnlyNotice, systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.muted)
            }

            Section("可导出数据") {
                ForEach(inventory.exportCategories) { category in
                    privacyCategoryRow(category)
                }

                NavigationLink(destination: ExportDataSettingsView()) {
                    Label("导出本地备份", systemImage: "square.and.arrow.up.fill")
                }
            }

            Section("本机保存但默认不导出") {
                ForEach(inventory.categories.filter { !$0.isExported }) { category in
                    privacyCategoryRow(category)
                }
            }

            Section("删除控制") {
                Text(inventory.irreversibleWarning)
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.muted)

                ForEach(inventory.deleteGroups) { group in
                    Button(role: .destructive) {
                        pendingDeleteGroup = group
                    } label: {
                        Label(group.title, systemImage: group.systemImage)
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(isError ? VelaTheme.strainColor : VelaTheme.recoveryColor)
                }
            }
        }
        .navigationTitle("隐私与数据控制")
        .onAppear {
            reloadInventory()
        }
        .confirmationDialog(
            pendingDeleteGroup?.title ?? "确认删除",
            isPresented: Binding(
                get: { pendingDeleteGroup != nil },
                set: { if !$0 { pendingDeleteGroup = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let group = pendingDeleteGroup {
                Button(group.title, role: .destructive) {
                    delete(group)
                }
            }
            Button("取消", role: .cancel) {
                pendingDeleteGroup = nil
            }
        } message: {
            Text(pendingDeleteGroup?.detail ?? inventory.irreversibleWarning)
        }
    }

    private func privacyCategoryRow(_ category: PrivacyDataCategory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(category.title)
                Spacer()
                Text("\(category.count)")
                    .foregroundStyle(VelaTheme.muted)
                    .monospacedDigit()
            }
            Text(category.detail)
                .font(.caption)
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(.vertical, 2)
    }

    private func reloadInventory() {
        inventory = PrivacyDataInventoryBuilder.build(modelContext: modelContext)
    }

    private func delete(_ group: PrivacyDeleteGroup) {
        do {
            let deleted = try PrivacyDataDeletionService.delete(scope: group.scope, modelContext: modelContext)
            pendingDeleteGroup = nil
            reloadInventory()
            statusMessage = "已删除 \(deleted) 条本地记录。"
            isError = false
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            statusMessage = "删除失败：\(error.localizedDescription)"
            isError = true
        }
    }
}

struct ExportDataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showExporter = false
    @State private var exportData: Data?
    @State private var statusMessage = ""
    @State private var isError = false
    
    var body: some View {
        Form {
            Section(header: Text("数据导出与备份")) {
                Text("Vela 采用本机优先的数据策略，你的健康数据默认保留在设备本地。为了迁移或备份，你可以导出健康摘要与日志；导出过程中数据不会离开你的设备。")
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
                    Label("导出本地健康数据", systemImage: "doc.text.fill")
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
        // 1. Fetch Daily Summaries
        let summariesDesc = FetchDescriptor<DailyHealthSummaryRecord>(sortBy: [SortDescriptor(\.date, order: .forward)])
        let summaries = (try? modelContext.fetch(summariesDesc)) ?? []
        let exportSummaries: [[String: Any]] = summaries.map { record in
            var dict: [String: Any] = [
                "date": record.date.formatted(.iso8601),
                "dayIdentifier": record.dayIdentifier
            ]
            if let val = record.sleepScore { dict["sleepScore"] = val }
            if let val = record.recoveryScore { dict["recoveryScore"] = val }
            if let val = record.strainScore { dict["strainScore"] = val }
            if let val = record.stressIndex { dict["stressIndex"] = val }
            if let val = record.morningEnergy { dict["morningEnergy"] = val }
            if let val = record.currentEnergy { dict["currentEnergy"] = val }
            if let val = record.energyBank { dict["energyBank"] = val }
            if let val = record.hrvAverage { dict["hrvAverage"] = val }
            if let val = record.restingHeartRate { dict["restingHeartRate"] = val }
            if let val = record.sleepHours { dict["sleepHours"] = val }
            if let val = record.deepSleepPercent { dict["deepSleepPercent"] = val }
            if let val = record.remSleepPercent { dict["remSleepPercent"] = val }
            if let val = record.sleepEfficiency { dict["sleepEfficiency"] = val }
            if let val = record.steps { dict["steps"] = val }
            if let val = record.activeCalories { dict["activeCalories"] = val }
            if let val = record.activeMinutes { dict["activeMinutes"] = val }
            if let val = record.workoutCount { dict["workoutCount"] = val }
            if let val = record.workoutDuration { dict["workoutDuration"] = val }
            if let val = record.bodyWeight { dict["bodyWeight"] = val }
            if let val = record.bodyFatPercent { dict["bodyFatPercent"] = val }
            if let val = record.oxygenSaturation { dict["oxygenSaturation"] = val }
            if let val = record.respiratoryRate { dict["respiratoryRate"] = val }
            if let val = record.wristTemperature { dict["wristTemperature"] = val }
            if let val = record.dailyLoad { dict["dailyLoad"] = val }
            return dict
        }

        // 2. Fetch Strength Workouts
        let workoutsDesc = FetchDescriptor<StrengthWorkoutRecord>(sortBy: [SortDescriptor(\.startedAt, order: .forward)])
        let workouts = (try? modelContext.fetch(workoutsDesc)) ?? []
        let exportWorkouts: [[String: Any]] = workouts.map { record in
            var dict: [String: Any] = [
                "id": record.id.uuidString,
                "title": record.title,
                "startedAt": record.startedAt.formatted(.iso8601),
                "durationMinutes": record.durationMinutes,
                "notes": record.notes
            ]
            if let val = record.linkedWorkoutEventId { dict["linkedWorkoutEventId"] = val.uuidString }
            if let val = record.sourceTemplateId { dict["sourceTemplateId"] = val.uuidString }
            if let val = record.planDayId { dict["planDayId"] = val.uuidString }
            if let val = record.sessionRPE { dict["sessionRPE"] = val }
            if let val = record.completedAt { dict["completedAt"] = val.formatted(.iso8601) }
            if let val = record.analyticsJSON { dict["analyticsJSON"] = val }
            // Decode and embed raw exercises JSON
            if let exercisesObj = try? JSONSerialization.jsonObject(with: record.exercisesData) {
                dict["exercises"] = exercisesObj
            }
            return dict
        }

        // 3. Fetch Journals
        let journalsDesc = FetchDescriptor<JournalEntryRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let journals = (try? modelContext.fetch(journalsDesc)) ?? []
        let exportJournals: [[String: Any]] = journals.map { record in
            var dict: [String: Any] = [
                "createdAt": record.createdAt.formatted(.iso8601),
                "tags": record.tags,
                "note": record.note
            ]
            if let val = record.value { dict["value"] = val }
            if let val = record.unit { dict["unit"] = val }
            return dict
        }

        // 4. Fetch Food Logs
        let foodLogsDesc = FetchDescriptor<FoodLogRecord>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let foodLogs = (try? modelContext.fetch(foodLogsDesc)) ?? []
        let exportFoodLogs: [[String: Any]] = foodLogs.map { record in
            var dict: [String: Any] = [
                "id": record.id.uuidString,
                "mealName": record.mealName,
                "createdAt": record.createdAt.formatted(.iso8601),
                "updatedAt": record.updatedAt.formatted(.iso8601),
                "source": record.source,
                "totalCalories": record.totalCalories,
                "proteinGrams": record.proteinGrams,
                "carbsGrams": record.carbsGrams,
                "fatGrams": record.fatGrams,
                "fiberGrams": record.fiberGrams,
                "healthScore": record.healthScore,
                "rawAnalysis": record.rawAnalysis
            ]
            if let foodsData = record.serializedFoods.data(using: .utf8),
               let foodsObj = try? JSONSerialization.jsonObject(with: foodsData) {
                dict["foods"] = foodsObj
            }
            if let suggestionsData = record.serializedSuggestions.data(using: .utf8),
               let suggestionsObj = try? JSONSerialization.jsonObject(with: suggestionsData) {
                dict["suggestions"] = suggestionsObj
            }
            return dict
        }

        // 5. Fetch Biomarkers
        let biomarkersDesc = FetchDescriptor<BiomarkerRecord>(sortBy: [SortDescriptor(\.date, order: .forward)])
        let biomarkers = (try? modelContext.fetch(biomarkersDesc)) ?? []
        let exportBiomarkers: [[String: Any]] = biomarkers.map { record in
            var dict: [String: Any] = [
                "id": record.id.uuidString,
                "name": record.name,
                "value": record.value,
                "unit": record.unit,
                "date": record.date.formatted(.iso8601),
                "isOptimal": record.isOptimal,
                "referenceMin": record.referenceMin,
                "referenceMax": record.referenceMax
            ]
            if let val = record.sourceDocumentName { dict["sourceDocumentName"] = val }
            return dict
        }

        // 6. Fetch User Wiki Documents
        let wikiDesc = FetchDescriptor<UserWikiDocumentRecord>(sortBy: [SortDescriptor(\.filename, order: .forward)])
        let wikiDocs = (try? modelContext.fetch(wikiDesc)) ?? []
        let exportWikiDocs: [[String: Any]] = wikiDocs.map { record in
            [
                "filename": record.filename,
                "title": record.title,
                "markdownContent": record.markdownContent,
                "updatedAt": record.updatedAt.formatted(.iso8601)
            ]
        }

        let export: [String: Any] = [
            "app": "Vela",
            "export_date": Date().formatted(.iso8601),
            "config_version": VelaAppMetadata.configVersion,
            "summaries": exportSummaries,
            "workouts": exportWorkouts,
            "journals": exportJournals,
            "food_logs": exportFoodLogs,
            "biomarkers": exportBiomarkers,
            "wiki_documents": exportWikiDocs
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
