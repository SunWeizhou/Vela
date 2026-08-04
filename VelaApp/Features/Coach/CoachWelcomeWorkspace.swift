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
        VStack(alignment: .leading, spacing: 24) {
            welcomeHeader

            workspaceCarousel

            if !vm.isReady {
                localModeCard
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("你可以这样问")
                    .font(VelaTheme.caption1().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)

                VStack(spacing: 0) {
                    ForEach(Array(vm.quickQuestions.prefix(4).enumerated()), id: \.offset) { index, text in
                        Button {
                            onSendMessage(text)
                        } label: {
                            HStack(spacing: 12) {
                                Text(text)
                                    .font(VelaTheme.body())
                                    .foregroundStyle(VelaTheme.fg)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(VelaTheme.meta)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < min(vm.quickQuestions.count, 4) - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                        .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                )
            }

            HStack(spacing: 12) {
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
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Circle().fill(VelaTheme.accent.opacity(0.11))
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("今天想聊什么？")
                    .font(VelaTheme.title1())
                    .foregroundStyle(VelaTheme.fg)
                Text("我会结合你的健康数据，帮助你理解状态并决定下一步。")
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private var localModeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 36, height: 36)
                .background(VelaTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd))

            VStack(alignment: .leading, spacing: 4) {
                Text("本机建议已经可用")
                    .font(VelaTheme.subheadline().weight(.semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text("即使不连接 AI，Vela 仍会根据已同步信号解释今日计划。连接 AI 只用于更深入的追问。")
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.fg2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .stroke(VelaTheme.accent.opacity(0.18), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    private func shortcutCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 32, height: 32)
                .background(VelaTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text(subtitle)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VelaTheme.meta)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VelaTheme.borderSoft.opacity(0.6), lineWidth: 0.5)
        )
    }

    private var workspaceCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            workspaceSectionTitle(L10n.t("TODAY", "今天"), L10n.t("Your current recommendation", "当前最重要的建议"))
                .padding(.horizontal, 4)

            LazyVStack(spacing: 12) {
                    if let plan = todayOperatingPlan {
                        let display = displayModel(for: plan)
                        carouselCard(
                            title: display.statusTitle,
                            detail: display.summary,
                            icon: "sparkles",
                            footer: "\(display.confidenceLabel) · 训练建议"
                        ) {
                            appState.routeToTraining()
                        }
                    } else {
                        carouselCard(
                            title: "今日计划待数据",
                            detail: "同步健康数据后，Vela 会生成与训练页一致的建议；也可以先按当前有限信息生成保守方案。",
                            icon: "waveform.path.ecg",
                            footer: "数据不足 · 可生成保守建议"
                        ) {
                            onSendMessage("请根据当前可用数据生成保守的今日训练建议。")
                        }
                    }

                    if !pendingMemoryProposals.isEmpty {
                        carouselCard(
                            title: "待确认长期记忆",
                            detail: "\(pendingMemoryProposals.count) 条候选内容，确认后才会写入你的档案。",
                            icon: "brain.head.profile",
                            footer: "点击进行归档确认",
                            accentColor: VelaTheme.systemOrange
                        ) {
                            showWikiProfile = true
                        }
                    }

                    ForEach(agentArtifacts.prefix(3)) { artifact in
                        carouselCard(
                            title: artifact.title,
                            detail: localizedArtifactType(artifact.type),
                            icon: artifactIcon(artifact.type),
                            footer: "\(evidenceLabel(artifact.confidence)) · 历史产物"
                        ) {
                            onSendMessage("基于产物 \(artifact.title) 给我下一步行动。")
                        }
                    }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
        }
    }

    private func carouselCard(
        title: String,
        detail: String,
        icon: String,
        footer: String,
        accentColor: Color = VelaTheme.accent,
        isAI: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(accentColor)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(accentColor.opacity(0.12)))
                    
                    Text(title)
                        .font(VelaTheme.subheadline().weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                Text(detail)
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                Text(footer)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg).fill(VelaTheme.cardBg))
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg)
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            )
            .appleIntelligenceGlow(isHighlighted: isAI, radius: 18)
        }
        .buttonStyle(.cardPress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)。\(detail)。\(footer)")
        .accessibilityHint("轻点查看或继续讨论")
    }

    private func workspaceSectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.accent)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(VelaTheme.muted)
        }
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
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("历史报告")
        .navigationBarTitleDisplayMode(.inline)
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
                ForEach(Array(reports.prefix(5).enumerated()), id: \.element.createdAt) { index, report in
                    reportRow(
                        icon: report.type.contains("sleep") ? "moon.fill" : "sun.max.fill",
                        color: report.type.contains("sleep") ? .indigo : .orange,
                        title: report.title,
                        subtitle: report.createdAt.formatted(.dateTime.month().day().hour().minute())
                    )
                    if index < min(reports.count, 5) - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var artifactRows: some View {
        if artifacts.isEmpty {
            VelaMakeCard {
                Text("暂无生成物")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.fg2)
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
            .background(VelaTheme.cardBg)
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
        .background(VelaTheme.cardBg)
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
        .navigationTitle("生成物")
        .navigationBarTitleDisplayMode(.inline)
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
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("生成物详情")
        .navigationBarTitleDisplayMode(.inline)
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
