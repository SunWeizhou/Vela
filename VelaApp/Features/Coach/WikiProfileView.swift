import SwiftUI
import SwiftData

struct WikiProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var documents: [WikiDocument] = []
    @State private var editingFileId: String?
    @State private var draftFields: [WikiField] = []
    @State private var baselineDoc: WikiDocument?
    @State private var isRefreshingBaselines = false

    @Query(
        filter: #Predicate<MemoryEventRecord> { $0.status == "proposed" },
        sort: \MemoryEventRecord.createdAt,
        order: .reverse
    ) private var pendingProposals: [MemoryEventRecord]

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(spacing: 16) {
                    profileHeaderCard

                    if let baselineDoc {
                        baselineSummaryCard(baselineDoc)
                    }

                    if !pendingProposals.isEmpty {
                        pendingMemoriesSection
                    }

                    ForEach(documents) { doc in
                        wikiFileCard(doc)
                    }
                }
                .padding(VelaTheme.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VelaDetailBackButton(label: L10n.t("Back to Settings", "返回设置"))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("My Profile", "我的档案"))
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(L10n.t("Health memory & knowledge base", "健康记忆与知识档案库"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                Divider().opacity(0.4)
            }
        }
        .task {
            WikiSyncManager.sync(modelContext: modelContext)
            let allDocs = WikiFileService.loadAllDocuments()
            documents = allDocs.filter { $0.filename != "baselines.md" }
            baselineDoc = allDocs.first { $0.filename == "baselines.md" && $0.content.count > 100 }
        }
    }

    // MARK: - Header

    private var profileHeaderCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(VelaTheme.accent.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(VelaTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Your Health Profile", "你的健康档案"))
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(L10n.t(
                        "Vela maintains this profile based on your data and conversations.",
                        "Vela 根据你的数据和对话维护此档案。"
                    ))
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                }

                Spacer()
            }

            let filled = documents.filter { $0.content.count > 50 }.count
            let total = documents.count
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.t("Profile completeness", "档案完整度"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelaTheme.secondaryText)
                    Spacer()
                    Text("\(filled)/\(total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [VelaTheme.accent, Color(hex: "#AF52DE")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: total > 0 ? geo.size.width * CGFloat(filled) / CGFloat(total) : 0, height: 6)
                            .shadow(color: VelaTheme.accent.opacity(0.3), radius: 3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    // MARK: - Baseline Card

    @ViewBuilder
    private func baselineSummaryCard(_ doc: WikiDocument) -> some View {
        let parsedMetrics = parseBaselineMetrics(from: doc.content)
        let daysSince = daysSinceUpdate(doc.updatedAt)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title3)
                    .foregroundStyle(VelaTheme.energy)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLanguage.stored.isChinese ? "个人生理基线" : "Personal Baselines")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(appLanguageAwareDateLabel(daysSince: daysSince))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }

                Spacer()

                Button {
                    Task {
                        isRefreshingBaselines = true
                        let allDocs = WikiFileService.loadAllDocuments()
                        baselineDoc = allDocs.first { $0.filename == "baselines.md" && $0.content.count > 100 }
                        isRefreshingBaselines = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelaTheme.accent)
                }
                .disabled(isRefreshingBaselines)
            }

            if !parsedMetrics.isEmpty {
                VStack(spacing: 6) {
                    ForEach(parsedMetrics.prefix(4), id: \.label) { metric in
                        HStack {
                            Text(metric.label)
                                .font(.caption)
                                .foregroundStyle(VelaTheme.secondaryText)
                            Spacer()
                            Text(metric.value)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VelaTheme.primaryText)
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VelaTheme.elevatedSurface)
                )
            }

            if parsedMetrics.isEmpty {
                Text(AppLanguage.stored.isChinese
                     ? "基线数据正在计算中..."
                     : "Baseline data is being computed..."
                )
                .font(.caption)
                .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private struct BaselineMetric {
        let label: String
        let value: String
    }

    private func parseBaselineMetrics(from markdown: String) -> [BaselineMetric] {
        var metrics: [BaselineMetric] = []
        let lines = markdown.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") && !trimmed.contains("---") && !trimmed.contains("Metric") else { continue }
            let parts = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            let meaningful = parts.filter { !$0.isEmpty }
            guard meaningful.count >= 2 else { continue }
            let label = meaningful[0]
            let value = meaningful[1]
            if !label.isEmpty && !value.isEmpty {
                metrics.append(BaselineMetric(label: label, value: value))
            }
        }
        return metrics
    }

    private func daysSinceUpdate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: date, to: now).day ?? 0
    }

    private func appLanguageAwareDateLabel(daysSince: Int) -> String {
        if AppLanguage.stored.isChinese {
            switch daysSince {
            case 0: return "今天更新"
            case 1: return "昨天更新"
            default: return "\(daysSince) 天前更新"
            }
        } else {
            switch daysSince {
            case 0: return "Updated today"
            case 1: return "Updated yesterday"
            default: return "Updated \(daysSince) days ago"
            }
        }
    }

    // MARK: - File Card

    private func wikiFileCard(_ doc: WikiDocument) -> some View {
        let isEditing = editingFileId == doc.id
        let fields = parseFields(from: doc)

        return VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: iconForFile(doc.filename))
                    .font(.title3)
                    .foregroundStyle(tintForFile(doc.filename))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(fields.count.formatted() + " " + (AppLanguage.stored.isChinese ? "项" : "fields"))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }

                Spacer()

                if isEditing {
                    Button {
                        cancelEdit()
                    } label: {
                        Text(L10n.t("Cancel", "取消"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }

                    Button {
                        saveEdit(doc)
                    } label: {
                        Text(L10n.t("Save", "保存"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(VelaTheme.accent))
                    }
                } else {
                    Button {
                        startEdit(doc)
                    } label: {
                        Label(L10n.t("Edit", "编辑"), systemImage: "pencil")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VelaTheme.accent)
                    }
                }
            }
            .padding(14)

            // Field list
            VStack(spacing: 0) {
                ForEach(Array(isEditing ? draftFields.enumerated() : fields.enumerated()), id: \.offset) { index, field in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 14)
                            .opacity(0.5)
                    }

                    if isEditing {
                        editableFieldRow(index: index, field: field)
                    } else {
                        readOnlyFieldRow(field)
                    }
                }
            }
        }
        .velaNativeCard(radius: 18)
    }

    // MARK: - Read-Only Field Row

    private func readOnlyFieldRow(_ field: WikiField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizedLabel(field.label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tintForFile(fieldsToFilename[field.label] ?? ""))
            Text(field.value.isEmpty ? "—" : field.value)
                .font(.footnote)
                .foregroundStyle(field.value.isEmpty ? VelaTheme.mutedText : VelaTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editable Field Row

    private func editableFieldRow(index: Int, field: WikiField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedLabel(field.label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tintForFile(fieldsToFilename[field.label] ?? ""))

            TextField(
                placeholderForField(field.label),
                text: Binding(
                    get: { draftFields[safe: index]?.value ?? "" },
                    set: { if index < draftFields.count { draftFields[index].value = $0 } }
                ),
                axis: .vertical
            )
            .font(.footnote)
            .foregroundStyle(VelaTheme.primaryText)
            .lineLimit(1...4)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(VelaTheme.elevatedSurface)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editing Actions

    private func startEdit(_ doc: WikiDocument) {
        draftFields = parseFields(from: doc)
        editingFileId = doc.id
    }

    private func cancelEdit() {
        editingFileId = nil
        draftFields = []
    }

    private func saveEdit(_ doc: WikiDocument) {
        let fieldValues = Dictionary(uniqueKeysWithValues: draftFields.map { ($0.label, $0.value) })
        let newContent = WikiFileService.replacingStructuredFields(
            in: doc.content,
            title: doc.title,
            fieldValues: fieldValues,
            preferredOrder: fileTemplateFields[doc.filename] ?? [doc.title]
        )
        try? WikiFileService.updateSection(filename: doc.filename, content: newContent, mode: .replace)
        
        WikiSyncManager.sync(modelContext: modelContext)
        
        editingFileId = nil
        draftFields = []
        let allDocs = WikiFileService.loadAllDocuments()
        documents = allDocs.filter { $0.filename != "baselines.md" }
        baselineDoc = allDocs.first { $0.filename == "baselines.md" && $0.content.count > 100 }
    }

    // MARK: - Field Parsing

    private struct WikiField: Hashable {
        var label: String
        var value: String
    }

    /// Maps wiki filenames to their default template field labels in order
    private let fileTemplateFields: [String: [String]] = [
        "profile.md": ["Age", "Activity level", "Primary sports", "Health goals"],
        "goals.md": ["Sleep", "Activity", "Recovery", "Other"],
        "constraints.md": ["Injuries", "Equipment", "Time", "Dietary"],
        "preferences.md": ["Training style", "Communication style", "Dietary preferences"],
        "habits.md": ["Caffeine", "Alcohol", "Evening routine", "Morning routine"],
        "training_history.md": ["Typical weekly volume", "Preferred training types", "Past injuries"],
        "health_context.md": ["Known conditions", "Medications", "Recent changes"],
        "diet.md": ["Dietary restrictions", "Caffeine window", "Preferred meals"],
        "sleep.md": ["Sleep environment", "Wind-down routine", "Targets"],
        "notes.md": ["Notes"],
        "observations.md": ["Observations"],
        "strategies.md": ["Active strategies"],
        "archive.md": ["Archive"]
    ]

    /// Reverse mapping: field label → filename
    private var fieldsToFilename: [String: String] {
        var result: [String: String] = [:]
        for (filename, labels) in fileTemplateFields {
            for label in labels {
                result[label] = filename
            }
        }
        return result
    }

    private func parseFields(from doc: WikiDocument) -> [WikiField] {
        let labels = fileTemplateFields[doc.filename] ?? [doc.title]
        let content = doc.content
        let lines = content.components(separatedBy: "\n")

        // Try to parse existing values from markdown: "- Label: value" or "# Label\nvalue"
        var values: [String: String] = [:]

        for i in 0..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            // Pattern: "- Label: value" or "- Label value"
            if trimmed.hasPrefix("- ") {
                let body = String(trimmed.dropFirst(2))
                for label in labels {
                    let colonPrefix = "\(label): "
                    let spacePrefix = "\(label) "
                    if body.hasPrefix(colonPrefix) {
                        values[label] = String(body.dropFirst(colonPrefix.count))
                        break
                    } else if body.hasPrefix(spacePrefix) && !body.hasPrefix(colonPrefix) {
                        values[label] = String(body.dropFirst(spacePrefix.count))
                        break
                    }
                }
            }
        }

        return labels.map { WikiField(label: $0, value: values[$0] ?? "") }
    }

    private func placeholderForField(_ label: String) -> String {
        let lang = AppLanguage.stored
        let map: [String: (en: String, zh: String)] = [
            "Age": ("e.g. 28", "例如 28"),
            "Activity level": ("e.g. Moderately active", "例如 中等活跃"),
            "Primary sports": ("e.g. Running, Swimming", "例如 跑步、游泳"),
            "Health goals": ("e.g. Improve sleep quality", "例如 提升睡眠质量"),
            "Sleep": ("e.g. 8 hours per night", "例如 每晚8小时"),
            "Activity": ("e.g. 5 workouts per week", "例如 每周5次训练"),
            "Recovery": ("e.g. Daily stretching", "例如 每日拉伸"),
            "Other": ("e.g. Reduce stress", "例如 减轻压力"),
            "Caffeine": ("e.g. 2 cups before noon", "例如 上午2杯"),
            "Alcohol": ("e.g. Occasionally", "例如 偶尔"),
            "Evening routine": ("e.g. No screens after 10pm", "例如 10点后不看屏幕"),
            "Morning routine": ("e.g. Cold shower, stretch", "例如 冷水澡、拉伸"),
            "Typical weekly volume": ("e.g. 6-8 hours", "例如 6-8小时"),
            "Preferred training types": ("e.g. Strength, HIIT", "例如 力量训练、HIIT"),
            "Past injuries": ("e.g. Left knee (2023)", "例如 左膝(2023年)"),
            "Known conditions": ("e.g. Seasonal allergies", "例如 季节性过敏"),
            "Medications": ("e.g. None", "例如 无"),
            "Recent changes": ("e.g. New diet plan", "例如 新的饮食计划"),
            "Notes": ("e.g. Any observations...", "例如 任何观察..."),
            "Injuries": ("e.g. Back pain", "例如 腰背疼痛"),
            "Equipment": ("e.g. Dumbbells, barbell", "例如 哑铃、杠铃"),
            "Time": ("e.g. 45 mins/day", "例如 每天45分钟"),
            "Dietary": ("e.g. Vegetarian", "例如 素食"),
            "Training style": ("e.g. Hypertrophy", "例如 肌肥大训练"),
            "Communication style": ("e.g. Direct and encouraging", "例如 直接且鼓励性质"),
            "Dietary preferences": ("e.g. High protein", "例如 高蛋白饮食"),
            "Dietary restrictions": ("e.g. Low sodium", "例如 低钠饮食"),
            "Caffeine window": ("e.g. Before 2 PM", "例如 下午2点前"),
            "Preferred meals": ("e.g. Chicken breast, broccoli", "例如 鸡胸肉、西兰花"),
            "Sleep environment": ("e.g. Cool and dark", "例如 凉爽、黑暗"),
            "Wind-down routine": ("e.g. Reading, no screens", "例如 阅读、不看屏幕"),
            "Targets": ("e.g. 7.5 hours sleep", "例如 7.5小时睡眠"),
            "Observations": ("e.g. Fatigue after squats", "例如 深蹲后大腿易疲劳"),
            "Active strategies": ("e.g. Progressive overload", "例如 渐进性超负荷"),
            "Archive": ("e.g. Old goals...", "例如 历史目标存档...")
        ]
        if let entry = map[label] {
            return lang.isChinese ? entry.zh : entry.en
        }
        return lang.isChinese ? "输入内容..." : "Enter value..."
    }

    private func localizedLabel(_ label: String) -> String {
        guard AppLanguage.stored.isChinese else { return label }
        let map: [String: String] = [
            "Age": "年龄",
            "Activity level": "活跃程度",
            "Primary sports": "主要运动项目",
            "Health goals": "健康目标",
            "Sleep": "睡眠目标",
            "Activity": "运动目标",
            "Recovery": "恢复目标",
            "Other": "其他目标",
            "Caffeine": "咖啡因摄入",
            "Alcohol": "饮酒习惯",
            "Evening routine": "晚间常规",
            "Morning routine": "早间常规",
            "Typical weekly volume": "每周运动量",
            "Preferred training types": "偏好运动类型",
            "Past injuries": "历史伤病情况",
            "Known conditions": "已知身体状况",
            "Medications": "服用药物",
            "Recent changes": "近期身体变化",
            "Notes": "备注与发现",
            "Injuries": "运动伤病情况",
            "Equipment": "可用训练装备",
            "Time": "运动时间限制",
            "Dietary": "饮食禁忌",
            "Training style": "训练风格偏好",
            "Communication style": "沟通语言风格",
            "Dietary preferences": "饮食风格偏好",
            "Dietary restrictions": "饮食限制与禁忌",
            "Caffeine window": "咖啡因摄入窗口期",
            "Preferred meals": "偏好膳食类型",
            "Sleep environment": "睡眠物理环境",
            "Wind-down routine": "睡前放松常规",
            "Targets": "睡眠目标与时长",
            "Observations": "AI 观察发现",
            "Active strategies": "当前执行策略",
            "Archive": "历史存档记录"
        ]
        return map[label] ?? label
    }

    // MARK: - Icon / Tint Mapping

    private func iconForFile(_ filename: String) -> String {
        switch filename {
        case "profile.md": return "person.fill"
        case "goals.md": return "target"
        case "habits.md": return "leaf.fill"
        case "training_history.md": return "figure.run"
        case "health_context.md": return "heart.text.square.fill"
        case "notes.md", "observations.md": return "note.text"
        case "constraints.md": return "exclamationmark.shield.fill"
        case "preferences.md": return "slider.horizontal.3"
        case "strategies.md": return "lightbulb.fill"
        default: return "doc.fill"
        }
    }

    private func tintForFile(_ filename: String) -> Color {
        switch filename {
        case "profile.md": return VelaTheme.accent
        case "goals.md": return VelaTheme.energy
        case "habits.md": return VelaTheme.recovery
        case "training_history.md": return VelaTheme.strain
        case "health_context.md": return VelaTheme.sleep
        case "notes.md", "observations.md": return VelaTheme.secondaryText
        case "constraints.md": return VelaTheme.stress
        case "preferences.md": return VelaTheme.energy
        case "strategies.md": return VelaTheme.accent
        default: return VelaTheme.accent
        }
    }

    // MARK: - Pending Memories Section

    @ViewBuilder
    private var pendingMemoriesSection: some View {
        VelaHeroSurface(tint: VelaTheme.energy) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VelaTheme.energy)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VelaTheme.energy.opacity(0.12)))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLanguage.stored.isChinese ? "Vela 学到了一些关于你的信息" : "Vela learned something about you")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(AppLanguage.stored.isChinese
                             ? "确认后才会写入个人 Wiki。你可以保存可信记忆，或拒绝不准确的发现。"
                             : "Nothing is saved to your Wiki until you confirm it. Save trusted memories or reject anything inaccurate."
                        )
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                VelaInlineAlert(
                    title: AppLanguage.stored.isChinese ? "待你确认" : "Awaiting review",
                    message: AppLanguage.stored.isChinese
                    ? "\(pendingProposals.count) 条候选长期记忆会影响未来建议、解释和训练调整。"
                    : "\(pendingProposals.count) proposed memories may shape future recommendations, explanations, and training adjustments.",
                    systemImage: "person.crop.circle.badge.questionmark",
                    tint: VelaTheme.energy
                )

                ForEach(pendingProposals) { proposal in
                    VelaMemoryProposalCard(
                        proposal: proposal,
                        onAccept: { confirmProposal(proposal) },
                        onReject: { rejectProposal(proposal) }
                    )
                }
            }
        }
        .appleIntelligenceGlow(isHighlighted: true, radius: 18)
    }

    @ViewBuilder
    private var legacyPendingMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.title3)
                    .foregroundStyle(VelaTheme.energy)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLanguage.stored.isChinese ? "待确认记忆" : "Pending Memories")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(AppLanguage.stored.isChinese
                         ? "Vela 发现了 \(pendingProposals.count) 条可能需要你确认的长期记忆"
                         : "Vela found \(pendingProposals.count) memories for your review"
                    )
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.mutedText)
                }
                Spacer()
            }

            ForEach(pendingProposals) { proposal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(
                            memoryTypeBadge(proposal.memoryType),
                            systemImage: iconForFile(proposal.targetFile)
                        )
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(tintForFile(proposal.targetFile))

                        Spacer()

                        Text(confidenceLabel(proposal.confidence))
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                    }

                    Text(proposal.content)
                        .font(.footnote)
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if !proposal.evidence.isEmpty {
                        Text(proposal.evidence)
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.secondaryText)
                            .lineLimit(3)
                    }

                    HStack(spacing: 12) {
                        Button {
                            confirmProposal(proposal)
                        } label: {
                            Label(
                                AppLanguage.stored.isChinese ? "保存" : "Save",
                                systemImage: "checkmark.circle.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(VelaTheme.accent))
                        }

                        Button {
                            rejectProposal(proposal)
                        } label: {
                            Label(
                                AppLanguage.stored.isChinese ? "忽略" : "Ignore",
                                systemImage: "xmark.circle"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VelaTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(VelaTheme.elevatedSurface))
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VelaTheme.elevatedSurface)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.surface)
        )
    }

    private func memoryTypeBadge(_ type: MemoryType) -> String {
        switch type {
        case .fact: return AppLanguage.stored.isChinese ? "事实" : "Fact"
        case .observation: return AppLanguage.stored.isChinese ? "观察" : "Observation"
        case .hypothesis: return AppLanguage.stored.isChinese ? "推测" : "Hypothesis"
        case .strategy: return AppLanguage.stored.isChinese ? "策略" : "Strategy"
        case .preference: return AppLanguage.stored.isChinese ? "偏好" : "Preference"
        case .constraint: return AppLanguage.stored.isChinese ? "约束" : "Constraint"
        case .goalChange: return AppLanguage.stored.isChinese ? "目标变更" : "Goal Change"
        case .baselineUpdate: return AppLanguage.stored.isChinese ? "基线更新" : "Baseline Update"
        }
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        let pct = Int((confidence * 100).rounded())
        if confidence >= 0.9 { return "High · \(pct)%" }
        if confidence >= 0.7 { return "Medium · \(pct)%" }
        return "Low · \(pct)%"
    }

    private func confirmProposal(_ proposal: MemoryEventRecord) {
        do {
            let ledger = MemoryLedger(modelContext: modelContext)
            try ledger.confirmProposal(proposal.id)
            // Refresh wiki documents
            let allDocs = WikiFileService.loadAllDocuments()
            documents = allDocs.filter { $0.filename != "baselines.md" }
            baselineDoc = allDocs.first { $0.filename == "baselines.md" && $0.content.count > 100 }
        } catch {
            print("Failed to confirm proposal: \(error)")
        }
    }

    private func rejectProposal(_ proposal: MemoryEventRecord) {
        do {
            let ledger = MemoryLedger(modelContext: modelContext)
            try ledger.rejectProposal(proposal.id)
        } catch {
            print("Failed to reject proposal: \(error)")
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
