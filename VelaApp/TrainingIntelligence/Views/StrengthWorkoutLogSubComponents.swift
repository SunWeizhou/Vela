import SwiftUI
import SwiftData

// MARK: - RestTimerState

struct RestTimerState {
    var endsAt: Date
    var exerciseName: String
    var setNumber: Int
}

// MARK: - StrengthWorkoutSessionViewModel

@MainActor
final class StrengthWorkoutSessionViewModel: ObservableObject {
    private var draftSaveTask: Task<Void, Never>?

    func scheduleDraftSave(_ action: @escaping @MainActor () -> Void) {
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func saveImmediately(_ action: @escaping @MainActor () -> Void) {
        draftSaveTask?.cancel()
        action()
    }

    deinit {
        draftSaveTask?.cancel()
    }
}

// MARK: - StrengthWorkoutSessionPrefill

enum StrengthWorkoutSessionPrefill {
    static func previousCompletedSets(
        for exerciseName: String,
        in workoutHistory: [StrengthWorkoutRecord]
    ) -> [StrengthSetLog] {
        let normalizedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedName.isEmpty,
              let previous = workoutHistory.lazy
                .flatMap(\.exercises)
                .first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName }) else {
            return []
        }
        return previous.sets.filter { !$0.isWarmup && $0.isCompleted == true }
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseDefinitionRecord.name) private var customDefinitions: [ExerciseDefinitionRecord]
    @State private var query = ""
    @State private var saveError: String?
    let onSelect: (ExerciseDefinitionRecord) -> Void

    private var definitions: [ExerciseDefinitionRecord] {
        let defaults = ExerciseLibraryService.defaultDefinitions()
        let names = Set(customDefinitions.map(\.name))
        return ExerciseLibraryService.search(query, in: customDefinitions + defaults.filter { !names.contains($0.name) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(definitions) { definition in
                    Button {
                        onSelect(definition)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(definition.name)
                            Text("\(localizedMuscle(definition.primaryMuscleGroup)) · \(localizedEquipment(definition.equipment))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !definitions.contains(where: { $0.name == query }) {
                    Button("新增自定义动作「\(query)」") {
                        let definition = ExerciseDefinitionRecord(
                            name: query,
                            primaryMuscleGroup: "other",
                            equipment: "other",
                            movementPattern: "other",
                            isCustom: true
                        )
                        modelContext.insert(definition)
                        do {
                            try modelContext.save()
                            VelaAppState.shared.markLocalDataChanged()
                            onSelect(definition)
                            dismiss()
                        } catch {
                            modelContext.rollback()
                            saveError = "自定义动作未保存。请稍后重试。"
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索动作或肌群")
            .navigationTitle("添加动作")
        }
        .task {
            try? ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: modelContext)
        }
        .alert("无法保存动作", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
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

    private func localizedEquipment(_ equipment: String) -> String {
        [
            "barbell": "杠铃",
            "dumbbell": "哑铃",
            "machine": "器械",
            "cable": "绳索",
            "bodyweight": "自重",
            "kettlebell": "壶铃",
            "other": "其他"
        ][equipment] ?? equipment
    }
}

// MARK: - Strength Workout Summary Sheet

struct StrengthWorkoutSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: StrengthWorkoutAnalysis
    let workout: StrengthWorkoutRecord?
    let onSaveTemplate: () -> Bool
    let onDone: () -> Void
    @State private var isTemplateSaved = false

    private var muscleSetSummary: String {
        let lines = summary.muscleGroupSets
            .sorted { $0.value > $1.value }
            .map { "\(localizedMuscle($0.key))：\($0.value) 组" }
        return lines.isEmpty ? "本次没有形成可计入分析的有效组。" : lines.joined(separator: "\n")
    }

    private var recoveryRecommendation: String {
        guard summary.effectiveSets > 0 else {
            return "本次没有形成足够的有效训练量。下一次训练前，优先根据动作完成度、主观疲劳和当天恢复信号重新安排。"
        }
        let muscles = summary.muscleGroupSets
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { localizedMuscle($0.key) }
            .joined(separator: "、")
        let loadText = summary.effectiveSets >= 12 ? "本次有效训练量较高" : "本次训练量处于可跟踪范围"
        let focusText = muscles.isEmpty ? "涉及肌群" : "\(muscles)等涉及肌群"
        return "\(loadText)。接下来 24–48 小时留意\(focusText)的酸痛、动作稳定性和精神状态；如这些信号明显变差，下一次同部位训练应减量或改做低强度活动。"
    }

    private var nutritionRecommendation: String {
        "训练后的进食以全天总能量、蛋白质 and 碳水安排为先。选择你方便的下一餐补充蛋白质、主食 and 水分即可；无需为了固定的时间窗口强行进食。"
    }

    private var nextSessionRecommendation: String {
        if summary.uncompletedSets > 0 {
            return "本次仍有 \(summary.uncompletedSets) 组未完成。下次优先复盘重量、次数或休息时间，而不是直接加量。"
        }
        if summary.effectiveSets >= 12 {
            return "下一次同部位训练前先查看今日恢复和局部疲劳；恢复不足时可保留动作，但降低组数或强度。"
        }
        return "下一次训练可从本次已完成的动作和重量开始，再根据动作质量与主观用力程度小幅调整。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("训练已保存", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.recoveryColor)
                        Text(workout?.title ?? "力量训练")
                            .font(.system(size: 24, weight: .bold))
                        Text("基于本次已完成的训练组生成")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        metric("时长", "\(workout?.durationMinutes ?? 0) 分钟")
                        metric("总容量", "\(Int(summary.totalVolumeKg.rounded())) kg")
                        metric("计划组", "\(summary.plannedSets)")
                        metric("完成组", "\(summary.completedSets)")
                        metric("有效组", "\(summary.effectiveSets)")
                        metric("未完成", "\(summary.uncompletedSets)")
                        metric("总次数", "\(summary.totalReps)")
                        metric("训练密度", "\(Int(summary.densityKgPerMinute.rounded())) kg/min")
                    }
                    summaryCard("肌群组数", muscleSetSummary)
                    summaryCard("e1RM", summary.estimatedOneRepMaxByExercise.sorted { $0.key < $1.key }.map { "\($0.key): \(Int($0.value.rounded())) kg" }.joined(separator: "\n"))
                    summaryCard("PR", summary.personalRecords.isEmpty ? "历史数据不足，完成更多训练后会自动识别 PR。" : summary.personalRecords.map(\.summary).joined(separator: "\n"))
                    summaryCard("恢复建议", recoveryRecommendation)
                    summaryCard("饮食与补水", nutritionRecommendation)
                    summaryCard("下次训练", nextSessionRecommendation)
                    Button {
                        isTemplateSaved = onSaveTemplate()
                    } label: {
                        Label(isTemplateSaved ? "已保存到模板库" : "保存为训练模板", systemImage: isTemplateSaved ? "checkmark" : "bookmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTemplateSaved)
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("训练完成")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 15, weight: .bold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .velaNativeCard(radius: 14)
    }

    private func summaryCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .bold))
            Text(body.isEmpty ? "暂无数据" : body).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .velaNativeCard(radius: 16)
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
}

extension StrengthWorkoutAnalysis: Identifiable {
    public var id: String { summaryText + "\(totalSets)" }
}
