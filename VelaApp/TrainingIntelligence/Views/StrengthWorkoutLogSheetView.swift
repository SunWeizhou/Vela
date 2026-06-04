import SwiftUI
import SwiftData
import Combine

private struct RestTimerState {
    var endsAt: Date
    var exerciseName: String
    var setNumber: Int
}

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

struct StrengthWorkoutLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var workoutHistory: [StrengthWorkoutRecord]
    @Query(sort: \WorkoutTemplateRecord.title) private var persistedTemplates: [WorkoutTemplateRecord]
    
    @State private var title = "力量训练"
    @State private var startedAt = Date()
    @State private var notes = ""
    @State private var exertionScore: Double = 7.0
    @State private var exercises: [StrengthExerciseLog] = []
    @State private var showExercisePicker = false
    @State private var showDiscardConfirmation = false
    @State private var restTimer: RestTimerState?
    @State private var restSecondsRemaining = 0
    @State private var saveError: String?
    @State private var completedSummary: StrengthWorkoutAnalysis?
    @State private var completedWorkout: StrengthWorkoutRecord?
    @State private var closeAfterSummary = false
    @State private var now = Date()
    @State private var isLoaded = false
    @State private var showIgnoreUncompletedConfirmation = false
    @StateObject private var sessionViewModel = StrengthWorkoutSessionViewModel()

    private let startingTemplateID: UUID?
    private let equipmentOptions = ["杠铃", "哑铃", "固定器械", "绳索", "壶铃", "自重", "其他"]
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(startingTemplateID: UUID? = nil) {
        self.startingTemplateID = startingTemplateID
    }

    private var durationMinutes: Int {
        max(1, Int(now.timeIntervalSince(startedAt) / 60))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sessionCard

                    if let restTimer {
                        restTimerCard(restTimer)
                    }

                    ForEach($exercises) { $exercise in
                        exerciseCard(exercise: $exercise)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("添加动作", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .velaNativeCard(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("记录力量训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("放弃") { showDiscardConfirmation = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { requestSave() }
                        .disabled(validExercises.isEmpty)
                }
            }
        }
        .onReceive(timer) { date in
            now = date
            if let restTimer {
                restSecondsRemaining = max(0, Int(restTimer.endsAt.timeIntervalSince(date).rounded(.up)))
                if restSecondsRemaining == 0 { self.restTimer = nil }
            }
        }
        .task {
            try? ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: modelContext)
            loadDraftIfNeeded()
        }
        .onChange(of: title) { _, _ in scheduleDraftSave() }
        .onChange(of: notes) { _, _ in scheduleDraftSave() }
        .onChange(of: exercises) { _, _ in scheduleDraftSave() }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { definition in
                addExercise(definition)
            }
        }
        .sheet(item: $completedSummary, onDismiss: {
            if closeAfterSummary { dismiss() }
        }) { summary in
            StrengthWorkoutSummarySheet(
                summary: summary,
                workout: completedWorkout,
                onSaveTemplate: saveCompletedWorkoutAsTemplate,
                onDone: {
                    closeAfterSummary = true
                    completedSummary = nil
                }
            )
        }
        .confirmationDialog("要放弃这次训练吗？", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("放弃训练", role: .destructive) { discardWorkout() }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("放弃后将清除本次训练的草稿。")
        }
        .confirmationDialog("忽略未完成组？", isPresented: $showIgnoreUncompletedConfirmation, titleVisibility: .visible) {
            Button("忽略并保存", role: .destructive) { save(ignoringUncompletedSets: true) }
            Button("返回继续记录", role: .cancel) {}
        } message: {
            Text("未打勾的组不会计入训练总结、肌群疲劳或今日负荷。")
        }
        .alert("无法保存训练", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("训练名称", text: $title)
                .font(.system(size: 18, weight: .bold))
            HStack {
                Label("\(durationMinutes) 分钟", systemImage: "timer")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Menu("从模板开始") {
                    Button("空白训练") { exercises = [] }
                    ForEach(availableTemplates) { template in
                        Button(template.title) { applyTemplate(template) }
                    }
                }
                .font(.system(size: 13, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("自觉竭力程度 (RPE):")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    Text("\(Int(exertionScore)) / 10")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.accent)
                }
                Slider(value: $exertionScore, in: 1...10, step: 1)
                    .tint(VelaTheme.accent)
                Text("1 = 极轻松，10 = 力竭且无任何保留组。用于重算今日负荷。")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(.top, 4)

            TextField("训练备注（可选）", text: $notes, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(2...4)
        }
        .padding(16)
        .velaNativeCard(radius: 16)
    }

    private func exerciseCard(exercise: Binding<StrengthExerciseLog>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("动作名称，例如卧推", text: exercise.name)
                    .font(.system(size: 16, weight: .bold))
                if exercises.count > 1 {
                    Button {
                        exercises.removeAll { $0.id == exercise.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("器械", selection: exercise.equipment) {
                ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            if let previous = previousPerformance(for: exercise.wrappedValue.name) {
                Text("上次表现：\(previous)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
            }

            ForEach(exercise.sets) { set in
                strengthSetRow(set: set, exercise: exercise)
            }

            Button {
                exercise.wrappedValue.sets.append(StrengthSetLog(repetitions: 10, weightKilograms: 20.0, isWarmup: false, rpe: nil, rir: nil, isCompleted: false, completedAt: nil))
            } label: {
                Label("添加一组", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
            }
            .buttonStyle(.plain)

            if let last = exercise.wrappedValue.sets.last {
                Button {
                    var copy = last
                    copy.id = UUID()
                    copy.isCompleted = false
                    copy.completedAt = nil
                    exercise.wrappedValue.sets.append(copy)
                } label: {
                    Label("复制上一组", systemImage: "plus.square.on.square")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .velaNativeCard(radius: 16)
    }

    private func strengthSetRow(
        set: Binding<StrengthSetLog>,
        exercise: Binding<StrengthExerciseLog>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Toggle("热身", isOn: set.isWarmup)
                    .font(.system(size: 11, weight: .medium))
                    .toggleStyle(.button)

                TextField("kg", value: set.weightKilograms, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 62)

                Text("kg ×")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)

                Stepper("\(set.wrappedValue.repetitions)", value: set.repetitions, in: 1...100)
                    .font(.system(size: 12, weight: .semibold))

                Button {
                    complete(set: set, in: exercise)
                } label: {
                    Image(systemName: (set.wrappedValue.isCompleted ?? false) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle((set.wrappedValue.isCompleted ?? false) ? VelaTheme.success : VelaTheme.accent)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                quickAdjust("-2.5") { set.wrappedValue.weightKilograms = max(0, set.wrappedValue.weightKilograms - 2.5) }
                quickAdjust("+2.5") { set.wrappedValue.weightKilograms += 2.5 }
                quickAdjust("-1次") { set.wrappedValue.repetitions = max(1, set.wrappedValue.repetitions - 1) }
                quickAdjust("+1次") { set.wrappedValue.repetitions += 1 }
                Spacer()
                Menu("RPE \(set.wrappedValue.rpe.map { String(Int($0)) } ?? "-")") {
                    ForEach(6...10, id: \.self) { value in
                        Button("\(value)") { set.wrappedValue.rpe = Double(value) }
                    }
                }
                Menu("RIR \(set.wrappedValue.rir.map { String(Int($0)) } ?? "-")") {
                    ForEach(0...5, id: \.self) { value in
                        Button("\(value)") { set.wrappedValue.rir = Double(value) }
                    }
                }
                if exercise.wrappedValue.sets.count > 1 {
                    Button {
                        exercise.wrappedValue.sets.removeAll { $0.id == set.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(VelaTheme.meta)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 11, weight: .bold))
        }
    }

    private var validExercises: [StrengthExerciseLog] {
        exercises.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func requestSave() {
        if hasUncompletedSets {
            showIgnoreUncompletedConfirmation = true
        } else {
            save(ignoringUncompletedSets: false)
        }
    }

    private func save(ignoringUncompletedSets: Bool) {
        let exercisesToSave = ignoringUncompletedSets ? completedOnlyExercises : validExercises
        let record = StrengthWorkoutRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "力量训练" : title,
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: exercisesToSave
        )
        modelContext.insert(record)
        do {
            let analysis = TrainingAnalyticsService().summarizeWorkout(
                record,
                history: workoutHistory,
                exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
            )
            record.analyticsJSON = (try? String(data: JSONEncoder().encode(analysis), encoding: .utf8)) ?? "{}"
            _ = try WorkoutAggregationService.shared.upsertWorkoutEvent(
                from: record,
                modelContext: modelContext,
                sessionRPE: exertionScore
            )
            
            // Delete drafts
            clearDraft()
            
            VelaAppState.shared.markLocalDataChanged()
            completedWorkout = record
            completedSummary = analysis
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
        } catch {
            modelContext.delete(record)
            saveError = "训练暂时无法保存，请稍后再试。\(error.localizedDescription)"
        }
    }

    private func addExercise(_ definition: ExerciseDefinitionRecord) {
        let previousSets = previousCompletedSets(for: definition.name)
        let seedSets = previousSets.isEmpty
            ? [StrengthSetLog(repetitions: 10, weightKilograms: 20.0, isWarmup: false, rpe: nil, rir: nil, isCompleted: false, completedAt: nil)]
            : previousSets.prefix(3).map {
                StrengthSetLog(
                    repetitions: $0.repetitions,
                    weightKilograms: $0.weightKilograms,
                    isWarmup: false,
                    rpe: $0.rpe,
                    rir: $0.rir,
                    isCompleted: false,
                    completedAt: nil
                )
            }
        exercises.append(StrengthExerciseLog(
            exerciseDefinitionId: definition.id,
            exerciseCanonicalKey: definition.canonicalKey,
            name: definition.name,
            equipment: localizedEquipment(definition.equipment),
            primaryMuscleGroup: definition.primaryMuscleGroup,
            sets: Array(seedSets)
        ))
    }

    private func applyTemplate(_ template: WorkoutTemplateRecord) {
        title = template.title
        template.lastUsedAt = Date()
        template.updatedAt = Date()
        exercises = template.exercises.map { item in
            var definition: ExerciseDefinitionRecord?
            if let defKey = item.exerciseCanonicalKey {
                let descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
                    predicate: #Predicate<ExerciseDefinitionRecord> { $0.canonicalKey == defKey }
                )
                definition = try? modelContext.fetch(descriptor).first
            }
            if definition == nil {
                let descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
                    predicate: #Predicate<ExerciseDefinitionRecord> { $0.name == item.name }
                )
                definition = try? modelContext.fetch(descriptor).first
            }
            
            let libDef = ExerciseLibraryService.defaultDefinitions().first {
                if let defKey = item.exerciseCanonicalKey { return $0.canonicalKey == defKey }
                return $0.name == item.name
            }
            
            let finalId = definition?.id ?? libDef?.id
            let finalKey = definition?.canonicalKey ?? libDef?.canonicalKey
            
            let reps = Int(item.targetReps) ?? (item.targetReps.components(separatedBy: CharacterSet.decimalDigits.inverted).first.flatMap(Int.init) ?? 10)
            
            let previousSets = previousCompletedSets(for: item.name)
            let defaultWeight = previousSets.first?.weightKilograms ?? 20.0
            return StrengthExerciseLog(
                exerciseDefinitionId: finalId,
                exerciseCanonicalKey: finalKey,
                name: item.name,
                equipment: localizedEquipment(definition?.equipment ?? libDef?.equipment ?? "other"),
                primaryMuscleGroup: definition?.primaryMuscleGroup ?? libDef?.primaryMuscleGroup,
                sets: (0..<max(1, item.targetSets)).map { index in
                    let previous = index < previousSets.count ? previousSets[index] : nil
                    return StrengthSetLog(
                        repetitions: previous?.repetitions ?? reps,
                        weightKilograms: previous?.weightKilograms ?? defaultWeight,
                        isWarmup: false,
                        rpe: previous?.rpe ?? item.targetRPE,
                        rir: previous?.rir,
                        isCompleted: false,
                        completedAt: nil
                    )
                }
            )
        }
    }

    private var availableTemplates: [WorkoutTemplateRecord] {
        let persistedTitles = Set(persistedTemplates.map(\.title))
        return persistedTemplates + ExerciseLibraryService.defaultTemplates().filter { !persistedTitles.contains($0.title) }
    }

    private func localizedEquipment(_ value: String) -> String {
        switch value.lowercased() {
        case "barbell": return "杠铃"
        case "dumbbell": return "哑铃"
        case "machine": return "固定器械"
        case "cable": return "绳索"
        case "kettlebell": return "壶铃"
        case "bodyweight": return "自重"
        default: return "其他"
        }
    }

    private func previousPerformance(for exerciseName: String) -> String? {
        let sets = previousCompletedSets(for: exerciseName)
        guard !sets.isEmpty else {
            return nil
        }
        return sets.prefix(3).map {
            "\($0.weightKilograms.formatted(.number.precision(.fractionLength(0...1))))kg × \($0.repetitions)"
        }.joined(separator: "，")
    }

    private func previousCompletedSets(for exerciseName: String) -> [StrengthSetLog] {
        StrengthWorkoutSessionPrefill.previousCompletedSets(for: exerciseName, in: workoutHistory)
    }

    private func complete(set: Binding<StrengthSetLog>, in exercise: Binding<StrengthExerciseLog>) {
        set.wrappedValue.isCompleted = !(set.wrappedValue.isCompleted ?? false)
        set.wrappedValue.completedAt = (set.wrappedValue.isCompleted ?? false) ? Date() : nil
        sessionViewModel.saveImmediately { saveDraft() }
        guard set.wrappedValue.isCompleted ?? false,
              let index = exercise.wrappedValue.sets.firstIndex(where: { $0.id == set.wrappedValue.id }) else { return }
        restTimer = RestTimerState(endsAt: Date().addingTimeInterval(90), exerciseName: exercise.wrappedValue.name, setNumber: index + 1)
        restSecondsRemaining = 90
    }

    private func quickAdjust(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }

    private func restTimerCard(_ timer: RestTimerState) -> some View {
        HStack {
            Image(systemName: "timer")
            Text("\(timer.exerciseName) 第 \(timer.setNumber) 组休息")
            Spacer()
            Text("\(restSecondsRemaining)s").monospacedDigit()
            Button("跳过") { restTimer = nil }
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(VelaTheme.accent)
        .padding(14)
        .velaNativeCard(radius: 16)
    }

    private func saveCompletedWorkoutAsTemplate() {
        guard let workout = completedWorkout else { return }
        modelContext.insert(WorkoutTemplateRecord(
            title: workout.title,
            goal: "custom",
            notes: workout.notes,
            exercises: workout.exercises.map {
                WorkoutTemplateExercise(
                    exerciseDefinitionId: $0.exerciseDefinitionId,
                    exerciseCanonicalKey: $0.exerciseCanonicalKey,
                    name: $0.name,
                    targetSets: max(1, $0.sets.filter { !($0.isWarmup) }.count),
                    targetReps: $0.sets.first.map { "\($0.repetitions)" } ?? "8-12",
                    targetRPE: $0.sets.compactMap(\.rpe).first,
                    restSeconds: 90
                )
            },
            estimatedDurationMinutes: workout.durationMinutes
        ))
        try? modelContext.save()
    }

    // MARK: - Draft Autosave Mechanism

    private func loadDraftIfNeeded() {
        let descriptor = FetchDescriptor<ActiveWorkoutDraftRecord>()
        if let draft = (try? modelContext.fetch(descriptor))?.first {
            self.title = draft.title
            self.startedAt = draft.startedAt
            self.notes = draft.notes
            self.exercises = draft.exercises
        } else if let startingTemplateID,
                  let template = availableTemplates.first(where: { $0.id == startingTemplateID }) {
            self.startedAt = Date()
            applyTemplate(template)
        }
        self.isLoaded = true
    }

    private func saveDraft() {
        guard isLoaded else { return }
        let descriptor = FetchDescriptor<ActiveWorkoutDraftRecord>()
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.title = title
            existing.startedAt = startedAt
            existing.notes = notes
            existing.exercises = exercises
            existing.lastUpdated = Date()
        } else {
            let draft = ActiveWorkoutDraftRecord(
                title: title,
                startedAt: startedAt,
                notes: notes
            )
            draft.exercises = exercises
            modelContext.insert(draft)
        }
        try? modelContext.save()
    }

    private func scheduleDraftSave() {
        guard isLoaded else { return }
        sessionViewModel.scheduleDraftSave { saveDraft() }
    }

    private var hasUncompletedSets: Bool {
        validExercises.flatMap(\.sets).contains { $0.isCompleted != true }
    }

    private var completedOnlyExercises: [StrengthExerciseLog] {
        validExercises.compactMap { exercise in
            var copy = exercise
            copy.sets = exercise.sets.filter { $0.isCompleted == true }
            return copy.sets.isEmpty ? nil : copy
        }
    }

    private func discardWorkout() {
        clearDraft()
        dismiss()
    }

    private func clearDraft() {
        let descriptor = FetchDescriptor<ActiveWorkoutDraftRecord>()
        if let drafts = try? modelContext.fetch(descriptor) {
            for draft in drafts {
                modelContext.delete(draft)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseDefinitionRecord.name) private var customDefinitions: [ExerciseDefinitionRecord]
    @State private var query = ""
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
                            Text("\(definition.primaryMuscleGroup) · \(definition.equipment)")
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
                        try? modelContext.save()
                        onSelect(definition)
                        dismiss()
                    }
                }
            }
            .searchable(text: $query, prompt: "搜索动作或肌群")
            .navigationTitle("添加动作")
        }
        .task {
            try? ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: modelContext)
        }
    }
}

// MARK: - Strength Workout Summary Sheet

struct StrengthWorkoutSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    let summary: StrengthWorkoutAnalysis
    let workout: StrengthWorkoutRecord?
    let onSaveTemplate: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(workout?.title ?? "训练总结")
                        .font(.system(size: 24, weight: .bold))
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
                    summaryCard("肌群组数", summary.muscleGroupSets.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value) 组" }.joined(separator: "\n"))
                    summaryCard("e1RM", summary.estimatedOneRepMaxByExercise.sorted { $0.key < $1.key }.map { "\($0.key): \(Int($0.value.rounded())) kg" }.joined(separator: "\n"))
                    summaryCard("PR", summary.personalRecords.isEmpty ? "历史数据不足，完成更多训练后会自动识别 PR。" : summary.personalRecords.map(\.summary).joined(separator: "\n"))
                    summaryCard("恢复建议", "恢复是成长的一部分。建议今晚优先保证 8 小时高质量睡眠。局部肌群在 48 小时内仍处于超补偿重建期，尽量避免对同一肌群的连续力竭刺激。")
                    summaryCard("饮食建议", "训练后 2 小时是营养合成窗口期，补充 30g 优质蛋白质与充足碳水（比例约 1:3 ），加速糖原储备重建，促进肌肉纤维修复。")
                    summaryCard("下次训练建议", "配合智能负荷监控，当明天 HRV 恢复正常、主观酸痛减轻后可进行下一部位的力量训练。")
                    Button("保存为模板", action: onSaveTemplate)
                        .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .scrollContentBackground(.hidden)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("Workout Summary")
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
}

extension StrengthWorkoutAnalysis: Identifiable {
    public var id: String { summaryText + "\(totalSets)" }
}
