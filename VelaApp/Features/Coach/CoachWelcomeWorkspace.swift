import SwiftUI
import SwiftData

// MARK: - CoachWelcomeWorkspace

struct CoachWelcomeWorkspace: View {
    @ObservedObject var vm: CoachChatVM
    let todayOperatingPlan: DailyOperatingPlanRecord?
    let pendingMemoryProposals: [MemoryEventRecord]
    let agentArtifacts: [AgentArtifactRecord]
    @Binding var showWikiProfile: Bool
    let onSendMessage: (String) -> Void

    @ObservedObject private var appState = VelaAppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            welcomeHeader

            HStack(spacing: 10) {
                Button {
                    showWikiProfile = true
                } label: {
                    shortcutCard(title: "健康档案", subtitle: "长期记忆", icon: "books.vertical.fill")
                }
                .buttonStyle(.plain)

                NavigationLink(destination: VelaReportsView()) {
                    shortcutCard(title: "历史报告", subtitle: "自动分析", icon: "doc.text.fill")
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("健康分析能力")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .padding(.leading, 2)

                VStack(spacing: 0) {
                    ForEach(Array(healthAnalysisCapabilities.enumerated()), id: \.offset) { index, item in
                        Button {
                            onSendMessage(item.query)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(VelaTheme.rhythmInk)
                                    Text(item.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < healthAnalysisCapabilities.count - 1 {
                            Rectangle()
                                .fill(VelaTheme.rhythmMist)
                                .frame(height: 0.75)
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }
        }
    }

    private var healthAnalysisCapabilities: [(title: String, subtitle: String, icon: String, query: String)] {
        [
            ("分析今日身体状态", "全面剖析恢复、睡眠、心率与压力状态", "sparkles", "请全面分析我今天的身体状态，结合各项体征和个人基线，指出当前身体最重要的生理特征。"),
            ("最近 30 天变化", "识别近期各项指标趋势与显著偏离", "chart.xyaxis.line", "请帮我梳理最近 30 天的身体数据变化趋势，有哪些指标明显上升或下降？"),
            ("关键指标偏离分析", "找出偏离个人基准的指标及生理考量", "waveform.path.ecg", "我最近有哪些体征偏离了个人正常基线？这种偏离可能意味着什么？"),
            ("睡眠与压力相关性", "探讨跨系统协同影响与因果联系", "moon.stars.fill", "我的睡眠质量、日常压力和心率之间表现出什么关联？"),
            ("转化为训练建议", "基于当前生理窗口给出运动强度指导", "figure.run", "基于我目前的身体状态与恢复节奏，今天以及未来几天我应该怎样安排训练？")
        ]
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("Vela AI 健康分析师")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(VelaTheme.rhythmDeep.opacity(0.08), in: Capsule())

            Text("健康分析工作台")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)

            Text("基于 Apple 健康与长期基线，探索身体状态与趋势。")
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(.top, 4)
    }

    private func shortcutCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 32, height: 32)
                .background(VelaTheme.rhythmMist, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(subtitle)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }

    private func displayModel(for plan: DailyOperatingPlanRecord) -> DailyOperatingPlanDisplayModel {
        return DailyOperatingPlanDisplayModel.build(
            payload: plan.operatingPlanPayload,
            primaryActionType: plan.primaryActionType,
            source: plan.source,
            safetyNotice: plan.safetyNotice,
            confidence: plan.confidence
        )
    }

    private func localizedArtifactType(_ type: String) -> String {
        switch type {
        case "daily_plan": return "每日训练计划"
        case "training_adjustment": return "训练调整方案"
        case "weekly_report": return "周度分析报告"
        case "correlation_chart": return "体征行为关联图"
        case "wiki_diff": return "教练记忆更新"
        case "nutrition_feedback": return "营养饮食反馈"
        default: return "决策分析报告"
        }
    }

    private func evidenceLabel(_ confidence: Double) -> String {
        if confidence >= 0.8 { return "判断依据充分" }
        if confidence >= 0.55 { return "判断依据部分" }
        return "判断依据有限"
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "daily_plan": return "calendar.badge.checkmark"
        case "training_adjustment": return "slider.horizontal.3"
        case "weekly_report": return "chart.line.uptrend.xyaxis"
        case "correlation_chart": return "point.3.connected.trianglepath.dotted"
        case "wiki_diff": return "doc.badge.gearshape"
        case "nutrition_feedback": return "fork.knife"
        default: return "doc.text.fill"
        }
    }
}

struct VelaReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIReportRecord.createdAt, order: .reverse)
    private var reports: [AIReportRecord]
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var artifacts: [AgentArtifactRecord]

    @AppStorage("agent_morning_brief_alerts") private var morningBriefOn = true
    @AppStorage("agent_bedtime_reminders") private var sleepReviewOn = true
    @AppStorage("agent_weekly_review_enabled") private var weeklyReviewOn = true
    @AppStorage("agent_post_workout_checkin_enabled") private var postWorkoutOn = true
    @State private var artifactPendingDeletion: AgentArtifactRecord?
    @State private var artifactError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                morningBriefHero

                VelaMakeSectionHeader(title: "今日")
                reportRows

                HStack {
                    VelaMakeSectionHeader(title: "生成物")
                    Spacer()
                    NavigationLink("查看全部") {
                        AgentArtifactLibraryView()
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                artifactRows

                VelaMakeSectionHeader(title: "自动报告")
                automationRows

                Text("可在「设置 · 通知」中调整时间与开关。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("历史报告")
        .velaRhythmDetailChrome()
        .confirmationDialog(
            "删除这个生成物？",
            isPresented: Binding(
                get: { artifactPendingDeletion != nil },
                set: { if !$0 { artifactPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除生成物", role: .destructive) {
                deletePendingArtifact()
            }
            Button("取消", role: .cancel) {
                artifactPendingDeletion = nil
            }
        } message: {
            Text("这只会删除本机保存的生成物，且无法撤销。")
        }
        .alert("无法删除", isPresented: Binding(
            get: { artifactError != nil },
            set: { if !$0 { artifactError = nil } }
        )) {
            Button("好", role: .cancel) { artifactError = nil }
        } message: {
            Text(artifactError ?? "未知错误")
        }
    }

    private var morningBriefHero: some View {
        let latest = reports.first
        return VStack(alignment: .leading, spacing: 8) {
            Label("今日 Morning Brief · 6:00", systemImage: "sun.max.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
            Text(latest?.title ?? "今日身体状态简报")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(reportPreview(latest?.markdownContent) ?? "同步健康数据后，Vela 会自动生成恢复、睡眠和训练建议。")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.orange, Color(uiColor: .systemPink)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var reportRows: some View {
        if reports.isEmpty {
            VelaMakeCard {
                Text("暂无历史报告")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.fg2)
            }
        } else {
            VStack(spacing: 0) {
                // PR8：报告行可点开阅读完整正文（此前周报/月报正文生成后无阅读入口）。
                ForEach(Array(reports.prefix(5).enumerated()), id: \.element.createdAt) { index, report in
                    NavigationLink {
                        AIReportDetailView(report: report)
                    } label: {
                        reportRow(
                            icon: report.type.contains("sleep") ? "moon.fill" : "sun.max.fill",
                            color: report.type.contains("sleep") ? .indigo : .orange,
                            title: report.title,
                            subtitle: report.createdAt.formatted(.dateTime.month().day().hour().minute())
                        )
                    }
                    .buttonStyle(.plain)
                    if index < min(reports.count, 5) - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(VelaTheme.rhythmCanvasRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// PR8：报告完整正文阅读页（此前只显示标题行，正文不可读）。
    private struct AIReportDetailView: View {
        let report: AIReportRecord

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(report.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    MarkdownText(markdown: report.markdownContent, color: VelaTheme.rhythmInk)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(VelaTheme.rhythmCanvas)
            .navigationTitle("历史报告")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var artifactRows: some View {
        if artifacts.isEmpty {
            VelaMakeCard {
                Text("暂无生成物")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(artifacts.prefix(5).enumerated()), id: \.element.id) { index, artifact in
                    NavigationLink {
                        AgentArtifactDetailView(record: artifact)
                    } label: {
                        reportRow(
                            icon: AgentArtifactPresentation.icon(for: artifact.type),
                            color: .indigo,
                            title: artifact.title,
                            subtitle: "\(AgentArtifactPresentation.typeLabel(for: artifact.type)) · \(artifact.createdAt.formatted(.relative(presentation: .named)))"
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            artifactPendingDeletion = artifact
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    if index < min(artifacts.count, 5) - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(VelaTheme.rhythmCanvasRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var automationRows: some View {
        VStack(spacing: 0) {
            automationRow("Morning Brief", "每日 6:00", .blue, $morningBriefOn)
            Divider().padding(.leading, 60)
            automationRow("睡眠回顾", "起床后", .purple, $sleepReviewOn)
            Divider().padding(.leading, 60)
            automationRow("周报", "周日 21:00", .green, $weeklyReviewOn)
            Divider().padding(.leading, 60)
            automationRow("训练后复盘", "训练结束 15 分钟后", .orange, $postWorkoutOn)
        }
        .background(VelaTheme.rhythmCanvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reportRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VelaMakeIconTile(systemName: icon, color: color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VelaTheme.fg)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.meta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func automationRow(
        _ title: String,
        _ subtitle: String,
        _ color: Color,
        _ isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VelaMakeIconTile(systemName: "sparkles", color: color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func reportPreview(_ markdown: String?) -> String? {
        guard let markdown else { return nil }
        return markdown
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deletePendingArtifact() {
        guard let artifact = artifactPendingDeletion else { return }
        do {
            try PersistenceWriteGate.shared.assertWritable(
                operation: "VelaReportsView: delete agent artifact",
                modelContext: modelContext
            )
            modelContext.delete(artifact)
            try modelContext.save()
            artifactPendingDeletion = nil
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            artifactError = error.localizedDescription
        }
    }
}

// MARK: - Agent artifact library

struct AgentArtifactFact: Identifiable, Equatable {
    let label: String
    let value: String
    var id: String { "\(label):\(value)" }
}

struct AgentArtifactPresentation: Equatable {
    let summary: String?
    let facts: [AgentArtifactFact]

    static func parse(payloadJSON: String) -> AgentArtifactPresentation {
        guard let data = payloadJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return AgentArtifactPresentation(summary: nil, facts: [])
        }

        let summary = nonEmptyString(root["summary"])
            ?? nonEmptyString(root["decision"])
            ?? nonEmptyString(root["description"])
        var facts: [AgentArtifactFact] = []

        appendStringFact("训练决策", key: "decision", from: root, to: &facts)
        appendStringFact("目标训练", key: "targetSessionTitle", from: root, to: &facts)
        if let value = root["volumeMultiplier"] as? NSNumber {
            facts.append(AgentArtifactFact(label: "训练量", value: "\(Int((value.doubleValue * 100).rounded()))%"))
        }
        if let value = root["intensityCap"] as? NSNumber {
            facts.append(AgentArtifactFact(label: "强度上限", value: "RPE \(value.intValue)"))
        }
        appendStringFact("结论", key: "decisionText", from: root, to: &facts)

        if let reasons = root["reasons"] as? [[String: Any]] {
            for reason in reasons.prefix(4) {
                let signal = nonEmptyString(reason["signal"]) ?? "判断依据"
                let value = nonEmptyString(reason["value"])
                let explanation = nonEmptyString(reason["explanation"])
                let detail = [value, explanation].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty {
                    facts.append(AgentArtifactFact(label: signal, value: detail))
                }
            }
        } else if let reasons = root["reasons"] as? [String] {
            for (index, reason) in reasons.prefix(4).enumerated() where !reason.isEmpty {
                facts.append(AgentArtifactFact(label: "依据 \(index + 1)", value: reason))
            }
        }

        return AgentArtifactPresentation(summary: summary, facts: Array(facts.prefix(8)))
    }

    static func typeLabel(for type: String) -> String {
        switch type {
        case "daily_plan": return "每日计划"
        case "training_adjustment": return "训练调整"
        case "weekly_report", "weekly_review": return "周度报告"
        case "correlation_chart": return "关联分析"
        case "wiki_diff", "wiki_update_proposal": return "记忆更新"
        case "nutrition_feedback": return "营养反馈"
        case "morning_brief": return "今日简报"
        case "workout_readiness": return "训练准备度"
        case "post_workout_review": return "训练后复盘"
        case "evening_review": return "晚间回顾"
        default: return "Coach 生成物"
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "daily_plan": return "calendar.badge.checkmark"
        case "training_adjustment", "workout_readiness": return "slider.horizontal.3"
        case "weekly_report", "weekly_review": return "chart.line.uptrend.xyaxis"
        case "correlation_chart": return "point.3.connected.trianglepath.dotted"
        case "wiki_diff", "wiki_update_proposal": return "brain.head.profile"
        case "nutrition_feedback": return "fork.knife"
        case "post_workout_review": return "figure.strengthtraining.traditional"
        default: return "doc.text.fill"
        }
    }

    private static func appendStringFact(
        _ label: String,
        key: String,
        from object: [String: Any],
        to facts: inout [AgentArtifactFact]
    ) {
        guard let value = nonEmptyString(object[key]),
              !facts.contains(where: { $0.value == value }) else { return }
        facts.append(AgentArtifactFact(label: label, value: value))
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AgentArtifactLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var artifacts: [AgentArtifactRecord]

    @State private var searchText = ""
    @State private var selectedType = "all"
    @State private var pendingDeletion: AgentArtifactRecord?
    @State private var errorMessage: String?

    private var availableTypes: [String] {
        Array(Set(artifacts.map(\.type))).sorted {
            AgentArtifactPresentation.typeLabel(for: $0) < AgentArtifactPresentation.typeLabel(for: $1)
        }
    }

    private var filteredArtifacts: [AgentArtifactRecord] {
        artifacts.filter { artifact in
            let matchesType = selectedType == "all" || artifact.type == selectedType
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || artifact.title.localizedCaseInsensitiveContains(query)
                || AgentArtifactPresentation.typeLabel(for: artifact.type).localizedCaseInsensitiveContains(query)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        List {
            Section {
                Picker("类型", selection: $selectedType) {
                    Text("全部").tag("all")
                    ForEach(availableTypes, id: \.self) { type in
                        Text(AgentArtifactPresentation.typeLabel(for: type)).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("本机生成物 · \(filteredArtifacts.count)") {
                if filteredArtifacts.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "暂无生成物" : "没有匹配结果",
                        systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Coach 创建的计划、分析和报告会保存在这里。" : "请尝试其他关键词或类型。")
                    )
                } else {
                    ForEach(filteredArtifacts) { artifact in
                        NavigationLink {
                            AgentArtifactDetailView(record: artifact)
                        } label: {
                            AgentArtifactLibraryRow(record: artifact)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = artifact
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("生成物")
        .velaRhythmDetailChrome()
        .searchable(text: $searchText, prompt: "搜索计划、报告或分析")
        .confirmationDialog(
            "删除这个生成物？",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除生成物", role: .destructive) { deletePendingArtifact() }
            Button("取消", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("这只会删除本机保存的生成物，且无法撤销。")
        }
        .alert("无法删除", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func deletePendingArtifact() {
        guard let artifact = pendingDeletion else { return }
        do {
            try PersistenceWriteGate.shared.assertWritable(
                operation: "AgentArtifactLibraryView: delete agent artifact",
                modelContext: modelContext
            )
            modelContext.delete(artifact)
            try modelContext.save()
            pendingDeletion = nil
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AgentArtifactLibraryRow: View {
    let record: AgentArtifactRecord

    var body: some View {
        HStack(spacing: 12) {
            VelaMakeIconTile(
                systemName: AgentArtifactPresentation.icon(for: record.type),
                color: .indigo,
                size: 36
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)
                    .lineLimit(2)
                Text("\(AgentArtifactPresentation.typeLabel(for: record.type)) · \(record.createdAt.formatted(.dateTime.month().day().hour().minute()))")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            ConfidenceBadge(score: record.confidence)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

struct AgentArtifactDetailView: View {
    let record: AgentArtifactRecord

    private var presentation: AgentArtifactPresentation {
        AgentArtifactPresentation.parse(payloadJSON: record.payloadJSON)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VelaMakeIconTile(
                            systemName: AgentArtifactPresentation.icon(for: record.type),
                            color: .indigo,
                            size: 42
                        )
                        Spacer()
                        ConfidenceBadge(score: record.confidence)
                    }
                    Text(record.title)
                        .font(VelaTheme.title2())
                        .foregroundStyle(VelaTheme.fg)
                    Text(AgentArtifactPresentation.typeLabel(for: record.type))
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.muted)
                }
                .padding(18)
                .velaNativeCard(radius: 20)

                if let summary = presentation.summary {
                    artifactSection(title: "摘要") {
                        Text(summary)
                            .font(VelaTheme.body())
                            .foregroundStyle(VelaTheme.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !presentation.facts.isEmpty {
                    artifactSection(title: "关键内容") {
                        VStack(spacing: 0) {
                            ForEach(Array(presentation.facts.enumerated()), id: \.element.id) { index, fact in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(fact.label)
                                        .font(VelaTheme.subheadline().weight(.semibold))
                                        .foregroundStyle(VelaTheme.fg)
                                        .frame(width: 82, alignment: .leading)
                                    Text(fact.value)
                                        .font(VelaTheme.subheadline())
                                        .foregroundStyle(VelaTheme.fg2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 11)
                                if index < presentation.facts.count - 1 { Divider() }
                            }
                        }
                    }
                }

                artifactSection(title: "来源与安全") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(record.source.isEmpty ? "本机生成" : record.source, systemImage: "iphone")
                        Label(record.createdAt.formatted(.dateTime.year().month().day().hour().minute()), systemImage: "clock")
                        Label(record.status == "active" ? "当前有效" : record.status, systemImage: "checkmark.shield")
                        if let notice = record.safetyNotice, !notice.isEmpty {
                            Label(notice, systemImage: "cross.case")
                        }
                    }
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.fg2)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("生成物详情")
        .velaRhythmDetailChrome()
    }

    private func artifactSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.muted)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .velaNativeCard(radius: 18)
    }
}
