import SwiftUI

struct TrainingHeroSection: View {
    let todaySession: TrainingDay?
    let todayPlan: DailyOperatingPlanRecord?
    let activePlan: TrainingPlanRecord?
    let lastWorkoutSummary: String?
    let startStrengthWorkout: () -> Void

    var body: some View {
        let session = todaySession
        let payload = todayPlan?.operatingPlanPayload
        let reasons = todayPlan?.operatingPlanReasons ?? []
        let display = DailyOperatingPlanDisplayModel.build(
            payload: payload,
            primaryActionType: todayPlan?.primaryActionType,
            source: todayPlan?.source,
            safetyNotice: todayPlan?.safetyNotice,
            confidence: todayPlan?.confidence ?? 0.0
        )
        let hasPlan = todayPlan != nil
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天的训练")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.muted)
                    Text(session?.title ?? activePlan?.title ?? "自由训练")
                        .font(VelaTheme.title1())
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                if hasPlan {
                    Text(display.actionLabel)
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(hasPlan ? display.statusTitle : "还没有足够数据生成个性化建议")
                    .font(VelaTheme.headline())
                    .foregroundStyle(hasPlan ? VelaTheme.accent : VelaTheme.fg)
                
                Text(session?.description ?? (hasPlan
                    ? display.summary
                    : "你仍然可以开始自由训练；同步健康数据后，Vela 会补充容量和强度建议。"))
                    .font(VelaTheme.subheadline())
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

            if hasPlan {
                HStack(spacing: 8) {
                    executionMetric("容量", payload.map { "\(Int(($0.volumeMultiplier * 100).rounded()))%" } ?? "--")
                    executionMetric("RPE 上限", payload.map { "\($0.intensityCap)" } ?? "--")
                    executionMetric("时长", session.map { "\($0.durationMinutes) 分" } ?? "--")
                }
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
                    Text(hasPlan ? "执行建议并记录训练" : "开始自由训练")
                }
                .font(VelaTheme.headline())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(VelaTheme.accent)
                )
            }
            .buttonStyle(.plain)

            if hasPlan {
                HStack {
                    Text(display.evidenceLine).lineLimit(2)
                    Spacer()
                    Text(display.confidenceLabel).lineLimit(1)
                }
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
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
