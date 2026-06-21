import SwiftUI

struct TodayEvidenceSheet: View {
    let state: TodayCommandState
    let dashboard: DashboardSummary
    var onAskCoach: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("今日状态决策") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            Text(state.bodyStateTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(readinessColor(state.readinessDecision.decision))
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                ConfidenceBadge(confidence: state.dataConfidence)
                                Text("\(Int((state.readinessDecision.confidence * 100).rounded()))%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(readinessColor(state.readinessDecision.decision))
                            }
                        }
                        
                        Text(state.coachArtifact?.summary ?? state.summary)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.fg2)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 4)
                }

                let insights = ProactiveInsightService.evaluate(dashboard: dashboard)
                if !insights.isEmpty {
                    Section("AI 针对性指导建议") {
                        ForEach(insights) { insight in
                            NavigationLink {
                                ProactiveInsightDetailSheet(insight: insight) { question in
                                    dismiss()
                                    onAskCoach(question)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: insight.focus.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(insight.focus.color.opacity(0.10)))
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(insight.displayTitle)
                                            .font(VelaTheme.subheadline())
                                            .fontWeight(.semibold)
                                            .foregroundStyle(VelaTheme.fg)
                                            .lineLimit(1)
                                        
                                        Text(insight.body)
                                            .font(VelaTheme.caption1())
                                            .foregroundStyle(VelaTheme.muted)
                                            .lineLimit(1)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(insight.focus.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(insight.focus.color.opacity(0.08)))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                if !state.keySignals.isEmpty {
                    Section("今日身体数据信号") {
                        ForEach(state.keySignals) { signal in
                            SignalRow(signal: signal)
                        }
                    }
                }

                if !state.readinessDecision.reasons.isEmpty {
                    Section("决策详细逻辑推理") {
                        ForEach(state.readinessDecision.reasons, id: \.self) { reason in
                            Text(localizedReason(reason))
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.fg2)
                                .lineSpacing(3)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("今日指导与证据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func readinessColor(_ decision: ReadinessDecisionKind) -> Color {
        switch decision {
        case .keep: return VelaTheme.success
        case .reduce: return Color(hex: "#FF9F0A")
        case .swap: return Color(hex: "#5C6BC0")
        case .recover: return VelaTheme.sleep
        }
    }
}
