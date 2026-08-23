import SwiftUI

struct CoreMetricHeroFact: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let value: String
    let systemImage: String
}

/// The first viewport for the five canonical scored domains. It preserves the
/// Today grammar while giving each metric its own physical representation:
/// rings for Recovery/Sleep/Strain, a dial for Stress, and reserve bars for
/// Energy. The score remains primary; guidance is one short, tappable line.
struct CoreMetricDetailHero: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let metric: VelaMetricDetailView.MetricType
    let valueText: String
    let score: Double?
    let color: Color
    let state: MetricState
    let guidance: String
    let facts: [CoreMetricHeroFact]
    let baselineValue: Double?
    let targetRange: ClosedRange<Double>?
    let onAskCoach: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 22) {
                    heroVisual
                    factColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 16) {
                    heroVisual
                        .frame(maxWidth: .infinity)
                    factColumn
                }
            }

            Divider()
                .overlay(VelaTheme.rhythmMist)

            Button {
                VelaHaptic.selection()
                onAskCoach()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("指导")
                            .font(VelaTheme.caption1().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Image(systemName: "sparkles")
                            .font(VelaTheme.caption2().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(guidance)
                            .font(VelaTheme.body().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .multilineTextAlignment(.leading)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(metric.accessibleTitle)指导，\(guidance)")
            .accessibilityHint("打开 Coach 继续追问")
        }
        .padding(18)
        .background(VelaTheme.rhythmCanvasRaised)
        .clipShape(RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous)
                .stroke(
                    colorSchemeContrast == .increased
                        ? VelaTheme.rhythmInk
                        : VelaTheme.rhythmMist.opacity(0.82),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.6
                )
        }
    }

    @ViewBuilder
    private var heroVisual: some View {
        switch metric {
        case .recovery, .sleep, .strain:
            CoreMetricScoreRing(
                valueText: valueText,
                score: score,
                color: color,
                baselineValue: baselineValue,
                targetRange: metric == .strain ? targetRange : nil
            )
        case .stress:
            CoreMetricStressDial(score: score, state: state)
        case .energy:
            CoreMetricEnergyReserve(valueText: valueText, score: score, color: color)
        default:
            EmptyView()
        }
    }

    private var factColumn: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(facts) { fact in
                HStack(spacing: 10) {
                    Image(systemName: fact.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                        .frame(width: 26, height: 26)
                        .background(color.opacity(0.10), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(fact.title)
                            .font(VelaTheme.caption2())
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Text(fact.value)
                            .font(VelaTheme.subheadline().weight(.semibold).monospacedDigit())
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CoreMetricScoreRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let valueText: String
    let score: Double?
    let color: Color
    let baselineValue: Double?
    let targetRange: ClosedRange<Double>?

    private var progress: Double {
        min(1, max(0, (score ?? 0) / 100))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(VelaTheme.rhythmCanvasRaised)

            Circle()
                .stroke(color.opacity(0.12), lineWidth: 9)

            if let targetRange {
                Circle()
                    .trim(
                        from: min(1, max(0, targetRange.lowerBound / 100)),
                        to: min(1, max(0, targetRange.upperBound / 100))
                    )
                    .stroke(
                        color.opacity(0.34),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(-7)
            }

            if score != nil {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.70), color], center: .center),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(VelaTheme.dataAnimation(reduceMotion: reduceMotion), value: progress)
            } else {
                Circle()
                    .stroke(
                        VelaTheme.rhythmInkSecondary.opacity(0.34),
                        style: StrokeStyle(lineWidth: 2, dash: [3, 5])
                    )
            }

            if let baselineValue {
                Circle()
                    .fill(VelaTheme.rhythmInkSecondary)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(VelaTheme.rhythmCanvasRaised, lineWidth: 2))
                    .offset(y: -58)
                    .rotationEffect(.degrees(min(100, max(0, baselineValue)) * 3.6))
                    .accessibilityHidden(true)
            }

            Text(valueText)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VelaTheme.rhythmInk)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前值")
        .accessibilityValue(valueText)
    }
}

private struct CoreMetricStressDial: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let score: Double?
    let state: MetricState

    private let tickCount = 36

    private var filledTicks: Int {
        guard let score else { return 0 }
        return Int((min(100, max(0, score)) / 100 * Double(tickCount)).rounded(.up))
    }

    private var stateLabel: String {
        guard score != nil else { return "等待数据" }
        switch state {
        case .good: return "低"
        case .moderate: return "适中"
        case .poor: return "高"
        }
    }

    var body: some View {
        ZStack {
            // One Canvas node draws all 36 ticks (previously 36 individual
            // Capsule views) around the dial.
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                for index in 0..<tickCount {
                    let angle = Angle.degrees(-128 + Double(index) * 256 / Double(tickCount - 1))
                    context.drawLayer { layer in
                        layer.translateBy(x: center.x, y: center.y)
                        layer.rotate(by: angle)
                        let rect = CGRect(x: -1.5, y: -57, width: 3, height: 10)
                        let path = Path(roundedRect: rect, cornerRadius: 1.5)
                        layer.fill(
                            path,
                            with: .color(index < filledTicks ? VelaTheme.color(for: state) : VelaTheme.rhythmMist)
                        )
                    }
                }
            }

            VStack(spacing: 2) {
                Text(score.map { String(Int($0.rounded())) } ?? "--")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(stateLabel)
                    .font(VelaTheme.caption1().weight(.semibold))
                    .foregroundStyle(score == nil ? VelaTheme.rhythmInkSecondary : VelaTheme.textColor(for: state))
            }
            .offset(y: 4)
        }
        .frame(width: 124, height: 124)
        .animation(VelaTheme.dataAnimation(reduceMotion: reduceMotion), value: filledTicks)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前生理压力信号")
        .accessibilityValue(score.map { "\(Int($0.rounded()))，\(stateLabel)" } ?? "暂无数据")
    }
}

private struct CoreMetricEnergyReserve: View {
    let valueText: String
    let score: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color)
                Text(valueText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VelaTheme.rhythmInk)
            }

            SegmentedBatteryBar(
                percentage: min(1, max(0, (score ?? 0) / 100)),
                barCount: 18,
                color: color
            )
            .opacity(score == nil ? 0.45 : 1)
        }
        .padding(16)
        .frame(width: 154, height: 112, alignment: .leading)
        .background(color.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前能量剩余")
        .accessibilityValue(valueText)
    }
}

private extension VelaMetricDetailView.MetricType {
    var accessibleTitle: String {
        switch self {
        case .recovery: return "恢复"
        case .sleep: return "睡眠"
        case .strain: return "负荷"
        case .stress: return "压力"
        case .energy: return "能量"
        default: return rawValue
        }
    }
}

struct MetricCustomWidgetsSection: View {
    let metric: VelaMetricDetailView.MetricType
    let isSleep: Bool
    let dashboard: DashboardSummary
    
    // Sleep parameters
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let wakeHour: Int
    let wakeMinute: Int
    let sleepTargetMinutes: Int
    let hasCompleteSleepTimes: Bool
    
    let bedtimeText: String
    let targetBedtimeText: String
    let wakeTimeText: String
    let primarySleepStartText: String
    
    // Timeline
    let selectedFullDateText: String
    
    // Heart Rate Zones
    let isLoadingHeartRateZones: Bool
    let heartRateZoneSummary: HeartRateZoneSummary?
    let heartRateZoneRowAction: (HeartRateZoneSummary.Zone, Double) -> AnyView
    let limitingFactors: [String]
    let metricColor: Color

    var body: some View {
        switch metric {
        case .recovery:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                Text("恢复基线")
                    .font(VelaTheme.footnote().weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                HStack(spacing: 10) {
                    recoveryBaselineMetric(
                        title: "HRV",
                        current: dashboard.recoveryMetrics.hrvMilliseconds,
                        baseline: dashboard.recoveryBaseline.hrvMilliseconds,
                        unit: "ms",
                        higherIsBetter: true
                    )
                    recoveryBaselineMetric(
                        title: "静息心率",
                        current: dashboard.recoveryMetrics.restingHeartRate,
                        baseline: dashboard.recoveryBaseline.restingHeartRate,
                        unit: "bpm",
                        higherIsBetter: false
                    )
                }

            }

        case .strain:
            // --- Strain Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Timeline
                HStack {
                    Text("时间线")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.rhythmInk)
                    Spacer()
                }
                
                VelaTimelineCard(
                    items: dashboard.workouts.map { workout in
                        VelaTimelineItem(
                            id: workout.id.uuidString,
                            title: workout.activityName,
                            subtitle: VelaMinimalFormatting.duration(
                                minutes: Int(workout.end.timeIntervalSince(workout.start) / 60.0)
                            ),
                            systemImage: "figure.run",
                            domain: .strain
                        )
                    },
                    emptyMessage: "此期间没有记录到活动。"
                )

                // Heart Rate Zones
                VStack(alignment: .leading, spacing: 10) {
                    Text("心率区间")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.rhythmInk)

                    if isLoadingHeartRateZones {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 72)
                    } else if let heartRateZoneSummary {
                        VStack(spacing: 10) {
                            ForEach(heartRateZoneSummary.zones) { zone in
                                heartRateZoneRowAction(zone, heartRateZoneSummary.totalMinutes)
                            }
                        }
                    } else {
                        Text("此期间没有可用的逐点心率，无法生成分区明细。")
                            .font(VelaTheme.caption1())
                            .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )

                strainLoadContext
            }

        case .sleep:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("睡眠节律")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    sleepRhythmSummary
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(VelaTheme.rhythmCanvasRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("睡眠阶段")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    sleepStageSummary
                }
            }

        case .stress:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("压力计算证据")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    stressEvidenceRow("心率", key: "rhr_stress", symbol: "heart.fill")
                    stressEvidenceRow("HRV", key: "hrv_stress", symbol: "waveform.path.ecg")
                    stressEvidenceRow("睡眠债", key: "sleep_debt_stress", symbol: "moon.zzz.fill")
                    stressEvidenceRow("近期负荷", key: "load_stress", symbol: "figure.run")

                    Label("尚无可追溯的连续日内压力采样", systemImage: "clock.badge.questionmark")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .padding(.top, 2)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }

        case .energy:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("能量变化")
                                .font(VelaTheme.footnote().weight(.bold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text("从早间储备到当前状态")
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }
                        Spacer()
                        Text("\(Int(dashboard.energy.morningEnergy.rounded())) → \(dashboard.energy.formattedScore)")
                            .font(VelaTheme.subheadline().weight(.bold).monospacedDigit())
                            .foregroundStyle(metricColor)
                    }

                    energyReserveComparison

                    HStack(spacing: 8) {
                        energyDriver("负荷", value: dashboard.energy.components["strain_drain"])
                        energyDriver("压力", value: dashboard.energy.components["stress_drain"])
                        energyDriver("时间", value: dashboard.energy.components["time_drain"])
                        if let recharge = dashboard.energy.components["recharge"], recharge > 0 {
                            energyDriver("补充", value: recharge, positive: true)
                        }
                    }

                    Text("当前仅显示早间与当前两个可追溯的计算截面。")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }

        default:
            // --- Default Evidence List for other metrics ---
            VStack(alignment: .leading, spacing: 10) {
                Text("主要限制因素")
                    .font(VelaTheme.footnote())
                    .fontWeight(.bold)
                    .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(limitingFactors, id: \.self) { factor in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(metricColor)
                                .frame(width: 6, height: 6)
                            Text(factor)
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(isSleep ? VelaTheme.mistGray : VelaTheme.fg2)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }
        }
    }

    private func recoveryBaselineMetric(
        title: String,
        current: Double?,
        baseline: Double?,
        unit: String,
        higherIsBetter: Bool
    ) -> some View {
        let delta = current.flatMap { value in baseline.map { value - $0 } }
        let isPositive = delta.map { higherIsBetter ? $0 >= 0 : $0 <= 0 }
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
            Text(current.map { "\(Int($0.rounded())) \(unit)" } ?? "--")
                .font(VelaTheme.cardValue())
                .foregroundStyle(VelaTheme.rhythmInk)
                .monospacedDigit()
            Text(baseline.map { "基线 \(Int($0.rounded())) \(unit)" } ?? "个人基线建立中")
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            if let delta, let isPositive {
                Label(
                    "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))",
                    systemImage: isPositive ? "arrow.up.right" : "arrow.down.right"
                )
                .font(VelaTheme.caption2().weight(.semibold))
                .foregroundStyle(isPositive ? VelaTheme.recoveryColor : VelaTheme.warn)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }

    private var sleepRhythmSummary: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                sleepTimeFact("入睡", value: hasCompleteSleepTimes ? bedtimeText : "--", symbol: "moon.fill")

                HStack(spacing: 4) {
                    Circle().fill(VelaTheme.sleepColor).frame(width: 6, height: 6)
                    Rectangle().fill(VelaTheme.sleepColor.opacity(0.22)).frame(height: 2)
                    Image(systemName: "arrow.right")
                        .font(VelaTheme.caption2().weight(.bold))
                        .foregroundStyle(VelaTheme.sleepColor)
                }
                .accessibilityHidden(true)

                sleepTimeFact("起床", value: hasCompleteSleepTimes ? wakeTimeText : "--", symbol: "sun.max.fill")
            }

            Divider().overlay(VelaTheme.rhythmMist)

            ViewThatFits(in: .horizontal) {
                HStack {
                    Label("计划就寝 \(targetBedtimeText)", systemImage: "calendar")
                    Spacer()
                    Text("目标 \(VelaMinimalFormatting.duration(minutes: sleepTargetMinutes))")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("计划就寝 \(targetBedtimeText)", systemImage: "calendar")
                    Text("目标 \(VelaMinimalFormatting.duration(minutes: sleepTargetMinutes))")
                }
            }
            .font(VelaTheme.caption1())
            .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
    }

    private func sleepTimeFact(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(VelaTheme.caption2().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(VelaTheme.title3().monospacedDigit())
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sleepStageSummary: some View {
        let stages = displayedSleepStages
        if stages.isEmpty {
            VelaStateCard(state: .empty, message: "本晚没有可用的睡眠阶段记录。")
        } else {
            VStack(spacing: 11) {
                ForEach(Array(stages.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        Text(sleepStageLabel(item.stage))
                            .font(VelaTheme.caption1().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .frame(width: 46, alignment: .leading)
                        ProgressView(value: Double(item.minutes), total: Double(max(displayedSleepStageTotal, 1)))
                            .tint(sleepStageColor(item.stage))
                            .accessibilityHidden(true)
                        Text("\(item.minutes) 分钟")
                            .font(VelaTheme.caption1().monospacedDigit())
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .frame(width: 58, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            }
        }
    }

    private var displayedSleepStages: [(stage: SleepStage, minutes: Int)] {
        let orderedStages: [SleepStage] = [.awake, .rem, .core, .deep]
        return orderedStages.compactMap { stage -> (stage: SleepStage, minutes: Int)? in
            guard let minutes = dashboard.sleepSummary.stageMinutes[stage], minutes > 0 else { return nil }
            return (stage, minutes)
        }
    }

    private var displayedSleepStageTotal: Int {
        displayedSleepStages.reduce(0) { $0 + $1.minutes }
    }

    private func sleepStageLabel(_ stage: SleepStage) -> String {
        switch stage {
        case .awake: return "清醒"
        case .rem: return "REM"
        case .core: return "核心"
        case .deep: return "深睡"
        case .asleep: return "睡眠"
        case .inBed: return "卧床"
        }
    }

    private func sleepStageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return VelaTheme.energyColor
        case .rem: return VelaTheme.sleepColor.opacity(0.72)
        case .core: return VelaTheme.sleepColor
        case .deep: return VelaTheme.rhythmDeep
        case .asleep, .inBed: return VelaTheme.rhythmInkSecondary
        }
    }

    private var strainLoadContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练节律")
                .font(VelaTheme.footnote().weight(.bold))
                .foregroundStyle(VelaTheme.rhythmInk)
            HStack(spacing: 8) {
                loadFact("7 天负荷", key: "acute_7d_load")
                loadFact("28 天等效", key: "chronic_28d_equivalent")
                loadFact("负荷比", key: "training_load_ratio", suffix: "x")
            }
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
    }

    private func loadFact(_ title: String, key: String, suffix: String = "") -> some View {
        let value = dashboard.strain.components[key]
        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineLimit(2)
            Text(value.map { String(format: "%.1f%@", $0, suffix) } ?? "--")
                .font(VelaTheme.subheadline().weight(.semibold).monospacedDigit())
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func energyDriver(
        _ title: String,
        value: Double?,
        positive: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
            Text(value.map { "\(positive ? "+" : "−")\(String(format: "%.0f", abs($0)))" } ?? "--")
                .font(VelaTheme.caption1().weight(.bold).monospacedDigit())
                .foregroundStyle(positive ? VelaTheme.recoveryColor : VelaTheme.fg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(VelaTheme.rhythmMist.opacity(0.35), in: RoundedRectangle(cornerRadius: VelaTheme.radiusSm, style: .continuous))
    }

    private func stressEvidenceRow(
        _ title: String,
        key: String,
        symbol: String
    ) -> some View {
        let value = dashboard.stress.components[key]
        return HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.stressColor)
                .frame(width: 28, height: 28)
                .background(VelaTheme.stressColor.opacity(0.10), in: Circle())
            Text(title)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.rhythmInk)
            Spacer(minLength: 8)
            Text(value.map { "\(Int($0.rounded()))" } ?? "-- · 未采集")
                .font(VelaTheme.subheadline().weight(.semibold).monospacedDigit())
                .foregroundStyle(value == nil ? VelaTheme.rhythmInkSecondary : VelaTheme.rhythmInk)
        }
        .frame(minHeight: VelaTheme.minimumHitTarget)
    }

    private var energyReserveComparison: some View {
        VStack(spacing: 12) {
            reserveBar(
                title: "早间储备",
                value: dashboard.energy.hasData ? dashboard.energy.morningEnergy : nil
            )
            reserveBar(
                title: "当前剩余",
                value: dashboard.energy.value
            )
        }
        .padding(.vertical, 4)
    }

    private func reserveBar(title: String, value: Double?) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .frame(width: 68, alignment: .leading)
            SegmentedBatteryBar(
                percentage: min(1, max(0, (value ?? 0) / 100)),
                barCount: 20,
                color: VelaTheme.energyColor
            )
            .opacity(value == nil ? 0.35 : 1)
            Text(value.map { "\(Int($0.rounded()))" } ?? "--")
                .font(VelaTheme.caption1().weight(.bold).monospacedDigit())
                .foregroundStyle(VelaTheme.rhythmInk)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
