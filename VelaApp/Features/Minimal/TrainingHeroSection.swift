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
    let evidenceMetrics: [String]
    let heatmapWeeks: [TrainingHeatmapWeek]
    let futureRecommendations: [RotationDayRecommendation]
    let aiFutureDays: [RotationDayRecommendation]?
    let isPlanningWithAI: Bool
    let onRequestAIPlan: () -> Void
    let onDiscussWithCoach: () -> Void

    @State private var isRevealed = false
    @State private var showEvidence = false

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

    private var focusLine: String {
        if decision == .rest { return "优先恢复 · 轻活动" }
        if let focus { return "下一站 · \(focus.title)" }
        return "自由训练"
    }

    private var boundaryLine: String {
        [volumeText, "RPE \(rpeText)", durationText]
            .filter { !$0.isEmpty && $0 != "--" }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TrainingRhythmHeatmap(
                weeks: heatmapWeeks,
                revealProgress: isRevealed ? 1 : 0
            )
            .padding(.top, 12)

            decisionSummaryRow
                .padding(.top, 16)

            futureRecommendationStrip
                .padding(.top, 12)

            evidenceSection
                .padding(.top, 16)

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
        return todaySession.map { "\($0.durationMinutes) 分" } ?? "自由训练"
    }

    /// 紧凑的今日安排行：左侧决定 + 下一站，右侧容量/RPE/时长。
    private var decisionSummaryRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(planStateLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(focusLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            Spacer(minLength: 8)

            Text(boundaryLine)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(VelaTheme.rhythmInk)
                .multilineTextAlignment(.trailing)
        }
    }

    /// 训练规划卡：「今天（今日决定）+ 明 + 后」，本地推荐器即时给出，
    /// 可点「Vela 规划」让 Coach 结合数据复核。
    @ViewBuilder
    private var futureRecommendationStrip: some View {
        let cards = aiFutureDays ?? Array(futureRecommendations.prefix(2))
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("训练规划")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)

                    if let aiDays = aiFutureDays, !aiDays.isEmpty {
                        Text("Vela 建议")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeepOn)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VelaTheme.rhythmDeep, in: Capsule())
                    }

                    Spacer(minLength: 6)

                    Button(action: onRequestAIPlan) {
                        HStack(spacing: 4) {
                            if isPlanningWithAI {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: aiFutureDays == nil ? "sparkles" : "arrow.clockwise")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text(aiFutureDays == nil ? "Vela 规划" : "重新生成")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(VelaTheme.rhythmCanvasRaised, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isPlanningWithAI)
                    .accessibilityLabel("让 Vela 结合数据规划训练")
                }

                HStack(spacing: 8) {
                    todayPlanCard()
                    ForEach(Array(cards.prefix(2).enumerated()), id: \.offset) { _, recommendation in
                        futurePlanCard(recommendation)
                    }
                }
            }
        }
    }

    /// 今日计划日的动作清单（plannedExercisesJSON 解码——「练什么」的具体内容）。
    private var todayExercises: [WorkoutTemplateExercise] {
        guard let todaySession,
              let data = todaySession.plannedExercisesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) else {
            return []
        }
        return list
    }

    /// 具体动作预览行：前 2 个动作的组×次 + 剩余数 + 时长。
    private var todayExerciseLine: String {
        guard !todayExercises.isEmpty else { return "" }
        let preview = todayExercises.prefix(2).map { "\($0.name) \($0.targetSets)×\($0.targetReps)" }
        var line = preview.joined(separator: " · ")
        if todayExercises.count > 2 { line += " +\(todayExercises.count - 2)" }
        if let session = todaySession { line += " · \(session.durationMinutes) 分" }
        return line
    }

    /// 今天卡片：今日决策 + 目标部位/休息 + 具体动作/边界（两行注记，与未来卡等高）。
    private func todayPlanCard() -> some View {
        let isRest = decision == .rest
        let groupsText = isRest ? "休息" : (focus?.shortTitle ?? "训练")
        let primaryNote: String
        let secondaryNote: String
        if isRest {
            primaryNote = "优先恢复 · 轻活动"
            secondaryNote = "散步、拉伸都算"
        } else if !todayExerciseLine.isEmpty {
            primaryNote = todayExerciseLine
            secondaryNote = boundaryLine.isEmpty ? focusLine : boundaryLine
        } else {
            primaryNote = focusLine
            secondaryNote = boundaryLine.isEmpty ? "训练计划" : boundaryLine
        }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("今天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(planStateLabel)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(VelaTheme.rhythmDeep.opacity(0.12), in: Capsule())
            }
            Text(groupsText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isRest ? VelaTheme.sleepColor : VelaTheme.rhythmDeep)
            Text(primaryNote)
                .font(.system(size: 8.5))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.85))
                .lineLimit(2)
                .frame(height: 20, alignment: .top)
            Text(secondaryNote)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInk.opacity(0.75))
                .lineLimit(1)
                .frame(height: 10, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(VelaTheme.rhythmDeep.opacity(0.55), lineWidth: 1)
        }
    }

    private func futurePlanCard(_ recommendation: RotationDayRecommendation) -> some View {
        let label: String
        switch recommendation.dayOffset {
        case 1: label = "明天"
        case 2: label = "后天"
        default: label = "第\(recommendation.dayOffset)天"
        }
        let isRest = recommendation.groups.isEmpty
        let groupsText = isRest
            ? "休息"
            : recommendation.groups.map(TrainingHeatmapData.shortLabel).joined(separator: "+")

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                if recommendation.source == "ai" {
                    Text("AI")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(VelaTheme.rhythmDeep.opacity(0.12), in: Capsule())
                }
            }
            Text(groupsText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isRest ? VelaTheme.sleepColor : VelaTheme.rhythmDeep)
            Text(isRest ? recommendation.note : shortNote(recommendation.note))
                .font(.system(size: 8.5))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.85))
                .lineLimit(2)
                .frame(height: 20, alignment: .top)
            Text("")
                .font(.system(size: 8.5, weight: .medium))
                .lineLimit(1)
                .frame(height: 10, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
    }

    /// 「依据：48h 2 组 · 7 天 6 组」→ 卡内短文案「48h 2组 · 7天 6组」。
    private func shortNote(_ note: String) -> String {
        note
            .replacingOccurrences(of: "依据：", with: "")
            .replacingOccurrences(of: " · ", with: " · ")
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

    /// 「为什么」证据层：一行最强依据 + 点环/点箭头展开完整理由与评分。
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    showEvidence.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(VelaTheme.rhythmDeep)
                        .frame(width: 2, height: 13)
                    Text(evidenceLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .rotationEffect(.degrees(showEvidence ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日训练依据，\(evidenceLine)")

            if showEvidence {
                VStack(alignment: .leading, spacing: 8) {
                    if !decisionReasons.isEmpty {
                        ForEach(Array(decisionReasons.enumerated()), id: \.offset) { _, reason in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(VelaTheme.rhythmDeep.opacity(0.6))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(reason)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if !evidenceMetrics.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(evidenceMetrics, id: \.self) { metric in
                                Text(metric)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(VelaTheme.rhythmCanvasRaised.opacity(0.95), in: Capsule())
                            }
                        }
                    }
                }
                .padding(12)
                .background(VelaTheme.rhythmCanvasRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// 一行最强依据（决策理由优先，其次局部疲劳，无数据时用保守边界说明）。
    private var evidenceLine: String {
        if let first = decisionReasons.first {
            return first
        }
        if let top = summary.localFatigue.values.max(by: { $0.setsLast7d < $1.setsLast7d }),
           top.setsLast7d > 0 {
            return "\(localizedMuscleGroup(top.muscleGroup)) 7 天 \(top.setsLast7d) 组，今天优先避开或减量"
        }
        return "数据积累中，先按保守边界执行"
    }

    private var decisionReasons: [String] {
        todayPlan?.operatingPlanReasons ?? []
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

/// 未来一天的最佳训练部位推荐（结合真实肌群疲劳 + 恢复状态 + 轮转交替）。
struct RotationDayRecommendation: Equatable {
    let dayOffset: Int       // 1=明天, 2=后天, 3=大后天
    let groups: [String]     // 肌群键；空数组 = 建议休息/暂无数据
    let note: String
    var source: String = "local"   // "local" 本机推荐器 / "ai" Coach 参与
}

/// 纯函数推荐器：不依赖计划，无计划同样成立。
enum TrainingRotationRecommender {
    static func upcomingDays(
        localFatigue: [String: LocalMuscleFatigue],
        decision: DailyTrainingDecisionType,
        recoveryScore: Double?,
        recoveryRestThreshold: Double = 50,
        days: Int = 3,
        calendar: Calendar = .current
    ) -> [RotationDayRecommendation] {
        // 候选：疲劳高（避开）的肌群排除；其余按 48h 组数升序（最近练得少的优先）。
        let ranked = localFatigue
            .map(\.value)
            .filter { $0.fatigueLevel != "high" }
            .sorted {
                if $0.setsLast48h != $1.setsLast48h { return $0.setsLast48h < $1.setsLast48h }
                return $0.setsLast7d < $1.setsLast7d
            }

        var recommendations: [RotationDayRecommendation] = []
        var lastPick: String?
        var pendingRecoveryDay = false
        if let recoveryScore, recoveryScore < recoveryRestThreshold, decision != .rest {
            pendingRecoveryDay = true
        }

        for offset in 1...days {
            if pendingRecoveryDay {
                recommendations.append(RotationDayRecommendation(
                    dayOffset: offset,
                    groups: [],
                    note: "恢复偏低，建议休息或轻活动"
                ))
                pendingRecoveryDay = false
                continue
            }
            let preferred = ranked.first { $0.muscleGroup != lastPick } ?? ranked.first
            if let pick = preferred {
                lastPick = pick.muscleGroup
                recommendations.append(RotationDayRecommendation(
                    dayOffset: offset,
                    groups: [pick.muscleGroup],
                    note: "依据：48h \(pick.setsLast48h) 组 · 7 天 \(pick.setsLast7d) 组"
                ))
            } else {
                recommendations.append(RotationDayRecommendation(
                    dayOffset: offset,
                    groups: [],
                    note: "暂无训练数据"
                ))
            }
        }
        return recommendations
    }
}

/// 日历热力图的一天：真实训练强度分档 + 当天练过的肌群 + 有氧时长。
struct TrainingHeatmapDay: Equatable {
    let date: Date
    let tier: Int          // 0 无训练 / 1 轻度 / 2 中度 / 3 高
    let groups: [String]   // 力量肌群键（仅 App 内手动力量记录可解析出肌群）
    let cardioMinutes: Double
    let activityNames: [String]  // 当天训练类型（力量训练/跑步/骑行…）
    let isFuture: Bool
}

struct TrainingHeatmapWeek: Equatable {
    let days: [TrainingHeatmapDay]
}

/// 热力图数据构建（纯函数，可测试）：周一起始的 N 周网格。
enum TrainingHeatmapData {
    static func weeks(
        endingAt: Date,
        weeks: Int = 5,
        records: [DailyHealthSummaryRecord],
        workouts: [StrengthWorkoutRecord],
        summaries: [WorkoutSummary] = [],
        calendar: Calendar = .current
    ) -> [TrainingHeatmapWeek] {
        let endDay = calendar.startOfDay(for: endingAt)
        // 网格以「本周周日」为终点回推 N 周：每行周一起始，覆盖今天，
        // 本周剩余未来天用弱化色占位。
        let weekday = calendar.component(.weekday, from: endDay)   // 1=周日..7=周六
        let daysToSunday = (8 - weekday) % 7
        let lastSunday = calendar.date(byAdding: .day, value: daysToSunday, to: endDay) ?? endDay
        let firstDay = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: lastSunday) ?? lastSunday

        var groupsByDay: [Date: Set<String>] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.startedAt)
            guard day >= firstDay, day <= endDay else { continue }
            let analysis = TrainingAnalyticsService().summarizeWorkout(workout.dto)
            for key in analysis.muscleGroupSets.keys {
                groupsByDay[day, default: []].insert(key)
            }
        }
        // 有氧分钟 + 当天训练类型：非力量类按天聚合分钟，所有类型记名字
        //（修复：此前 HK 同步来的力量/有氧既不进肌群也不进名字 → 点击显示「休息」）。
        var cardioByDay: [Date: Double] = [:]
        var namesByDay: [Date: [String]] = [:]
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.start)
            guard day >= firstDay, day <= endDay else { continue }
            if isStrength(summary) {
                var names = namesByDay[day] ?? []
                if !names.contains("力量训练") { names.append("力量训练") }
                namesByDay[day] = names
            } else {
                cardioByDay[day, default: 0] += summary.end.timeIntervalSince(summary.start) / 60
                var names = namesByDay[day] ?? []
                let display = summary.activityName.isEmpty ? "训练" : summary.activityName
                if !names.contains(display) { names.append(display) }
                namesByDay[day] = names
            }
        }
        var recordsByDay: [Date: DailyHealthSummaryRecord] = [:]
        for record in records {
            recordsByDay[calendar.startOfDay(for: record.date)] = record
        }

        var weeksOut: [TrainingHeatmapWeek] = []
        var current: [TrainingHeatmapDay] = []
        var day = firstDay
        for _ in 0..<(weeks * 7) {
            let isFuture = day > endDay
            let tier = isFuture ? 0 : tier(for: recordsByDay[day])
            let groups = groupsByDay[day].map { Array($0) } ?? []
            let cardio = cardioByDay[day] ?? 0
            let names = namesByDay[day] ?? []
            current.append(TrainingHeatmapDay(
                date: day,
                tier: tier,
                groups: groups,
                cardioMinutes: cardio,
                activityNames: names,
                isFuture: isFuture
            ))
            if current.count == 7 {
                weeksOut.append(TrainingHeatmapWeek(days: current))
                current = []
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }
        return weeksOut
    }

    /// 力量类判定：本地力量日志/训记导入/手动记录/HK 合并镜像，或活动名含 strength/力量。
    static func isStrength(_ summary: WorkoutSummary) -> Bool {
        if let source = summary.source,
           ["strengthLog", "xunji", "manual", "healthKit+xunji", "healthKit+strengthLog"].contains(source) {
            return true
        }
        let name = summary.activityName.lowercased()
        return name.contains("strength") || name.contains("力量")
    }

    /// 与 DEEP ANALYSIS 月热力图同源的强度分档规则。
    static func tier(for record: DailyHealthSummaryRecord?) -> Int {
        guard let record else { return 0 }
        let count = record.workoutCount ?? 0
        let calories = record.activeCalories ?? 0
        let duration = record.workoutDuration ?? 0
        if count >= 3 { return 3 }
        if count == 2 { return 2 }
        if count == 1 { return 1 }
        if calories > 400 || duration > 45 { return 2 }
        if calories > 150 || duration > 15 { return 1 }
        return 0
    }

    static func shortLabel(_ key: String) -> String {
        switch key.lowercased() {
        case "chest": return "胸"
        case "back": return "背"
        case "shoulders": return "肩"
        case "quads", "hamstrings", "glutes", "legs": return "腿"
        case "biceps", "triceps", "core", "abs", "arms": return "臂"
        case "other": return "其"
        default: return String(key.prefix(2))
        }
    }
}

/// 训练节律日历热力图：最近几周训练强度色块，今天描边，点格子看当天练了什么。
private struct TrainingRhythmHeatmap: View {
    let weeks: [TrainingHeatmapWeek]
    let revealProgress: CGFloat

    @State private var selectedDay: TrainingHeatmapDay?

    private static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Self.weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 6) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 6) {
                        ForEach(week.days, id: \.date) { day in
                            cell(day)
                        }
                    }
                }
            }
            .opacity(revealProgress)

            // 固定高度详情区：选中显示当天内容，否则显示图例——不跳布局。
            ZStack {
                if let selected = selectedDay {
                    selectedInfo(selected)
                        .transition(.opacity)
                } else {
                    legend
                        .transition(.opacity)
                }
            }
            .frame(height: 28)
        }
    }

    private var legend: some View {
        HStack(spacing: 7) {
            Text("最近 5 周训练")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
            legendCell(color: VelaTheme.rhythmMist.opacity(0.6), label: "无")
            legendCell(color: VelaTheme.rhythmGlow.opacity(0.55), label: "轻")
            legendCell(color: VelaTheme.rhythmGlow, label: "中")
            legendCell(color: VelaTheme.rhythmDeep, label: "高")
            Spacer()
            Text("点格子看当天")
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
        }
    }

    private func selectedInfo(_ day: TrainingHeatmapDay) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(VelaTheme.rhythmDeep)
                .frame(width: 6, height: 6)
            Text(detailText(day))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("再点取消")
                .font(.system(size: 9))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(VelaTheme.rhythmCanvasRaised.opacity(0.95), in: Capsule())
        .shadow(color: VelaTheme.rhythmGlow.opacity(0.3), radius: 5)
    }

    private func legendCell(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
        }
    }

    private func cell(_ day: TrainingHeatmapDay) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(cellColor(day))
            .frame(height: 26)
            .frame(maxWidth: .infinity)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(VelaTheme.rhythmDeep, lineWidth: 1.5)
                }
                if selectedDay == day {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(VelaTheme.rhythmInk.opacity(0.55), lineWidth: 1.2)
                }
            }
            .opacity(day.isFuture ? 0.14 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    if day.isFuture {
                        selectedDay = nil
                    } else {
                        selectedDay = selectedDay == day ? nil : day
                    }
                }
            }
            .accessibilityLabel(detailText(day))
    }

    private func cellColor(_ day: TrainingHeatmapDay) -> Color {
        switch day.tier {
        case 3: return VelaTheme.rhythmDeep
        case 2: return VelaTheme.rhythmGlow
        case 1: return VelaTheme.rhythmGlow.opacity(0.55)
        default: return VelaTheme.rhythmMist.opacity(0.6)
        }
    }

    private func detailText(_ day: TrainingHeatmapDay) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        let dateText = formatter.string(from: day.date)

        var parts: [String] = []
        if !day.groups.isEmpty {
            let names = day.groups.map { localizedMuscleGroup($0) }.joined(separator: "、")
            parts.append("力量 \(names)")
        } else if day.activityNames.contains("力量训练") {
            parts.append("力量训练")
        }
        if day.cardioMinutes > 0 {
            parts.append("有氧 \(Int(day.cardioMinutes.rounded())) 分")
        }
        if parts.isEmpty, !day.activityNames.isEmpty {
            parts.append(day.activityNames.prefix(2).joined(separator: "、"))
        }
        if parts.isEmpty {
            return "\(dateText) · 休息"
        }
        return "\(dateText) · \(parts.joined(separator: " · "))"
    }
}

// MARK: - Local fatigue landscape

struct TrainingMuscleLandscape: View {
    let summary: RecentTrainingSummary
    /// 肌群键 → 最近 7 天逐日有效组数（index 0 = 最旧），数据加载时预计算。
    var muscleDailySets: [String: [Int]] = [:]
    /// 疲劳计算的锚定日（跟随页面浏览日期）。
    var endingAt: Date = Date()

    @State private var expandedGroup: String?

    private var groups: [(name: String, key: String, fatigue: LocalMuscleFatigue)] {
        summary.localFatigue
            .map { (localizedMuscleGroup($0.key), $0.key, $0.value) }
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
                eyebrow: "",
                title: "局部训练状态",
                actionTitle: nil,
                action: {}
            )

            if groups.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("完成并同步训练后，这里会判断各部位是否适合再次训练。")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    statusSummaryChips

                    VStack(spacing: 0) {
                        ForEach(Array(groups.prefix(6).enumerated()), id: \.offset) { index, group in
                            muscleRow(group)
                            if index < min(groups.count, 6) - 1 {
                                Rectangle()
                                    .fill(VelaTheme.rhythmMist)
                                    .frame(height: 0.75)
                                    .padding(.leading, 16)
                            }
                        }
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

    /// 概览胶囊：可练 / 留量 / 避开的部位数量（真实计数，非装饰）。
    private var statusSummaryChips: some View {
        let counts = Dictionary(grouping: groups, by: { $0.fatigue.fatigueLevel })
            .mapValues(\.count)
        return HStack(spacing: 8) {
            statusChip(label: "可练", count: counts["low"] ?? 0, color: VelaTheme.rhythmDeep)
            statusChip(label: "留量", count: counts["moderate"] ?? 0, color: VelaTheme.rhythmWarm)
            statusChip(label: "避开", count: counts["high"] ?? 0, color: VelaTheme.statePoor)
            Spacer(minLength: 0)
            Text("点一行看 7 天走势")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.75))
        }
    }

    private func statusChip(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(VelaTheme.rhythmMist.opacity(0.6), in: Capsule())
    }

    private func muscleRow(_ group: (name: String, key: String, fatigue: LocalMuscleFatigue)) -> some View {
        let isExpanded = expandedGroup == group.key
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    expandedGroup = isExpanded ? nil : group.key
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("48 小时 \(group.fatigue.setsLast48h) 组 · 7 天 \(group.fatigue.setsLast7d) 组")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    .frame(width: 116, alignment: .leading)

                    GeometryReader { proxy in
                        let ratio = min(1, CGFloat(group.fatigue.setsLast7d) / 24)
                        ZStack(alignment: .leading) {
                            Capsule().fill(VelaTheme.rhythmMist).frame(height: 5)
                            Capsule().fill(fatigueColor(group.fatigue.fatigueLevel))
                                .frame(width: max(5, proxy.size.width * ratio), height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text(fatigueLabel(group.fatigue.fatigueLevel))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(fatigueColor(group.fatigue.fatigueLevel))
                        .frame(width: 38, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 16, height: 16)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
            .accessibilityLabel("\(group.name)，\(fatigueLabel(group.fatigue.fatigueLevel))，过去四十八小时 \(group.fatigue.setsLast48h) 组，七天 \(group.fatigue.setsLast7d) 组")

            if isExpanded {
                MuscleExpandedPanel(
                    fatigue: group.fatigue,
                    dailySets: muscleDailySets[group.key] ?? [],
                    endingAt: endingAt
                )
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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

/// 展开后的单肌群面板：建议 + 7 天逐日组数 + 下次可练时间。
private struct MuscleExpandedPanel: View {
    let fatigue: LocalMuscleFatigue
    let dailySets: [Int]
    let endingAt: Date

    private var maxDaily: Int {
        max(1, dailySets.max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(fatigue.recommendation)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            dailyBars

            HStack(spacing: 8) {
                Label("下次可练：\(nextTrainingText)", systemImage: "clock")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer(minLength: 4)
                Text("7 天容量 \(Int(fatigue.volumeLast7d.rounded())) kg")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.rhythmMist.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 最近 7 天逐日组数迷你柱（真实组数，空天为弱化占位）。
    private var dailyBars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array(dailySets.enumerated()), id: \.offset) { index, sets in
                VStack(spacing: 3) {
                    Text(sets > 0 ? "\(sets)" : "")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(sets > 0 ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.7))
                        .frame(height: max(4, CGFloat(sets) / CGFloat(maxDaily) * 34))
                    Text(dayLabel(index))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayLabel(_ index: Int) -> String {
        // 数组 index 0 = 锚定日 6 天前，最后一个 = 锚定日（endingAt）当天。
        guard dailySets.count > 0, index >= 0, index < dailySets.count else { return "" }
        let daysAgo = dailySets.count - 1 - index
        switch daysAgo {
        case 0: return "今"
        case 1: return "昨"
        default:
            let calendar = Calendar.current
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: endingAt)) ?? endingAt
            let weekday = calendar.component(.weekday, from: day)   // 1=周日..7=周六
            let labels = ["日", "一", "二", "三", "四", "五", "六"]
            return labels[weekday - 1]
        }
    }

    private var nextTrainingText: String {
        switch fatigue.fatigueLevel {
        case "high": return "至少再休息 24–48 小时"
        case "moderate": return "明天可安排低容量"
        default: return "恢复信号允许时今天可练"
        }
    }
}

struct TrainingAnalysisPortal: View {
    let sessions: Int
    let totalDuration: String
    let cardioStatus: String
    /// 30 天耗力趋势（归一化折线点，可为空）。
    var sparkline: [CGPoint] = []
    /// 窗口内个人纪录数（去重后）。
    var prCount: Int = 0

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("深入分析")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("\(sessions) 次力量 · \(totalDuration) · 有氧\(cardioStatus)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(1)
                if prCount > 0 {
                    Text("个人纪录 \(prCount) 项")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(VelaTheme.rhythmDeep.opacity(0.12), in: Capsule())
                        .padding(.top, 3)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                PortalSparkline(points: sparkline)
                    .frame(width: 62, height: 30)
                Text("30 天耗力")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

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
}

/// 迷你耗力趋势线：无数据时显示弱化虚线，不伪造曲线。
private struct PortalSparkline: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else {
                var dash = Path()
                dash.move(to: CGPoint(x: 6, y: size.height / 2))
                dash.addLine(to: CGPoint(x: size.width - 6, y: size.height / 2))
                context.stroke(dash, with: .color(VelaTheme.rhythmMist), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                return
            }
            var path = Path()
            for (index, point) in points.enumerated() {
                let x = point.x * size.width
                let y = point.y * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [VelaTheme.rhythmGlow, VelaTheme.rhythmDeep]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            if let last = points.last {
                let center = CGPoint(x: last.x * size.width, y: last.y * size.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
                    with: .color(VelaTheme.rhythmDeep)
                )
            }
        }
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
    /// 活跃计划的完整训练日序列（轮转条数据源）。
    var days: [TrainingDay] = []
    /// 今天解析到的计划日标题（轮转条高亮）。
    var todayTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

            if !days.isEmpty {
                rotationStrip
                    .padding(.top, 13)
            }
        }
        .padding(15)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// 计划训练日序列条：完成=实心勾、今天=描边、未来=弱化，最多 7 个 + 溢出计数。
    private var rotationStrip: some View {
        HStack(spacing: 7) {
            ForEach(Array(days.prefix(7).enumerated()), id: \.element.id) { _, day in
                rotationChip(day)
            }
            if days.count > 7 {
                Text("+\(days.count - 7)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func rotationChip(_ day: TrainingDay) -> some View {
        let isToday = todayTitle != nil && day.title == todayTitle && !day.isCompleted
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(day.isCompleted ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.75))
                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                } else {
                    Text(rotationShortLabel(day))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isToday ? VelaTheme.rhythmDeep : VelaTheme.rhythmInkSecondary)
                }
            }
            .frame(width: 26, height: 26)
            .overlay {
                if isToday {
                    Circle()
                        .stroke(VelaTheme.rhythmDeep, lineWidth: 1.5)
                }
            }
            Text("\(day.dayNumber)")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(day.dayNumber) 训练日：\(day.title)，\(day.isCompleted ? "已完成" : isToday ? "今天" : "未完成")")
    }

    private func rotationShortLabel(_ day: TrainingDay) -> String {
        if day.focus == "rest" { return "休" }
        if let focus = TrainingRotationFocus.resolve(from: "\(day.title) \(day.focus)") {
            return focus.shortTitle
        }
        switch day.focus {
        case "cardio": return "有氧"
        case "flexibility", "mobility": return "活"
        default: return String(day.title.prefix(1))
        }
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
