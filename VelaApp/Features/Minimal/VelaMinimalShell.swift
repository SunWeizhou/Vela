import SwiftUI
import SwiftData
import UIKit

enum VelaNavigationVisibility {
    static func shouldShowBottomBar(keyboardVisible: Bool) -> Bool {
        !keyboardVisible
    }
}

enum VelaNavigationMotion {
    static let destinationFadeDuration = 0.16
}

// MARK: - VelaScrollTracking
// Kept for child view compatibility. Without binding injection these are no-ops.

enum VelaScrollDirection { case up, down, idle }

private struct VelaScrollDirectionKey: EnvironmentKey {
    static let defaultValue: Binding<VelaScrollDirection> = .constant(.idle)
}

extension EnvironmentValues {
    var velaScrollDirection: Binding<VelaScrollDirection> {
        get { self[VelaScrollDirectionKey.self] }
        set { self[VelaScrollDirectionKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func velaTrackScroll(direction: Binding<VelaScrollDirection>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldY, newY in
                let delta = newY - oldY
                if abs(delta) > 3 {
                    direction.wrappedValue = delta > 0 ? .down : .up
                }
            }
        } else {
            self
        }
    }
}

// MARK: - VelaShell — Native iOS 26 Navigation with Legacy Fallback
//
// iOS 26 uses the system Liquid Glass tab bar and its native scroll minimization.
// Earlier releases keep the custom floating glass navigation.

struct VelaShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var services: VelaServices

    @State private var showPlusSheet = false
    @State private var showCoach     = false
    @State private var showSettings  = false
    @State private var keyboardVisible = false

    @ObservedObject private var appState = VelaAppState.shared
    @Namespace private var tabAnimation

    // MARK: - Tab Enum

    enum VelaTab: Int, CaseIterable, Hashable {
        case today = 0
        case training = 1
        case insights = 2
        case coach = 3
        case me = 4
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            navigationSurface
        }
        .onReceive(appState.$showCoachHub) { show in
            if show {
                showPlusSheet = false
                showCoach = true
                appState.showCoachHub = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(VelaTheme.snappy) {
                keyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(VelaTheme.snappy) {
                keyboardVisible = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            services.coachChat.handleAppActiveChange(isActive: phase == .active)
        }
        .sheet(isPresented: $showPlusSheet, onDismiss: appState.runDeferredQuickAction) {
            PlusActionSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .fullScreenCover(isPresented: $showCoach) {
            VelaCoachView(presentation: .quickCover, vm: services.coachChat)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { VelaSettingsView() }
        }
        .sheet(isPresented: $appState.triggerWeightLog, onDismiss: appState.markLocalDataChanged) {
            WeightLogSheetView()
        }
        .sheet(isPresented: $appState.triggerBloodLog, onDismiss: appState.markLocalDataChanged) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.triggerWorkoutLog, onDismiss: appState.markLocalDataChanged) {
            WorkoutLogSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerFoodSearch, onDismiss: appState.markLocalDataChanged) {
            FoodSearchSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerFoodScanner, onDismiss: appState.markLocalDataChanged) {
            FoodScannerView(type: appState.scannerType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerJournal, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                VelaJournalView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerRecoveryDetail) {
            NavigationStack {
                VelaMetricDetailView(metric: .recovery)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerPostWorkoutCheckIn, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                PostWorkoutCheckInSheet(workoutID: appState.postWorkoutCheckInWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerPostWorkoutImpact) {
            NavigationStack {
                PostWorkoutImpactSheet(workoutID: appState.postWorkoutImpactWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .tint(VelaTheme.accent)
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
    }

    @ViewBuilder
    private var navigationSurface: some View {
        if #available(iOS 26.0, *) {
            nativeTabNavigation
        } else {
            legacyFloatingNavigation
        }
    }

    @available(iOS 26.0, *)
    private var nativeTabNavigation: some View {
        TabView(selection: $appState.selectedTab) {
            nativeTabSurface(.today) {
                VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
            }
            .tabItem {
                Label(label(for: .today), systemImage: iconName(for: .today))
            }
            .tag(0)

            nativeTabSurface(.training) {
                VelaTrainingView()
            }
            .tabItem {
                Label(label(for: .training), systemImage: iconName(for: .training))
            }
            .tag(1)

            nativeTabSurface(.insights) {
                VelaVitalsView()
            }
            .tabItem {
                Label(label(for: .insights), systemImage: iconName(for: .insights))
            }
            .tag(2)

            nativeTabSurface(.coach) {
                VelaCoachView(presentation: .embedded, vm: services.coachChat)
            }
            .tabItem {
                Label(label(for: .coach), systemImage: iconName(for: .coach))
            }
            .tag(3)

            nativeTabSurface(.me) {
                NavigationStack {
                    VelaMeView()
                }
            }
            .tabItem {
                Label(label(for: .me), systemImage: iconName(for: .me))
            }
            .tag(4)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbar(keyboardVisible ? .hidden : .visible, for: .tabBar)
    }

    private var legacyFloatingNavigation: some View {
        ZStack(alignment: .bottom) {
            VelaTheme.systemGroupedBackground.ignoresSafeArea()

            // Keep legacy primary surfaces mounted so cached SwiftData content
            // is already hydrated when the user switches tabs.
            ZStack {
                tabSurface(.today) {
                    VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
                }
                tabSurface(.training) {
                    VelaTrainingView()
                }
                tabSurface(.insights) {
                    VelaVitalsView()
                }
                tabSurface(.coach) {
                    VelaCoachView(
                        presentation: .embedded,
                        usesOverlayNavigation: true,
                        vm: services.coachChat
                    )
                }
                tabSurface(.me) {
                    NavigationStack {
                        VelaMeView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .bottom)

            if VelaNavigationVisibility.shouldShowBottomBar(keyboardVisible: keyboardVisible) {
                bottomGlassNavBar
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Legacy Floating Glass Navigation
    
    private var bottomGlassNavBar: some View {
        HStack(spacing: 0) {
            ForEach(VelaTabSelection.contentTabs, id: \.self) { tab in
                customTabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(VelaTheme.cardBg.opacity(0.12))
                .velaInteractiveGlass(in: Capsule())
        )
        .overlay(
            Capsule()
                .stroke(VelaTheme.cardBg.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.018), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Individual Tab Button with Premium Sliding Highlight

    private func tabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = appState.selectedTab == tab.rawValue
        if isActive {
            return AnyView(
                content()
                    .zIndex(1)
            )
        } else {
            return AnyView(
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
            )
        }
    }

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = appState.selectedTab == tab.rawValue
        return Button {
            withAnimation(VelaTheme.snappy) {
                appState.selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .frame(height: 22)
                Text(label(for: tab))
                    .font(.system(size: 8.5, weight: .bold))
            }
            .foregroundStyle(isActive ? VelaTheme.fg : VelaTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VelaTheme.accent.opacity(0.08))
                            .matchedGeometryEffect(id: "activeTabHighlight", in: tabAnimation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func iconName(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "sun.max"
        case .training: "figure.run"
        case .insights: "chart.xyaxis.line"
        case .coach:    "sparkles"
        case .me:       "person.crop.circle"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    L10n.t("Today", "今日")
        case .training: L10n.t("Training", "训练")
        case .insights: L10n.t("Insights", "趋势")
        case .coach:    L10n.t("Coach", "Coach")
        case .me:       L10n.t("Me", "个人")
        }
    }

    private func nativeTabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = appState.selectedTab == tab.rawValue
        return content()
            .opacity(isActive ? 1 : 0)
            .animation(VelaTheme.snappy, value: appState.selectedTab)
    }
}

enum VelaTabSelection {
    struct Result {
        var selectedTab: VelaShell.VelaTab
        var shouldPresentQuickActions: Bool
    }

    static let contentTabs: [VelaShell.VelaTab] = [.today, .training, .insights, .coach, .me]

    static func resolve(
        candidate: VelaShell.VelaTab,
        current: VelaShell.VelaTab
    ) -> Result {
        Result(selectedTab: candidate, shouldPresentQuickActions: false)
    }

}

private struct PostWorkoutCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutID: UUID?

    @State private var workout: StrengthWorkoutRecord?
    @State private var selectedTags: Set<String> = []
    @State private var rpe: Double = 7
    @State private var note = ""
    @State private var saveError: String?

    private let tagOptions: [(key: String, label: String)] = [
        ("felt_strong", "状态很好"),
        ("normal", "正常完成"),
        ("fatigued", "明显疲劳"),
        ("muscle_soreness", "肌肉酸痛"),
        ("joint_discomfort", "关节不适"),
        ("poor_sleep", "睡眠影响"),
        ("good_pump", "泵感明显"),
        ("low_motivation", "动力不足")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tagGrid
                rpeSection
                noteSection
                if let saveError {
                    Text(saveError)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.stress)
                }
                saveButton
            }
            .padding(16)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("训练后感受")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
        .task {
            loadExistingState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout?.title ?? "训练后复盘")
                .font(VelaTheme.title2())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.fg)
            Text("这些反馈会进入训练响应模型，用来判断不同训练对恢复、HRV 和次日状态的代价。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var tagGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主观感受")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(tagOptions, id: \.key) { option in
                    Button {
                        if selectedTags.contains(option.key) {
                            selectedTags.remove(option.key)
                        } else {
                            selectedTags.insert(option.key)
                        }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedTags.contains(option.key) ? .white : VelaTheme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedTags.contains(option.key) ? VelaTheme.accent : VelaTheme.cardBg)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("整体用力程度")
                    .font(VelaTheme.headline())
                Spacer()
                Text("\(Int(rpe.rounded())) / 10")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
            }
            Slider(value: $rpe, in: 1...10, step: 1)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("补充说明")
                .font(VelaTheme.headline())
            TextField("例如：深蹲最后两组腰背紧张，整体还可以。", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存训练反馈")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.accent))
        }
        .buttonStyle(.plain)
    }

    private func loadExistingState() {
        guard let workoutID else { return }
        let workoutDescriptor = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.id == workoutID }
        )
        workout = try? modelContext.fetch(workoutDescriptor).first

        let responseDescriptor = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.workoutId == workoutID }
        )
        guard let response = try? modelContext.fetch(responseDescriptor).first else {
            if let sessionRPE = workout?.sessionRPE {
                rpe = sessionRPE
            }
            return
        }

        rpe = response.sessionRPE ?? workout?.sessionRPE ?? 7
        let tags = response.subjectiveTags
        selectedTags = Set(tags.filter { !$0.hasPrefix("note:") })
        note = tags.first(where: { $0.hasPrefix("note:") })?
            .replacingOccurrences(of: "note:", with: "") ?? ""
    }

    private func save() {
        guard let workoutID else {
            saveError = "没有找到关联训练，无法保存训练反馈。"
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var tags = Array(selectedTags).sorted()
        if !trimmedNote.isEmpty {
            tags.append("note:\(trimmedNote)")
        }

        let responseDescriptor = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.workoutId == workoutID }
        )

        do {
            if let existing = try modelContext.fetch(responseDescriptor).first {
                existing.sessionRPE = rpe
                existing.subjectiveTags = tags
            } else if let workout {
                let completedSets = workout.exercises
                    .flatMap(\.sets)
                    .filter { $0.isCompleted != false && !$0.isWarmup }
                    .count
                let muscles = Set(workout.exercises.compactMap(\.primaryMuscleGroup).filter { !$0.isEmpty })
                modelContext.insert(TrainingResponseRecord(
                    workoutId: workout.id,
                    date: workout.startedAt,
                    nextDayDate: Calendar.current.date(byAdding: .day, value: 1, to: workout.startedAt) ?? workout.startedAt,
                    primaryMuscleGroups: Array(muscles).sorted(),
                    totalEffectiveSets: completedSets,
                    totalVolumeKg: workout.totalVolumeKilograms,
                    sessionRPE: rpe,
                    subjectiveTags: tags
                ))
            } else {
                saveError = "没有找到关联训练，无法保存训练反馈。"
                return
            }

            workout?.sessionRPE = rpe
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
            dismiss()
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }
}

private struct PostWorkoutImpactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutID: UUID?

    @State private var impact: PostWorkoutImpact?
    @State private var isLoading = true
    @State private var errorText: String?

    private let queryService = HealthKitQueryService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLoading {
                    VStack(alignment: .leading, spacing: 16) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 100)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 140)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 120)
                            .shimmer()
                    }
                    .frame(maxWidth: .infinity)
                } else if let impact {
                    trendSection(impact)
                    summaryGrid(impact)
                    shortWindowSection(impact)
                    nextDaySection(impact)
                    interpretationSection(impact)
                } else {
                    emptyState
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("恢复影响")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
        .task {
            await loadImpact()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(impact?.title ?? "训练后恢复影响")
                .font(VelaTheme.title2())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(2)
            Text("这里看的是训练结束后 2 小时内的恢复、耗力和电量趋势，以及次日恢复反应。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func summaryGrid(_ impact: PostWorkoutImpact) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            impactCard(title: "耗力代价", value: impact.strainCostText, caption: impact.strainSourceText)
            impactCard(title: "能量消耗", value: impact.energyText, caption: "训练记录")
            impactCard(title: "0-2h 心率", value: impact.postHeartRateText, caption: "结束后窗口")
        }
    }

    private func trendSection(_ impact: PostWorkoutImpact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("2 小时趋势")
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.fg)
                Text("按训练后心率回落、RPE、能量消耗和当天电量推估。")
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
            }

            VStack(spacing: 10) {
                trendCard(
                    title: "恢复情况",
                    value: impact.recoveryTrendValueText,
                    caption: "越高表示越接近恢复",
                    color: VelaTheme.recovery,
                    points: impact.recoveryTrend
                )
                trendCard(
                    title: "耗力情况",
                    value: impact.strainTrendValueText,
                    caption: "越高表示身体仍在承压",
                    color: VelaTheme.stress,
                    points: impact.strainTrend
                )
                trendCard(
                    title: "电量情况",
                    value: impact.energyTrendValueText,
                    caption: "越高表示可用能量越充足",
                    color: VelaTheme.accent,
                    points: impact.energyTrend
                )
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func trendCard(
        title: String,
        value: String,
        caption: String,
        color: Color,
        points: [PostWorkoutTrendPoint]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(caption)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            PostWorkoutTrendLine(points: points, color: color)
                .frame(height: 86)

            HStack {
                Text("0m")
                Spacer()
                Text("60m")
                Spacer()
                Text("120m")
            }
            .font(VelaTheme.caption2())
            .foregroundStyle(VelaTheme.muted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
    }

    private func impactCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.muted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(caption)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .velaNativeCard(radius: 16)
    }

    private func shortWindowSection(_ impact: PostWorkoutImpact) -> some View {
        sectionCard(title: "短期窗口") {
            metricRow("训练后平均心率", impact.postAverageHeartRateText)
            metricRow("训练后峰值心率", impact.postPeakHeartRateText)
            metricRow("当日总压力", impact.todayStrainText)
            metricRow("当前电量", impact.energyBankText)
        }
    }

    private func nextDaySection(_ impact: PostWorkoutImpact) -> some View {
        sectionCard(title: "次日反应") {
            metricRow("恢复分变化", impact.recoveryDeltaText)
            metricRow("HRV 变化", impact.hrvDeltaText)
            metricRow("静息心率变化", impact.rhrDeltaText)
            metricRow("睡眠分", impact.sleepScoreText)
        }
    }

    private func interpretationSection(_ impact: PostWorkoutImpact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("判断")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(impact.interpretation)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            content()
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.fg)
                .multilineTextAlignment(.trailing)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有找到这次训练的恢复影响数据")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(errorText ?? "请等待健康数据同步完成后再查看。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    @MainActor
    private func loadImpact() async {
        isLoading = true
        defer { isLoading = false }

        guard let workoutID else {
            errorText = "这个复盘没有关联到具体训练。"
            impact = nil
            return
        }

        do {
            let workouts = try modelContext.fetch(FetchDescriptor<StrengthWorkoutRecord>())
            let events = try modelContext.fetch(FetchDescriptor<WorkoutEventRecord>())
            let responses = try modelContext.fetch(FetchDescriptor<TrainingResponseRecord>())
            let summaries = try modelContext.fetch(FetchDescriptor<DailyHealthSummaryRecord>())

            let workout = workouts.first { $0.id == workoutID }
            let event = events.first {
                $0.id == workoutID || $0.linkedStrengthWorkoutId == workoutID || $0.linkedHealthKitWorkoutId == workoutID
            } ?? workout.flatMap { strength in
                events.first { $0.linkedStrengthWorkoutId == strength.id }
            }
            let response = responses.first { $0.workoutId == workoutID }
            guard workout != nil || event != nil || response != nil else {
                errorText = "没有找到关联的力量训练或统一训练记录。"
                impact = nil
                return
            }

            let start = workout?.startedAt ?? event?.startedAt ?? response?.date ?? Date()
            let end = workout?.endedAt ?? event?.endedAt ?? start
            let calendar = Calendar.current
            let todayID = DailyHealthSummaryRecord.dayIdentifier(for: start, calendar: calendar)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let nextDayID = DailyHealthSummaryRecord.dayIdentifier(for: nextDay, calendar: calendar)
            let todaySummary = summaries.first { $0.dayIdentifier == todayID }
            let nextDaySummary = summaries.first { $0.dayIdentifier == nextDayID }

            let postWindowEnd = min(Date(), end.addingTimeInterval(2 * 3600))
            let postSamples: [HeartRateSample]
            if postWindowEnd > end {
                postSamples = (try? await queryService.heartRateSamples(start: end, end: postWindowEnd)) ?? []
            } else {
                postSamples = []
            }

            impact = PostWorkoutImpact(
                workout: workout,
                event: event,
                response: response,
                todaySummary: todaySummary,
                nextDaySummary: nextDaySummary,
                postWorkoutHeartRates: postSamples
            )
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            impact = nil
        }
    }
}

private struct PostWorkoutImpact {
    let title: String
    let strainCost: Double?
    let strainSourceText: String
    let energyKilocalories: Double?
    let postAverageHeartRate: Double?
    let postPeakHeartRate: Double?
    let todayStrain: Double?
    let energyBank: Double?
    let nextDayRecoveryDelta: Double?
    let nextDayHRVDelta: Double?
    let nextDayRHRDelta: Double?
    let nextDaySleepScore: Double?
    let recoveryTrend: [PostWorkoutTrendPoint]
    let strainTrend: [PostWorkoutTrendPoint]
    let energyTrend: [PostWorkoutTrendPoint]

    init(
        workout: StrengthWorkoutRecord?,
        event: WorkoutEventRecord?,
        response: TrainingResponseRecord?,
        todaySummary: DailyHealthSummaryRecord?,
        nextDaySummary: DailyHealthSummaryRecord?,
        postWorkoutHeartRates: [HeartRateSample]
    ) {
        title = workout?.title ?? event?.title ?? "训练后恢复影响"
        let rpe = response?.sessionRPE ?? workout?.sessionRPE ?? event?.rpe
        let duration = Double(workout?.durationMinutes ?? Int(event?.durationMinutes ?? 0))
        if let response {
            strainCost = Double(response.totalEffectiveSets) * (response.sessionRPE ?? rpe ?? 6)
            strainSourceText = "有效组 x RPE"
        } else if duration > 0 {
            strainCost = duration * (rpe ?? 6) / 10
            strainSourceText = "时长 x RPE"
        } else {
            strainCost = nil
            strainSourceText = "待同步"
        }

        energyKilocalories = event?.energyKilocalories
        postAverageHeartRate = Self.average(postWorkoutHeartRates.map(\.bpm))
        postPeakHeartRate = postWorkoutHeartRates.map(\.bpm).max()
        todayStrain = todaySummary?.strainScore
        energyBank = todaySummary?.currentEnergy ?? todaySummary?.energyBank ?? todaySummary?.morningEnergy
        nextDayRecoveryDelta = response?.nextDayRecoveryDelta ?? Self.delta(nextDaySummary?.recoveryScore, todaySummary?.recoveryScore)
        nextDayHRVDelta = response?.nextDayHRVDelta ?? Self.delta(nextDaySummary?.hrvAverage, todaySummary?.hrvAverage)
        nextDayRHRDelta = response?.nextDayRHRDelta ?? Self.delta(nextDaySummary?.restingHeartRate, todaySummary?.restingHeartRate)
        nextDaySleepScore = response?.nextDaySleepScore ?? nextDaySummary?.sleepScore

        let trends = Self.buildTrends(
            samples: postWorkoutHeartRates,
            restingHeartRate: todaySummary?.restingHeartRate,
            eventAverageHeartRate: event?.averageHeartRate,
            strainCost: strainCost,
            energyKilocalories: energyKilocalories,
            energyBank: energyBank
        )
        recoveryTrend = trends.recovery
        strainTrend = trends.strain
        energyTrend = trends.energy
    }

    var strainCostText: String { roundedText(strainCost, suffix: "") }
    var energyText: String { roundedText(energyKilocalories, suffix: " kcal") }
    var postHeartRateText: String { postAverageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--" }
    var postAverageHeartRateText: String { postHeartRateText }
    var postPeakHeartRateText: String { postPeakHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--" }
    var todayStrainText: String { roundedText(todayStrain, suffix: "/100") }
    var energyBankText: String { roundedText(energyBank, suffix: "/100") }
    var recoveryDeltaText: String { signedText(nextDayRecoveryDelta, suffix: " 分") }
    var hrvDeltaText: String { signedText(nextDayHRVDelta, suffix: " ms") }
    var rhrDeltaText: String { signedText(nextDayRHRDelta, suffix: " bpm") }
    var sleepScoreText: String { roundedText(nextDaySleepScore, suffix: "/100") }
    var recoveryTrendValueText: String { trendValueText(recoveryTrend) }
    var strainTrendValueText: String { trendValueText(strainTrend) }
    var energyTrendValueText: String { trendValueText(energyTrend) }

    var interpretation: String {
        if nextDayRecoveryDelta == nil && nextDayHRVDelta == nil && nextDayRHRDelta == nil {
            return "次日恢复数据还没补全。当前只能看这次训练的耗力和训练后心率，等睡眠、HRV、静息心率同步后会更准确。"
        }
        if (nextDayRecoveryDelta ?? 0) <= -8 || (nextDayRHRDelta ?? 0) >= 5 || (nextDayHRVDelta ?? 0) <= -8 {
            return "这次训练的恢复代价偏高。下一次训练应降低同肌群容量或强度，优先看睡眠、HRV 和静息心率是否回到基线。"
        }
        if (todayStrain ?? 0) >= 75 || (strainCost ?? 0) >= 70 {
            return "这次训练本身耗力较高，但暂时没有看到明确的次日恢复崩塌。下一次训练可以保留计划，但不要叠加高强度同肌群。"
        }
        return "这次训练的恢复代价目前看可控。可以按计划推进，但仍建议结合主观疲劳和睡眠质量判断是否加量。"
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func delta(_ next: Double?, _ current: Double?) -> Double? {
        guard let next, let current else { return nil }
        return next - current
    }

    private static func buildTrends(
        samples: [HeartRateSample],
        restingHeartRate: Double?,
        eventAverageHeartRate: Double?,
        strainCost: Double?,
        energyKilocalories: Double?,
        energyBank: Double?
    ) -> (recovery: [PostWorkoutTrendPoint], strain: [PostWorkoutTrendPoint], energy: [PostWorkoutTrendPoint]) {
        let resting = restingHeartRate ?? 62
        let peak = max(samples.map(\.bpm).max() ?? 0, eventAverageHeartRate ?? 0, resting + 55)
        let highRange = max(35, peak - resting)
        let baseStrain = clamp((strainCost ?? 35) / 85)
        let baseEnergy = clamp(energyBank ?? 68, min: 15, max: 95)
        let energyDrain = clamp((energyKilocalories ?? (strainCost ?? 45) * 4) / 18, min: 8, max: 34)
        let firstSampleDate = samples.map(\.date).min()

        var recovery: [PostWorkoutTrendPoint] = []
        var strain: [PostWorkoutTrendPoint] = []
        var energy: [PostWorkoutTrendPoint] = []

        for minute in stride(from: 0.0, through: 120.0, by: 15.0) {
            let hr = heartRateAtMinute(
                minute,
                samples: samples,
                firstSampleDate: firstSampleDate,
                fallbackAverage: eventAverageHeartRate,
                resting: resting
            )
            let hrLoad = clamp((hr - resting) / highRange)
            let strainValue = clamp((hrLoad * 0.72 + baseStrain * 0.28) * 100)
            let recoveryValue = clamp(100 - strainValue * 0.78 + (baseEnergy - 50) * 0.16)
            let energyValue = clamp(baseEnergy - energyDrain * exp(-minute / 80))

            recovery.append(PostWorkoutTrendPoint(minute: minute, value: recoveryValue))
            strain.append(PostWorkoutTrendPoint(minute: minute, value: strainValue))
            energy.append(PostWorkoutTrendPoint(minute: minute, value: energyValue))
        }

        return (recovery, strain, energy)
    }

    private static func heartRateAtMinute(
        _ minute: Double,
        samples: [HeartRateSample],
        firstSampleDate: Date?,
        fallbackAverage: Double?,
        resting: Double
    ) -> Double {
        if let firstSampleDate {
            let nearby = samples.filter { sample in
                let sampleMinute = sample.date.timeIntervalSince(firstSampleDate) / 60
                return abs(sampleMinute - minute) <= 8
            }
            if let average = average(nearby.map(\.bpm)) {
                return average
            }
        }

        let elevated = max((fallbackAverage ?? resting + 42) - resting, 18)
        return resting + elevated * exp(-minute / 48)
    }

    private static func clamp(_ value: Double, min lower: Double = 0, max upper: Double = 100) -> Double {
        Swift.min(Swift.max(value, lower), upper)
    }

    private func roundedText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))\(suffix)"
    }

    private func signedText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)\(suffix)"
        }
        return "\(rounded)\(suffix)"
    }

    private func trendValueText(_ points: [PostWorkoutTrendPoint]) -> String {
        guard let value = points.last?.value else { return "--" }
        return "\(Int(value.rounded()))"
    }
}

private struct PostWorkoutTrendPoint: Identifiable, Hashable {
    var id: Double { minute }
    let minute: Double
    let value: Double
}

private struct PostWorkoutTrendLine: View {
    let points: [PostWorkoutTrendPoint]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                grid(size: size)
                trendPath(size: size)
            }
        }
    }

    private func grid(size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(VelaTheme.borderSoft), lineWidth: 0.6)
        }
    }

    private func trendPath(size: CGSize) -> some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }

            var line = Path()
            for (index, point) in points.enumerated() {
                let x = size.width * point.minute / 120
                let y = size.height * (1 - min(max(point.value, 0), 100) / 100)
                let cgPoint = CGPoint(x: x, y: y)
                if index == 0 {
                    line.move(to: cgPoint)
                } else {
                    line.addLine(to: cgPoint)
                }
            }

            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            if let last = points.last {
                let x = size.width * last.minute / 120
                let y = size.height * (1 - min(max(last.value, 0), 100) / 100)
                let marker = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
                context.fill(Path(ellipseIn: marker), with: .color(color))
            }
        }
    }
}
