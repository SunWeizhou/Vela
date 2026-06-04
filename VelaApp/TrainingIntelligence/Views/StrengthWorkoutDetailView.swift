import SwiftUI
import SwiftData

struct StrengthWorkoutDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var allWorkouts: [StrengthWorkoutRecord]
    let workout: StrengthWorkoutRecord

    @State private var selectedSet: StrengthSetDetail?

    private var analysis: StrengthWorkoutAnalysis {
        TrainingAnalyticsService().summarizeWorkout(
            workout,
            history: allWorkouts.filter { $0.startedAt < workout.startedAt },
            exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
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
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $selectedSet) { detail in
            StrengthSetDetailSheet(detail: detail)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
    }

    private var hero: some View {
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
        .padding(18)
        .background(heroBackground)
    }

    private var intelligenceStrip: some View {
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
        .padding(16)
        .background(cardBackground)
    }

    private var muscleDistribution: some View {
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
        .padding(16)
        .background(cardBackground)
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("动作与组次")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(bodyTextColor)

            ForEach(workout.exercises) { exercise in
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
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(cardBackground)
            }
        }
    }

    @ViewBuilder
    private var notesCard: some View {
        if !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("训练备注")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(bodyTextColor)
                Text(workout.notes)
                    .font(.system(size: 13))
                    .foregroundStyle(mutedColor)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private func heroMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mutedColor)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(mutedColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.72)))
    }

    private func setRow(index: Int, set: StrengthSetLog) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(set.isWarmup ? mutedColor : accentColor))
            Text(set.isWarmup ? "热身组" : "\(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg × \(set.repetitions)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(bodyTextColor)
            Spacer()
            if let rpe = set.rpe {
                Text("RPE \(Int(rpe))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(mutedColor)
            }
            Image(systemName: (set.isCompleted ?? true) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle((set.isCompleted ?? true) ? Color(hex: "#34C759") : mutedColor)
        }
        .padding(.vertical, 6)
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
        case "shoulders": return Color(hex: "#5C6BC0")
        case "biceps", "triceps": return Color(hex: "#AB47BC")
        case "core": return Color(hex: "#FFCA28")
        default: return Color(hex: "#90A4AE")
        }
    }
}

private struct TrainingVolumeSparkline: View {
    let exercises: [StrengthExerciseLog]

    private var values: [Double] {
        exercises.flatMap(\.sets).map(\.volumeKilograms)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(Color(hex: "#E5E5EA"))
                        .frame(height: 0.7)
                        .offset(y: geo.size.height * CGFloat(index) / 3)
                }
                Path { path in
                    guard values.count > 1 else { return }
                    let maxValue = max(values.max() ?? 1, 1)
                    for index in values.indices {
                        let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * geo.size.width
                        let y = geo.size.height - CGFloat(values[index] / maxValue) * (geo.size.height - 8) - 4
                        if index == values.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(VelaTheme.accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct StrengthSetDetail: Identifiable {
    let id = UUID()
    var exerciseName: String
    var setIndex: Int
    var set: StrengthSetLog
}

private struct StrengthSetDetailSheet: View {
    let detail: StrengthSetDetail

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(detail.exerciseName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("第 \(detail.setIndex) 组")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metric("重量", "\(detail.set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                    metric("次数", "\(detail.set.repetitions)")
                    metric("容量", "\(Int(detail.set.volumeKilograms.rounded())) kg")
                    metric("RPE", detail.set.rpe.map { "\(Int($0))" } ?? "--")
                    metric("RIR", detail.set.rir.map { "\(Int($0))" } ?? "--")
                    metric("状态", (detail.set.isCompleted ?? true) ? "已完成" : "未完成")
                }
                Spacer()
            }
            .padding(18)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("组详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
    }
}
