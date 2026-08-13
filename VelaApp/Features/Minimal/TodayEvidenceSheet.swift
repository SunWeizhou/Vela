import SwiftUI

struct TodayEvidenceSheet: View {
    let state: TodayCommandState
    let dashboard: DashboardSummary
    var onAskCoach: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    decisionSummary

                    if !state.keySignals.isEmpty {
                        signalEvidence
                    }

                    if !state.readinessDecision.reasons.isEmpty {
                        reasoningEvidence
                    }

                    let insights = ProactiveInsightService.evaluate(dashboard: dashboard)
                    if !insights.isEmpty {
                        insightEvidence(insights)
                    }

                    permissionEntry
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 18)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .background(VelaTheme.rhythmCanvas)
            .navigationTitle("判断依据")
            .velaRhythmDetailChrome()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .tint(VelaTheme.rhythmDeep)
    }

    private var decisionSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(VelaTheme.rhythmDeep)
                    .frame(width: 7, height: 7)
                Text("VELA DECISION")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                Spacer()
                Text(confidenceLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }

            Text(state.bodyStateTitle)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(VelaTheme.rhythmInk)

            Text(state.coachArtifact?.summary ?? state.summary)
                .font(.system(.body, design: .default))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("由本机健康证据与规则生成，AI 只负责解释。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
        }
        .padding(20)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
    }

    private var signalEvidence: some View {
        VStack(alignment: .leading, spacing: 14) {
            VelaRhythmSectionHeader(
                eyebrow: "EVIDENCE",
                title: "哪些信号影响了判断",
                actionTitle: nil,
                action: {}
            )

            VStack(spacing: 0) {
                ForEach(Array(state.keySignals.enumerated()), id: \.element.id) { index, signal in
                    HStack(alignment: .top, spacing: 13) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .padding(.top, 3)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(localizedSignalTitle(signal.title))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                Spacer(minLength: 8)
                                Text(signal.value)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                            }
                            Text(localizedReason(signal.interpretation))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 14)

                    if index < state.keySignals.count - 1 {
                        Divider().overlay(VelaTheme.rhythmMist)
                    }
                }
            }
        }
    }

    /// 健康权限的恢复入口：拒绝权限后主流程没有重新授权按钮，
    /// 这里始终提供「打开系统设置」的直达路径。
    private var permissionEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            VelaRhythmSectionHeader(
                eyebrow: "PERMISSIONS",
                title: "健康数据权限",
                actionTitle: nil,
                action: {}
            )
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "heart.text.square")
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("在系统设置中管理健康权限")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(14)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.cardPress)
        }
    }

    private var reasoningEvidence: some View {
        VStack(alignment: .leading, spacing: 14) {
            VelaRhythmSectionHeader(
                eyebrow: "REASONING",
                title: "判断逻辑",
                actionTitle: nil,
                action: {}
            )

            VStack(alignment: .leading, spacing: 12) {
                ForEach(state.readinessDecision.reasons, id: \.self) { reason in
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(VelaTheme.rhythmDeep)
                            .frame(width: 2, height: 16)
                            .padding(.top, 2)
                        Text(localizedReason(reason))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }

    private func insightEvidence(_ insights: [ProactiveInsight]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VelaRhythmSectionHeader(
                eyebrow: "PERSONAL MODEL",
                title: "可能与你有关的规律",
                actionTitle: nil,
                action: {}
            )

            ForEach(insights) { insight in
                NavigationLink {
                    ProactiveInsightDetailSheet(insight: insight) { question in
                        dismiss()
                        onAskCoach(question)
                    }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: insight.focus.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .frame(width: 34, height: 34)
                            .background(VelaTheme.rhythmMist, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.displayTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text(insight.body)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    .padding(14)
                    .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.cardPress)
            }
        }
    }

    private var confidenceLabel: String {
        switch state.dataConfidence {
        case .high: "依据充分"
        case .medium: "依据部分"
        case .low: "依据有限"
        case .unavailable: "仍在建立基线"
        }
    }

    private func localizedSignalTitle(_ title: String) -> String {
        switch title {
        case "Recovery": "恢复"
        case "Sleep": "睡眠"
        case "HRV vs baseline": "HRV 与基线"
        case "Resting HR": "静息心率"
        case "Training load": "训练负荷"
        case "Local fatigue": "局部疲劳"
        default: title
        }
    }
}
