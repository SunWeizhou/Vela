import Charts
import SwiftUI
import SwiftData

struct ImpactMatrixPoint: Identifiable, Hashable {
    var id: String
    var habit: String
    var outcome: String
    var magnitude: Double
    var signedCorrelation: Double
    var sampleSize: Int
    var lagDays: Int
    var confidence: MetricConfidence
}

enum ImpactMatrixBuilder {
    static func build(_ insights: [HabitCorrelationInsight]) -> [ImpactMatrixPoint] {
        insights
            .filter { $0.sampleSize > 0 && $0.correlation.isFinite }
            .map {
                ImpactMatrixPoint(
                    id: $0.id,
                    habit: $0.habit,
                    outcome: $0.outcome,
                    magnitude: abs($0.correlation),
                    signedCorrelation: $0.correlation,
                    sampleSize: $0.sampleSize,
                    lagDays: $0.lagDays,
                    confidence: $0.confidence
                )
            }
            .sorted {
                if $0.magnitude == $1.magnitude { return $0.sampleSize > $1.sampleSize }
                return $0.magnitude > $1.magnitude
            }
    }
}

struct JournalCorrelationSection: View {
    let bodyModelState: BodyModelState
    let insights: [HabitCorrelationInsight]

    private var matrixPoints: [ImpactMatrixPoint] {
        ImpactMatrixBuilder.build(insights)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行为信号与待验证区域")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.muted)

            impactMatrix

            if bodyModelState.maturity.overall == .seed || bodyModelState.uncertainAreas.contains(where: { $0.id == "behavior_pairs" }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.muted)
                    Text("行为-结果配对仍在积累")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                    Text("继续用「随手记」记录酒精、咖啡因、晚餐时间、吃撑、补水等低摩擦信号。Vela 会先积累样本，再把它们和次日睡眠、HRV、RHR、恢复进行配对。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    bodyModelStatsRow(bodyModelState)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            } else {
                VStack(spacing: 12) {
                    bodyModelStatsRow(bodyModelState)
                    ForEach(bodyModelState.claims) { claim in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(claim.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(claim.summary)
                                .font(.system(size: 12))
                                .foregroundStyle(VelaTheme.muted)
                                .lineSpacing(3)
                            Text("置信度 \(displayConfidence(claim.confidence.rawValue)) · n=\(claim.evidenceCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(confidenceColor(claim.confidence))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var impactMatrix: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Impact Matrix")
                        .font(.system(size: 15, weight: .bold))
                    Text("关联强度 × 真实配对样本")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Image(systemName: "circle.grid.cross")
                    .foregroundStyle(VelaTheme.accent)
            }

            if matrixPoints.isEmpty {
                VelaStateCard(
                    state: .partial,
                    title: "矩阵仍在积累",
                    message: "至少记录 28 天行为与健康结果，并保留足够记录日和对照日后，才会显示关联点。"
                )
            } else {
                Chart(matrixPoints) { point in
                    PointMark(
                        x: .value("关联强度", point.magnitude),
                        y: .value("配对样本", point.sampleSize)
                    )
                    .symbolSize(72)
                    .foregroundStyle(point.signedCorrelation >= 0 ? VelaTheme.success : VelaTheme.warn)
                    .annotation(position: .top, spacing: 4) {
                        Text(point.habit)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg2)
                            .lineLimit(1)
                    }
                }
                .chartXScale(domain: 0...1)
                .chartXAxisLabel("关联强度 |ρ|")
                .chartYAxisLabel("真实配对 n")
                .frame(height: 190)

                HStack(spacing: 14) {
                    Label("正相关", systemImage: "circle.fill")
                        .foregroundStyle(VelaTheme.success)
                    Label("负相关", systemImage: "circle.fill")
                        .foregroundStyle(VelaTheme.warn)
                    Spacer()
                    Text("仅探索性证据")
                        .foregroundStyle(VelaTheme.muted)
                }
                .font(.system(size: 10, weight: .semibold))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }

    private func bodyModelStatsRow(_ state: BodyModelState) -> some View {
        HStack(spacing: 8) {
            detailStat("基线", "\(state.maturity.baselineDays)天")
            detailStat("行为", "\(state.maturity.behaviorPairs)条")
            detailStat("训练", "\(state.maturity.trainingSessions)次")
        }
        .padding(.horizontal, 12)
    }

    private func detailStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
    }

    private func confidenceColor(_ conf: DataConfidence) -> Color {
        switch conf {
        case .high: return VelaTheme.success
        case .medium: return VelaTheme.accent
        case .low: return VelaTheme.systemOrange
        case .unavailable: return VelaTheme.muted
        }
    }

    private func displayConfidence(_ conf: String) -> String {
        switch conf.lowercased() {
        case "high": return L10n.t("High", "高")
        case "medium": return L10n.t("Medium", "中")
        case "low": return L10n.t("Low", "低")
        case "unavailable": return L10n.t("Unavailable", "不可用")
        default: return conf
        }
    }
}

struct PersonalExperimentCard: View {
    let experiment: PersonalExperimentRecord?
    let checkIns: [ExperimentCheckInRecord]
    let onTap: () -> Void

    private var todayCheckIn: ExperimentCheckInRecord? {
        guard let experiment else { return nil }
        return checkIns.first {
            $0.experimentID == experiment.id && Calendar.current.isDateInToday($0.date)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: experiment == nil ? "flask.fill" : "moon.stars.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: "#6657C8")))

                VStack(alignment: .leading, spacing: 4) {
                    Text(experiment?.title ?? "开始一个个人实验")
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(cardSubtitle)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                if todayCheckIn != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VelaTheme.success)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(experiment == nil ? "开始个人实验" : "查看个人实验")
    }

    private var cardSubtitle: String {
        guard let experiment else {
            return "用 14 天验证咖啡因、晚餐、酒精或睡眠窗口对你的真实影响"
        }
        if todayCheckIn != nil { return "今天已打卡 · 继续保持单一变量" }
        let elapsed = max(1, Calendar.current.dateComponents([.day], from: experiment.startDate, to: Date()).day.map { $0 + 1 } ?? 1)
        let total = max(1, Calendar.current.dateComponents([.day], from: experiment.startDate, to: experiment.endDate).day ?? 14)
        return "第 \(min(elapsed, total)) / \(total) 天 · 今天还未打卡"
    }
}

struct PersonalExperimentHubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let activeExperiment: PersonalExperimentRecord?
    let latestExperiment: PersonalExperimentRecord?
    let checkIns: [ExperimentCheckInRecord]
    let healthSummaries: [DailyHealthSummaryRecord]
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let activeExperiment {
                        activeExperimentContent(activeExperiment)
                    } else {
                        experimentPickerContent
                        if let latestExperiment {
                            previousOutcomeContent(latestExperiment)
                        }
                    }

                    if !errorMessage.isEmpty {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(VelaTheme.warn)
                    }
                }
                .padding(20)
            }
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("个人实验")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func activeExperimentContent(_ experiment: PersonalExperimentRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("进行中", systemImage: "flask.fill")
                .font(VelaTheme.caption1().weight(.bold))
                .foregroundStyle(VelaTheme.accent)
            Text(experiment.title)
                .font(VelaTheme.title2())
            Text(experiment.hypothesis)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg2)
            Text(experiment.protocolText)
                .font(VelaTheme.subheadline().weight(.semibold))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(VelaTheme.cardBg))
        }

        let today = checkIns.first { $0.experimentID == experiment.id && Calendar.current.isDateInToday($0.date) }
        VStack(alignment: .leading, spacing: 12) {
            Text("今天执行了吗？")
                .font(VelaTheme.headline())
            if let today {
                Label(today.followedProtocol ? "已完成今天的方案" : "已记录今天未完成", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(today.followedProtocol ? VelaTheme.success : VelaTheme.warn)
            } else {
                HStack(spacing: 10) {
                    checkInButton("完成了", followed: true, experiment: experiment, color: VelaTheme.success)
                    checkInButton("今天没有", followed: false, experiment: experiment, color: VelaTheme.warn)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))

        previousOutcomeContent(experiment)
    }

    private var experimentPickerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("一次只改变一个变量")
                    .font(VelaTheme.title2())
                Text("先使用已有 7 天作为基线，再连续执行 14 天。Vela 会比较睡眠分变化，但不会把相关变化表述为医学因果。")
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.muted)
            }

            ForEach(PersonalExperimentService.templates) { template in
                Button {
                    do {
                        _ = try PersonalExperimentService().start(template: template, modelContext: modelContext)
                        dismiss()
                    } catch {
                        errorMessage = "无法开始实验：\(error.localizedDescription)"
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(template.title)
                                .font(VelaTheme.headline())
                                .foregroundStyle(VelaTheme.fg)
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(VelaTheme.accent)
                        }
                        Text(template.hypothesis)
                            .font(VelaTheme.caption1())
                            .foregroundStyle(VelaTheme.muted)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func previousOutcomeContent(_ experiment: PersonalExperimentRecord) -> some View {
        let outcome = PersonalExperimentService().outcome(
            experiment: experiment,
            summaries: healthSummaries,
            checkIns: checkIns
        )
        return VStack(alignment: .leading, spacing: 10) {
            Text("当前证据")
                .font(VelaTheme.headline())
            HStack(spacing: 10) {
                experimentStat("基线", outcome.baselineAverage.map { String(format: "%.0f", $0) } ?? "--", "n=\(outcome.baselineSampleCount)")
                experimentStat("实验期", outcome.experimentAverage.map { String(format: "%.0f", $0) } ?? "--", "n=\(outcome.experimentSampleCount)")
                experimentStat("执行率", outcome.adherenceRate.formatted(.percent.precision(.fractionLength(0))), "按日打卡")
            }
            Text(outcome.hasEnoughEvidence ? resultSentence(outcome) : "仍在积累样本：至少需要 3 个基线夜晚和 5 个实验夜晚，才展示方向性比较。")
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
    }

    private func checkInButton(_ title: String, followed: Bool, experiment: PersonalExperimentRecord, color: Color) -> some View {
        Button {
            do {
                try PersonalExperimentService().checkIn(
                    experiment: experiment,
                    followed: followed,
                    modelContext: modelContext
                )
                dismiss()
            } catch {
                errorMessage = "打卡未保存：\(error.localizedDescription)"
            }
        } label: {
            Text(title)
                .font(VelaTheme.subheadline().weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(color))
        }
        .buttonStyle(.plain)
    }

    private func experimentStat(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(VelaTheme.title3()).monospacedDigit()
            Text(title).font(VelaTheme.caption1().weight(.semibold))
            Text(detail).font(VelaTheme.caption2()).foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultSentence(_ outcome: PersonalExperimentOutcome) -> String {
        guard let delta = outcome.delta else { return "暂无可比较结果。" }
        if abs(delta) < 2 {
            return "目前睡眠分与基线接近（\(String(format: "%+.1f", delta))）。这是方向性观察，不代表因果。"
        }
        return "目前实验期睡眠分较基线 \(delta > 0 ? "提高" : "降低") \(String(format: "%.1f", abs(delta))) 分。这是方向性观察，不代表因果。"
    }
}
