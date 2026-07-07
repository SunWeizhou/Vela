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
        VStack(alignment: .leading, spacing: 18) {
            welcomeHeader
            
            workspaceCarousel
            
            Button {
                showWikiProfile = true
            } label: {
                HStack {
                    Label("健康档案与长期记忆", systemImage: "books.vertical.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            NavigationLink(destination: VelaReportsView()) {
                HStack {
                    Label("历史报告与自动分析", systemImage: "doc.text.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Suggestion questions
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("QUICK SUGGESTIONS", "快捷提问"))
                    .font(VelaTheme.caption2().weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
                    .tracking(0.5)
                    .padding(.leading, 4)

                FlexStack(spacing: 8) {
                    ForEach(vm.quickQuestions, id: \.self) { text in
                        Button(text) {
                            onSendMessage(text)
                        }
                        .font(VelaTheme.subheadline())
                        .foregroundStyle(VelaTheme.fg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(VelaTheme.cardBg)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(VelaTheme.borderSoft, lineWidth: 0.7)
                                )
                        )
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(spacing: 16) {
            AppleIntelligenceOrb()
                .padding(.top, 10)

            Text("Vela 教练")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)

            Text("你的 AI 身体智能代理。你可以与我讨论训练、恢复、睡眠或营养，我将基于你的健康 data 为你提供个性化建议。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4.5)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 14)
    }

    private var workspaceCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            workspaceSectionTitle(L10n.t("INTELLIGENCE WORKSPACE", "智能决策舱"), L10n.t("Active insights & actionable plans", "主动智能洞察与建议"))
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if let plan = todayOperatingPlan {
                        let display = displayModel(for: plan)
                        carouselCard(
                            title: display.statusTitle,
                            detail: display.summary,
                            icon: "sparkles",
                            footer: "\(display.confidenceLabel) · 训练建议"
                        ) {
                            appState.routeToTab(1)
                        }
                    } else {
                        carouselCard(
                            title: "今日计划正在生成",
                            detail: "正在读取恢复、睡眠、训练负荷和近期训练记录；完成后会与训练页保持同一条建议。",
                            icon: "arrow.triangle.2.circlepath",
                            footer: "数据同步中",
                            isAI: true
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
                            accentColor: Color.orange
                        ) {
                            showWikiProfile = true
                        }
                    }

                    ForEach(agentArtifacts.prefix(3)) { artifact in
                        carouselCard(
                            title: artifact.title,
                            detail: localizedArtifactType(artifact.type),
                            icon: artifactIcon(artifact.type),
                            footer: "置信度 \(Int((artifact.confidence * 100).rounded()))% · 历史产物"
                        ) {
                            onSendMessage("基于产物 \(artifact.title) 给我下一步行动。")
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(3)
                    .frame(height: 54, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                Text(footer)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
            }
            .frame(width: 250, height: 132)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            )
            .appleIntelligenceGlow(isHighlighted: isAI, radius: 18)
        }
        .buttonStyle(.cardPress)
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
        let payload: DailyOperatingPlanPayload? = {
            guard let data = plan.payloadJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: data)
        }()
        return DailyOperatingPlanDisplayModel.build(
            payload: payload,
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
    @Query(sort: \AIReportRecord.createdAt, order: .reverse)
    private var reports: [AIReportRecord]
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var artifacts: [AgentArtifactRecord]

    @AppStorage("agent_morning_brief_alerts") private var morningBriefOn = true
    @AppStorage("agent_bedtime_reminders") private var sleepReviewOn = true
    @AppStorage("agent_weekly_review_enabled") private var weeklyReviewOn = true
    @AppStorage("agent_post_workout_checkin_enabled") private var postWorkoutOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                morningBriefHero

                VelaMakeSectionHeader(title: "今日")
                reportRows

                VelaMakeSectionHeader(title: "生成物")
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
                    reportRow(
                        icon: "doc.text.fill",
                        color: .indigo,
                        title: artifact.title,
                        subtitle: "\(artifact.type.replacingOccurrences(of: "_", with: " ")) · \(artifact.createdAt.formatted(.relative(presentation: .named)))"
                    )
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
}
