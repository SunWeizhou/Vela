import SwiftUI

struct TrainingHeroSection: View {
    let todaySession: TrainingDay?
    let todayPlan: DailyOperatingPlanRecord?
    let activePlan: TrainingPlanRecord?
    let lastWorkoutSummary: String?
    let startStrengthWorkout: () -> Void

    var body: some View {
        let session = todaySession
        let payload = todayPlan.flatMap { plan -> DailyOperatingPlanPayload? in
            guard let data = plan.payloadJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: data)
        }
        let reasons = todayPlan.flatMap { plan -> [String]? in
            guard let data = plan.reasonsJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        } ?? []
        let display = DailyOperatingPlanDisplayModel.build(
            payload: payload,
            primaryActionType: todayPlan?.primaryActionType,
            source: todayPlan?.source,
            safetyNotice: todayPlan?.safetyNotice,
            confidence: todayPlan?.confidence ?? 0.0
        )
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("基于今日状态的训练建议")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                    Text(session?.title ?? activePlan?.title ?? "自由训练")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                Text(display.actionLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(display.statusTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                
                Text(session?.description ?? display.summary)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.fg2)
                    .lineSpacing(4)
                    .lineLimit(3)
                
                if !reasons.isEmpty {
                    Text(reasons.map { localizedReason($0) }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(3)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 10) {
                executionMetric("容量", payload.map { "\(Int(($0.volumeMultiplier * 100).rounded()))%" } ?? "--")
                executionMetric("RPE 上限", payload.map { "\($0.intensityCap)" } ?? "--")
                executionMetric("时长", session.map { "\($0.durationMinutes) 分" } ?? "--")
            }

            if let latest = lastWorkoutSummary {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                    Text("上次表现：\(latest)")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            Button {
                startStrengthWorkout()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                    Text("执行建议并记录训练")
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(VelaTheme.accent)
                )
            }
            .buttonStyle(.plain)

            HStack {
                Text(display.evidenceLine)
                    .lineLimit(2)
                Spacer()
                Text(display.confidenceLabel)
                    .lineLimit(1)
            }
            .font(.system(size: 9))
            .foregroundStyle(VelaTheme.muted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }

    private func executionMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(VelaTheme.muted)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(VelaTheme.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))
    }
}
