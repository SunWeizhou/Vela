import SwiftUI

struct TodayHeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let targetStrainRange: ClosedRange<Double>?
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void
    
    let generatedAt: Date?
    let safetyNotice: String?
    let isStale: Bool

    private var hasRecoveryScore: Bool {
        recoveryScoreText != "--"
    }

    private var coreSignals: [TodayExperienceSignalCard] {
        ["recovery", "sleep", "strain"].compactMap { id in
            model.signalCards.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label(statusTitle, systemImage: statusIcon)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(statusColor)

                Spacer(minLength: 8)

                if let generatedAt {
                    Text(formattedTime(generatedAt))
                        .font(VelaTheme.caption2().monospacedDigit())
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            coreScoreOverview
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            Button(action: onPrimaryAction) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("指导")
                            .font(VelaTheme.caption2().weight(.semibold))
                            .foregroundStyle(VelaTheme.muted)
                        Spacer()
                        Label(model.hero.confidenceLabel, systemImage: evidenceIcon)
                            .font(VelaTheme.caption2().weight(.semibold))
                            .foregroundStyle(statusColor)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.hero.decisionTitle)
                                .font(VelaTheme.headline())
                                .foregroundStyle(VelaTheme.fg)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                            Text(model.hero.summary)
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.fg2)
                                .lineSpacing(2)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(VelaTheme.caption1().weight(.bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.top, 3)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: primaryActionIcon)
                        Text(model.hero.primaryActionTitle)
                        Spacer()
                        if let targetStrainText {
                            Text(targetStrainText)
                        }
                    }
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(accent)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.cardPress)

            if let safetyNotice, !safetyNotice.isEmpty {
                Text(safetyNotice)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(VelaTheme.meta)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var coreScoreOverview: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(coreSignals) { signal in
                    coreScoreMetric(signal, horizontal: true)
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(coreSignals) { signal in
                    coreScoreMetric(signal, horizontal: false)
                        .frame(maxWidth: .infinity)

                    if signal.id != coreSignals.last?.id {
                        Divider()
                            .frame(height: 74)
                    }
                }
            }
        }
    }

    private func coreScoreMetric(
        _ signal: TodayExperienceSignalCard,
        horizontal: Bool
    ) -> some View {
        let color = scoreColor(for: signal.id)
        let metricType: VelaMetricDetailView.MetricType? = {
            switch signal.id {
            case "recovery": return .recovery
            case "sleep": return .sleep
            case "strain": return .strain
            default: return nil
            }
        }()

        return Group {
            if let metricType {
                NavigationLink {
                    VelaMetricDetailView(metric: metricType)
                } label: {
                    metricContent(signal: signal, color: color, horizontal: horizontal)
                }
                .buttonStyle(.cardPress)
            } else {
                metricContent(signal: signal, color: color, horizontal: horizontal)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(signal.title)，\(signal.value == "--" ? "待同步" : "\(signal.value)分")，\(signal.directionLabel)，\(signal.confidenceLabel)"
        )
    }

    private func metricContent(
        signal: TodayExperienceSignalCard,
        color: Color,
        horizontal: Bool
    ) -> some View {
        Group {
            if horizontal {
                HStack(spacing: 12) {
                    metricRing(signal, color: color, size: 62)
                    scoreLabel(signal)
                    Spacer(minLength: 0)
                }
            } else {
                VStack(spacing: 5) {
                    metricRing(signal, color: color, size: 70)
                    scoreLabel(signal)
                }
            }
        }
        .padding(.horizontal, horizontal ? 8 : 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: horizontal ? 68 : 104)
    }

    private func metricRing(
        _ signal: TodayExperienceSignalCard,
        color: Color,
        size: CGFloat
    ) -> some View {
        VelaMetricScoreRing(
            score: Double(signal.value),
            label: signal.title,
            domain: metricDomain(for: signal.id),
            size: size,
            accent: color,
            targetRange: nil,
            allowsOverflow: signal.id == "strain",
            showsLabel: false,
            direction: signal.directionLabel,
            confidence: signal.confidenceLabel,
            dataState: signal.coverageLabel
        )
        .accessibilityHidden(true)
    }

    private func scoreLabel(_ signal: TodayExperienceSignalCard) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(signal.title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
            Text(signal.value == "--" ? "待同步" : signal.directionLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(1)
        }
    }

    private func scoreColor(for signalID: String) -> Color {
        switch signalID {
        case "recovery": return VelaTheme.recoveryColor
        case "sleep": return VelaTheme.sleepColor
        case "strain": return VelaTheme.strainColor
        default: return accent
        }
    }

    private func metricDomain(for signalID: String) -> VelaMetricDomain {
        switch signalID {
        case "recovery": .recovery
        case "sleep": .sleep
        case "strain": .strain
        default: .neutral
        }
    }

    private var strainTargetRange: ClosedRange<Double>? {
        targetStrainRange
    }

    private var targetStrainText: String? {
        guard let strainTargetRange else { return nil }
        return "目标负荷 \(Int(strainTargetRange.lowerBound))–\(Int(strainTargetRange.upperBound))"
    }

    private var evidenceIcon: String {
        if !hasRecoveryScore { return "circle.dotted" }
        return model.hero.confidenceLabel.contains("充分") ? "checkmark.seal.fill" : "info.circle.fill"
    }

    private var statusTitle: String {
        if generatedAt == nil { return "正在建立身体基线" }
        if isStale { return "建议需要刷新" }
        return "今日建议已更新"
    }

    private var statusIcon: String {
        if generatedAt == nil { return "circle.dotted" }
        if isStale { return "arrow.clockwise" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if generatedAt == nil { return VelaTheme.muted }
        if isStale { return VelaTheme.warn }
        return VelaTheme.recoveryColor
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DailyDecisionFeedbackValues {
    var adoptionStatus: String
    var accuracyRating: String
    var actualAction: String
    var energyRating: Int?
    var fatigueRating: Int?
    var painRating: Int?
    var satisfactionRating: Int?
    var note: String
}

struct DailyDecisionFeedbackCard: View {
    let record: DailyDecisionFeedbackRecord?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: record?.isCompleted == true ? "checkmark.circle.fill" : "scope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(record?.isCompleted == true ? VelaTheme.success : VelaTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(VelaTheme.secondaryGroupedBackground))

                VStack(alignment: .leading, spacing: 3) {
                    Text(record?.isCompleted == true ? "今日反馈已记录" : "这个建议适合你吗？")
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(record?.isCompleted == true ? "可随时更新，Vela 会用它校准后续建议" : "记录实际行动与体感，约 20 秒")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record?.isCompleted == true ? "更新今日建议反馈" : "记录今日建议反馈")
    }
}

struct DailyDecisionFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: DailyDecisionFeedbackRecord
    let onSave: (DailyDecisionFeedbackValues) -> Void

    @State private var adoptionStatus: String
    @State private var accuracyRating: String
    @State private var actualAction: String
    @State private var energyRating: Int?
    @State private var fatigueRating: Int?
    @State private var painRating: Int?
    @State private var satisfactionRating: Int?
    @State private var note: String

    init(record: DailyDecisionFeedbackRecord, onSave: @escaping (DailyDecisionFeedbackValues) -> Void) {
        self.record = record
        self.onSave = onSave
        _adoptionStatus = State(initialValue: record.adoptionStatus ?? "")
        _accuracyRating = State(initialValue: record.accuracyRating ?? "")
        _actualAction = State(initialValue: record.actualAction ?? "")
        _energyRating = State(initialValue: record.energyRating)
        _fatigueRating = State(initialValue: record.fatigueRating)
        _painRating = State(initialValue: record.painRating)
        _satisfactionRating = State(initialValue: record.satisfactionRating)
        _note = State(initialValue: record.note)
    }

    private var canSave: Bool {
        !adoptionStatus.isEmpty && !accuracyRating.isEmpty && !actualAction.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("校准 Vela 的判断")
                            .font(VelaTheme.title2())
                            .foregroundStyle(VelaTheme.fg)
                        Text(record.decisionTitle)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.muted)
                    }

                    feedbackChoiceSection(
                        title: "你采纳建议了吗？",
                        options: [("followed", "完全采纳"), ("modified", "调整后采纳"), ("not_followed", "没有采纳")],
                        selection: $adoptionStatus
                    )
                    feedbackChoiceSection(
                        title: "建议符合当时状态吗？",
                        options: [("accurate", "准确"), ("partly", "部分准确"), ("inaccurate", "不准确")],
                        selection: $accuracyRating
                    )
                    feedbackChoiceSection(
                        title: "你实际做了什么？",
                        options: [("as_planned", "按计划训练"), ("lighter", "降低强度"), ("harder", "提高强度"), ("recovery", "主动恢复"), ("rest", "休息")],
                        selection: $actualAction
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("完成后的体感（可选）")
                            .font(VelaTheme.headline())
                        DecisionRatingRow(title: "精力", lowLabel: "低", highLabel: "高", value: $energyRating)
                        DecisionRatingRow(title: "疲劳", lowLabel: "低", highLabel: "高", value: $fatigueRating)
                        DecisionRatingRow(title: "疼痛", lowLabel: "无", highLabel: "明显", value: $painRating)
                        DecisionRatingRow(title: "满意度", lowLabel: "低", highLabel: "高", value: $satisfactionRating)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充说明（可选）")
                            .font(VelaTheme.headline())
                        TextField("例如：腿部仍然酸痛，所以改成低强度", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).fill(VelaTheme.secondaryGroupedBackground))
                    }
                }
                .padding(20)
            }
            .background(VelaTheme.rhythmCanvas)
            .navigationTitle("今日反馈")
            .velaRhythmDetailChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(DailyDecisionFeedbackValues(
                            adoptionStatus: adoptionStatus,
                            accuracyRating: accuracyRating,
                            actualAction: actualAction,
                            energyRating: energyRating,
                            fatigueRating: fatigueRating,
                            painRating: painRating,
                            satisfactionRating: satisfactionRating,
                            note: note
                        ))
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackChoiceSection(
        title: String,
        options: [(String, String)],
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(VelaTheme.headline())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Button {
                        selection.wrappedValue = option.0
                    } label: {
                        Text(option.1)
                            .font(VelaTheme.subheadline().weight(.semibold))
                            .foregroundStyle(selection.wrappedValue == option.0 ? Color.white : VelaTheme.fg)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(selection.wrappedValue == option.0 ? VelaTheme.accent : VelaTheme.secondaryGroupedBackground))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DecisionRatingRow: View {
    let title: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(VelaTheme.subheadline().weight(.semibold))
                Spacer()
                Text("1 \(lowLabel) · 5 \(highLabel)")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        value = value == rating ? nil : rating
                    } label: {
                        Text("\(rating)")
                            .font(VelaTheme.subheadline().weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .foregroundStyle(value == rating ? Color.white : VelaTheme.fg2)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                                    .fill(value == rating ? VelaTheme.accent : VelaTheme.secondaryGroupedBackground)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(rating)，\(rating == 1 ? lowLabel : rating == 5 ? highLabel : "")")
                    .accessibilityAddTraits(value == rating ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Vela Rhythm Horizon

/// The Today surface's primary visual object. It intentionally avoids an
/// aggregate readiness number: the band communicates a changing capacity
/// window, while the copy owns the actual decision.
struct VelaRhythmHorizonHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: TodayExperienceModel
    let state: TodayCommandState
    let selectedDate: Date
    let isToday: Bool
    let restingHeartRate: Double?
    let maxHeartRate: Double?
    let onOpenPlan: () -> Void
    let onAskCoach: () -> Void

    @State private var isRevealed = false
    @State private var rhythmMetric = "recovery"
    @State private var rhythmGranularity: RhythmGranularity = .day
    @State private var rhythmHourlyMetric: RhythmHourlyMetric = .heartRate

    private var decision: ReadinessDecisionKind {
        state.readinessDecision.decision
    }

    private var headline: String {
        switch decision {
        case .keep: return "保持今天的节奏"
        case .reduce: return "给身体留一点余量"
        case .swap: return "换一条更合适的路径"
        case .recover: return "先把状态收回来"
        }
    }

    private var eyebrow: String {
        if state.dataConfidence == .unavailable { return "正在建立你的节律" }
        return "今日节律 · \(model.hero.confidenceLabel)"
    }

    private var primaryAction: TodayExperienceAction? {
        model.actions.first(where: \.isPrimary) ?? model.actions.first
    }

    /// B2：数据覆盖度徽标——低覆盖时显式标注「按保守方案」。
    private var coverageBadge: (label: String, color: Color)? {
        guard model.signalCards.count >= 5 else { return nil }
        let available = model.signalCards.filter { $0.value != "--" && !$0.value.isEmpty }.count
        switch available {
        case 5: return ("数据覆盖 · 完整", VelaTheme.rhythmDeep)
        case 3...4: return ("数据覆盖 · 中等", VelaTheme.energyColor)
        default: return ("数据覆盖 · 有限，按保守方案", VelaTheme.strainColor)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(VelaTheme.rhythmDeep)
                    .frame(width: 7, height: 7)
                    .shadow(color: VelaTheme.rhythmGlow.opacity(0.55), radius: 6)

                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.15)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                if let badge = coverageBadge {
                    Text(badge.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(badge.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.color.opacity(0.12), in: Capsule())
                        .accessibilityLabel("数据覆盖度：" + badge.label)
                }

                Spacer(minLength: 8)

                Button(action: onAskCoach) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .frame(width: 42, height: 42)
                        .background(VelaTheme.rhythmCanvasRaised.opacity(0.68), in: Circle())
                }
                .buttonStyle(.cardPress)
                .accessibilityLabel("询问 Vela")
            }

            RhythmHorizonVisualization(
                signals: model.signalCards,
                decision: decision,
                selectedDate: selectedDate,
                isToday: isToday,
                selectedMetric: $rhythmMetric,
                granularity: rhythmGranularity,
                selectedHourlyMetric: $rhythmHourlyMetric,
                restingHeartRate: restingHeartRate,
                maxHeartRate: maxHeartRate,
                revealProgress: isRevealed ? 1 : 0
            )
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 176 : 206)
            .padding(.top, 4)
            .accessibilityHidden(true)

            rhythmMetricChips
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 10) {
                Text(headline)
                    .font(.system(.largeTitle, design: .default, weight: .semibold))
                    .tracking(-1.2)
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .fixedSize(horizontal: false, vertical: true)

            }

            Button(action: onOpenPlan) {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(VelaTheme.rhythmDeep)
                        Image(systemName: actionIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeepOn)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryAction?.title ?? "查看今日安排")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.75)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.cardPress)
            .padding(.top, 18)
        }
        .padding(.horizontal, VelaTheme.pagePadding)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .background(alignment: .top) {
            RhythmAmbientField(decision: decision)
                .frame(height: 480)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
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

    private var actionIcon: String {
        switch decision {
        case .keep: return "figure.strengthtraining.traditional"
        case .reduce: return "dial.low"
        case .swap: return "arrow.triangle.swap"
        case .recover: return "wind"
        }
    }

    /// 节律曲线指标切换胶囊（与曲线同源的五个真实评分指标）+ 按天/按小时切换。
    private var rhythmMetricChips: some View {
        HStack(spacing: 6) {
            if rhythmGranularity == .day {
                ForEach(RhythmHorizonVisualization.metricOrder, id: \.self) { id in
                    if let card = model.signalCards.first(where: { $0.id == id }) {
                        let isSelected = rhythmMetric == id
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.92)) {
                                rhythmMetric = id
                            }
                        } label: {
                            Text(card.title)
                                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(
                                    isSelected
                                        ? VelaTheme.rhythmDeep
                                        : VelaTheme.rhythmInkSecondary.opacity(0.75)
                                )
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(
                                    isSelected ? VelaTheme.rhythmCanvasRaised : Color.clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看\(card.title)趋势")
                    }
                }
            } else {
                // 按小时：四个真实日内指标（心率/活动强度/步数/能量消耗）
                ForEach(RhythmHourlyMetric.allCases) { metric in
                    let isSelected = rhythmHourlyMetric == metric
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.92)) {
                            rhythmHourlyMetric = metric
                        }
                    } label: {
                        Text(metric.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(
                                isSelected
                                    ? VelaTheme.rhythmDeep
                                    : VelaTheme.rhythmInkSecondary.opacity(0.75)
                            )
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                isSelected ? VelaTheme.rhythmCanvasRaised : Color.clear,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看\(metric.title)逐小时数据")
                }
            }

            Spacer(minLength: 8)

            // 按天 / 按小时切换（小分段胶囊，不改变整体风格）
            HStack(spacing: 2) {
                granularityButton(.day, label: "按天")
                granularityButton(.hour, label: "按小时")
            }
            .padding(2)
            .background(VelaTheme.rhythmMist.opacity(0.5), in: Capsule())
        }
    }

    private func granularityButton(_ granularity: RhythmGranularity, label: String) -> some View {
        let isSelected = rhythmGranularity == granularity
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.92)) {
                rhythmGranularity = granularity
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VelaTheme.rhythmInk : VelaTheme.rhythmInkSecondary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isSelected ? VelaTheme.rhythmCanvasRaised : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct RhythmAmbientField: View {
    let decision: ReadinessDecisionKind

    private var glow: Color {
        switch decision {
        case .keep: VelaTheme.rhythmGlow
        case .reduce: VelaTheme.rhythmWarm
        case .swap: VelaTheme.rhythmMist
        case .recover: VelaTheme.sleepColor
        }
    }

    var body: some View {
        ZStack {
            VelaTheme.rhythmCanvas

            RadialGradient(
                colors: [glow.opacity(0.24), glow.opacity(0.06), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 270
            )

            RadialGradient(
                colors: [VelaTheme.rhythmGlow.opacity(0.13), .clear],
                center: UnitPoint(x: 0.08, y: 0.58),
                startRadius: 0,
                endRadius: 220
            )
        }
    }
}

private struct RhythmEvidenceAnchors: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                anchors
            }

            VStack(alignment: .leading, spacing: 9) {
                anchors
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("主要依据：\(items.joined(separator: "，"))")
    }

    @ViewBuilder
    private var anchors: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            HStack(spacing: 7) {
                Rectangle()
                    .fill(index == 0 ? VelaTheme.rhythmDeep : VelaTheme.rhythmInkSecondary.opacity(0.45))
                    .frame(width: 1, height: 13)
                Text(item)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(1)
            }

            if index < items.count - 1 {
                Spacer(minLength: 12)
            }
        }
    }
}

private struct RhythmHorizonVisualization: View {
    static let metricOrder = ["recovery", "sleep", "strain", "stress", "energy"]

    let signals: [TodayExperienceSignalCard]
    let decision: ReadinessDecisionKind
    let selectedDate: Date
    let isToday: Bool
    @Binding var selectedMetric: String
    let granularity: RhythmGranularity
    @Binding var selectedHourlyMetric: RhythmHourlyMetric
    let restingHeartRate: Double?
    let maxHeartRate: Double?
    let revealProgress: CGFloat

    @State private var scrubFraction: CGFloat?
    @State private var showValueLabels = false
    @State private var hourlySeries: [RhythmHourlyMetric: [RhythmHourlyPoint]] = [:]
    @State private var hourlyLoadedDay: String?

    private var selectedCard: TodayExperienceSignalCard? {
        signals.first { $0.id == selectedMetric }
    }

    private var dayKey: String {
        DailyHealthSummaryRecord.dayIdentifier(for: selectedDate)
    }

    /// 按天：所选指标的 7 天历史趋势（signal card 自带的 trend 数组，
    /// 由 DailyHealthSummaryRecord 历史评分构成，含当天值）。
    private var series: [Double] {
        guard let card = selectedCard else { return [] }
        return RhythmTrendSource.series(for: card)
    }

    /// 按小时：所选日内指标的逐小时真实值。
    private var currentHourlyPoints: [RhythmHourlyPoint] {
        hourlySeries[selectedHourlyMetric] ?? []
    }

    private var xys: [(CGFloat, CGFloat)] {
        currentHourlyPoints.map { point in
            (CGFloat(point.hour) / 24.0, yPosition(forHourly: point.value, metric: selectedHourlyMetric))
        }
    }

    private var hasData: Bool {
        granularity == .hour ? xys.count >= 3 : series.count >= 2
    }

    /// 0-100 分数 → 垂直位置（0 底 0.74，100 顶 0.28），与旧视觉一致。
    private var dailySamples: [CGFloat] {
        series.map { value in
            yPosition(forScore: value)
        }
    }

    private func yPosition(forScore value: Double) -> CGFloat {
        let y = 0.74 - (CGFloat(value) / 100.0) * 0.46
        return min(0.74, max(0.28, y))
    }

    private func yPosition(forHourly value: Double, metric: RhythmHourlyMetric) -> CGFloat {
        let normalized: CGFloat
        switch metric {
        case .heartRate:
            // 心率 30-220 bpm 绝对刻度
            normalized = CGFloat((min(220, max(30, value)) - 30) / 190.0)
        case .exertionLoad:
            // 小时负荷 0-20（TRIMP 分钟）
            normalized = CGFloat(min(20, max(0, value)) / 20.0)
        case .steps:
            // 当日动态刻度（至少 500 步）
            let ceiling = max(currentHourlyPoints.map(\.value).max() ?? 0, 500)
            normalized = CGFloat(min(ceiling, max(0, value)) / ceiling)
        case .activeEnergy:
            // 当日动态刻度（至少 100 kcal）
            let ceiling = max(currentHourlyPoints.map(\.value).max() ?? 0, 100)
            normalized = CGFloat(min(ceiling, max(0, value)) / ceiling)
        }
        let y = 0.74 - normalized * 0.46
        return min(0.74, max(0.28, y))
    }

    private func progress(for index: Int) -> CGFloat {
        dailySamples.count > 1 ? CGFloat(index) / CGFloat(dailySamples.count - 1) : 0
    }

    private var activeDailyIndex: Int {
        if let scrubFraction {
            let index = Int((scrubFraction * CGFloat(max(dailySamples.count - 1, 0))).rounded())
            return min(max(index, 0), max(dailySamples.count - 1, 0))
        }
        return max(0, dailySamples.count - 1)
    }

    private var activeFraction: CGFloat {
        guard granularity == .hour else { return progress(for: activeDailyIndex) }
        if let scrubFraction { return scrubFraction }
        return xys.last?.0 ?? 0.5
    }

    private func dateLabel(for index: Int) -> String {
        guard dailySamples.count > 1 else { return isToday ? "今天" : "当日" }
        let offset = dailySamples.count - 1 - index
        guard offset > 0 else { return isToday ? "今天" : "当日" }
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private var bandWidth: CGFloat {
        switch decision {
        case .keep: return 0.18
        case .reduce: return 0.13
        case .swap: return 0.11
        case .recover: return 0.085
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let point = activePoint(size: size)

            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    for fraction in [CGFloat(0.0), 0.25, 0.5, 0.75, 1.0] {
                        var guide = Path()
                        let x = fraction * canvasSize.width
                        guide.move(to: CGPoint(x: x, y: 28))
                        guide.addLine(to: CGPoint(x: x, y: canvasSize.height - 28))
                        context.stroke(guide, with: .color(VelaTheme.rhythmInkSecondary.opacity(0.10)), lineWidth: 0.5)
                    }

                    // 心率视图叠加静息基线参考线：高于基线=负荷/压力，低于=恢复。
                    if granularity == .hour,
                       selectedHourlyMetric == .heartRate,
                       let restingHeartRate {
                        var baseline = Path()
                        let baselineY = yPosition(forHourly: restingHeartRate, metric: .heartRate) * canvasSize.height
                        baseline.move(to: CGPoint(x: 0, y: baselineY))
                        baseline.addLine(to: CGPoint(x: canvasSize.width, y: baselineY))
                        context.stroke(
                            baseline,
                            with: .color(VelaTheme.rhythmInkSecondary.opacity(0.4)),
                            style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
                        )
                    }

                    if hasData {
                        let band: Path
                        let center: Path
                        if granularity == .hour {
                            band = RhythmCurve.bandPath(from: xys, width: bandWidth, size: canvasSize)
                            center = RhythmCurve.path(from: xys, size: canvasSize)
                        } else {
                            band = RhythmCurve.bandPath(samples: dailySamples, width: bandWidth, size: canvasSize)
                            center = RhythmCurve.centerPath(samples: dailySamples, size: canvasSize)
                        }

                        context.fill(
                            band,
                            with: .linearGradient(
                                Gradient(colors: [
                                    VelaTheme.rhythmGlow.opacity(0.04),
                                    VelaTheme.rhythmGlow.opacity(0.32),
                                    VelaTheme.rhythmGlow.opacity(0.08)
                                ]),
                                startPoint: CGPoint(x: 0, y: canvasSize.height * 0.5),
                                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height * 0.5)
                            )
                        )

                        context.stroke(
                            center,
                            with: .linearGradient(
                                Gradient(colors: [
                                    VelaTheme.rhythmDeep.opacity(0.18),
                                    VelaTheme.rhythmDeep,
                                    VelaTheme.rhythmDeep.opacity(0.35)
                                ]),
                                startPoint: .zero,
                                endPoint: CGPoint(x: canvasSize.width, y: 0)
                            ),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                    } else {
                        // 数据不足：虚线中位占位，不伪造曲线
                        var pending = Path()
                        pending.move(to: CGPoint(x: 0, y: canvasSize.height * 0.5))
                        pending.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height * 0.5))
                        context.stroke(
                            pending,
                            with: .color(VelaTheme.rhythmInkSecondary.opacity(0.25)),
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 5])
                        )
                    }
                }
                .opacity(revealProgress)
                .scaleEffect(x: revealProgress, y: 1, anchor: .leading)

                if hasData {
                    Circle()
                        .fill(VelaTheme.rhythmCanvasRaised)
                        .frame(width: 15, height: 15)
                        .overlay(Circle().fill(VelaTheme.rhythmDeep).frame(width: 7, height: 7))
                        .shadow(color: VelaTheme.rhythmGlow.opacity(0.9), radius: 10)
                        .position(point)
                        .opacity(revealProgress)

                    // 交互提示：拖动时显示真实数值（与图表同源）
                    if scrubFraction != nil {
                        Text(tooltipText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(VelaTheme.rhythmCanvasRaised.opacity(0.95), in: Capsule())
                            .shadow(color: VelaTheme.rhythmGlow.opacity(0.35), radius: 6)
                            .position(
                                x: min(size.width - 56, max(56, point.x)),
                                y: max(15, point.y - 24)
                            )
                    } else {
                        Text(defaultAnchorText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .position(
                                x: min(size.width - 24, max(24, point.x)),
                                y: max(13, point.y - 23)
                            )
                            .opacity(revealProgress)
                    }
                }

                // 数值标注模式：点一下曲线显示每个数据点数值 + 最高/最低图例，再点关闭。
                valueLabelOverlay(size: size)

                HStack {
                    Text(axisLeftLabel)
                    Spacer()
                    Text(axisMidLabel)
                    Spacer()
                    Text(axisRightLabel)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
                .frame(width: size.width)
                .offset(y: size.height - 19)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard hasData, size.width > 0 else { return }
                        scrubFraction = min(1, max(0, value.location.x / size.width))
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            scrubFraction = nil
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard hasData else { return }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                            showValueLabels.toggle()
                        }
                    }
            )
        }
        .task(id: "rhythm-hour-\(dayKey)-\(granularity.rawValue)") {
            guard granularity == .hour, hourlyLoadedDay != dayKey else { return }
            let start = Calendar.current.startOfDay(for: selectedDate)
            let end = start.addingTimeInterval(86_400)
            let service = HealthKitQueryService()
            let samples = (try? await service.heartRateSamples(start: start, end: end)) ?? []
            let steps = (try? await service.hourlySteps(day: start)) ?? []
            let energy = (try? await service.hourlyActiveEnergy(day: start)) ?? []
            var loaded: [RhythmHourlyMetric: [RhythmHourlyPoint]] = [:]
            loaded[.heartRate] = RhythmTrendSource.hourlyHeartRate(samples: samples, day: start)
            loaded[.exertionLoad] = RhythmTrendSource.hourlyExertionLoad(
                samples: samples,
                day: start,
                restingHeartRate: restingHeartRate,
                maxHeartRate: maxHeartRate
            )
            loaded[.steps] = RhythmTrendSource.hourlyValues(steps)
            loaded[.activeEnergy] = RhythmTrendSource.hourlyValues(energy)
            hourlySeries = loaded
            hourlyLoadedDay = dayKey
        }
    }

    private func activePoint(size: CGSize) -> CGPoint {
        if granularity == .hour {
            return RhythmCurve.point(nearX: activeFraction, xys: xys, size: size)
        }
        return RhythmCurve.point(
            at: progress(for: activeDailyIndex),
            samples: dailySamples,
            size: size
        )
    }

    private var tooltipText: String {
        if granularity == .hour {
            let nearest = xys.min(by: { abs($0.0 - activeFraction) < abs($1.0 - activeFraction) })
            guard let nearest,
                  let point = currentHourlyPoints.first(where: { $0.hour == Int((nearest.0 * 24).rounded()) }) else {
                return "--"
            }
            let hourText = "\(point.hour):00"
            switch selectedHourlyMetric {
            case .heartRate:
                let delta = restingHeartRate.map { point.value - $0 }.map { "（静息 \($0 >= 0 ? "+" : "")\(Int($0.rounded()))）" } ?? ""
                return "\(hourText) · \(Int(point.value.rounded())) bpm \(delta)"
            case .exertionLoad:
                return "\(hourText) · 负荷 \(String(format: "%.1f", point.value))"
            case .steps:
                return "\(hourText) · \(Int(point.value.rounded())) 步"
            case .activeEnergy:
                return "\(hourText) · \(Int(point.value.rounded())) kcal"
            }
        }
        let index = activeDailyIndex
        guard series.indices.contains(index) else { return "--" }
        return "\(dateLabel(for: index)) · \(selectedCard?.title ?? "") \(Int(series[index].rounded()))"
    }

    private var defaultAnchorText: String {
        if granularity == .hour {
            guard let last = currentHourlyPoints.last else { return isToday ? "今天" : "当日" }
            return "\(last.hour):00"
        }
        return dateLabel(for: activeDailyIndex)
    }

    /// 数值标注覆盖层：点一下开启——每个数据点右侧标数值，右上角标最高/最低。
    @ViewBuilder
    private func valueLabelOverlay(size: CGSize) -> some View {
        if showValueLabels, hasData {
            if granularity == .hour {
                ForEach(currentHourlyPoints, id: \.hour) { point in
                    let labelY = max(8.0, yPosition(forHourly: point.value, metric: selectedHourlyMetric) * size.height - 5)
                    Text(compactValue(point.value))
                        .font(.system(size: 7.5, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .position(
                            x: min(size.width - 14, CGFloat(point.hour) / 24.0 * size.width + 6),
                            y: labelY
                        )
                }
            } else {
                ForEach(Array(series.enumerated()), id: \.offset) { index, value in
                    let labelY = max(8.0, dailySamples[index] * size.height - 5)
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .position(
                            x: min(size.width - 14, progress(for: index) * size.width + 7),
                            y: labelY
                        )
                }
            }

            // 最高 / 最低图例（右上角小胶囊）
            HStack(spacing: 8) {
                Label("最高 \(maxLabel)", systemImage: "arrow.up")
                Label("最低 \(minLabel)", systemImage: "arrow.down")
            }
            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
            .foregroundStyle(VelaTheme.rhythmInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VelaTheme.rhythmCanvasRaised.opacity(0.95), in: Capsule())
            .shadow(color: VelaTheme.rhythmGlow.opacity(0.3), radius: 5)
            .position(x: size.width - 68, y: 14)
        }
    }

    /// 数值标注用的紧凑格式：步数大值缩写（1.2k）、活动强度保留一位小数。
    private func compactValue(_ value: Double) -> String {
        switch selectedHourlyMetric {
        case .steps:
            return value >= 1000 ? String(format: "%.1fk", value / 1000) : "\(Int(value.rounded()))"
        case .exertionLoad:
            return String(format: "%.1f", value)
        case .heartRate, .activeEnergy:
            return "\(Int(value.rounded()))"
        }
    }

    private var maxLabel: String {
        if granularity == .hour {
            guard let maxValue = currentHourlyPoints.map(\.value).max() else { return "--" }
            return compactValue(maxValue)
        }
        guard let maxValue = series.max() else { return "--" }
        return "\(Int(maxValue.rounded()))"
    }

    private var minLabel: String {
        if granularity == .hour {
            guard let minValue = currentHourlyPoints.map(\.value).min() else { return "--" }
            return compactValue(minValue)
        }
        guard let minValue = series.min() else { return "--" }
        return "\(Int(minValue.rounded()))"
    }

    private var axisLeftLabel: String {
        granularity == .hour ? "0时" : dateLabel(for: 0)
    }

    private var axisMidLabel: String {
        if granularity == .hour { return "12时" }
        return dateLabel(for: max(0, dailySamples.count / 2))
    }

    private var axisRightLabel: String {
        if granularity == .hour { return "24时" }
        return dateLabel(for: max(0, dailySamples.count - 1))
    }
}

/// 节律曲线唯一数据源：signal card 自带的真实历史趋势（≤7 天，含当天）。
/// 少于 2 个真实点时返回空——不伪造曲线。
enum RhythmTrendSource {
    static func series(for card: TodayExperienceSignalCard) -> [Double] {
        let values = card.trend.map { min(100, max(0, $0)) }
        return values.count >= 2 ? values : []
    }

    /// 按小时模式：把当日 HealthKit 心率样本聚合为逐小时均值（真实日内信号）。
    static func hourlyHeartRate(
        samples: [HeartRateSample],
        day: Date,
        calendar: Calendar = .current
    ) -> [RhythmHourlyPoint] {
        var buckets: [Int: [Double]] = [:]
        for sample in samples {
            guard calendar.isDate(sample.date, inSameDayAs: day) else { continue }
            let hour = calendar.component(.hour, from: sample.date)
            buckets[hour, default: []].append(sample.bpm)
        }
        return buckets.keys.sorted().map { hour in
            let values = buckets[hour] ?? []
            let average = values.reduce(0, +) / Double(max(values.count, 1))
            return RhythmHourlyPoint(hour: hour, value: min(220, max(30, average)))
        }
    }

    /// 小时级活动强度（TRIMP 启发式）：小时平均心率储备率 × 覆盖分钟数。
    /// 覆盖分钟按 5 分钟/样本估算（Apple Watch 采样间隔），每小时封顶 60 分钟。
    /// 需要个人静息心率与最大心率基线；缺任一则返回空（不伪造）。
    static func hourlyExertionLoad(
        samples: [HeartRateSample],
        day: Date,
        restingHeartRate: Double?,
        maxHeartRate: Double?,
        calendar: Calendar = .current
    ) -> [RhythmHourlyPoint] {
        guard let restingHeartRate, let maxHeartRate, maxHeartRate > restingHeartRate else { return [] }
        var buckets: [Int: [Double]] = [:]
        for sample in samples {
            guard calendar.isDate(sample.date, inSameDayAs: day) else { continue }
            buckets[calendar.component(.hour, from: sample.date), default: []].append(sample.bpm)
        }
        return buckets.keys.sorted().compactMap { hour in
            let values = buckets[hour] ?? []
            guard !values.isEmpty else { return nil }
            let average = values.reduce(0, +) / Double(values.count)
            let heartRateReserve = max(0, (average - restingHeartRate) / (maxHeartRate - restingHeartRate))
            let coveredMinutes = min(60, Double(values.count) * 5)
            return RhythmHourlyPoint(hour: hour, value: heartRateReserve * coveredMinutes)
        }
    }

    /// 步数/活动能量等累计型指标的逐小时值。
    static func hourlyValues(_ quantities: [HourlyQuantity]) -> [RhythmHourlyPoint] {
        quantities.map { RhythmHourlyPoint(hour: $0.hour, value: $0.value) }
    }
}

struct RhythmHourlyPoint: Equatable {
    let hour: Int
    let value: Double
}

enum RhythmGranularity: String, CaseIterable {
    case day
    case hour
}

/// 按小时模式下的日内指标：全部来自 HealthKit 真实样本。
/// 日级得分（恢复/睡眠/负荷…）本质是日粒度，不做小时级伪造。
enum RhythmHourlyMetric: String, CaseIterable, Identifiable {
    case heartRate
    case exertionLoad
    case steps
    case activeEnergy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate: return "心率"
        case .exertionLoad: return "活动强度"
        case .steps: return "步数"
        case .activeEnergy: return "能量消耗"
        }
    }
}

private enum RhythmCurve {
    // MARK: - 按天（等距采样 + 平滑插值）

    static func centerPath(samples: [CGFloat], size: CGSize) -> Path {
        sampledPath(samples: samples, size: size, offset: 0)
    }

    static func bandPath(samples: [CGFloat], width: CGFloat, size: CGSize) -> Path {
        var path = sampledPath(samples: samples, size: size, offset: -width / 2)
        let lower = sampledPoints(samples: samples, size: size, offset: width / 2).reversed()
        for point in lower { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    static func point(at progress: CGFloat, samples: [CGFloat], size: CGSize) -> CGPoint {
        CGPoint(
            x: progress * size.width,
            y: interpolatedY(at: progress, samples: samples) * size.height
        )
    }

    // MARK: - 按小时（真实 x 位置，逐点折线）

    static func path(from xys: [(CGFloat, CGFloat)], size: CGSize) -> Path {
        var path = Path()
        guard let first = xys.first else { return path }
        path.move(to: CGPoint(x: first.0 * size.width, y: first.1 * size.height))
        for xy in xys.dropFirst() {
            path.addLine(to: CGPoint(x: xy.0 * size.width, y: xy.1 * size.height))
        }
        return path
    }

    static func bandPath(from xys: [(CGFloat, CGFloat)], width: CGFloat, size: CGSize) -> Path {
        guard let first = xys.first else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: first.0 * size.width, y: (first.1 - width / 2) * size.height))
        for xy in xys.dropFirst() {
            path.addLine(to: CGPoint(x: xy.0 * size.width, y: (xy.1 - width / 2) * size.height))
        }
        for xy in xys.reversed() {
            path.addLine(to: CGPoint(x: xy.0 * size.width, y: (xy.1 + width / 2) * size.height))
        }
        path.closeSubpath()
        return path
    }

    static func point(nearX fraction: CGFloat, xys: [(CGFloat, CGFloat)], size: CGSize) -> CGPoint {
        guard !xys.isEmpty else { return .zero }
        let nearest = xys.min(by: { abs($0.0 - fraction) < abs($1.0 - fraction) }) ?? xys.last!
        return CGPoint(x: nearest.0 * size.width, y: nearest.1 * size.height)
    }

    private static func sampledPath(samples: [CGFloat], size: CGSize, offset: CGFloat) -> Path {
        let points = sampledPoints(samples: samples, size: size, offset: offset)
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    private static func sampledPoints(samples: [CGFloat], size: CGSize, offset: CGFloat) -> [CGPoint] {
        (0...80).map { index in
            let progress = CGFloat(index) / 80
            return CGPoint(
                x: progress * size.width,
                y: (interpolatedY(at: progress, samples: samples) + offset) * size.height
            )
        }
    }

    private static func interpolatedY(at progress: CGFloat, samples: [CGFloat]) -> CGFloat {
        guard samples.count > 1 else { return samples.first ?? 0.5 }
        let scaled = progress * CGFloat(samples.count - 1)
        let lower = min(samples.count - 2, max(0, Int(floor(scaled))))
        let local = scaled - CGFloat(lower)
        let eased = local * local * (3 - 2 * local)
        return samples[lower] + (samples[lower + 1] - samples[lower]) * eased
    }
}

// MARK: - Rhythm secondary surfaces

struct VelaRhythmActionSequence: View {
    let actions: [TodayExperienceAction]
    let onAction: (TodayExperienceAction) -> Void
    let onEvidence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VelaRhythmSectionHeader(
                eyebrow: "TODAY",
                title: "今天只做这几件事",
                actionTitle: "查看依据",
                action: onEvidence
            )
            .padding(.bottom, 12)

            ForEach(Array(actions.prefix(3).enumerated()), id: \.element.id) { index, action in
                Button { onAction(action) } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(index == 0 ? VelaTheme.rhythmDeep : VelaTheme.rhythmInkSecondary)
                            .padding(.top, 4)

                        Text(action.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.cardPress)

                if index < min(actions.count, 3) - 1 {
                    Divider()
                        .overlay(VelaTheme.rhythmMist)
                        .padding(.leading, 35)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct VelaRhythmSignalLandscape: View {
    let signals: [TodayExperienceSignalCard]
    let onSignal: (TodayExperienceSignalCard) -> Void

    private var ordered: [TodayExperienceSignalCard] {
        ["recovery", "sleep", "strain", "stress", "energy"].compactMap { id in
            signals.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VelaRhythmSectionHeader(
                eyebrow: "SIGNALS",
                title: "身体信号",
                actionTitle: nil,
                action: {}
            )

            VStack(spacing: 12) {
                ForEach(ordered) { signal in
                    Button { onSignal(signal) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(signal.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                Text(signal.subtitle)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 92, alignment: .leading)

                            RhythmSparkline(values: signal.trend, state: signal.state)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)

                            Text(signal.value)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(VelaTheme.rhythmInk)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel("\(signal.title)，\(signal.value)，\(signal.subtitle)")
                }
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(VelaTheme.rhythmMist.opacity(0.85), lineWidth: 0.75)
            }
        }
    }
}

private struct RhythmSparkline: View {
    let values: [Double]
    let state: MetricState

    private var color: Color {
        switch state {
        case .good: VelaTheme.rhythmDeep
        case .moderate: VelaTheme.rhythmWarm
        case .poor: VelaTheme.statePoor
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let points = normalizedPoints(in: proxy.size)
            ZStack {
                Rectangle()
                    .fill(VelaTheme.rhythmMist)
                    .frame(height: 1)
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        // 空数据直接不画（不伪造 sparkline）；单点退化为一点
        let source = values
        guard !source.isEmpty else { return [] }
        let low = source.min() ?? 0
        let high = source.max() ?? 1
        let span = max(8, high - low)
        return source.enumerated().map { index, value in
            let x = source.count == 1 ? size.width : CGFloat(index) / CGFloat(source.count - 1) * size.width
            let normalized = (value - low) / span
            return CGPoint(x: x, y: size.height - CGFloat(normalized) * (size.height - 6) - 3)
        }
    }
}

struct VelaRhythmSectionHeader: View {
    let eyebrow: String
    let title: String
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.35)
                    .foregroundStyle(VelaTheme.rhythmInk)
            }

            Spacer(minLength: 12)

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
        }
    }
}
