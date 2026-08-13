import SwiftUI
import SwiftData
import Combine

// MARK: - VelaTrainingView
// The phone decides and explains. Apple Watch records the training itself.

struct VelaTrainingView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Environment(\.colorScheme) private var cs
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var appState = VelaAppState.shared

    private static let lookbackDays = 90
    private var trainingLookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.lookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    @State private var strengthWorkouts: [StrengthWorkoutRecord] = []
    @State private var localWorkoutEvents: [WorkoutEventRecord] = []
    @State private var workoutTemplates: [WorkoutTemplateRecord] = []
    @State private var trainingPlans: [TrainingPlanRecord] = []
    @State private var operatingPlans: [DailyOperatingPlanRecord] = []
    @State private var trainingResponses: [TrainingResponseRecord] = []

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
            plan: activePlan.dto,
            on: dashboardVM.selectedDate,
            events: localWorkoutEvents.map { $0.dto }
        )
    }
    private var todayDecision: DailyTrainingDecision? {
        todayPlan?.trainingDecision
    }
    private let xunjiKeychainAccount = "xunji_open_api_key"

    @State private var previousMonthActiveTiers: [Int: Int] = [:]
    @State private var currentMonthActiveTiers: [Int: Int] = [:]

    // Dynamic states for statistics & trend graphs
    @State private var totalWorkoutDurationText = "--"
    @State private var summaryPeakStrainText = "--"
    @State private var summaryWorkPathPoints: [CGPoint] = []
    @State private var dynamicExertionWorkload: [Double] = []
    @State private var targetComparison: TrainingTargetComparison = .unavailable
    @State private var recentWorkouts: [WorkoutSummary] = []
    @State private var showStrengthWorkoutLog = false
    @State private var selectedTemplateID: UUID?
    @State private var selectedSessionDraft: TrainingSessionDraft?
    @State private var trainingExecutionMessage: String?
    @State private var templatePendingDeletion: WorkoutTemplateRecord?
    @State private var templateMutationError: String?
    @State private var showXunjiImport = false
    @State private var xunjiImportDate = Date()
    @State private var xunjiAPIKey = ""
    @State private var xunjiIncludeFullData = false
    @State private var isImportingXunji = false
    @State private var xunjiImportMessage: String?
    @State private var isAutoImportingXunji = false
    @State private var selectedAnalyticsTab = 0
    @State private var handledAdaptiveTrainingStartRequest = 0

    var body: some View {
        let strengthSummary = recentStrengthSummary
        let cardioSnapshot = CardioTrainingAnalyzer.analyze(
            workouts: recentWorkouts,
            endingAt: dashboardVM.selectedDate
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                TrainingHeroSection(
                    todaySession: todaySession,
                    todayPlan: todayPlan,
                    activePlan: activePlan,
                    summary: strengthSummary,
                    onDiscussWithCoach: {
                        VelaAppState.shared.routeToCoach(question: trainingAnalysisQuestion)
                    }
                )

                VStack(alignment: .leading, spacing: 34) {
                    if let workout = postWorkoutPromptWorkout {
                        TrainingPostWorkoutPrompt(workout: workout) {
                            appState.routeToPostWorkoutCheckIn(
                                workoutID: strengthWorkout(for: workout)?.id ?? workout.id
                            )
                        }
                    }

                    TrainingMuscleLandscape(summary: strengthSummary)

                    VStack(alignment: .leading, spacing: 14) {
                        VelaRhythmSectionHeader(
                            eyebrow: "ROTATION",
                            title: "计划与轮转",
                            actionTitle: nil,
                            action: {}
                        )

                        NavigationLink {
                            VelaTrainingPlanView()
                        } label: {
                            TrainingPlanPortal(
                                planTitle: activePlan?.title,
                                nextFocus: todaySession?.title,
                                completedDays: activePlan?.days.filter(\.isCompleted).count ?? 0,
                                totalDays: activePlan?.days.count ?? 0
                            )
                        }
                        .buttonStyle(.cardPress)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        VelaRhythmSectionHeader(
                            eyebrow: "TRAINING FACTS",
                            title: "趋势与记录",
                            actionTitle: nil,
                            action: {}
                        )

                        NavigationLink {
                            TrainingDeepAnalysisView(
                                selectedAnalyticsTab: $selectedAnalyticsTab,
                                targetComparison: targetComparison,
                                dynamicExertionWorkload: dynamicExertionWorkload,
                                totalWorkoutDurationText: totalWorkoutDurationText,
                                summaryWorkPathPoints: summaryWorkPathPoints,
                                summaryPeakStrainText: summaryPeakStrainText,
                                selectedDate: dashboardVM.selectedDate,
                                previousMonthActiveTiers: previousMonthActiveTiers,
                                currentMonthActiveTiers: currentMonthActiveTiers,
                                cardioSnapshot: cardioSnapshot,
                                recentWorkouts: recentWorkouts,
                                strengthSummary: strengthSummary,
                                exerciseProgressLines: exerciseProgressLines,
                                strengthWorkout: { workout in self.strengthWorkout(for: workout) }
                            )
                        } label: {
                            TrainingAnalysisPortal(
                                sessions: strengthSummary.sessions,
                                totalDuration: totalWorkoutDurationText,
                                cardioStatus: cardioSnapshot.status?.title ?? (cardioSnapshot.acuteMinutes > 0 ? "已记录" : "待建立")
                            )
                        }
                        .buttonStyle(.cardPress)
                    }
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            fitnessHeader
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.vertical, 10)
                .background(VelaTheme.rhythmCanvas.opacity(0.94))
        }
        .background(VelaTheme.rhythmCanvas)
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            loadRealFitnessData()
            loadXunjiAPIKey()
            consumeAdaptiveTrainingStartIfNeeded()
            try? ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: modelContext)
            await syncRealFitnessData()
            await autoImportRecentXunjiTraining()
        }
        .refreshable {
            await syncRealFitnessData(force: true)
            await autoImportRecentXunjiTraining()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            guard isActiveSurface else { return }
            loadRealFitnessData()
            Task {
                await syncRealFitnessData()
            }
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            guard isActiveSurface else { return }
            loadRealFitnessData()
            Task {
                await syncRealFitnessData()
            }
        }
        .onChange(of: appState.adaptiveTrainingStartRequest) { _, _ in
            consumeAdaptiveTrainingStartIfNeeded()
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
        .confirmationDialog("删除训练模板？", isPresented: Binding(
            get: { templatePendingDeletion != nil },
            set: { if !$0 { templatePendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("删除模板", role: .destructive) {
                if let templatePendingDeletion {
                    deleteTemplate(templatePendingDeletion)
                }
            }
            Button("取消", role: .cancel) { templatePendingDeletion = nil }
        } message: {
            Text("删除后将无法从模板库直接开始这套训练。")
        }
        .alert("无法删除模板", isPresented: Binding(
            get: { templateMutationError != nil },
            set: { if !$0 { templateMutationError = nil } }
        )) {
            Button("好", role: .cancel) { templateMutationError = nil }
        } message: {
            Text(templateMutationError ?? "")
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



    // MARK: - Training Title Header
    private var fitnessHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("训练")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("轮转、边界与训练事实")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    VelaAppState.shared.routeToCoach(question: trainingAnalysisQuestion)
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("让 Coach 分析训练")

                Menu {
                    Button {
                        // Detailed logging is an optional post-workout action. It
                        // should never inherit today's recommendation or block on
                        // an incomplete plan.
                        selectedTemplateID = nil
                        selectedSessionDraft = nil
                        showStrengthWorkoutLog = true
                    } label: {
                        Label("补录动作与组数", systemImage: "square.and.pencil")
                    }

                    Button {
                        xunjiImportDate = dashboardVM.selectedDate
                        xunjiImportMessage = nil
                        showXunjiImport = true
                    } label: {
                        Label("导入训记", systemImage: "tray.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .accessibilityLabel("更多训练操作")
            }
        }
    }

    private var postWorkoutPromptWorkout: WorkoutSummary? {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dashboardVM.selectedDate))
            ?? dashboardVM.selectedDate
        let start = end.addingTimeInterval(-36 * 60 * 60)
        let responseWorkoutIDs = Set(trainingResponses.map(\.workoutId))
        let annotatedWorkoutIDs = Set(localWorkoutEvents.compactMap { event -> UUID? in
            if responseWorkoutIDs.contains(event.id) { return event.id }
            if let strengthID = event.linkedStrengthWorkoutId,
               responseWorkoutIDs.contains(strengthID) {
                return event.id
            }
            return nil
        }).union(responseWorkoutIDs)
        return recentWorkouts.first {
            $0.start >= start && $0.start < end && !annotatedWorkoutIDs.contains($0.id)
        }
    }

    // MARK: - Double-Month Activity Heatmap Card
    // Combined into performanceAnalyticsCard

    // Individual Month Heatmap builder


    private var trainingAnalysisQuestion: String {
        "请结合我过去 30 天的 Apple 健康训练记录、耗力趋势、恢复、睡眠和能量，分析训练状态并给出下一次训练建议。"
    }

    private var recentStrengthSummary: RecentTrainingSummary {
        // Anchor to the browsed date, not real-world "today": otherwise browsing a
        // historical date on the Training page still shows real-today muscle volume,
        // PRs and fatigue.
        TrainingAnalyticsService().buildRecentSummary(
            workouts: strengthWorkouts.map { $0.dto },
            days: 7,
            endingAt: dashboardVM.selectedDate
        )
    }

    private func startStrengthWorkout(templateID: UUID? = nil) {
        if let templateID {
            selectedTemplateID = templateID
            selectedSessionDraft = nil
            showStrengthWorkoutLog = true
            return
        }

        guard let day = todaySession else {
            // A plan is optional. The primary action and the blank-template action
            // must always open the full logger instead of sending users to a dead end.
            selectedTemplateID = nil
            selectedSessionDraft = nil
            showStrengthWorkoutLog = true
            return
        }
        let decision = todayDecision ?? TrainingDecisionFallback.conservative(targetSessionTitle: day.title)
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

    private func consumeAdaptiveTrainingStartIfNeeded() {
        let request = appState.adaptiveTrainingStartRequest
        guard request > handledAdaptiveTrainingStartRequest else { return }
        handledAdaptiveTrainingStartRequest = request
        loadDynamicData()
        // 训练数据来自 Apple 健康:从训练页/今日页发起的「开始训练」改为与 Coach 讨论。
        VelaAppState.shared.routeToCoach(question: trainingAnalysisQuestion)
    }

    private func deleteTemplate(_ template: WorkoutTemplateRecord) {
        modelContext.insert(DeletedWorkoutRecord(id: "template:\(template.title)"))
        modelContext.delete(template)
        do {
            try modelContext.save()
            templatePendingDeletion = nil
            VelaAppState.shared.markLocalDataChanged()
            loadRealFitnessData()
        } catch {
            modelContext.rollback()
            templateMutationError = "模板未删除。请稍后重试。"
        }
    }

    // MARK: - SwiftData and HealthKit loader
    @MainActor
    private func importXunjiTraining() async {
        let datestr = xunjiDateString(xunjiImportDate)
        let key = storedXunjiAPIKey()
        guard !key.isEmpty else {
            xunjiImportMessage = "请先填写训记密钥。"
            return
        }

        isImportingXunji = true
        xunjiImportMessage = "正在读取 \(datestr) 的训记训练..."
        defer { isImportingXunji = false }

        await services.syncCoordinator.run(source: .xunji, force: true) {
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
    }

    @MainActor
    private func autoImportRecentXunjiTraining() async {
        guard !isAutoImportingXunji else { return }
        let key = storedXunjiAPIKey()
        guard !key.isEmpty else { return }

        isAutoImportingXunji = true
        defer { isAutoImportingXunji = false }

        await services.syncCoordinator.run(source: .xunji, force: false) {
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
    }

    @MainActor
    private func xunjiResponseData(
        apiKey: String,
        datestr: String,
        includeFullData: Bool
    ) async throws -> Data {
        var desc = FetchDescriptor<XunjiDailyCacheRecord>(
            predicate: #Predicate<XunjiDailyCacheRecord> { $0.datestr == datestr }
        )
        desc.fetchLimit = 1
        let caches = (try? modelContext.fetch(desc)) ?? []

        if let cache = caches.first, XunjiCachePolicy.shouldReuse(cache, datestr: datestr, includeFullData: includeFullData) {
            return cache.responseData
        }

        let data = try await XunjiTrainingAPIClient().fetchTraining(
            apiKey: apiKey,
            datestr: datestr,
            includeFullData: includeFullData
        )

        if let cache = caches.first {
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

    private func loadRealFitnessData() {
        let calendar = Calendar.current
        let now = dashboardVM.selectedDate
        
        let currentMonthStart = monthStart(for: now)
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? now
        
        let lowerBound = min(previousMonthStart, calendar.date(byAdding: .day, value: -29, to: now) ?? now)
        let upperBound = nextMonthStart
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { record in
                record.date >= lowerBound && record.date < upperBound
            },
            sortBy: [SortDescriptor(\DailyHealthSummaryRecord.date, order: .forward)]
        )
        
        do {
            let allRecords: [DailyHealthSummaryRecord] = try modelContext.fetch(descriptor)
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
                    targetComparison = .unavailable
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
                targetComparison = TrainingTargetComparison.evaluate(
                    strainValues: strains,
                    target: dashboard.strain
                )
            } else {
                useEmptyFitnessDefaults()
            }
            
        } catch {
            useEmptyFitnessDefaults()
        }
        loadDynamicData()
    }

    private func loadDynamicData() {
        let calendar = Calendar.current
        let refDate = dashboardVM.selectedDate
        let startOfDayRef = calendar.startOfDay(for: refDate)
        
        let startLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -Self.lookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let endLimit = calendar.date(byAdding: .day, value: 1, to: startOfDayRef) ?? startOfDayRef
        
        let strengthDesc = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= startLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        self.strengthWorkouts = (try? modelContext.fetch(strengthDesc)) ?? []

        let eventsDesc = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= startLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        self.localWorkoutEvents = (try? modelContext.fetch(eventsDesc)) ?? []

        let templatesDesc = FetchDescriptor<WorkoutTemplateRecord>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        self.workoutTemplates = (try? modelContext.fetch(templatesDesc)) ?? []

        var plansDesc = FetchDescriptor<TrainingPlanRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        plansDesc.fetchLimit = 10
        self.trainingPlans = (try? modelContext.fetch(plansDesc)) ?? []

        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: refDate, calendar: calendar)
        var opPlansDesc = FetchDescriptor<DailyOperatingPlanRecord>(
            predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == dayIdentifier },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        opPlansDesc.fetchLimit = 1
        self.operatingPlans = (try? modelContext.fetch(opPlansDesc)) ?? []

        let responseDesc = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        self.trainingResponses = (try? modelContext.fetch(responseDesc)) ?? []
    }
    
    private func useEmptyFitnessDefaults() {
        previousMonthActiveTiers = [:]
        currentMonthActiveTiers = [:]
        totalWorkoutDurationText = "--"
        summaryPeakStrainText = "--"
        summaryWorkPathPoints = []
        dynamicExertionWorkload = []
        targetComparison = .unavailable
    }
    
    private func monthStart(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }
}

// MARK: - Secondary analysis

private struct TrainingDeepAnalysisView: View {
    @Binding var selectedAnalyticsTab: Int
    let targetComparison: TrainingTargetComparison
    let dynamicExertionWorkload: [Double]
    let totalWorkoutDurationText: String
    let summaryWorkPathPoints: [CGPoint]
    let summaryPeakStrainText: String
    let selectedDate: Date
    let previousMonthActiveTiers: [Int: Int]
    let currentMonthActiveTiers: [Int: Int]
    let cardioSnapshot: CardioTrainingSnapshot
    let recentWorkouts: [WorkoutSummary]
    let strengthSummary: RecentTrainingSummary
    let exerciseProgressLines: [String]
    let strengthWorkout: (WorkoutSummary) -> StrengthWorkoutRecord?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEEP ANALYSIS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Text("训练事实，而不是评分")
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.65)
                        .foregroundStyle(VelaTheme.rhythmInk)
                }
                .padding(.bottom, 6)

                TrainingStatsSection(
                    selectedAnalyticsTab: $selectedAnalyticsTab,
                    targetComparison: targetComparison,
                    dynamicExertionWorkload: dynamicExertionWorkload,
                    totalWorkoutDurationText: totalWorkoutDurationText,
                    summaryWorkPathPoints: summaryWorkPathPoints,
                    summaryPeakStrainText: summaryPeakStrainText,
                    selectedDate: selectedDate,
                    previousMonthActiveTiers: previousMonthActiveTiers,
                    currentMonthActiveTiers: currentMonthActiveTiers
                )

                CardioStatusCard(snapshot: cardioSnapshot)

                MuscleVolumeCard(
                    summary: strengthSummary,
                    exerciseProgressLines: exerciseProgressLines
                )

                RecentWorkoutsSection(
                    recentWorkouts: recentWorkouts,
                    strengthWorkout: strengthWorkout
                )

                VelaHealthSyncNote()
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("深入分析")
        .velaRhythmDetailChrome()
    }
}

// MARK: - Safe-zone workload chart helpers



// MARK: - Preview
#Preview {
    VelaTrainingView()
        .environmentObject(DashboardViewModel())
}
