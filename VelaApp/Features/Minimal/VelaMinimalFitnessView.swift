import SwiftUI
import SwiftData
import Combine

// MARK: - VelaTrainingView — Bevel Replica Fitness Tab
// Double-Month thinned activity heatmaps × Area workouts summary × Target safe-zone Exertion workload chart

struct VelaTrainingView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var appState = VelaAppState.shared
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse) private var localWorkoutEvents: [WorkoutEventRecord]
    @Query(sort: \WorkoutTemplateRecord.title) private var workoutTemplates: [WorkoutTemplateRecord]
    @Query(sort: \TrainingPlanRecord.updatedAt, order: .reverse) private var trainingPlans: [TrainingPlanRecord]
    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse) private var operatingPlans: [DailyOperatingPlanRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var activePlan: TrainingPlanRecord? {
        trainingPlans.first(where: { $0.isActive })
    }
    private var todayPlan: DailyOperatingPlanRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        return operatingPlans.first(where: { $0.dayIdentifier == identifier })
    }
    private var todaySession: TrainingDay? {
        guard let activePlan else { return nil }
        return TrainingScheduleResolver.resolve(
            plan: activePlan,
            on: dashboardVM.selectedDate,
            events: localWorkoutEvents
        )
    }
    private var todayDecision: DailyTrainingDecision? {
        guard let plan = todayPlan,
              let payloadData = plan.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: payloadData) else {
            return nil
        }
        let reasons = plan.reasonsJSON.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        return DailyTrainingDecision(
            decision: payload.decision,
            targetSessionTitle: payload.targetSessionTitle,
            volumeMultiplier: payload.volumeMultiplier,
            intensityCap: payload.intensityCap,
            reasons: reasons,
            userFacingSummary: payload.summary,
            confidence: plan.confidence,
            source: plan.source ?? "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: plan.safetyNotice ?? "General wellness and training guidance only."
        )
    }
    private let xunjiKeychainAccount = "xunji_open_api_key"

    @State private var previousMonthActiveTiers: [Int: Int] = [:]
    @State private var currentMonthActiveTiers: [Int: Int] = [:]

    // Dynamic states for statistics & trend graphs
    @State private var totalWorkoutDurationText = "--"
    @State private var summaryPeakStrainText = "--"
    @State private var summaryWorkPathPoints: [CGPoint] = []
    @State private var dynamicExertionWorkload: [Double] = []
    @State private var changePercentageText = "--"
    @State private var isExertionBelowTarget: Bool = true
    @State private var recentWorkouts: [WorkoutSummary] = []
    @State private var showStrengthWorkoutLog = false
    @State private var selectedTemplateID: UUID?
    @State private var selectedSessionDraft: TrainingSessionDraft?
    @State private var trainingExecutionMessage: String?
    @State private var showXunjiImport = false
    @State private var xunjiImportDate = Date()
    @State private var xunjiAPIKey = ""
    @State private var xunjiIncludeFullData = false
    @State private var isImportingXunji = false
    @State private var xunjiImportMessage: String?
    @State private var isAutoImportingXunji = false
    @State private var selectedAnalyticsTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Fitness Title Header
                fitnessHeader

                adaptiveCockpitCard

                muscleVolumeCard

                templateLibraryCard

                performanceAnalyticsCard

                recentWorkoutsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            loadRealFitnessData()
            loadXunjiAPIKey()
        }
        .task {
            try? ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: modelContext)
            await syncRealFitnessData()
            await autoImportRecentXunjiTraining()
        }
        .refreshable {
            await syncRealFitnessData(force: true)
            await autoImportRecentXunjiTraining()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            loadRealFitnessData()
            Task {
                await syncRealFitnessData()
            }
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            loadRealFitnessData()
            Task {
                await syncRealFitnessData()
            }
        }
        .sheet(isPresented: $showStrengthWorkoutLog, onDismiss: {
            selectedTemplateID = nil
            selectedSessionDraft = nil
        }) {
            StrengthWorkoutLogSheetView(
                startingTemplateID: selectedTemplateID,
                initialDraft: selectedSessionDraft
            )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .alert("今日训练", isPresented: Binding(
            get: { trainingExecutionMessage != nil },
            set: { if !$0 { trainingExecutionMessage = nil } }
        )) {
            Button("好", role: .cancel) { trainingExecutionMessage = nil }
        } message: {
            Text(trainingExecutionMessage ?? "")
        }
        .sheet(isPresented: $showXunjiImport) {
            XunjiImportSheet(
                apiKey: $xunjiAPIKey,
                selectedDate: $xunjiImportDate,
                includeFullData: $xunjiIncludeFullData,
                isImporting: isImportingXunji,
                message: xunjiImportMessage,
                onImport: {
                    Task { await importXunjiTraining() }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

        private var adaptiveCockpitCard: some View {
        let session = todaySession
        let payload = todayPlan.flatMap { plan -> DailyOperatingPlanPayload? in
            guard let data = plan.payloadJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: data)
        }
        let reasons = todayPlan.flatMap { plan -> [String]? in
            guard let data = plan.reasonsJSON.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        } ?? []
        let shouldTrain = payload.map { $0.decision != .rest } ?? false
        let intensity = payload.map { "RPE \($0.intensityCap)" } ?? "--"
        let confidence = todayPlan?.confidence ?? 0.85

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日智能自适应")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                    Text(session?.title ?? activePlan?.title ?? "自由训练")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                Text(todayPlan?.primaryActionType.uppercased() ?? "READY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(shouldTrain ? VelaTheme.accent : VelaTheme.sleepColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule().fill((shouldTrain ? VelaTheme.accent : VelaTheme.sleepColor).opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(shouldTrain ? "建议训练 · \(intensity)" : "建议恢复或休息")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(shouldTrain ? VelaTheme.accent : VelaTheme.sleepColor)
                
                Text(session?.description ?? payload?.summary ?? "选择模板开始记录；每组完成后自动启动休息计时。")
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.fg2)
                    .lineSpacing(4)
                
                if !reasons.isEmpty {
                    Text(reasons.map { localizedReason($0) }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(3)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))

            HStack(spacing: 10) {
                executionMetric("容量", payload.map { "\(Int(($0.volumeMultiplier * 100).rounded()))%" } ?? "--")
                executionMetric("RPE 上限", payload.map { "\($0.intensityCap)" } ?? "--")
                executionMetric("时长", session.map { "\($0.durationMinutes) 分" } ?? "--")
            }

            if let latest = recentStrengthSummary.lastWorkoutSummary {
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
                    Text("开始今日自适应训练")
                }
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [VelaTheme.accent, Color(hex: "#00C6FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                .shadow(color: VelaTheme.accent.opacity(0.25), radius: 8, y: 3)
            }
            .buttonStyle(.plain)

            HStack {
                Text("\(todayPlan?.source ?? "BodyStateKernel") · \(todayPlan?.safetyNotice ?? "一般建议，不构成医疗诊断。")")
                Spacer()
                Text("置信度 \(Int((confidence * 100).rounded()))%")
            }
            .font(.system(size: 9))
            .foregroundStyle(VelaTheme.muted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }

    private var performanceAnalyticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: selectedAnalyticsTab == 0 ? "bolt.heart.fill" : (selectedAnalyticsTab == 1 ? "chart.bar.fill" : "calendar"))
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                    Text("表现与分析")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                
                Picker("", selection: $selectedAnalyticsTab) {
                    Text("负荷").tag(0)
                    Text("趋势").tag(1)
                    Text("热力").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Divider()

            switch selectedAnalyticsTab {
            case 0:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(changePercentageText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(dynamicExertionWorkload.isEmpty ? "暂无耗力记录" : (isExertionBelowTarget ? "低于目标值" : "高于目标值"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isExertionBelowTarget ? Color(hex: "#4285F4") : Color(hex: "#66BB6A"))
                        }
                        Spacer()
                        NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                            HStack(spacing: 4) {
                                Text("详情")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    SafeZoneWorkloadChartView(workload: dynamicExertionWorkload)
                        .frame(height: 72)
                        .padding(.vertical, 4)
                }
            case 1:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(totalWorkoutDurationText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text("过去 30 天耗力趋势")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer()
                        NavigationLink(destination: FitnessActivitySummaryDetailView()) {
                            HStack(spacing: 4) {
                                Text("分析")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        AreaChartCurveView(points: summaryWorkPathPoints)
                            .frame(height: 100)
                            .padding(.top, 10)
                        
                        Text(summaryPeakStrainText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#BFB9AC"))
                            .offset(y: -4)
                        
                        HStack {
                            Text("30天前")
                            Spacer()
                            Text("15天前")
                            Spacer()
                            Text("今天")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                        .padding(.top, 114)
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        monthHeatmap(
                            monthTitle: monthTitle(for: previousMonthStart),
                            totalDays: dayCount(in: previousMonthStart),
                            startOffset: startOffset(for: previousMonthStart),
                            activeTiers: previousMonthActiveTiers
                        )
                        
                        monthHeatmap(
                            monthTitle: monthTitle(for: currentMonthStart),
                            totalDays: dayCount(in: currentMonthStart),
                            startOffset: startOffset(for: currentMonthStart),
                            activeTiers: currentMonthActiveTiers
                        )
                    }
                    
                    HStack(spacing: 12) {
                        legendItem(color: Color(hex: "#A5D6A7"), label: "1 项活动")
                        legendItem(color: Color(hex: "#66BB6A"), label: "2 项活动")
                        legendItem(color: Color(hex: "#29B6F6"), label: "3+ 活动")
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
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

    // MARK: - Fitness Title Header
    private var fitnessHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("健身")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("过去 30 天")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    VelaAppState.shared.routeToCoach(question: trainingAnalysisQuestion)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("分析")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
                    .shadow(color: Color.black.opacity(0.01), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    xunjiImportDate = dashboardVM.selectedDate
                    xunjiImportMessage = nil
                    showXunjiImport = true
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VelaTheme.muted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    startStrengthWorkout()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(VelaTheme.muted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Double-Month Activity Heatmap Card
    // Combined into performanceAnalyticsCard

    // Individual Month Heatmap builder
    private func monthHeatmap(
        monthTitle: String,
        totalDays: Int,
        startOffset: Int,
        activeTiers: [Int: Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
            
            // Grid Header Days
            HStack(spacing: 5) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                        .frame(width: 16)
                }
            }
            
            // Grid Cells
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(16), spacing: 5), count: 7),
                spacing: 5
            ) {
                // Empty padding offset cells
                ForEach((0..<startOffset).map { "padding-\($0)" }, id: \.self) { _ in
                    Color.clear
                        .frame(width: 16, height: 16)
                }
                
                // Active calendar days
                ForEach(1...totalDays, id: \.self) { day in
                    let tier = activeTiers[day] ?? 0
                    let cellColor: Color = {
                        switch tier {
                        case 1:  return Color(hex: "#C8E6C9") // light green
                        case 2:  return Color(hex: "#81C784") // medium green
                        case 3:  return Color(hex: "#29B6F6") // teal-blue
                        default: return Color(hex: "#ECEFF1") // light grey/off-white
                        }
                    }()
                    
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(cellColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
        }
    }

    // MARK: - Activity Summary Card (活动摘要 with orange filled area curve)
    // Combined into performanceAnalyticsCard

    private var currentMonthStart: Date {
        monthStart(for: dashboardVM.selectedDate)
    }

    private var previousMonthStart: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
    }

    private func monthStart(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func dayCount(in date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 0
    }

    private func startOffset(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    private var trainingAnalysisQuestion: String {
        "请结合我过去 30 天的 Apple 健康训练记录、耗力趋势、恢复、睡眠和能量，分析训练状态并给出下一次训练建议。"
    }

    private var recentStrengthSummary: RecentTrainingSummary {
        TrainingAnalyticsService().buildRecentSummary(workouts: strengthWorkouts, days: 7)
    }

    // Combined into adaptiveCockpitCard

    private var muscleVolumeCard: some View {
        let summary = recentStrengthSummary
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("过去 7 天肌群有效组")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text("\(summary.sessions) 次力量训练")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            if summary.muscleGroupSets.isEmpty {
                Text("完成力量训练后，这里会显示肌群训练量 and 局部疲劳。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.muscleGroupSets.sorted { $0.key < $1.key }, id: \.key) { muscle, sets in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(muscle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                Spacer()
                                Text("\(sets) 组")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(sets >= 18 ? Color(hex: "#FF3B30") : (sets < 6 ? Color(hex: "#4285F4") : Color(hex: "#34C759")))
                            }
                            
                            GeometryReader { geo in
                                let pct = min(CGFloat(sets) / 20.0, 1.0)
                                let barColor = sets >= 18 ? Color(hex: "#FF3B30") : (sets < 6 ? Color(hex: "#4285F4") : Color(hex: "#34C759"))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(VelaTheme.surface)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(barColor)
                                        .frame(width: geo.size.width * pct, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            
            if !summary.recentPRs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("近期 PR")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    Text(summary.recentPRs.prefix(3).map(\.summary).joined(separator: " · "))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
            }
            
            if let latest = summary.lastWorkoutSummary {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.muted)
                    Text("最近一次：\(latest)")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            
            if !exerciseProgressLines.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("常练动作进步")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    ForEach(exerciseProgressLines.prefix(3), id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }

    private var templateLibraryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练模板")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("从常用结构开始记录，每组数据仍可自由调整")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Button {
                    startStrengthWorkout()
                } label: {
                    Label("空白", systemImage: "square.and.pencil")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: "#EAF3FF")))
                }
                .buttonStyle(.plain)
            }

            if workoutTemplates.isEmpty {
                Text("模板库正在准备。打开记录页也可以直接创建自定义模板。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(templateShortcuts) { template in
                            Button {
                                startStrengthWorkout(templateID: template.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack(spacing: 8) {
                                        Image(systemName: templateIcon(for: template))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(VelaTheme.accent)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(Color(hex: "#EAF3FF")))
                                        Spacer()
                                        Text("\(template.estimatedDurationMinutes)′")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(VelaTheme.muted)
                                    }

                                    Text(template.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VelaTheme.fg)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)

                                    Text("\(template.exercises.count) 个动作 · \(template.exercises.reduce(0) { $0 + $1.targetSets }) 组")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VelaTheme.muted)
                                }
                                .frame(width: 132, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(VelaTheme.systemGroupedBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.7)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteTemplate(template)
                                } label: {
                                    Label("删除模板", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(VelaTheme.cardBg))
    }

    private var templateShortcuts: [WorkoutTemplateRecord] {
        workoutTemplates
            .sorted { lhs, rhs in
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (left?, right?):
                    return left > right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return lhs.title < rhs.title
                }
            }
            .prefix(6)
            .map { $0 }
    }

    private func templateIcon(for template: WorkoutTemplateRecord) -> String {
        let title = template.title.lowercased()
        let exerciseNames = template.exercises.map(\.name).joined(separator: " ")
        if title.contains("leg") || exerciseNames.contains("深蹲") || exerciseNames.contains("腿") {
            return "figure.strengthtraining.functional"
        }
        if title.contains("pull") || exerciseNames.contains("划船") || exerciseNames.contains("下拉") {
            return "figure.climbing"
        }
        if title.contains("push") || exerciseNames.contains("卧推") || exerciseNames.contains("推") {
            return "dumbbell.fill"
        }
        return "figure.strengthtraining.traditional"
    }

    private var exerciseProgressLines: [String] {
        let exercises = strengthWorkouts
            .sorted { $0.startedAt > $1.startedAt }
            .flatMap { workout in workout.exercises.map { (workout.startedAt, $0) } }
        let grouped = Dictionary(grouping: exercises, by: { $0.1.name })
        return grouped.compactMap { name, entries in
            guard let latestDate = entries.map(\.0).max() else { return nil }
            let latest = peakEstimatedOneRepMax(entries.filter { $0.0 == latestDate }.map(\.1))
            let prior = peakEstimatedOneRepMax(entries.filter { $0.0 < latestDate }.map(\.1))
            guard latest > 0 else { return nil }
            if prior > 0 {
                return "\(name)：e1RM \(Int(latest.rounded())) kg（\(String(format: "%+.0f", latest - prior)) kg）"
            }
            return "\(name)：e1RM \(Int(latest.rounded())) kg（建立基线）"
        }.sorted()
    }

    private func peakEstimatedOneRepMax(_ exercises: [StrengthExerciseLog]) -> Double {
        exercises.flatMap(\.sets)
            .filter { !($0.isWarmup) && $0.weightKilograms > 0 && $0.repetitions >= 1 && $0.repetitions <= 12 }
            .map { $0.weightKilograms * (1 + Double($0.repetitions) / 30) }
            .max() ?? 0
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text("Apple + 训记自动合并")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }

            if recentWorkouts.isEmpty {
                Text("暂无可读取的训练记录")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            } else {
                ForEach(recentWorkouts.prefix(12)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        workoutRow(workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workoutListIcon(workout.activityName))
                .foregroundStyle(VelaTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
                HStack(spacing: 8) {
                    Text(sourceLabel(for: workout.source))
                    if let kcal = workout.energyKilocalories {
                        Text("\(Int(kcal.rounded())) kcal")
                    }
                    if let hr = workout.averageHeartRate {
                        Text("\(Int(hr.rounded())) bpm")
                    }
                    if let distance = workout.distanceMeters, distance > 0 {
                        Text(distance >= 1_000
                             ? String(format: "%.1f km", distance / 1_000)
                             : "\(Int(distance.rounded())) m")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "#B06A50"))
            }
            Spacer()
            Text("\(Int(workout.end.timeIntervalSince(workout.start) / 60)) 分钟")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
    }

    private var strengthWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("力量训练记录")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("动作、器械、组次与训练容量")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Button {
                    startStrengthWorkout()
                } label: {
                    Label("记录力量", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VelaTheme.cardBg))
                }
                .buttonStyle(.plain)
            }

            if strengthWorkouts.isEmpty {
                Text("尚未记录力量训练。完成一次动作与组次记录后，Coach 就能读取容量历史。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            } else {
                ForEach(strengthWorkouts.prefix(5)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: WorkoutSummary(
                        id: workout.id,
                        start: workout.startedAt,
                        end: workout.startedAt.addingTimeInterval(TimeInterval(workout.durationMinutes * 60)),
                        activityName: workout.title,
                        source: "strengthLog"
                    ))) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 18))
                                .foregroundStyle(VelaTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color(hex: "#EAF3FF")))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text("\(workout.exerciseCount) 个动作 · \(workout.totalSetCount) 组 · \(Int(workout.totalVolumeKilograms.rounded())) kg 容量")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.muted)
                                Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#BFB9AC"))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#BFB9AC"))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startStrengthWorkout(templateID: UUID? = nil) {
        if let templateID {
            selectedTemplateID = templateID
            selectedSessionDraft = nil
            showStrengthWorkoutLog = true
            return
        }

        guard let day = todaySession else {
            trainingExecutionMessage = "所选日期没有可执行的训练计划。你仍可从下方模板开始自由训练。"
            return
        }
        guard let decision = todayDecision else {
            trainingExecutionMessage = "今日训练决策尚未生成，请先刷新 Today 页面。"
            return
        }
        let draft = TrainingSessionDraftBuilder().build(
            day: day,
            decision: decision,
            history: strengthWorkouts,
            scheduledAt: Date()
        )
        switch draft.action {
        case .strength:
            guard !draft.exercises.isEmpty else {
                trainingExecutionMessage = "该力量训练日还没有配置动作，请先在训练计划中补充动作。"
                return
            }
            selectedSessionDraft = draft
            selectedTemplateID = nil
            showStrengthWorkoutLog = true
        case .cardio:
            trainingExecutionMessage = "今天是有氧训练：\(day.description.isEmpty ? "\(day.durationMinutes) 分钟" : day.description)。请使用 Apple Watch 或 Apple 健康记录本次训练。"
        case .flexibility:
            trainingExecutionMessage = "今天是灵活性/活动度训练：\(day.description.isEmpty ? "\(day.durationMinutes) 分钟" : day.description)。"
        case .rest:
            trainingExecutionMessage = "今天是休息日。无需打开力量训练记录。"
        case .unsupported:
            trainingExecutionMessage = "暂不支持直接执行“\(day.focus)”类型的计划日，请在计划中改为力量、有氧、灵活性或休息。"
        }
    }

    private func deleteTemplate(_ template: WorkoutTemplateRecord) {
        modelContext.insert(DeletedWorkoutRecord(id: "template:\(template.title)"))
        modelContext.delete(template)
        try? modelContext.save()
    }

    private func workoutListIcon(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("strength") || lowered.contains("力量") || lowered.contains("weight") {
            return "figure.strengthtraining.traditional"
        }
        if lowered.contains("walk") || lowered.contains("步行") {
            return "figure.walk"
        }
        if lowered.contains("cycle") || lowered.contains("骑行") {
            return "figure.outdoor.cycle"
        }
        if lowered.contains("swim") || lowered.contains("游泳") {
            return "figure.pool.swim"
        }
        return "figure.run"
    }

    // MARK: - SwiftData and HealthKit loader
    @MainActor
    private func importXunjiTraining() async {
        let datestr = xunjiDateString(xunjiImportDate)
        let key = storedXunjiAPIKey()
        guard !key.isEmpty else {
            xunjiImportMessage = "请先填写训记 Open API Key。"
            return
        }

        isImportingXunji = true
        xunjiImportMessage = "正在读取 \(datestr) 的训记训练..."
        defer { isImportingXunji = false }

        do {
            let responseData = try await xunjiResponseData(
                apiKey: key,
                datestr: datestr,
                includeFullData: xunjiIncludeFullData
            )
            let summary = try XunjiTrainingImportService().importResponseData(
                responseData,
                datestr: datestr,
                modelContext: modelContext
            )
            loadRealFitnessData()
            await dashboardVM.refresh(modelContext: modelContext)
            loadRealFitnessData()
            if summary.importedCount == 0, summary.updatedCount == 0 {
                xunjiImportMessage = "没有可导入的训练。"
            } else {
                let titles = summary.importedTitles.prefix(3).joined(separator: "、")
                xunjiImportMessage = "已合并 \(summary.importedCount) 条新训练，更新 \(summary.updatedCount) 条。\(titles.isEmpty ? "" : " \(titles)")"
                VelaAppState.shared.markLocalDataChanged()
            }
        } catch {
            xunjiImportMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func autoImportRecentXunjiTraining() async {
        guard !isAutoImportingXunji else { return }
        let key = storedXunjiAPIKey()
        guard !key.isEmpty else { return }

        isAutoImportingXunji = true
        defer { isAutoImportingXunji = false }

        let calendar = Calendar.current
        var changed = false
        for offset in 0..<3 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let datestr = xunjiDateString(date)
            do {
                let responseData = try await xunjiResponseData(
                    apiKey: key,
                    datestr: datestr,
                    includeFullData: true
                )
                let summary = try XunjiTrainingImportService().importResponseData(
                    responseData,
                    datestr: datestr,
                    modelContext: modelContext
                )
                changed = changed || summary.importedCount > 0 || summary.updatedCount > 0
            } catch {
                continue
            }
        }

        if changed {
            loadRealFitnessData()
            await dashboardVM.refresh(modelContext: modelContext)
            loadRealFitnessData()
            VelaAppState.shared.markLocalDataChanged()
        }
    }

    @MainActor
    private func xunjiResponseData(
        apiKey: String,
        datestr: String,
        includeFullData: Bool
    ) async throws -> Data {
        let caches = try modelContext.fetch(FetchDescriptor<XunjiDailyCacheRecord>())
        if let cache = caches.first(where: { XunjiCachePolicy.shouldReuse($0, datestr: datestr, includeFullData: includeFullData) }) {
            return cache.responseData
        }

        let data = try await XunjiTrainingAPIClient().fetchTraining(
            apiKey: apiKey,
            datestr: datestr,
            includeFullData: includeFullData
        )

        if let cache = caches.first(where: { $0.datestr == datestr }) {
            cache.fetchedAt = Date()
            cache.includeFullData = includeFullData
            cache.responseData = data
        } else {
            modelContext.insert(XunjiDailyCacheRecord(
                datestr: datestr,
                includeFullData: includeFullData,
                responseData: data
            ))
        }
        try modelContext.save()
        return data
    }

    private func xunjiDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    @MainActor
    private func loadXunjiAPIKey() {
        if let saved = try? KeychainService.shared.read(account: xunjiKeychainAccount), !saved.isEmpty {
            xunjiAPIKey = saved
        }
    }

    @MainActor
    private func storedXunjiAPIKey() -> String {
        let typed = xunjiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            try? KeychainService.shared.save(typed, account: xunjiKeychainAccount)
            return typed
        }
        do {
            return try KeychainService.shared.read(account: xunjiKeychainAccount)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }

    private func syncRealFitnessData(force: Bool = false) async {
        await services.syncCoordinator.run(source: .healthKit, force: force) {
            loadRealFitnessData()
            await dashboardVM.refresh(modelContext: modelContext, force: force)
            loadRealFitnessData()
            let healthKit = (try? await services.queryService.recentWorkouts(limit: 30)) ?? []
            let deletedRecords = (try? modelContext.fetch(FetchDescriptor<DeletedWorkoutRecord>())) ?? []
            let blacklistedIDs = Set(deletedRecords.map(\.id))
            let filteredHealthKit = healthKit.filter { !blacklistedIDs.contains($0.id.uuidString) }

            let local = localWorkoutEvents.map {
                WorkoutSummary(
                    id: $0.id,
                    start: $0.startedAt,
                    end: $0.endedAt,
                    activityName: $0.activityType,
                    energyKilocalories: $0.energyKilocalories,
                    averageHeartRate: $0.averageHeartRate,
                    source: $0.source,
                    rpe: $0.rpe
                )
            }
            let localIDs = Set(local.map(\.id))
            let representedHealthKitIDs = Set(localWorkoutEvents.compactMap(\.linkedHealthKitWorkoutId))
            recentWorkouts = (filteredHealthKit.filter { !localIDs.contains($0.id) && !representedHealthKitIDs.contains($0.id) } + local)
                .sorted { $0.start > $1.start }
        }
    }

    private func sourceLabel(for source: String?) -> String {
        switch source {
        case "healthKit+xunji":
            return "Apple + 训记"
        case "xunji":
            return "训记"
        case "strengthLog":
            return "力量"
        case "manual":
            return "手动"
        default:
            return "Apple"
        }
    }

    private func strengthWorkout(for workout: WorkoutSummary) -> StrengthWorkoutRecord? {
        if let event = localWorkoutEvents.first(where: { $0.id == workout.id || $0.linkedHealthKitWorkoutId == workout.id }),
           let strengthId = event.linkedStrengthWorkoutId {
            return strengthWorkouts.first(where: { $0.id == strengthId })
        }
        return strengthWorkouts.first(where: { $0.id == workout.id })
    }

    private func loadRealFitnessData() {
        let calendar = Calendar.current
        let now = dashboardVM.selectedDate
        
        let currentMonthStart = monthStart(for: now)
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? now
        
        let lowerBound = min(previousMonthStart, calendar.date(byAdding: .day, value: -29, to: now) ?? now)
        let upperBound = nextMonthStart
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> {
                $0.date >= lowerBound && $0.date < upperBound
            },
            sortBy: [SortDescriptor(\DailyHealthSummaryRecord.date, order: .forward)]
        )
        
        do {
            let allRecords = try modelContext.fetch(descriptor)
            let records = allRecords.filter { $0.date >= previousMonthStart && $0.date < nextMonthStart }
            
            var apTiers: [Int: Int] = [:]
            var myTiers: [Int: Int] = [:]
            
            for record in records {
                let day = calendar.component(.day, from: record.date)
                
                let count = record.workoutCount ?? 0
                let calories = record.activeCalories ?? 0
                let duration = record.workoutDuration ?? 0
                
                var tier = 0
                if count >= 3 {
                    tier = 3
                } else if count == 2 {
                    tier = 2
                } else if count == 1 {
                    tier = 1
                } else if calories > 400 || duration > 45 {
                    tier = 2
                } else if calories > 150 || duration > 15 {
                    tier = 1
                }
                
                if calendar.isDate(record.date, equalTo: previousMonthStart, toGranularity: .month) {
                    apTiers[day] = tier
                } else if calendar.isDate(record.date, equalTo: currentMonthStart, toGranularity: .month) {
                    myTiers[day] = tier
                }
            }
            
            previousMonthActiveTiers = apTiers
            currentMonthActiveTiers = myTiers
            
            // 2. Fetch past 30 days of records for statistics
            let startDate30 = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            let startOf30 = calendar.startOfDay(for: startDate30)
            let endOf30 = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            
            let records30 = allRecords.filter { $0.date >= startOf30 && $0.date <= endOf30 }
            if !records30.isEmpty {
                // Calculate total duration in minutes
                let totalMin = records30.compactMap { $0.workoutDuration }.reduce(0, +)
                let hours = Int(totalMin) / 60
                let mins = Int(totalMin) % 60
                totalWorkoutDurationText = "\(hours)小时 \(mins)分钟"
                
                // Construct points for summaryWorkPath
                let strains = records30.compactMap(\.strainScore)
                guard !strains.isEmpty else {
                    summaryWorkPathPoints = []
                    dynamicExertionWorkload = []
                    changePercentageText = "--"
                    summaryPeakStrainText = "--"
                    return
                }
                let maxStrain = strains.max() ?? 10.0
                summaryPeakStrainText = "\(Int(maxStrain.rounded()))"
                let minStrain = strains.min() ?? 0.0
                let strainDiff = maxStrain - minStrain
                
                var pts: [CGPoint] = []
                for idx in 0..<records30.count {
                    let x = Double(idx) / Double(max(records30.count - 1, 1))
                    let strain = records30[idx].strainScore ?? minStrain
                    let normalized = strainDiff > 0 ? (strain - minStrain) / strainDiff : 0.5
                    let y = 0.9 - (normalized * 0.78)
                    pts.append(CGPoint(x: x, y: y))
                }
                summaryWorkPathPoints = pts
                
                // Exertion workload (recent 12 records)
                let recent12 = records30.suffix(12)
                let strainRecent = recent12.compactMap(\.strainScore)
                let maxSR = strainRecent.max() ?? 10.0
                let minSR = strainRecent.min() ?? 0.0
                let srDiff = maxSR - minSR
                dynamicExertionWorkload = strainRecent.map { srDiff > 0 ? ($0 - minSR) / srDiff : 0.5 }
                
                // Target exertion zone comparison
                let avgStrain = strains.reduce(0, +) / Double(strains.count)
                let target = Double(dashboard.strain.recommendedRange.lowerBound + dashboard.strain.recommendedRange.upperBound) / 2
                let percentDiff = target > 0 ? Int((avgStrain - target) / target * 100.0) : 0
                if percentDiff >= 0 {
                    changePercentageText = "+\(percentDiff)%"
                    isExertionBelowTarget = false
                } else {
                    changePercentageText = "\(percentDiff)%"
                    isExertionBelowTarget = true
                }
            } else {
                useEmptyFitnessDefaults()
            }
            
        } catch {
            useEmptyFitnessDefaults()
        }
    }
    
    private func useEmptyFitnessDefaults() {
        previousMonthActiveTiers = [:]
        currentMonthActiveTiers = [:]
        totalWorkoutDurationText = "--"
        summaryPeakStrainText = "--"
        summaryWorkPathPoints = []
        dynamicExertionWorkload = []
        changePercentageText = "--"
        isExertionBelowTarget = true
    }
}

// MARK: - Safe-zone workload chart helpers
struct SafeZoneWorkloadChartView: View {
    let workload: [Double]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Green-tinged horizontal safe-zone band
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#E8F5E9").opacity(0.8))
                    .frame(height: geo.size.height * 0.45)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Colored workload line
                Path { path in
                    guard workload.count > 1 else { return }
                    let stepX = geo.size.width / CGFloat(workload.count - 1)
                    for idx in 0..<workload.count {
                        let x = CGFloat(idx) * stepX
                        let y = geo.size.height - (CGFloat(workload[idx]) * (geo.size.height - 8) + 4)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#81C784"), Color(hex: "#FFB74D"), Color(hex: "#64B5F6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                
                // Highlighting end node dot
                if let lastVal = workload.last {
                    let x = geo.size.width
                    let y = geo.size.height - (CGFloat(lastVal) * (geo.size.height - 8) + 4)
                    Circle()
                        .fill(Color(hex: "#4285F4"))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .position(x: x, y: y)
                }
            }
        }
    }
}

private struct XunjiImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var apiKey: String
    @Binding var selectedDate: Date
    @Binding var includeFullData: Bool
    var isImporting: Bool
    var message: String?
    var onImport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("训记训练导入", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("读取指定日期的训记训练，并合并到 Vela 的力量训练、统一训练记录和训练负荷中。")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    VStack(alignment: .leading, spacing: 12) {
                        DatePicker("训练日期", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        SecureField("训记 Open API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Toggle("读取完整组数据", isOn: $includeFullData)
                            .font(.system(size: 13, weight: .semibold))
                        Text("完整模式会保留未完成组、RPE、备注、超级组和部分记录型动作摘要。90 秒内同一天会复用本地缓存。")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    if let message {
                        Text(message)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
                    }

                    Button {
                        onImport()
                    } label: {
                        HStack {
                            if isImporting {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(isImporting ? "正在导入" : "导入并合并训练")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.white)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.fg))
                    }
                    .disabled(isImporting)
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("导入训记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VelaTrainingView()
        .environmentObject(DashboardViewModel())
}
