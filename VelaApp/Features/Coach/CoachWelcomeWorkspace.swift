import SwiftUI

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
