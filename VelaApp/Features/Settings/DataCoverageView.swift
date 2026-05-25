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
                ProgressView()
                    .tint(VelaTheme.accent)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
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

        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLanguage.stored.isChinese ? "总体数据覆盖" : "Overall Coverage")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(AppLanguage.stored.isChinese
                         ? "\(available)/\(total) 个信号可用"
                         : "\(available)/\(total) signals available"
                    )
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(VelaTheme.elevatedSurface, lineWidth: 6)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100)
                        .stroke(coverageColor(pct), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    Text("\(pct)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.surface))
    }

    // MARK: - Group Card

    private func coverageGroupCard(_ group: CoverageGroup) -> some View {
        let available = group.signals.filter { $0.isAvailable }.count
        let total = group.signals.count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: group.icon)
                    .font(.subheadline)
                    .foregroundStyle(groupColor(group))
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text("\(available)/\(total)")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            ForEach(group.affectedJudgments, id: \.self) { judgment in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.strain)
                    Text(judgment)
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(VelaTheme.elevatedSurface))
            }

            ForEach(group.signals) { signal in
                HStack {
                    Image(systemName: signal.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(signal.isAvailable ? VelaTheme.energy : VelaTheme.mutedText)
                    Text(signal.name)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.primaryText)
                    Spacer()
                    if signal.isAvailable {
                        Text(AppLanguage.stored.isChinese ? "可用" : "Available")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.energy)
                    } else {
                        Text(AppLanguage.stored.isChinese ? "缺失" : "Missing")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.surface))
    }

    // MARK: - Data Loading

    private func loadCoverage() async {
        let store = HKHealthStore()
        let lang = AppLanguage.stored

        var groups: [CoverageGroup] = [
            CoverageGroup(
                id: "recovery",
                title: AppLanguage.stored.isChinese ? "恢复" : "Recovery",
                icon: "heart.fill",
                signals: [
                    CoverageSignal(name: "HRV (SDNN)", type: .heartRateVariabilitySDNN, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "静息心率" : "Resting HR", type: .restingHeartRate, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "呼吸率" : "Respiratory Rate", type: .respiratoryRate, store: store),
                ],
                affectedJudgments: ["Recovery Score", "Autonomic Fatigue", "HRV Z-Score"]
            ),
            CoverageGroup(
                id: "sleep",
                title: AppLanguage.stored.isChinese ? "睡眠" : "Sleep",
                icon: "moon.zzz.fill",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "睡眠时长" : "Sleep Duration", type: .heartRate, isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "睡眠阶段" : "Sleep Stages", type: .heartRate, isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "腕温" : "Wrist Temperature", type: .appleSleepingWristTemperature, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "血氧" : "Blood Oxygen", type: .oxygenSaturation, store: store),
                ],
                affectedJudgments: ["Sleep Score", "Sleep Architecture", "Sleep Deficit"]
            ),
            CoverageGroup(
                id: "training",
                title: AppLanguage.stored.isChinese ? "训练" : "Training",
                icon: "figure.run",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "运动记录" : "Workouts", type: .activeEnergyBurned, isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "运动心率" : "Workout HR", type: .heartRate, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步数" : "Steps", type: .stepCount, store: store),
                ],
                affectedJudgments: ["Strain Score", "Training Load", "TSB"]
            ),
            CoverageGroup(
                id: "gait",
                title: AppLanguage.stored.isChinese ? "步态与活动" : "Gait & Mobility",
                icon: "figure.walk",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步行速度" : "Walking Speed", type: .walkingSpeed, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步态不对称" : "Walking Asymmetry", type: .walkingAsymmetryPercentage, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "双支撑比例" : "Double Support", type: .walkingDoubleSupportPercentage, store: store),
                ],
                affectedJudgments: ["Gait Assessment", "Injury Risk", "Muscular Fatigue"]
            ),
            CoverageGroup(
                id: "cardio",
                title: AppLanguage.stored.isChinese ? "心肺" : "Cardio",
                icon: "lungs.fill",
                signals: [
                    CoverageSignal(name: "VO₂ Max", type: .vo2Max, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "血氧" : "SpO₂", type: .oxygenSaturation, store: store),
                ],
                affectedJudgments: ["Cardio Fitness", "Health Age"]
            ),
            CoverageGroup(
                id: "nutrition",
                title: AppLanguage.stored.isChinese ? "营养" : "Nutrition",
                icon: "fork.knife",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "饮食能量" : "Dietary Energy", type: .dietaryEnergyConsumed, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "水分" : "Water", type: .dietaryWater, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "咖啡因" : "Caffeine", type: .dietaryCaffeine, store: store),
                ],
                affectedJudgments: ["Nutrition Score", "Hydration Status"]
            ),
            CoverageGroup(
                id: "environment",
                title: AppLanguage.stored.isChinese ? "环境" : "Environment",
                icon: "ear.fill",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "环境噪音" : "Env. Noise", type: .headphoneAudioExposure, isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "日照时间" : "Daylight", type: .timeInDaylight, store: store),
                ],
                affectedJudgments: ["Sleep Quality", "Circadian Rhythm"]
            ),
        ]

        // Check availability for each signal
        for i in 0..<groups.count {
            for j in groups[i].signals.indices {
                groups[i].signals[j].isAvailable = await checkAvailability(
                    groups[i].signals[j].type,
                    store: store
                )
            }
        }

        coverageGroups = groups
        isLoading = false
    }

    private func checkAvailability(_ type: HKQuantityTypeIdentifier, store: HKHealthStore) async -> Bool {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: type) else { return false }
        let status = store.authorizationStatus(for: quantityType)
        return status == .sharingAuthorized
    }

    // MARK: - Helpers

    private func coverageColor(_ pct: Int) -> Color {
        if pct >= 80 { return VelaTheme.energy }
        if pct >= 50 { return VelaTheme.accent }
        return VelaTheme.strain
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
    var signals: [CoverageSignal]
    var affectedJudgments: [String]
}

struct CoverageSignal: Identifiable {
    var id: String { name }
    var name: String
    var type: HKQuantityTypeIdentifier
    var isAvailable: Bool = false
    var store: HKHealthStore
}
