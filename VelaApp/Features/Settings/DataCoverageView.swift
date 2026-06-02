import SwiftUI
import HealthKit

/// Shows which Apple Health signals Vela reads, which are missing,
/// and how missing data affects judgment quality.
struct DataCoverageView: View {
    @State private var coverageGroups: [CoverageGroup] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            VelaBackground()

            if isLoading {
                VelaEmptyState(
                    title: AppLanguage.stored.isChinese ? "正在检查数据质量" : "Checking Data Quality",
                    message: AppLanguage.stored.isChinese ? "Vela 正在读取授权状态、新鲜度和样本数量。" : "Vela is reading authorization, freshness, and sample counts.",
                    systemImage: "waveform.path.ecg",
                    tint: VelaTheme.accent
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        overallScoreCard

                        ForEach(coverageGroups) { group in
                            coverageGroupCard(group)
                        }
                    }
                    .padding(VelaTheme.screenPadding)
                }
            }
        }
        .navigationTitle(AppLanguage.stored.isChinese ? "数据覆盖" : "Data Coverage")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadCoverage()
        }
    }

    // MARK: - Overall Score

    private var overallScoreCard: some View {
        let total = coverageGroups.flatMap(\.signals).count
        let available = coverageGroups.flatMap(\.signals).filter { $0.isAvailable }.count
        let pct = total > 0 ? Int(Double(available) / Double(total) * 100) : 0
        let missing = total - available

        return VelaHeroSurface(tint: coverageColor(pct)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(VelaTheme.elevatedSurface, lineWidth: 8)
                            .frame(width: 74, height: 74)
                        Circle()
                            .trim(from: 0, to: CGFloat(pct) / 100)
                            .stroke(coverageColor(pct), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 74, height: 74)
                            .rotationEffect(.degrees(-90))
                        Text("\(pct)%")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .monospacedDigit()
                    }
                    .accessibilityLabel(AppLanguage.stored.isChinese ? "数据覆盖 \(pct)%" : "Data coverage \(pct)%")

                    VStack(alignment: .leading, spacing: 5) {
                        Text(AppLanguage.stored.isChinese ? "今天哪些判断可信？" : "Which judgments are reliable today?")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(AppLanguage.stored.isChinese
                             ? "\(available)/\(total) 个健康信号可用，\(missing) 个需要补齐或授权。"
                             : "\(available)/\(total) health signals are available; \(missing) need data or permission."
                        )
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    VelaMetricPill(
                        title: AppLanguage.stored.isChinese ? "覆盖" : "Coverage",
                        value: "\(pct)%",
                        systemImage: "checkmark.shield.fill",
                        tint: coverageColor(pct)
                    )
                    VelaMetricPill(
                        title: AppLanguage.stored.isChinese ? "缺失" : "Missing",
                        value: "\(missing)",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: missing == 0 ? VelaTheme.recovery : VelaTheme.strain
                    )
                }

                VelaInlineAlert(
                    title: AppLanguage.stored.isChinese ? "影响范围" : "Confidence impact",
                    message: AppLanguage.stored.isChinese
                    ? "缺失或陈旧的数据会降低恢复、睡眠、训练负荷和风险判断的置信度。"
                    : "Missing or stale data lowers confidence for recovery, sleep, training load, and risk judgments.",
                    systemImage: "slider.horizontal.3",
                    tint: coverageColor(pct)
                )
            }
        }
    }

    // MARK: - Group Card

    private func coverageGroupCard(_ group: CoverageGroup) -> some View {
        let available = group.signals.filter { $0.isAvailable }.count
        let total = group.signals.count
        let staleOrMissing = group.signals.filter { $0.freshness == .stale || $0.freshness == .missing }.count
        let pct = total > 0 ? Int(Double(available) / Double(total) * 100) : 0
        let tint = groupColor(group)

        return VelaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: group.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(tint.opacity(0.12)))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(AppLanguage.stored.isChinese
                             ? "\(available)/\(total) 个信号可用 · \(staleOrMissing) 个陈旧或缺失"
                             : "\(available)/\(total) signals available · \(staleOrMissing) stale or missing"
                        )
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                    }

                    Spacer()
                    VelaStatusBadge(
                        label: AppLanguage.stored.isChinese ? "可信度 \(pct)%" : "Trust \(pct)%",
                        systemImage: "checkmark.shield.fill",
                        tint: coverageColor(pct)
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(AppLanguage.stored.isChinese ? "影响的判断" : "Affected judgments")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(group.affectedJudgments, id: \.self) { judgment in
                            VelaStatusBadge(label: judgment, systemImage: "scope", tint: tint)
                        }
                    }
                }

                Divider().overlay(VelaTheme.stroke)

                VStack(spacing: 8) {
                    ForEach(group.signals) { signal in
                        VelaDataQualityRow(
                            title: signal.signal.name,
                            subtitle: signalSubtitle(signal),
                            freshness: signal.freshness,
                            qualityLabel: signal.quality.label,
                            tint: qualityColor(signal.quality)
                        )
                    }
                }

                if group.signals.contains(where: { $0.authorizationState != .authorized }) {
                    VelaInlineAlert(
                        title: AppLanguage.stored.isChinese ? "需要健康权限" : "Health permission needed",
                        message: AppLanguage.stored.isChinese
                        ? "在系统健康权限中打开相关数据类型，可提升 Vela 今天判断的置信度。"
                        : "Enable the related Health data types in system permissions to improve today's confidence.",
                        systemImage: "lock.open.fill",
                        tint: VelaTheme.strain
                    )
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadCoverage() async {
        let service = HealthSignalCoverageService()

        let recoverySigs = [
            await service.fetchCoverage(for: .hrvSDNN),
            await service.fetchCoverage(for: .restingHR),
            await service.fetchCoverage(for: .respiratoryRate)
        ]

        let sleepSigs = [
            await service.fetchCoverage(for: .sleepAnalysis),
            await service.fetchCoverage(for: .wristTemperature),
            await service.fetchCoverage(for: .oxygenSaturation)
        ]

        let trainingSigs = [
            await service.fetchCoverage(for: .workouts),
            await service.fetchCoverage(for: .activeEnergy),
            await service.fetchCoverage(for: .exerciseTime),
            await service.fetchCoverage(for: .stepCount),
            await service.fetchCoverage(for: .workoutHR)
        ]

        let gaitSigs = [
            await service.fetchCoverage(for: .walkingSpeed),
            await service.fetchCoverage(for: .walkingAsymmetry),
            await service.fetchCoverage(for: .doubleSupport)
        ]

        let cardioSigs = [
            await service.fetchCoverage(for: .vo2Max)
        ]

        let nutritionSigs = [
            await service.fetchCoverage(for: .dietaryEnergy),
            await service.fetchCoverage(for: .water),
            await service.fetchCoverage(for: .caffeine)
        ]

        let environmentSigs = [
            await service.fetchCoverage(for: .envNoise),
            await service.fetchCoverage(for: .daylight)
        ]

        coverageGroups = [
            CoverageGroup(
                id: "recovery",
                title: AppLanguage.stored.isChinese ? "恢复" : "Recovery",
                icon: "heart.fill",
                signals: recoverySigs,
                affectedJudgments: ["Recovery Score", "Autonomic Fatigue", "HRV Z-Score"]
            ),
            CoverageGroup(
                id: "sleep",
                title: AppLanguage.stored.isChinese ? "睡眠" : "Sleep",
                icon: "moon.zzz.fill",
                signals: sleepSigs,
                affectedJudgments: ["Sleep Score", "Sleep Architecture", "Sleep Deficit"]
            ),
            CoverageGroup(
                id: "training",
                title: AppLanguage.stored.isChinese ? "训练" : "Training",
                icon: "figure.run",
                signals: trainingSigs,
                affectedJudgments: ["Strain Score", "Training Load", "TSB"]
            ),
            CoverageGroup(
                id: "gait",
                title: AppLanguage.stored.isChinese ? "步态与活动" : "Gait & Mobility",
                icon: "figure.walk",
                signals: gaitSigs,
                affectedJudgments: ["Gait Assessment", "Injury Risk", "Muscular Fatigue"]
            ),
            CoverageGroup(
                id: "cardio",
                title: AppLanguage.stored.isChinese ? "心肺" : "Cardio",
                icon: "lungs.fill",
                signals: cardioSigs,
                affectedJudgments: ["Cardio Fitness", "Health Age"]
            ),
            CoverageGroup(
                id: "nutrition",
                title: AppLanguage.stored.isChinese ? "营养" : "Nutrition",
                icon: "fork.knife",
                signals: nutritionSigs,
                affectedJudgments: ["Nutrition Score", "Hydration Status"]
            ),
            CoverageGroup(
                id: "environment",
                title: AppLanguage.stored.isChinese ? "环境" : "Environment",
                icon: "ear.fill",
                signals: environmentSigs,
                affectedJudgments: ["Sleep Quality", "Circadian Rhythm"]
            )
        ]

        isLoading = false
    }

    // MARK: - Helpers

    private func coverageColor(_ pct: Int) -> Color {
        if pct >= 80 { return VelaTheme.energy }
        if pct >= 50 { return VelaTheme.accent }
        return VelaTheme.strain
    }

    private func qualityColor(_ quality: SignalQuality) -> Color {
        switch quality {
        case .enough: return VelaTheme.energy
        case .partial: return VelaTheme.accent
        case .insufficient: return VelaTheme.strain
        }
    }

    private func signalSubtitle(_ signal: HealthSignalCoverage) -> String {
        if signal.authorizationState != .authorized {
            return AppLanguage.stored.isChinese ? "未授权 · 相关判断置信度会下降" : "Not authorized · related judgments lose confidence"
        }
        return AppLanguage.stored.isChinese
            ? "7天 \(signal.sampleCount7d) 条 · 30天 \(signal.sampleCount30d) 条"
            : "7d \(signal.sampleCount7d) samples · 30d \(signal.sampleCount30d) samples"
    }

    private func groupColor(_ group: CoverageGroup) -> Color {
        switch group.id {
        case "recovery": return VelaTheme.recovery
        case "sleep": return VelaTheme.sleep
        case "training": return VelaTheme.strain
        case "gait": return VelaTheme.accent
        case "cardio": return VelaTheme.energy
        case "nutrition": return VelaTheme.stress
        case "environment": return VelaTheme.secondaryText
        default: return VelaTheme.accent
        }
    }
}

// MARK: - Coverage Data Models

struct CoverageGroup: Identifiable {
    var id: String
    var title: String
    var icon: String
    var signals: [HealthSignalCoverage]
    var affectedJudgments: [String]
}
