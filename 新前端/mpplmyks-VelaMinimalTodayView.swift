import SwiftData
import SwiftUI

struct VelaMinimalTodayView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var animatedReadiness: CGFloat = 0
    @State private var animatedSleepRing: CGFloat = 0
    @State private var animatedStrainRing: CGFloat = 0
    @State private var animatedRecoveryRing: CGFloat = 0

    private var plan: DailyPlanRecommendation {
        DailyPlanEngine.recommendation(for: viewModel.dashboard)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.isLoading && !viewModel.dashboard.recovery.hasData {
                loadingState
            } else if viewModel.errorMessage != nil && !viewModel.dashboard.recovery.hasData {
                errorState
            } else {
                content
            }
        }
        .background(VelaTheme.background.ignoresSafeArea())
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
        }
        .onAppear { animateRings() }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xl) {
            dateSyncRow
            heroCard
            stressEnergyRow
            coachInsightCard
            dataCoverageCard
        }
        .padding(.horizontal, VelaTheme.screenPadding)
        .padding(.bottom, 96)
    }

    // MARK: - 1. Date + Sync Indicator Row

    private var dateSyncRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                Text(formattedDate)
                    .font(VelaTheme.pageTitle)
                    .foregroundStyle(VelaTheme.onSurface)
                Text(formattedWeekday)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }

            Spacer()

            HStack(spacing: VelaSpacing.xxs) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2.weight(.semibold))
                Text(syncLabel)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(syncColor)
            .padding(.horizontal, VelaSpacing.xs)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(syncColor.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(syncColor.opacity(0.18), lineWidth: 0.7)
            )
        }
    }

    // MARK: - 2. Hero Status Card

    private var heroCard: some View {
        VStack(alignment: .center, spacing: VelaSpacing.md) {
            readinessRing

            Text(viewModel.dashboard.dailyInsight)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VelaTheme.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            miniRingsRow

            if let limiter = plan.limiter {
                HStack(spacing: VelaSpacing.sm) {
                    GlassChip(
                        text: limiterDetailText(limiter),
                        icon: "exclamationmark.triangle.fill"
                    )
                    GlassChip(
                        text: plan.primaryActionTitle,
                        icon: "arrow.right"
                    )
                }
            } else {
                GlassChip(
                    text: plan.primaryActionTitle,
                    icon: "arrow.right"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .heroCardSurface(accent: heroTint)
        .onTapGesture {
            VelaAppState.shared.routeToCoach(question: plan.coachQuestion)
        }
    }

    private var readinessRing: some View {
        ZStack {
            Circle()
                .stroke(VelaTheme.outline.opacity(0.20), lineWidth: 4)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: animatedReadiness)
                .stroke(
                    VelaTheme.recovery,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .shadow(color: VelaTheme.recovery.opacity(0.18), radius: 10, y: 3)

            VStack(spacing: 0) {
                Text(recoveryScoreText)
                    .font(VelaTheme.heroMetric)
                    .foregroundStyle(VelaTheme.onSurface)
                Text(recoveryBandLabel)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
        }
        .frame(width: 120, height: 120)
    }

    private var miniRingsRow: some View {
        HStack(spacing: VelaSpacing.xl) {
            miniRing(
                progress: animatedSleepRing,
                score: sleepScore,
                color: VelaTheme.sleep,
                label: L10n.t("Sleep", "睡眠")
            )
            miniRing(
                progress: animatedStrainRing,
                score: strainScore,
                color: VelaTheme.strain,
                label: L10n.t("Strain", "负荷")
            )
            miniRing(
                progress: animatedRecoveryRing,
                score: recoveryScore,
                color: VelaTheme.recovery,
                label: L10n.t("Recovery", "恢复")
            )
        }
    }

    private func miniRing(progress: CGFloat, score: Double, color: Color, label: String) -> some View {
        VStack(spacing: VelaSpacing.xxs) {
            ZStack {
                Circle()
                    .stroke(VelaTheme.outline.opacity(0.20), lineWidth: 3)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(score > 0 ? "\(Int(score.rounded()))" : "--")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(VelaTheme.onSurface)
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                }
            }
            .frame(width: 60, height: 60)
        }
    }

    // MARK: - 3. Stress & Energy Row

    private var stressEnergyRow: some View {
        HStack(alignment: .top, spacing: VelaSpacing.sm) {
            stressCard
            energyCard
        }
    }

    private var stressCard: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xs) {
            HStack {
                Text(L10n.t("Stress", "压力"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Spacer()
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.stress)
            }
            if viewModel.dashboard.stress.hasData {
                StressGauge(value: viewModel.dashboard.stress.stressIndex)
            } else {
                noDataIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .compactCardSurface()
    }

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xs) {
            HStack {
                Text(L10n.t("Energy", "能量"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Spacer()
                Image(systemName: "battery.75percent")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.energy)
            }
            if viewModel.dashboard.energy.hasData {
                EnergyGauge(value: viewModel.dashboard.energy.currentEnergy)
            } else {
                noDataIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .compactCardSurface()
    }

    private var noDataIndicator: some View {
        HStack(spacing: VelaSpacing.xxs) {
            Text("—")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(VelaTheme.muted)
            Text(L10n.t("No Data", "无数据"))
                .font(.caption)
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(height: 44)
    }

    // MARK: - 4. Coach Insight Card

    private var coachInsightCard: some View {
        Button {
            VelaAppState.shared.routeToCoach(question: plan.coachQuestion)
        } label: {
            VStack(alignment: .leading, spacing: VelaSpacing.sm) {
                HStack(spacing: VelaSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primary)
                    Text(L10n.t("Coach Insight", "教练洞察"))
                        .font(VelaTheme.cardTitle)
                        .foregroundStyle(VelaTheme.onSurface)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                }

                Text(plan.body)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(VelaSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                    .fill(VelaTheme.primaryContainer.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Data Coverage Card

    private var dataCoverageCard: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.md) {
            HStack {
                Text(L10n.t("Data Confidence", "数据信心"))
                    .font(VelaTheme.cardTitle)
                    .foregroundStyle(VelaTheme.onSurface)
                Spacer()
                VelaConfidenceBadge(confidence: overallConfidence)
            }

            confidenceDotsRow

            VStack(spacing: VelaSpacing.xxs) {
                VelaDataQualityRow(
                    title: L10n.t("Recovery", "恢复"),
                    subtitle: recoverySourceDescription,
                    freshness: recoveryFreshness,
                    qualityLabel: recoveryQualityLabel,
                    tint: VelaTheme.recovery
                )
                VelaDataQualityRow(
                    title: L10n.t("Sleep", "睡眠"),
                    subtitle: sleepSourceDescription,
                    freshness: sleepFreshness,
                    qualityLabel: sleepQualityLabel,
                    tint: VelaTheme.sleep
                )
                VelaDataQualityRow(
                    title: L10n.t("Strain", "负荷"),
                    subtitle: strainSourceDescription,
                    freshness: strainFreshness,
                    qualityLabel: strainQualityLabel,
                    tint: VelaTheme.strain
                )
                VelaDataQualityRow(
                    title: L10n.t("Stress", "压力"),
                    subtitle: stressSourceDescription,
                    freshness: stressFreshness,
                    qualityLabel: stressQualityLabel,
                    tint: VelaTheme.stress
                )
                VelaDataQualityRow(
                    title: L10n.t("Energy", "能量"),
                    subtitle: energySourceDescription,
                    freshness: energyFreshness,
                    qualityLabel: energyQualityLabel,
                    tint: VelaTheme.energy
                )
            }
        }
        .cardSurface()
    }

    private var confidenceDotsRow: some View {
        HStack(spacing: VelaSpacing.xxs) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < confidenceDotCount ? confidenceDotColor : VelaTheme.outline.opacity(0.30))
                    .frame(width: 8, height: 8)
            }
            Text(confidenceLabelText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(VelaTheme.onSurfaceVariant)
                .padding(.leading, VelaSpacing.xxs)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xl) {
            dateSyncRow
            skeletonCard(height: 320)
            HStack(spacing: VelaSpacing.sm) {
                skeletonCard(height: 100)
                skeletonCard(height: 100)
            }
            skeletonCard(height: 120)
            skeletonCard(height: 200)
        }
        .padding(.horizontal, VelaTheme.screenPadding)
        .padding(.bottom, 96)
    }

    private func skeletonCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
            .fill(VelaTheme.outline.opacity(0.30))
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: VelaSpacing.md) {
            Image(systemName: "heart.slash")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(VelaTheme.error)
                .frame(width: 72, height: 72)
                .background(Circle().fill(VelaTheme.error.opacity(0.12)))

            Text(L10n.t("Health Access Required", "需要健康数据访问"))
                .font(.headline)
                .foregroundStyle(VelaTheme.onSurface)
                .multilineTextAlignment(.center)

            Text(L10n.t(
                "Vela needs access to your Apple Health data to work. Enable it in Settings > Privacy > Health > Vela.",
                "Vela 需要访问你的 Apple 健康数据才能工作。请在 设置 > 隐私 > 健康 > Vela 中启用。"
            ))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(
                    L10n.t("Open Health Settings", "打开健康设置"),
                    systemImage: "heart.text.square"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(Capsule(style: .continuous).fill(VelaTheme.primary))
            .buttonStyle(.plain)
            .padding(.horizontal, VelaSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, VelaTheme.screenPadding)
        .padding(.vertical, 120)
    }

    // MARK: - Animation

    private func animateRings() {
        withAnimation(VelaMotion.ringFill) { animatedReadiness = readinessProgress }
        withAnimation(VelaMotion.ringFill.delay(0.15)) { animatedSleepRing = sleepRingProgress }
        withAnimation(VelaMotion.ringFill.delay(0.25)) { animatedStrainRing = strainRingProgress }
        withAnimation(VelaMotion.ringFill.delay(0.35)) { animatedRecoveryRing = recoveryRingProgress }
    }

    // MARK: - Ring Computed Properties

    private var readinessProgress: CGFloat {
        guard viewModel.dashboard.recovery.hasData else { return 0.06 }
        return min(max(CGFloat(viewModel.dashboard.recovery.score / 100), 0.06), 1)
    }

    private var sleepRingProgress: CGFloat {
        guard viewModel.dashboard.sleepScore.hasData, viewModel.dashboard.sleepScore.score > 0 else { return 0 }
        return CGFloat(viewModel.dashboard.sleepScore.score / 100)
    }

    private var strainRingProgress: CGFloat {
        guard viewModel.dashboard.strain.hasData, viewModel.dashboard.strain.score > 0 else { return 0 }
        return CGFloat(viewModel.dashboard.strain.score / 100)
    }

    private var recoveryRingProgress: CGFloat {
        guard viewModel.dashboard.recovery.hasData, viewModel.dashboard.recovery.score > 0 else { return 0 }
        return CGFloat(viewModel.dashboard.recovery.score / 100)
    }

    private var recoveryScoreText: String {
        viewModel.dashboard.recovery.hasData
            ? "\(Int(viewModel.dashboard.recovery.score.rounded()))"
            : "--"
    }

    private var recoveryBandLabel: String {
        guard viewModel.dashboard.recovery.hasData else {
            return AppLanguage.stored.isChinese ? "正在建立基线" : "Building baseline"
        }
        return localizedBand(viewModel.dashboard.recovery.band)
    }

    private var sleepScore: Double {
        viewModel.dashboard.sleepScore.hasData ? viewModel.dashboard.sleepScore.score : 0
    }

    private var strainScore: Double {
        viewModel.dashboard.strain.hasData ? viewModel.dashboard.strain.score : 0
    }

    private var recoveryScore: Double {
        viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : 0
    }

    // MARK: - Hero Tint (Dynamic Glass Tinting Rule)

    private var heroTint: Color {
        if viewModel.dashboard.recovery.hasData, viewModel.dashboard.recovery.score >= 80 {
            return VelaTheme.recovery
        }
        if viewModel.dashboard.strain.hasData, viewModel.dashboard.strain.score >= 80 {
            return VelaTheme.strain
        }
        if viewModel.dashboard.stress.hasData, viewModel.dashboard.stress.stressIndex >= 70 {
            return VelaTheme.stress
        }
        return VelaTheme.primary
    }

    // MARK: - Limiter Detail

    private func limiterDetailText(_ limiter: DailyPlanLimiter) -> String {
        [limiter.title, limiter.detail]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        if AppLanguage.stored.isChinese {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "MMMM d"
        }
        return formatter.string(from: viewModel.selectedDate)
    }

    private var formattedWeekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: viewModel.selectedDate)
    }

    // MARK: - Sync Status

    private var syncLabel: String {
        if viewModel.isLoading {
            return AppLanguage.stored.isChinese ? "同步中..." : "Syncing..."
        }
        if let lastUpdated = viewModel.lastUpdated {
            let interval = Date().timeIntervalSince(lastUpdated)
            if interval < 3600 {
                return AppLanguage.stored.isChinese ? "已同步" : "Synced"
            }
            return AppLanguage.stored.isChinese ? "稍早" : "Earlier"
        }
        return AppLanguage.stored.isChinese ? "等待同步" : "Pending"
    }

    private var syncColor: Color {
        if viewModel.isLoading {
            return VelaTheme.primary
        }
        if let lastUpdated = viewModel.lastUpdated {
            let interval = Date().timeIntervalSince(lastUpdated)
            if interval < 3600 {
                return VelaTheme.recovery
            }
            return VelaTheme.energy
        }
        return VelaTheme.muted
    }

    // MARK: - Data Coverage

    private var overallConfidence: DataConfidence {
        let metrics: [Bool] = [
            viewModel.dashboard.recovery.hasData,
            viewModel.dashboard.sleepScore.hasData,
            viewModel.dashboard.strain.hasData,
            viewModel.dashboard.stress.hasData,
            viewModel.dashboard.energy.hasData
        ]
        let count = metrics.filter { $0 }.count
        if count >= 4 { return .high }
        if count >= 2 { return .medium }
        if count >= 1 { return .low }
        return .unavailable
    }

    private var confidenceDotCount: Int {
        let metrics: [Bool] = [
            viewModel.dashboard.recovery.hasData,
            viewModel.dashboard.sleepScore.hasData,
            viewModel.dashboard.strain.hasData,
            viewModel.dashboard.stress.hasData,
            viewModel.dashboard.energy.hasData
        ]
        return metrics.filter { $0 }.count
    }

    private var confidenceDotColor: Color {
        switch overallConfidence {
        case .high: return VelaTheme.recovery
        case .medium: return VelaTheme.energy
        case .low, .unavailable: return VelaTheme.stress
        }
    }

    private var confidenceLabelText: String {
        switch overallConfidence {
        case .high: return AppLanguage.stored.isChinese ? "高" : "High"
        case .medium: return AppLanguage.stored.isChinese ? "中" : "Medium"
        case .low: return AppLanguage.stored.isChinese ? "低" : "Low"
        case .unavailable: return AppLanguage.stored.isChinese ? "不可用" : "Unavailable"
        }
    }

    private var recoveryFreshness: DataFreshness {
        viewModel.dashboard.recovery.hasData ? .today : .missing
    }

    private var sleepFreshness: DataFreshness {
        viewModel.dashboard.sleepScore.hasData ? .today : .missing
    }

    private var strainFreshness: DataFreshness {
        viewModel.dashboard.strain.hasData ? .today : .missing
    }

    private var stressFreshness: DataFreshness {
        viewModel.dashboard.stress.hasData ? .today : .missing
    }

    private var energyFreshness: DataFreshness {
        viewModel.dashboard.energy.hasData ? .today : .missing
    }

    private var recoverySourceDescription: String {
        viewModel.dashboard.recovery.hasData
            ? "HRV · RHR"
            : (AppLanguage.stored.isChinese ? "无数据" : "No data")
    }

    private var sleepSourceDescription: String {
        viewModel.dashboard.sleepScore.hasData
            ? "\(viewModel.dashboard.sleepSummary.totalSleepMinutes / 60)h \(viewModel.dashboard.sleepSummary.totalSleepMinutes % 60)m"
            : (AppLanguage.stored.isChinese ? "无数据" : "No data")
    }

    private var strainSourceDescription: String {
        viewModel.dashboard.strain.hasData
            ? "\(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)"
            : (AppLanguage.stored.isChinese ? "无数据" : "No data")
    }

    private var stressSourceDescription: String {
        viewModel.dashboard.stress.hasData
            ? (AppLanguage.stored.isChinese ? "生理压力" : "Physiology load")
            : (AppLanguage.stored.isChinese ? "无数据" : "No data")
    }

    private var energySourceDescription: String {
        viewModel.dashboard.energy.hasData
            ? (AppLanguage.stored.isChinese ? "当前能量库" : "Current bank")
            : (AppLanguage.stored.isChinese ? "无数据" : "No data")
    }

    private var recoveryQualityLabel: String {
        viewModel.dashboard.recovery.hasData
            ? "\(Int(viewModel.dashboard.recovery.score.rounded()))"
            : "—"
    }

    private var sleepQualityLabel: String {
        viewModel.dashboard.sleepScore.hasData
            ? "\(Int(viewModel.dashboard.sleepScore.score.rounded()))"
            : "—"
    }

    private var strainQualityLabel: String {
        viewModel.dashboard.strain.hasData
            ? "\(Int(viewModel.dashboard.strain.score.rounded()))"
            : "—"
    }

    private var stressQualityLabel: String {
        viewModel.dashboard.stress.hasData
            ? "\(Int(viewModel.dashboard.stress.stressIndex.rounded()))/100"
            : "—"
    }

    private var energyQualityLabel: String {
        viewModel.dashboard.energy.hasData
            ? "\(Int(viewModel.dashboard.energy.currentEnergy.rounded()))%"
            : "—"
    }
}
