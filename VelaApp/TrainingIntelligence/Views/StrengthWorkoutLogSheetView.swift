import SwiftUI
import SwiftData
import Combine

struct StrengthWorkoutLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var workoutHistory: [StrengthWorkoutRecord]
    @Query(sort: \WorkoutTemplateRecord.title) private var persistedTemplates: [WorkoutTemplateRecord]
    @Query private var deletedWorkouts: [DeletedWorkoutRecord]
    
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
    private let initialDraft: TrainingSessionDraft?
    private let editingWorkout: StrengthWorkoutRecord?
    private let equipmentOptions = ["杠铃", "哑铃", "固定器械", "绳索", "壶铃", "自重", "其他"]
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        startingTemplateID: UUID? = nil,
        initialDraft: TrainingSessionDraft? = nil,
        editingWorkout: StrengthWorkoutRecord? = nil
    ) {
        self.startingTemplateID = startingTemplateID
        self.initialDraft = initialDraft
        self.editingWorkout = editingWorkout
    }

    private var durationMinutes: Int {
        max(1, Int(now.timeIntervalSince(startedAt) / 60))
    }

    private var completedSetCount: Int {
        exercises.flatMap(\.sets).filter { $0.isCompleted == true }.count
    }

    private var totalSetCount: Int {
        exercises.flatMap(\.sets).count
    }

    private var setProgressText: String {
        totalSetCount == 0 ? "未添加组" : "\(completedSetCount)/\(totalSetCount) 组"
    }

    private var hasMeaningfulDraft: Bool {
        guard editingWorkout == nil else { return false }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if title.trimmingCharacters(in: .whitespacesAndNewlines) != "力量训练" { return true }
        return exercises.contains { exercise in
            !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !exercise.sets.isEmpty
        }
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
                    .buttonStyle(.cardPress)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle(editingWorkout != nil ? "编辑力量训练" : "记录力量训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(editingWorkout == nil ? "关闭" : "取消") { requestClose() }
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
        .confirmationDialog("要关闭这次训练吗？", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("保存草稿并关闭") {
                saveDraft()
                dismiss()
            }
            Button("丢弃草稿", role: .destructive) { discardWorkout() }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text("已记录的动作和组次可以保留为草稿，下次打开会继续显示。")
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
            HStack(spacing: 10) {
                Label("\(durationMinutes) 分钟", systemImage: "timer")
                Label(setProgressText, systemImage: "checkmark.circle")
                Spacer()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(VelaTheme.muted)

            TextField("训练名称", text: $title)
                .font(.system(size: 18, weight: .bold))
            HStack {
                Spacer()
                Menu("从模板开始") {
                    Button("空白训练") { exercises = [] }
                    ForEach(availableTemplates) { template in
                        Menu(localizedWorkoutTemplateTitle(template.title)) {
                            Button("应用模板") { applyTemplate(template) }
                            Button("删除模板", role: .destructive) { deleteTemplate(template) }
                        }
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
                    .buttonStyle(.cardPress)
                }
            }

            Picker("器械", selection: exercise.equipment) {
                ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            let previousSets = previousCompletedSets(for: exercise.wrappedValue.name)
            if !previousSets.isEmpty {
                Text("上次表现：\(previousPerformance(for: exercise.wrappedValue.name) ?? "")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
            }

            // Set Table Header (Xunji style)
            if !exercise.wrappedValue.sets.isEmpty {
                HStack(spacing: 12) {
                    Text("组")
                        .frame(width: 32, alignment: .leading)
                    Text("前次")
                        .frame(width: 70, alignment: .leading)
                    Text("重量(kg)")
                        .frame(width: 70, alignment: .center)
                    Spacer()
                    Text("次数")
                        .frame(width: 50, alignment: .center)
                    Text("RPE")
                        .frame(width: 44, alignment: .center)
                    Text("状态")
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }

            ForEach(Array(exercise.wrappedValue.sets.enumerated()), id: \.element.id) { index, item in
                strengthSetRow(
                    index: index,
                    set: Binding(
                        get: { exercise.wrappedValue.sets[index] },
                        set: { exercise.wrappedValue.sets[index] = $0 }
                    ),
                    exercise: exercise,
                    previousSets: previousSets
                )
            }

            HStack(spacing: 16) {
                Button {
                    let lastWeight = exercise.wrappedValue.sets.last?.weightKilograms ?? 0
                    let lastReps = exercise.wrappedValue.sets.last?.repetitions ?? 10
                    exercise.wrappedValue.sets.append(StrengthSetLog(repetitions: lastReps, weightKilograms: lastWeight, isWarmup: false, rpe: nil, rir: nil, isCompleted: false, completedAt: nil))
                } label: {
                    Label("添加一组", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.cardPress)

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
                    .buttonStyle(.cardPress)
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .velaNativeCard(radius: 16)
    }

    private func strengthSetRow(
        index: Int,
        set: Binding<StrengthSetLog>,
        exercise: Binding<StrengthExerciseLog>,
        previousSets: [StrengthSetLog]
    ) -> some View {
        let prevText: String
        if index < previousSets.count {
            let prev = previousSets[index]
            prevText = "\(prev.weightKilograms.formatted(.number.precision(.fractionLength(0...1))))×\(prev.repetitions)"
        } else {
            prevText = "—"
        }

        return HStack(spacing: 12) {
            // 组号 / 热身标记
            Button {
                set.wrappedValue.isWarmup.toggle()
                scheduleDraftSave()
            } label: {
                Text(set.wrappedValue.isWarmup ? "热" : "\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(set.wrappedValue.isWarmup ? Color(hex: "#FF9500") : VelaTheme.accent))
            }
            .buttonStyle(.cardPress)
            .frame(width: 32, alignment: .leading)

            // 前次表现
            Text(prevText)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(VelaTheme.muted)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)

            // 重量输入
            TextField("0", value: set.weightKilograms, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
                .frame(width: 70)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .onChange(of: set.wrappedValue.weightKilograms) { _, _ in scheduleDraftSave() }

            Spacer()

            // 次数输入
            TextField("0", value: set.repetitions, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
                .frame(width: 50)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .onChange(of: set.wrappedValue.repetitions) { _, _ in scheduleDraftSave() }

            // RPE 菜单选择
            Menu {
                Button("无") { 
                    set.wrappedValue.rpe = nil
                    scheduleDraftSave()
                }
                ForEach((5...10).reversed(), id: \.self) { val in
                    Button("RPE \(val)") { 
                        set.wrappedValue.rpe = Double(val)
                        scheduleDraftSave()
                    }
                }
            } label: {
                Text(set.wrappedValue.rpe.map { "\(Int($0))" } ?? "RPE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(set.wrappedValue.rpe != nil ? VelaTheme.accent : VelaTheme.muted)
                    .frame(width: 44, height: 26)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))
            }
            .buttonStyle(.cardPress)

            // 完成状态
            Button {
                complete(set: set, in: exercise)
            } label: {
                Image(systemName: (set.wrappedValue.isCompleted ?? false) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle((set.wrappedValue.isCompleted ?? false) ? VelaTheme.success : VelaTheme.accent)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.cardPress)
            .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(set.wrappedValue.isWarmup ? "设为正式组" : "设为热身组") {
                set.wrappedValue.isWarmup.toggle()
                scheduleDraftSave()
            }
            
            if exercise.wrappedValue.sets.count > 1 {
                Button("删除此组", role: .destructive) {
                    exercise.wrappedValue.sets.removeAll { $0.id == set.wrappedValue.id }
                    scheduleDraftSave()
                }
            }
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
        let validation = StrengthWorkoutSaveValidator.exercisesToSave(
            from: exercises,
            ignoringUncompletedSets: ignoringUncompletedSets
        )
        let exercisesToSave: [StrengthExerciseLog]
        switch validation {
        case .success(let validatedExercises):
            exercisesToSave = validatedExercises
        case .failure(.emptyCompletedSets):
            saveError = "至少完成一组后才能保存训练。"
            return
        }
        
        if let editingWorkout {
            let previousStartDate = editingWorkout.startedAt
            editingWorkout.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "力量训练" : title
            editingWorkout.startedAt = startedAt
            editingWorkout.durationMinutes = durationMinutes
            editingWorkout.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editingWorkout.exercises = exercisesToSave
            editingWorkout.completedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            
            do {
                let analysis = TrainingAnalyticsService().summarizeWorkout(
                    editingWorkout,
                    history: workoutHistory.filter { $0.id != editingWorkout.id },
                    exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
                )
                editingWorkout.analyticsJSON = (try? String(data: JSONEncoder().encode(analysis), encoding: .utf8)) ?? "{}"
                
                _ = try WorkoutSaveCoordinator().commitWorkoutEdit(
                    workout: editingWorkout,
                    previousStartDate: previousStartDate,
                    sessionRPE: exertionScore,
                    modelContext: modelContext
                )
                
                VelaAppState.shared.markLocalDataChanged()
                completedWorkout = editingWorkout
                completedSummary = analysis
                Task {
                    await dashboardVM.refresh(modelContext: modelContext)
                }
            } catch {
                saveError = "训练更新失败，请稍后再试。\(error.localizedDescription)"
            }
        } else {
            let record = StrengthWorkoutRecord(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "力量训练" : title,
                startedAt: startedAt,
                durationMinutes: durationMinutes,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                exercises: exercisesToSave
            )
            record.planDayId = initialDraft?.planDayId
            do {
                let analysis = TrainingAnalyticsService().summarizeWorkout(
                    record,
                    history: workoutHistory,
                    exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
                )
                record.analyticsJSON = (try? String(data: JSONEncoder().encode(analysis), encoding: .utf8)) ?? "{}"
                let workoutIdStr = record.id.uuidString
                let existingArtifacts = try? modelContext.fetch(FetchDescriptor<CoachArtifactRecord>())
                if let existing = existingArtifacts {
                    for art in existing {
                        if art.actionsJSON.contains(workoutIdStr) {
                            modelContext.delete(art)
                        }
                    }
                }
                
                let planDayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: record.startedAt)
                let planDescriptor = FetchDescriptor<DailyOperatingPlanRecord>(
                    predicate: #Predicate<DailyOperatingPlanRecord> {
                        $0.dayIdentifier == planDayIdentifier
                    }
                )
                let readinessDecision = (try? modelContext.fetch(planDescriptor))?.first?.primaryActionType
                    ?? dashboardVM.dashboard.trainingDecision.kind.rawValue
                let artifact = CoachArtifact.postWorkoutReview(
                    workout: record,
                    summary: analysis,
                    readinessDecision: readinessDecision,
                    sourceContextHash: ContentHash.hash("\(record.id.uuidString)-\(record.analyticsJSON ?? "")")
                )
                _ = try WorkoutSaveCoordinator().commitNewWorkout(
                    workout: record,
                    artifact: CoachArtifactRecord(artifact: artifact),
                    sessionRPE: exertionScore,
                    modelContext: modelContext
                )
                
                VelaAppState.shared.markLocalDataChanged()
                completedWorkout = record
                completedSummary = analysis
                Task {
                    await dashboardVM.refresh(modelContext: modelContext)
                }
            } catch {
                saveError = "训练暂时无法保存，请稍后再试。\(error.localizedDescription)"
            }
        }
    }

    private func addExercise(_ definition: ExerciseDefinitionRecord) {
        let previousSets = previousCompletedSets(for: definition.name)
        let seedSets = previousSets.isEmpty
            ? [StrengthSetLog(
                repetitions: 10,
                weightKilograms: ExerciseLoadDefaults.initialWeight(
                    equipment: definition.equipment,
                    exerciseName: definition.name,
                    previousSets: []
                ),
                isWarmup: false,
                rpe: nil,
                rir: nil,
                isCompleted: false,
                completedAt: nil
            )]
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
        title = localizedWorkoutTemplateTitle(template.title)
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
            
            let reps = StrengthWorkoutTemplateParser.reps(from: item.targetReps)
            
            let previousSets = previousCompletedSets(for: item.name)
            let defaultWeight = ExerciseLoadDefaults.initialWeight(
                equipment: definition?.equipment ?? libDef?.equipment ?? "other",
                exerciseName: item.name,
                previousSets: previousSets
            )
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
        let deletedTemplateTitles = Set(deletedWorkouts.compactMap { rec -> String? in
            if rec.id.hasPrefix("template:") {
                return String(rec.id.dropFirst("template:".count))
            }
            return nil
        })
        let persistedTitles = Set(persistedTemplates.map(\.title))
        let filteredPersisted = persistedTemplates.filter { !deletedTemplateTitles.contains($0.title) }
        let filteredDefaults = ExerciseLibraryService.defaultTemplates().filter {
            !persistedTitles.contains($0.title) && !deletedTemplateTitles.contains($0.title)
        }
        return filteredPersisted + filteredDefaults
    }

    private func deleteTemplate(_ template: WorkoutTemplateRecord) {
        modelContext.insert(DeletedWorkoutRecord(id: "template:\(template.title)"))
        modelContext.delete(template)
        try? modelContext.save()
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
        
        var restDuration = 90
        if let plan = try? modelContext.fetch(FetchDescriptor<TrainingPlanRecord>(predicate: #Predicate { $0.isActive })).first {
            let todayWeekday = Calendar.current.component(.weekday, from: Date())
            let dayNum = todayWeekday == 1 ? 7 : todayWeekday - 1
            if let day = plan.days.first(where: { $0.dayNumber == dayNum }),
               let data = day.plannedExercisesJSON.data(using: .utf8),
               let planned = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data),
               let match = planned.first(where: { $0.name.caseInsensitiveCompare(exercise.wrappedValue.name) == .orderedSame }) {
                restDuration = match.restSeconds
            }
        }
        
        restTimer = RestTimerState(endsAt: Date().addingTimeInterval(TimeInterval(restDuration)), exerciseName: exercise.wrappedValue.name, setNumber: index + 1)
        restSecondsRemaining = restDuration
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
                .buttonStyle(.cardPress)
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(VelaTheme.accent)
        .padding(14)
        .velaNativeCard(radius: 16)
        .appleIntelligenceGlow(isHighlighted: true, radius: 16)
    }

    private func saveCompletedWorkoutAsTemplate() -> Bool {
        guard let workout = completedWorkout else { return false }
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
        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Draft Autosave Mechanism

    private func loadDraftIfNeeded() {
        if let editingWorkout {
            self.title = editingWorkout.title
            self.startedAt = editingWorkout.startedAt
            self.notes = editingWorkout.notes
            self.exercises = editingWorkout.exercises
            if let eventID = editingWorkout.linkedWorkoutEventId {
                let descriptor = FetchDescriptor<WorkoutEventRecord>(
                    predicate: #Predicate<WorkoutEventRecord> { $0.id == eventID }
                )
                if let event = (try? modelContext.fetch(descriptor))?.first {
                    self.exertionScore = event.rpe ?? 7.0
                }
            }
        } else if let initialDraft {
            self.title = initialDraft.title
            self.startedAt = initialDraft.startedAt
            self.notes = initialDraft.notes
            self.exercises = initialDraft.exercises
            self.exertionScore = initialDraft.exercises
                .flatMap(\.sets)
                .compactMap(\.rpe)
                .max() ?? 7
        } else {
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
        }
        self.isLoaded = true
    }

    private func saveDraft() {
        guard isLoaded && editingWorkout == nil else { return }
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
        guard isLoaded && editingWorkout == nil else { return }
        sessionViewModel.scheduleDraftSave { saveDraft() }
    }

    private var hasUncompletedSets: Bool {
        validExercises.flatMap(\.sets).contains { $0.isCompleted != true }
    }

    private func requestClose() {
        if editingWorkout != nil {
            dismiss()
            return
        }
        if hasMeaningfulDraft {
            showDiscardConfirmation = true
        } else {
            clearDraft()
            dismiss()
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

