import SwiftUI

// MARK: - Training Rhythm Surface

/// Training is a decision surface, not an in-session logger. The iPhone owns
/// the next-focus decision and its boundaries; Apple Watch owns execution.
struct TrainingHeroSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let todaySession: TrainingDay?
    let todayPlan: DailyOperatingPlanRecord?
    let activePlan: TrainingPlanRecord?
    let summary: RecentTrainingSummary
    let onDiscussWithCoach: () -> Void

    @State private var isRevealed = false

    private let rotation = TrainingRotationFocus.allCases

    private var payload: DailyOperatingPlanPayload? {
        todayPlan?.operatingPlanPayload
    }

    private var decision: DailyTrainingDecisionType {
        payload?.decision ?? .reduce
    }

    private var focus: TrainingRotationFocus? {
        TrainingRotationFocus.resolve(
            from: [todaySession?.title, todaySession?.focus, activePlan?.title]
                .compactMap { $0 }
                .joined(separator: " ")
        )
    }

    private var headline: String {
        if decision == .rest { return "让训练停在该停的位置" }
        if decision == .swap { return "换一站，保留训练节奏" }
        if let focus { return "下一站，\(focus.title)" }
        return "决定下一次训练"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(VelaTheme.rhythmDeep)
                    .frame(width: 7, height: 7)
                Text("TRAINING RHYTHM")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.35)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                Spacer(minLength: 8)

                Text(planStateLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }

            TrainingRotationPath(
                rotation: rotation,
                activeFocus: focus,
                decision: decision,
                revealProgress: isRevealed ? 1 : 0
            )
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 150 : 184)
            .padding(.top, 8)
            .accessibilityHidden(true)

            Text(headline)
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 34 : 42, weight: .semibold))
                .tracking(-1.15)
                .foregroundStyle(VelaTheme.rhythmInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                boundaryMetric("容量", volumeText)
                boundaryDivider
                boundaryMetric("RPE 上限", rpeText)
                boundaryDivider
                boundaryMetric("建议时长", durationText)
            }
            .padding(.top, 18)

            watchExecutionNote
                .padding(.top, 18)

            Button(action: onDiscussWithCoach) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 36, height: 36)
                        .background(VelaTheme.rhythmDeep, in: Circle())

                    Text("和 Vela 调整下一站")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.75)
                }
                .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
            }
            .buttonStyle(.cardPress)
            .padding(.top, 20)
        }
        .padding(.horizontal, VelaTheme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .background(alignment: .top) {
            TrainingAmbientField(decision: decision)
                .frame(height: 500)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !isRevealed else { return }
            if reduceMotion {
                isRevealed = true
            } else {
                withAnimation(.spring(response: 0.52, dampingFraction: 1.0)) {
                    isRevealed = true
                }
            }
        }
    }

    private var planStateLabel: String {
        guard todayPlan != nil else { return "采用保守边界" }
        switch decision {
        case .keep: return "保持计划"
        case .reduce: return "建议减量"
        case .swap: return "建议换部位"
        case .rest: return "恢复优先"
        }
    }

    private var volumeText: String {
        guard todayPlan != nil, let multiplier = payload?.volumeMultiplier else { return "--" }
        return "\(Int((multiplier * 100).rounded()))%"
    }

    private var rpeText: String {
        guard todayPlan != nil, let cap = payload?.intensityCap else { return "--" }
        return "≤ \(cap)"
    }

    private var durationText: String {
        guard decision != .rest else { return "轻活动" }
        return todaySession.map { "\($0.durationMinutes) 分" } ?? "按体感"
    }

    private func boundaryMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var boundaryDivider: some View {
        Rectangle()
            .fill(VelaTheme.rhythmMist)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }

    private var watchExecutionNote: some View {
        HStack(spacing: 11) {
            Image(systemName: "applewatch")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 32, height: 32)
                .background(VelaTheme.rhythmMist, in: Circle())

            Text("Apple Watch 记录，结束后自动同步")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TrainingAmbientField: View {
    let decision: DailyTrainingDecisionType

    private var glow: Color {
        switch decision {
        case .keep: VelaTheme.rhythmGlow
        case .reduce: VelaTheme.rhythmWarm
        case .swap: VelaTheme.rhythmMist
        case .rest: VelaTheme.sleepColor
        }
    }

    var body: some View {
        ZStack {
            VelaTheme.rhythmCanvas
            RadialGradient(
                colors: [glow.opacity(0.23), glow.opacity(0.05), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 290
            )
            RadialGradient(
                colors: [VelaTheme.rhythmGlow.opacity(0.10), .clear],
                center: UnitPoint(x: 0.92, y: 0.42),
                startRadius: 0,
                endRadius: 230
            )
        }
    }
}

private enum TrainingRotationFocus: String, CaseIterable, Identifiable {
    case back, chest, shoulders, legs, accessories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .back: "背部"
        case .chest: "胸部"
        case .shoulders: "肩部"
        case .legs: "腿部"
        case .accessories: "手臂与核心"
        }
    }

    var shortTitle: String {
        switch self {
        case .back: "背"
        case .chest: "胸"
        case .shoulders: "肩"
        case .legs: "腿"
        case .accessories: "臂"
        }
    }

    static func resolve(from raw: String) -> TrainingRotationFocus? {
        let value = raw.lowercased()
        if ["back", "pull", "背", "划船", "下拉"].contains(where: value.contains) { return .back }
        if ["chest", "push", "胸", "卧推"].contains(where: value.contains) { return .chest }
        if ["shoulder", "deltoid", "肩", "推举"].contains(where: value.contains) { return .shoulders }
        if ["leg", "quad", "hamstring", "glute", "腿", "蹲"].contains(where: value.contains) { return .legs }
        if ["arm", "biceps", "triceps", "core", "abs", "手臂", "腹", "核心"].contains(where: value.contains) { return .accessories }
        return nil
    }
}

private struct TrainingRotationPath: View {
    let rotation: [TrainingRotationFocus]
    let activeFocus: TrainingRotationFocus?
    let decision: DailyTrainingDecisionType
    let revealProgress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let horizontalInset: CGFloat = 21
            let step = (width - horizontalInset * 2) / CGFloat(max(rotation.count - 1, 1))
            let y = proxy.size.height * 0.48

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: horizontalInset, y: y))
                    for index in 1..<rotation.count {
                        let x = horizontalInset + CGFloat(index) * step
                        let previousX = horizontalInset + CGFloat(index - 1) * step
                        path.addCurve(
                            to: CGPoint(x: x, y: y),
                            control1: CGPoint(x: previousX + step * 0.42, y: y + (index.isMultiple(of: 2) ? -22 : 22)),
                            control2: CGPoint(x: x - step * 0.42, y: y + (index.isMultiple(of: 2) ? -22 : 22))
                        )
                    }
                }
                .trim(from: 0, to: revealProgress)
                .stroke(VelaTheme.rhythmDeep.opacity(0.55), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

                ForEach(Array(rotation.enumerated()), id: \.element.id) { index, item in
                    let isActive = item == activeFocus
                    VStack(spacing: 8) {
                        ZStack {
                            if isActive {
                                Circle()
                                    .fill(VelaTheme.rhythmGlow.opacity(0.26))
                                    .frame(width: 38, height: 38)
                            }
                            Circle()
                                .fill(isActive ? VelaTheme.rhythmDeep : VelaTheme.rhythmCanvasRaised)
                                .frame(width: isActive ? 20 : 14, height: isActive ? 20 : 14)
                                .overlay {
                                    Circle()
                                        .stroke(VelaTheme.rhythmDeep.opacity(isActive ? 0 : 0.34), lineWidth: 1)
                                }
                        }
                        .frame(height: 38)

                        Text(item.shortTitle)
                            .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                            .foregroundStyle(isActive ? VelaTheme.rhythmInk : VelaTheme.rhythmInkSecondary)
                    }
                    .frame(width: 42)
                    .position(x: horizontalInset + CGFloat(index) * step, y: y + 21)
                    .opacity(revealProgress)
                }

                if decision == .rest {
                    Text("恢复窗口")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(VelaTheme.rhythmMist, in: Capsule())
                        .position(x: width * 0.5, y: 21)
                        .opacity(revealProgress)
                }
            }
        }
    }
}

// MARK: - Local fatigue landscape

struct TrainingMuscleLandscape: View {
    let summary: RecentTrainingSummary

    private var groups: [(name: String, fatigue: LocalMuscleFatigue)] {
        summary.localFatigue
            .map { (localizedMuscleGroup($0.key), $0.value) }
            .sorted { lhs, rhs in
                if lhs.fatigue.fatigueLevel == rhs.fatigue.fatigueLevel {
                    return lhs.fatigue.setsLast7d > rhs.fatigue.setsLast7d
                }
                return fatigueRank(lhs.fatigue.fatigueLevel) > fatigueRank(rhs.fatigue.fatigueLevel)
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VelaRhythmSectionHeader(
                eyebrow: "LOCAL LOAD",
                title: "局部训练状态",
                actionTitle: nil,
                action: {}
            )

            if groups.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("完成并同步训练后，这里会判断各部位是否适合再次训练。")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 13) {
                    ForEach(Array(groups.prefix(6).enumerated()), id: \.offset) { _, group in
                        fatigueRow(group.name, group.fatigue)
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }
            }
        }
    }

    private func fatigueRow(_ name: String, _ fatigue: LocalMuscleFatigue) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("48 小时 \(fatigue.setsLast48h) 组 · 7 天 \(fatigue.setsLast7d) 组")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .frame(width: 116, alignment: .leading)

            GeometryReader { proxy in
                let ratio = min(1, CGFloat(fatigue.setsLast7d) / 24)
                ZStack(alignment: .leading) {
                    Capsule().fill(VelaTheme.rhythmMist).frame(height: 5)
                    Capsule().fill(fatigueColor(fatigue.fatigueLevel))
                        .frame(width: max(5, proxy.size.width * ratio), height: 5)
                }
            }
            .frame(height: 5)

            Text(fatigueLabel(fatigue.fatigueLevel))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(fatigueColor(fatigue.fatigueLevel))
                .frame(width: 38, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)，\(fatigueLabel(fatigue.fatigueLevel))，过去四十八小时 \(fatigue.setsLast48h) 组，七天 \(fatigue.setsLast7d) 组")
    }

    private func fatigueRank(_ value: String) -> Int {
        switch value {
        case "high": return 3
        case "moderate": return 2
        default: return 1
        }
    }

    private func fatigueLabel(_ value: String) -> String {
        switch value {
        case "high": return "避开"
        case "moderate": return "留量"
        default: return "可练"
        }
    }

    private func fatigueColor(_ value: String) -> Color {
        switch value {
        case "high": VelaTheme.statePoor
        case "moderate": VelaTheme.rhythmWarm
        default: VelaTheme.rhythmDeep
        }
    }
}

struct TrainingAnalysisPortal: View {
    let sessions: Int
    let totalDuration: String
    let cardioStatus: String

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DEEP ANALYSIS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                Text("深入分析")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("\(sessions) 次力量 · \(totalDuration) · 有氧\(cardioStatus)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 42, height: 42)
                .background(VelaTheme.rhythmMist, in: Circle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct TrainingPostWorkoutPrompt: View {
    let workout: WorkoutSummary
    let onAnnotate: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "applewatch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 38, height: 38)
                .background(VelaTheme.rhythmMist, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("这次训练感觉如何？")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("\(workout.activityName) · \(workout.start.formatted(date: .omitted, time: .shortened)) · 可跳过")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("补充体感", action: onAnnotate)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
    }
}

struct TrainingPlanPortal: View {
    let planTitle: String?
    let nextFocus: String?
    let completedDays: Int
    let totalDays: Int

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(VelaTheme.rhythmMist, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: completion)
                    .stroke(
                        VelaTheme.rhythmDeep,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(totalDays > 0 ? "\(completedDays)" : "—")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.rhythmInk)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(planTitle ?? "建立你的训练轮转")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .lineLimit(1)

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(15)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    private var completion: CGFloat {
        guard totalDays > 0 else { return 0 }
        return min(1, CGFloat(completedDays) / CGFloat(totalDays))
    }

    private var detail: String {
        if let nextFocus, !nextFocus.isEmpty { return "当前建议：\(nextFocus)" }
        if totalDays > 0 { return "\(completedDays) / \(totalDays) 个训练日已完成" }
        return "让 Vela 根据恢复与偏好生成可调整计划"
    }
}
