import SwiftUI
import SwiftData

/// The pending training-plan proposal belongs in the Today decision scene so
/// the user can act on the evidence while it is still relevant.
struct TodayTrainingPlanAdaptationCard: View {
    let activePlan: TrainingPlanRecord
    let pendingProposal: TrainingPlanAdaptationRecord

    @Environment(\.modelContext) private var modelContext
    @State private var actionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("Vela 的训练提案")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Spacer()
                    Text(pendingProposal.originalDayTitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .multilineTextAlignment(.trailing)
                }

                Text(adaptationLabel(pendingProposal.adjustment))
                    .font(.headline)
                    .foregroundStyle(VelaTheme.rhythmInk)

                VStack(alignment: .leading, spacing: 6) {
                    Text("为什么")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Text(pendingProposal.reason)
                        .font(.body)
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let alternative = pendingProposal.suggestedAlternative,
                   !alternative.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("替代方案")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Text(alternative)
                            .font(.body)
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        accept(pendingProposal, in: activePlan)
                    } label: {
                        Label("采纳", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmDeepOn)
                            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget)
                            .background(VelaTheme.rhythmDeep, in: Capsule())
                    }
                    .buttonStyle(.cardPress)

                    Button {
                        reject(pendingProposal)
                    } label: {
                        Label("拒绝", systemImage: "xmark")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget)
                            .background(VelaTheme.rhythmMist, in: Capsule())
                    }
                    .buttonStyle(.cardPress)
                }

                Text("Vela 只提出方案；采纳后才会改变训练轮转。")
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                if let actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(VelaTheme.stressColor)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.rhythmDeep.opacity(0.28), lineWidth: 0.9)
            }
    }

    private func accept(
        _ proposal: TrainingPlanAdaptationRecord,
        in plan: TrainingPlanRecord
    ) {
        let originalDays = plan.days
        let originalStatus = proposal.status
        let originalAcceptedAt = proposal.acceptedAt
        guard TodayTrainingPlanAdaptationDecision.accept(proposal, in: plan) else {
            actionError = "提案未能应用，请稍后重试。"
            return
        }
        do {
            try modelContext.save()
            actionError = nil
            VelaHaptic.success()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            plan.days = originalDays
            proposal.status = originalStatus
            proposal.acceptedAt = originalAcceptedAt
            actionError = "提案保存失败，请稍后重试。"
        }
    }

    private func reject(_ proposal: TrainingPlanAdaptationRecord) {
        TodayTrainingPlanAdaptationDecision.reject(proposal)
        do {
            try modelContext.save()
            actionError = nil
            VelaHaptic.light()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            proposal.status = AdaptationStatus.proposed.rawValue
            proposal.rejectedAt = nil
            actionError = "提案状态保存失败，请稍后重试。"
        }
    }

    private func adaptationLabel(_ adjustment: String) -> String {
        switch adjustment {
        case "keep": return "按计划执行，但保留余力"
        case "reduce": return "建议减量"
        case "swap": return "建议换成主动恢复"
        case "rest": return "建议安排休息"
        case "reschedule": return "建议改期"
        case "deloadWeek": return "建议本周减载"
        default: return adjustment
        }
    }
}

/// Shared state transition for the Today card and its tests. Plan mutation is
/// deliberately delegated to AdaptiveTrainingManager (ADR 0008); this helper
/// only records the user's explicit decision after that mutation succeeds.
enum TodayTrainingPlanAdaptationDecision {
    @discardableResult
    static func accept(
        _ proposal: TrainingPlanAdaptationRecord,
        in plan: TrainingPlanRecord,
        at date: Date = Date()
    ) -> Bool {
        guard proposal.status == AdaptationStatus.proposed.rawValue,
              AdaptiveTrainingManager().applyAdaptation(proposal, to: plan) else {
            return false
        }
        proposal.status = AdaptationStatus.accepted.rawValue
        proposal.acceptedAt = date
        return true
    }

    static func reject(
        _ proposal: TrainingPlanAdaptationRecord,
        at date: Date = Date()
    ) {
        guard proposal.status == AdaptationStatus.proposed.rawValue else { return }
        proposal.status = AdaptationStatus.rejected.rawValue
        proposal.rejectedAt = date
    }
}

extension TodayTrainingPlanAdaptationCard: @preconcurrency Equatable {
    @MainActor
    static func == (lhs: TodayTrainingPlanAdaptationCard, rhs: TodayTrainingPlanAdaptationCard) -> Bool {
        lhs.activePlan.id == rhs.activePlan.id &&
        lhs.activePlan.updatedAt == rhs.activePlan.updatedAt &&
        lhs.pendingProposal.id == rhs.pendingProposal.id &&
        lhs.pendingProposal.status == rhs.pendingProposal.status &&
        lhs.pendingProposal.adjustment == rhs.pendingProposal.adjustment &&
        lhs.pendingProposal.reason == rhs.pendingProposal.reason &&
        lhs.pendingProposal.suggestedAlternative == rhs.pendingProposal.suggestedAlternative
    }
}
