import SwiftUI
import SwiftData

struct CoachArtifactInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]
    
    @State private var selectedWorkoutForDetail: WorkoutSummary?
    
    var body: some View {
        List {
            if coachArtifacts.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 40)
                    Image(systemName: "tray.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(VelaTheme.muted)
                    Text("收件箱为空")
                        .font(VelaTheme.headline())
                        .foregroundStyle(VelaTheme.fg)
                    Text("与 Coach 聊天、记录训练或查看每日健康分析后，将在此处收到主动生成的分析简报与优化建议。")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(coachArtifacts) { record in
                    Section {
                        CoachArtifactCard(artifact: record.artifact, compact: false) { action in
                            handleArtifactAction(action, artifact: record.artifact)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(VelaTheme.rhythmCanvas)
        .scrollContentBackground(.hidden)
        .navigationTitle("AI 建议收件箱")
        .velaRhythmDetailChrome()
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
        .onAppear {
            deduplicateArtifacts()
        }
    }

    private func deduplicateArtifacts() {
        guard let records = try? modelContext.fetch(FetchDescriptor<CoachArtifactRecord>()) else { return }
        
        var workoutArtifacts: [String: [CoachArtifactRecord]] = [:]
        var dateTypeArtifacts: [String: [CoachArtifactRecord]] = [:]
        let calendar = Calendar.current
        
        for record in records {
            if record.type == CoachArtifactType.postWorkoutReview.rawValue {
                if let workoutID = extractWorkoutID(from: record.actionsJSON) {
                    workoutArtifacts[workoutID, default: []].append(record)
                }
            } else {
                let dateStr = calendar.startOfDay(for: record.createdAt).description
                let key = "\(record.type)-\(dateStr)"
                dateTypeArtifacts[key, default: []].append(record)
            }
        }
        
        for (_, list) in workoutArtifacts where list.count > 1 {
            let sorted = list.sorted { $0.createdAt > $1.createdAt }
            for dup in sorted.dropFirst() {
                modelContext.delete(dup)
            }
        }
        
        for (_, list) in dateTypeArtifacts where list.count > 1 {
            let sorted = list.sorted { $0.createdAt > $1.createdAt }
            for dup in sorted.dropFirst() {
                modelContext.delete(dup)
            }
        }
        
        try? modelContext.save()
    }
    
    private func extractWorkoutID(from json: String) -> String? {
        guard let range = json.range(of: "\"workout_id\":\"") else { return nil }
        let startIndex = range.upperBound
        guard let endIndex = json[startIndex...].firstIndex(of: "\"") else { return nil }
        return String(json[startIndex..<endIndex])
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        VelaAppState.shared.logDebug("[CoachArtifactInboxView] handleArtifactAction: type=\(action.type), label=\(action.label), payload=\(action.payload)")
        if action.type == "start_check_in" {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Opening post-workout check-in")
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Opening post-workout impact")
            VelaAppState.shared.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        } else if let workoutIDString = action.payload["workout_id"],
           let id = UUID(uuidString: workoutIDString) {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Found workout_id: \(workoutIDString)")
            let descriptor = FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.id == id }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                let summary = WorkoutSummary(
                    id: record.id,
                    start: record.startedAt,
                    end: record.startedAt.addingTimeInterval(TimeInterval(record.durationMinutes * 60)),
                    activityName: record.title,
                    source: "strengthLog"
                )
                VelaAppState.shared.logDebug("[CoachArtifactInboxView] Setting selectedWorkoutForDetail: \(record.title)")
                selectedWorkoutForDetail = summary
            } else {
                VelaAppState.shared.logDebug("[CoachArtifactInboxView] Workout record not found for id: \(id)")
            }
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to recovery (tab 2)")
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to training (tab 1)")
            VelaAppState.shared.routeToTraining()
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Triggering journal")
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to coach: \(action.label)")
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }
}

struct CoachArtifactDetailWrapper: View {
    @Environment(\.modelContext) private var modelContext
    let artifact: CoachArtifact
    @State private var selectedWorkoutForDetail: WorkoutSummary?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoachArtifactCard(artifact: artifact, compact: false) { action in
                    handleArtifactAction(action, artifact: artifact)
                }
                .padding(16)
            }
        }
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle(artifact.title)
        .velaRhythmDetailChrome()
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] handleArtifactAction: type=\(action.type), label=\(action.label), payload=\(action.payload)")
        if action.type == "start_check_in" {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Opening post-workout check-in")
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Opening post-workout impact")
            VelaAppState.shared.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        } else if let workoutIDString = action.payload["workout_id"],
           let id = UUID(uuidString: workoutIDString) {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Found workout_id: \(workoutIDString)")
            let descriptor = FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.id == id }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                let summary = WorkoutSummary(
                    id: record.id,
                    start: record.startedAt,
                    end: record.startedAt.addingTimeInterval(TimeInterval(record.durationMinutes * 60)),
                    activityName: record.title,
                    source: "strengthLog"
                )
                VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Setting selectedWorkoutForDetail: \(record.title)")
                selectedWorkoutForDetail = summary
            } else {
                VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Workout record not found for id: \(id)")
            }
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to recovery (tab 2)")
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to training (tab 1)")
            VelaAppState.shared.routeToTraining()
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Triggering journal")
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to coach: \(action.label)")
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }
}
