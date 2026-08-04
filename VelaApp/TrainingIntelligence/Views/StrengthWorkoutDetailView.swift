import SwiftUI
import SwiftData
import Charts

struct StrengthWorkoutDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var allWorkouts: [StrengthWorkoutRecord]
    let workout: StrengthWorkoutRecord

    @State private var selectedSet: StrengthSetDetail?
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

    private var analysis: StrengthWorkoutAnalysis {
        TrainingAnalyticsService().summarizeWorkout(
            workout.dto,
            history: allWorkouts.filter { $0.startedAt < workout.startedAt }.map { $0.dto },
            exerciseLibrary: ExerciseLibraryService.defaultDefinitionsDTO()
        )
    }

    private var completedSets: Int {
        workout.exercises.flatMap(\.sets).filter { $0.isCompleted ?? true }.count
    }

    private var bodyTextColor: Color { VelaTheme.fg }
    private var mutedColor: Color { VelaTheme.muted }
    private var accentColor: Color { VelaTheme.accent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hero
                intelligenceStrip
                progressionAdvice
                muscleDistribution
                exerciseList
                notesCard
            }
            .padding(16)
            .padding(.bottom, 88)
        }
        .scrollIndicators(.hidden)
        .background(detailBackground.ignoresSafeArea())
        .navigationTitle("力量训练详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .buttonStyle(.cardPress)
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VelaTheme.systemRed)
                    }
                    .buttonStyle(.cardPress)
                }
            }
        }
        .sheet(item: $selectedSet) { detail in
            StrengthSetDetailSheet(detail: detail)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showEditSheet) {
            StrengthWorkoutLogSheetView(editingWorkout: workout)
        }
        .confirmationDialog("确定要删除这条健身记录吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                deleteWorkout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后，该训练对应的组次、容量和计算负荷都将被移除。")
        }
    }

    private func deleteWorkout() {
        do {
            let workoutID = workout.id
            let eventDescriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.linkedStrengthWorkoutId == workoutID }
            )
            let events = try? modelContext.fetch(eventDescriptor)
            if let events {
                for event in events {
                    if let hkId = event.linkedHealthKitWorkoutId {
                        modelContext.insert(DeletedWorkoutRecord(id: hkId.uuidString))
                    } else if event.source == "healthKit" {
                        modelContext.insert(DeletedWorkoutRecord(id: event.id.uuidString))
                    }
                }
            }
            try WorkoutAggregationService.shared.deleteStrengthWorkout(workout, modelContext: modelContext)
            
            VelaAppState.shared.markLocalDataChanged()
            
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
            dismiss()
        } catch {
            print("Failed to delete workout: \(error)")
        }
    }

    private var hero: some View {
        VelaGlassCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(workout.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(bodyTextColor)
                        Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(mutedColor)
                    }
                    Spacer()
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color(hex: "#EAF3FF")))
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    heroMetric("时长", "\(workout.durationMinutes)", "分钟")
                    heroMetric("容量", "\(Int(analysis.totalVolumeKg.rounded()))", "kg")
                    heroMetric("有效组", "\(analysis.effectiveSets)", "组")
                }

                TrainingVolumeSparkline(exercises: workout.exercises)
                    .frame(height: 74)
                    .padding(.top, 2)
            }
        }
    }

    private var intelligenceStrip: some View {
        VelaGlassCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("训练智能摘要", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bodyTextColor)
                    Spacer()
                    Text("\(completedSets)/\(workout.totalSetCount) 完成")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accentColor)
                }

                Text(analysis.summaryText)
                    .font(.system(size: 13))
                    .foregroundStyle(mutedColor)

                if !analysis.personalRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(Array(analysis.personalRecords.prefix(3))) { record in
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(Color(hex: "#D89B28"))
                                Text(record.summary)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(bodyTextColor)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .appleIntelligenceGlow(isHighlighted: true, radius: 20)
    }

    private var muscleDistribution: some View {
        VelaGlassCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("肌群分布")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bodyTextColor)
                    Spacer()
                    Text("有效组")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(mutedColor)
                }

                if analysis.muscleGroupSets.isEmpty {
                    Text("这次训练暂未形成有效组。")
                        .font(.system(size: 13))
                        .foregroundStyle(mutedColor)
                } else {
                    ForEach(analysis.muscleGroupSets.sorted { $0.value > $1.value }, id: \.key) { muscle, sets in
                        let maxSets = max(analysis.muscleGroupSets.values.max() ?? 1, 1)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(localizedMuscle(muscle))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(bodyTextColor)
                                Spacer()
                                Text("\(sets) 组")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(mutedColor)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(hex: "#EFEAE2"))
                                    Capsule()
                                        .fill(muscleColor(muscle))
                                        .frame(width: geo.size.width * CGFloat(Double(sets) / Double(maxSets)))
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }

    private var progressionAdvice: some View {
        let advice = StrengthProgressionAdvisor.advise(
            current: workout,
            history: allWorkouts.filter { $0.id != workout.id }
        )
        return VelaGlassCard(padding: 16, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("渐进超负荷", systemImage: "arrow.up.forward.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bodyTextColor)
                    Spacer()
                    Text("基于最近 3 次")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(mutedColor)
                }

                ForEach(Array(advice.prefix(3))) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.exerciseName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(bodyTextColor)
                            Spacer()
                            Text(progressionStatusLabel(item.status))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(progressionStatusColor(item.status))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(progressionStatusColor(item.status).opacity(0.12), in: Capsule())
                        }
                        Text(item.evidence)
                            .font(.system(size: 12))
                            .foregroundStyle(mutedColor)
                        Text(item.action)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(bodyTextColor)
                    }
                    .padding(12)
                    .background(VelaTheme.fillSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("训练建议仅用于一般健身规划；疼痛、不适或异常疲劳时停止训练并寻求专业意见。")
                    .font(.system(size: 10))
                    .foregroundStyle(mutedColor)
            }
        }
    }

    private func progressionStatusLabel(_ status: StrengthProgressionStatus) -> String {
        switch status {
        case .ready: "可尝试最小增量"
        case .hold: "保持或减量"
        case .collecting: "继续收集"
        }
    }

    private func progressionStatusColor(_ status: StrengthProgressionStatus) -> Color {
        switch status {
        case .ready: VelaTheme.recoveryColor
        case .hold: VelaTheme.energyColor
        case .collecting: VelaTheme.muted
        }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("动作与组次")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(bodyTextColor)

            ForEach(workout.exercises) { exercise in
                VelaGlassCard(padding: 16, cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(bodyTextColor)
                                Text("\(exercise.equipment) · \(Int(exercise.volumeKilograms.rounded())) kg")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(mutedColor)
                            }
                            Spacer()
                            if let e1RM = analysis.estimatedOneRepMaxByExercise[exercise.name] {
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(Int(e1RM.rounded())) kg")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(accentColor)
                                    Text("e1RM")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(mutedColor)
                                }
                            }
                        }

                        if !exercise.sets.isEmpty {
                            HStack(spacing: 12) {
                                Text("组")
                                    .frame(width: 32, alignment: .leading)
                                Text("重量")
                                    .frame(width: 70, alignment: .center)
                                Spacer()
                                Text("次数")
                                    .frame(width: 50, alignment: .center)
                                Text("RPE")
                                    .frame(width: 44, alignment: .center)
                                Text("状态")
                                    .frame(width: 32, alignment: .trailing)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(mutedColor)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 2)
                        }

                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            Button {
                                selectedSet = StrengthSetDetail(
                                    exerciseName: exercise.name,
                                    setIndex: index + 1,
                                    set: set
                                )
                            } label: {
                                setRow(index: index, set: set)
                            }
                            .buttonStyle(.cardPress)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VelaGlassCard(padding: 16, cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("训练备注")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(bodyTextColor)
                    Text(workout.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(mutedColor)
                }
            }
        }
    }

    private func heroMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mutedColor)
                    .lineLimit(1)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(mutedColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.72)))
    }

    private func setRow(index: Int, set: StrengthSetLog) -> some View {
        HStack(spacing: 12) {
            // 组号 / 热身标记
            Text(set.kind == .working ? "\(index + 1)" : set.kind.shortLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(detailSetKindColor(set.kind)))
                .frame(width: 32, alignment: .leading)

            // 重量
            Text("\(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(bodyTextColor)
                .frame(width: 70, alignment: .center)

            Spacer()

            // 次数
            Text("\(set.repetitions) 次")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(bodyTextColor)
                .frame(width: 50, alignment: .center)

            // RPE
            Text(set.rpe.map { "\(Int($0))" } ?? "—")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(set.rpe != nil ? VelaTheme.accent : mutedColor)
                .frame(width: 44, height: 26)
                .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(VelaTheme.elevatedBg))

            // 状态
            Image(systemName: (set.isCompleted ?? true) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle((set.isCompleted ?? true) ? VelaTheme.success : mutedColor)
                .font(.system(size: 20))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(index + 1) 组，\(set.kind.displayName)，\(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) 千克，\(set.repetitions) 次")
    }

    private func detailSetKindColor(_ kind: StrengthSetKind) -> Color {
        switch kind {
        case .working: VelaTheme.accent
        case .warmup: VelaTheme.systemOrange
        case .drop: VelaTheme.sleepColor
        case .backoff: VelaTheme.recoveryColor
        case .failure: VelaTheme.strainColor
        }
    }

    private var detailBackground: some View {
        ZStack {
            VelaTheme.systemGroupedBackground
            LinearGradient(
                colors: [Color(hex: "#EAF3FF"), VelaTheme.systemGroupedBackground, Color(hex: "#EEF7F4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(VelaTheme.cardBg.opacity(colorScheme == .dark ? 0.62 : 0.92))
            .shadow(color: VelaTheme.nativeShadow(colorScheme), radius: 10, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(VelaTheme.cardBg)
            .shadow(color: VelaTheme.nativeShadow(colorScheme), radius: 8, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
    }

    private func localizedMuscle(_ muscle: String) -> String {
        [
            "chest": "胸部",
            "back": "背部",
            "quads": "股四头肌",
            "hamstrings": "腘绳肌",
            "glutes": "臀部",
            "shoulders": "肩部",
            "biceps": "肱二头肌",
            "triceps": "肱三头肌",
            "core": "核心",
            "other": "其他"
        ][muscle] ?? muscle
    }

    private func muscleColor(_ muscle: String) -> Color {
        switch muscle {
        case "chest": return Color(hex: "#FF8A65")
        case "back": return Color(hex: "#4DB6AC")
        case "quads", "hamstrings", "glutes": return Color(hex: "#66BB6A")
        case "shoulders": return VelaTheme.indigo
        case "biceps", "triceps": return Color(hex: "#AB47BC")
        case "core": return Color(hex: "#FFCA28")
        default: return Color(hex: "#90A4AE")
        }
    }
}

private struct TrainingVolumeSparkline: View {
    let exercises: [StrengthExerciseLog]

    private var chartData: [VolumeItem] {
        var items: [VolumeItem] = []
        let sets = exercises.flatMap(\.sets).filter { !($0.isWarmup) }
        for (index, set) in sets.enumerated() {
            items.append(VolumeItem(index: index, volume: set.volumeKilograms))
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练容量趋势")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
            
            if chartData.count < 2 {
                Text("暂无足够的容量趋势数据")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(chartData) { item in
                        AreaMark(
                            x: .value("Set", item.index),
                            y: .value("Volume", item.volume)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [VelaTheme.accent.opacity(0.24), VelaTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Set", item.index),
                            y: .value("Volume", item.volume)
                        )
                        .foregroundStyle(VelaTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(VelaTheme.separatorSoft)
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .frame(height: 50)
            }
        }
    }
}

private struct VolumeItem: Identifiable {
    let id = UUID()
    let index: Int
    let volume: Double
}
