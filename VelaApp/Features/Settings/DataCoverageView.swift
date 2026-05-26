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
                            title: signal.name,
                            subtitle: signalSubtitle(signal),
                            freshness: signal.freshness,
                            qualityLabel: signal.quality.label,
                            tint: qualityColor(signal.quality)
                        )
                    }
                }

                if group.signals.contains(where: { !$0.isAuthorized }) {
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

    private var legacyOverallScoreCard: some View {
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

    private func legacyCoverageGroupCard(_ group: CoverageGroup) -> some View {
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
                    Image(systemName: signal.quality == .enough ? "checkmark.circle.fill"
                         : signal.quality == .partial ? "circle.dotted"
                         : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(signal.quality == .enough ? VelaTheme.energy
                            : signal.quality == .partial ? VelaTheme.accent
                            : VelaTheme.mutedText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.name)
                            .font(.caption)
                            .foregroundStyle(VelaTheme.primaryText)
                        if signal.isAuthorized, let c7 = signal.sampleCount7d {
                            Text(AppLanguage.stored.isChinese
                                 ? "7天 \(c7) 条 · 质量 \(signal.quality.label)"
                                 : "7d \(c7) samples · \(signal.quality.label)"
                            )
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                        } else if !signal.isAuthorized {
                            Text(AppLanguage.stored.isChinese ? "未授权" : "Not authorized")
                                .font(.caption2)
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                    }
                    Spacer()
                    freshnessBadge(signal.freshness)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.surface))
    }

    // MARK: - Data Loading

    private func loadCoverage() async {
        let store = HKHealthStore()

        var groups: [CoverageGroup] = [
            CoverageGroup(
                id: "recovery",
                title: AppLanguage.stored.isChinese ? "恢复" : "Recovery",
                icon: "heart.fill",
                signals: [
                    CoverageSignal(name: "HRV (SDNN)", kind: .quantity(.heartRateVariabilitySDNN), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "静息心率" : "Resting HR", kind: .quantity(.restingHeartRate), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "呼吸率" : "Respiratory Rate", kind: .quantity(.respiratoryRate), store: store),
                ],
                affectedJudgments: ["Recovery Score", "Autonomic Fatigue", "HRV Z-Score"]
            ),
            CoverageGroup(
                id: "sleep",
                title: AppLanguage.stored.isChinese ? "睡眠" : "Sleep",
                icon: "moon.zzz.fill",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "睡眠分析" : "Sleep Analysis", kind: .category(.sleepAnalysis), isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "腕温" : "Wrist Temperature", kind: .quantity(.appleSleepingWristTemperature), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "血氧" : "Blood Oxygen", kind: .quantity(.oxygenSaturation), store: store),
                ],
                affectedJudgments: ["Sleep Score", "Sleep Architecture", "Sleep Deficit"]
            ),
            CoverageGroup(
                id: "training",
                title: AppLanguage.stored.isChinese ? "训练" : "Training",
                icon: "figure.run",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "运动记录" : "Workouts", kind: .quantity(.activeEnergyBurned), isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "运动心率" : "Workout HR", kind: .quantity(.heartRate), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步数" : "Steps", kind: .quantity(.stepCount), store: store),
                ],
                affectedJudgments: ["Strain Score", "Training Load", "TSB"]
            ),
            CoverageGroup(
                id: "gait",
                title: AppLanguage.stored.isChinese ? "步态与活动" : "Gait & Mobility",
                icon: "figure.walk",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步行速度" : "Walking Speed", kind: .quantity(.walkingSpeed), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "步态不对称" : "Walking Asymmetry", kind: .quantity(.walkingAsymmetryPercentage), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "双支撑比例" : "Double Support", kind: .quantity(.walkingDoubleSupportPercentage), store: store),
                ],
                affectedJudgments: ["Gait Assessment", "Injury Risk", "Muscular Fatigue"]
            ),
            CoverageGroup(
                id: "cardio",
                title: AppLanguage.stored.isChinese ? "心肺" : "Cardio",
                icon: "lungs.fill",
                signals: [
                    CoverageSignal(name: "VO₂ Max", kind: .quantity(.vo2Max), store: store),
                    CoverageSignal(name: "SpO₂", kind: .quantity(.oxygenSaturation), store: store),
                ],
                affectedJudgments: ["Cardio Fitness", "Health Age"]
            ),
            CoverageGroup(
                id: "nutrition",
                title: AppLanguage.stored.isChinese ? "营养" : "Nutrition",
                icon: "fork.knife",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "饮食能量" : "Dietary Energy", kind: .quantity(.dietaryEnergyConsumed), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "水分" : "Water", kind: .quantity(.dietaryWater), store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "咖啡因" : "Caffeine", kind: .quantity(.dietaryCaffeine), store: store),
                ],
                affectedJudgments: ["Nutrition Score", "Hydration Status"]
            ),
            CoverageGroup(
                id: "environment",
                title: AppLanguage.stored.isChinese ? "环境" : "Environment",
                icon: "ear.fill",
                signals: [
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "环境噪音" : "Env. Noise", kind: .quantity(.headphoneAudioExposure), isAvailable: true, store: store),
                    CoverageSignal(name: AppLanguage.stored.isChinese ? "日照时间" : "Daylight", kind: .quantity(.timeInDaylight), store: store),
                ],
                affectedJudgments: ["Sleep Quality", "Circadian Rhythm"]
            ),
        ]

        // Check authorization + sample counts for each signal
        for i in 0..<groups.count {
            for j in groups[i].signals.indices {
                var sig = groups[i].signals[j]
                sig.isAuthorized = await checkAuthorization(sig.kind, store: store)
                sig.isAvailable = sig.isAuthorized
                let (c7, c30) = await fetchSampleCounts(sig.kind, store: store)
                sig.sampleCount7d = c7; sig.sampleCount30d = c30
                if let c = c7, c >= 7 { sig.freshness = .live; sig.quality = .enough }
                else if let c = c7, c >= 3 { sig.freshness = .recent; sig.quality = .partial }
                else if let c = c30, c >= 1 { sig.freshness = .stale; sig.quality = .insufficient }
                else { sig.freshness = .missing; sig.quality = .insufficient }
                if !sig.isAuthorized { sig.freshness = .missing; sig.quality = .insufficient }
                groups[i].signals[j] = sig
            }
        }

        coverageGroups = groups
        isLoading = false
    }

    private func checkAuthorization(_ kind: CoverageSignalKind, store: HKHealthStore) async -> Bool {
        switch kind {
        case .quantity(let id):
            guard let qty = HKQuantityType.quantityType(forIdentifier: id) else { return false }
            return store.authorizationStatus(for: qty) == .sharingAuthorized
        case .category(let id):
            let cat = HKObjectType.categoryType(forIdentifier: id)!
            return store.authorizationStatus(for: cat) == .sharingAuthorized
        }
    }

    private func fetchSampleCounts(_ kind: CoverageSignalKind, store: HKHealthStore) async -> (Int?, Int?) {
        let sampleType: HKSampleType?
        switch kind {
        case .quantity(let id): sampleType = HKQuantityType.quantityType(forIdentifier: id)
        case .category(let id): sampleType = HKObjectType.categoryType(forIdentifier: id)
        }
        guard let st = sampleType else { return (nil, nil) }
        guard store.authorizationStatus(for: st) == .sharingAuthorized else { return (nil, nil) }
        let now = Date()
        let cal = Calendar.current
        let d7 = cal.date(byAdding: .day, value: -7, to: now)!
        let d30 = cal.date(byAdding: .day, value: -30, to: now)!
        let pred7d = HKQuery.predicateForSamples(withStart: d7, end: now, options: .strictStartDate)
        let pred30d = HKQuery.predicateForSamples(withStart: d30, end: now, options: .strictStartDate)
        let count7d = await countSamples(for: st, predicate: pred7d, store: store)
        let count30d = await countSamples(for: st, predicate: pred30d, store: store)
        return (count7d, count30d)
    }

    private func countSamples(for type: HKSampleType, predicate: NSPredicate, store: HKHealthStore) async -> Int? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: 0, sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil, let samples = samples else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: samples.count)
            }
            store.execute(query)
        }
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

    private func signalSubtitle(_ signal: CoverageSignal) -> String {
        if !signal.isAuthorized {
            return AppLanguage.stored.isChinese ? "未授权 · 相关判断置信度会下降" : "Not authorized · related judgments lose confidence"
        }
        let count7 = signal.sampleCount7d.map(String.init) ?? "-"
        let count30 = signal.sampleCount30d.map(String.init) ?? "-"
        return AppLanguage.stored.isChinese
            ? "7天 \(count7) 条 · 30天 \(count30) 条"
            : "7d \(count7) samples · 30d \(count30) samples"
    }

    private func freshnessBadge(_ freshness: DataFreshness) -> some View {
        let label: String; let color: Color
        switch freshness {
        case .live: label = AppLanguage.stored.isChinese ? "实时" : "Live"; color = VelaTheme.energy
        case .today: label = AppLanguage.stored.isChinese ? "今日" : "Today"; color = VelaTheme.accent
        case .recent: label = AppLanguage.stored.isChinese ? "近期" : "Recent"; color = VelaTheme.secondaryText
        case .stale: label = AppLanguage.stored.isChinese ? "陈旧" : "Stale"; color = VelaTheme.strain
        case .missing: label = AppLanguage.stored.isChinese ? "缺失" : "Missing"; color = VelaTheme.mutedText
        }
        return Text(label).font(.caption2.weight(.medium)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.1)))
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

enum CoverageSignalKind {
    case quantity(HKQuantityTypeIdentifier)
    case category(HKCategoryTypeIdentifier)
}

struct CoverageSignal: Identifiable {
    var id: String { name }
    var name: String
    var kind: CoverageSignalKind
    var isAvailable: Bool = false
    var isAuthorized: Bool = false
    var sampleCount7d: Int?
    var sampleCount30d: Int?
    var freshness: DataFreshness = .missing
    var quality: SignalQuality = .insufficient
    var store: HKHealthStore
}

enum SignalQuality: String {
    case enough
    case partial
    case insufficient

    var label: String {
        switch self {
        case .enough: return AppLanguage.stored.isChinese ? "充足" : "Enough"
        case .partial: return AppLanguage.stored.isChinese ? "部分" : "Partial"
        case .insufficient: return AppLanguage.stored.isChinese ? "不足" : "Insufficient"
        }
    }

}
