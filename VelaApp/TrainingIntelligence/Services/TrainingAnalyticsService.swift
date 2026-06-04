import Foundation
import SwiftData

struct TrainingAnalyticsService: Sendable {
    
    init() {}

    func summarizeWorkout(
        _ workout: StrengthWorkoutRecord,
        history: [StrengthWorkoutRecord] = [],
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> StrengthWorkoutAnalysis {
        var volume = 0.0
        var sets = 0
        var effectiveSets = 0
        var reps = 0
        var muscleGroupSets: [String: Int] = [:]
        var muscleGroupVolume: [String: Double] = [:]
        var e1RM: [String: Double] = [:]

        for exercise in workout.exercises {
            let muscle = resolvedMuscleGroup(for: exercise, library: exerciseLibrary)
            for set in exercise.sets {
                sets += 1
                reps += set.repetitions
                let setVolume = set.volumeKilograms
                volume += setVolume
                guard isEffective(set, equipment: exercise.equipment) else { continue }
                effectiveSets += 1
                muscleGroupSets[muscle, default: 0] += 1
                muscleGroupVolume[muscle, default: 0] += setVolume
                if set.repetitions >= 1, set.repetitions <= 12, set.weightKilograms > 0 {
                    let value = set.weightKilograms * (1 + Double(set.repetitions) / 30)
                    e1RM[exercise.name] = max(e1RM[exercise.name] ?? 0, value)
                }
            }
        }

        let records = detectPersonalRecords(workout: workout, history: history)
        let density = workout.durationMinutes > 0 ? volume / Double(workout.durationMinutes) : 0
        let muscleText = muscleGroupSets.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        let summary = "\(workout.title): \(effectiveSets) effective sets, \(Int(volume.rounded())) kg\(muscleText.isEmpty ? "" : ", \(muscleText)")"
        return StrengthWorkoutAnalysis(
            totalVolumeKg: volume,
            totalSets: sets,
            effectiveSets: effectiveSets,
            totalReps: reps,
            muscleGroupSets: muscleGroupSets,
            muscleGroupVolume: muscleGroupVolume,
            estimatedOneRepMaxByExercise: e1RM,
            personalRecords: records,
            densityKgPerMinute: density,
            summaryText: summary
        )
    }

    func detectPersonalRecords(workout: StrengthWorkoutRecord, history: [StrengthWorkoutRecord]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        for exercise in workout.exercises {
            let workSets = exercise.sets.filter { !$0.isWarmup }
            guard let maxWeight = workSets.map(\.weightKilograms).max(), !workSets.isEmpty else { continue }
            let maxE1RM = workSets
                .filter { $0.weightKilograms > 0 && $0.repetitions >= 1 && $0.repetitions <= 12 }
                .map { $0.weightKilograms * (1 + Double($0.repetitions) / 30) }
                .max() ?? 0
            let priorSets = history.flatMap(\.exercises).filter { namesMatch($0.name, exercise.name) }.flatMap(\.sets).filter { !$0.isWarmup }
            guard !priorSets.isEmpty else { continue }
            let priorMaxWeight = priorSets.map(\.weightKilograms).max() ?? 0
            let priorMaxE1RM = priorSets
                .filter { $0.weightKilograms > 0 && $0.repetitions >= 1 && $0.repetitions <= 12 }
                .map { $0.weightKilograms * (1 + Double($0.repetitions) / 30) }
                .max() ?? 0
            if maxWeight > priorMaxWeight {
                records.append(PersonalRecord(exerciseName: exercise.name, kind: "max_weight", value: maxWeight, previousValue: priorMaxWeight))
            }
            if maxE1RM > priorMaxE1RM {
                records.append(PersonalRecord(exerciseName: exercise.name, kind: "estimated_1rm", value: maxE1RM, previousValue: priorMaxE1RM))
            }
        }
        return records
    }

    func buildRecentSummary(
        workouts: [StrengthWorkoutRecord],
        days: Int,
        endingAt: Date = Date(),
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> RecentTrainingSummary {
        let start = endingAt.addingTimeInterval(-Double(days) * 86_400)
        let recent = workouts.filter { $0.startedAt >= start && $0.startedAt <= endingAt }
        guard !recent.isEmpty else { return .empty(days: days) }
        var totalSets = 0
        var totalVolume = 0.0
        var muscles: [String: Int] = [:]
        var records: [PersonalRecord] = []
        for workout in recent {
            let prior = workouts.filter { $0.startedAt < workout.startedAt }
            let analysis = summarizeWorkout(workout, history: prior, exerciseLibrary: exerciseLibrary)
            totalSets += analysis.effectiveSets
            totalVolume += analysis.totalVolumeKg
            records.append(contentsOf: analysis.personalRecords)
            for (muscle, count) in analysis.muscleGroupSets {
                muscles[muscle, default: 0] += count
            }
        }
        let latest = recent.max { $0.startedAt < $1.startedAt }
        return RecentTrainingSummary(
            days: days,
            sessions: recent.count,
            effectiveSets: totalSets,
            volumeKg: totalVolume,
            muscleGroupSets: muscles,
            recentPRs: records,
            lastWorkoutSummary: latest.map { latestWorkout in
                summarizeWorkout(
                    latestWorkout,
                    history: workouts.filter { $0.startedAt < latestWorkout.startedAt },
                    exerciseLibrary: exerciseLibrary
                ).summaryText
            },
            localFatigue: computeLocalFatigue(workouts: workouts, endingAt: endingAt, exerciseLibrary: exerciseLibrary)
        )
    }

    func computeLocalFatigue(
        workouts: [StrengthWorkoutRecord],
        endingAt: Date = Date(),
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> [String: LocalMuscleFatigue] {
        let start7d = endingAt.addingTimeInterval(-7 * 86_400)
        let start48h = endingAt.addingTimeInterval(-48 * 3_600)
        var result: [String: LocalMuscleFatigue] = [:]
        for workout in workouts where workout.startedAt >= start7d && workout.startedAt <= endingAt {
            for exercise in workout.exercises {
                let muscle = resolvedMuscleGroup(for: exercise, library: exerciseLibrary)
                for set in exercise.sets where isEffective(set, equipment: exercise.equipment) {
                    var fatigue = result[muscle] ?? LocalMuscleFatigue(muscleGroup: muscle, setsLast48h: 0, setsLast7d: 0, volumeLast7d: 0)
                    if workout.startedAt >= start48h { fatigue.setsLast48h += 1 }
                    fatigue.setsLast7d += 1
                    fatigue.volumeLast7d += set.volumeKilograms
                    result[muscle] = fatigue
                }
            }
        }
        return result
    }

    private func isEffective(_ set: StrengthSetLog, equipment: String) -> Bool {
        guard !set.isWarmup, set.repetitions >= 3 else { return false }
        let supportsBodyweight = equipment.lowercased().contains("bodyweight") || equipment.contains("自重")
        guard set.weightKilograms > 0 || supportsBodyweight else { return false }
        if let rpe = set.rpe, rpe < 6 { return false }
        if let rir = set.rir, rir > 4 { return false }
        return true
    }

    public func resolvedMuscleGroup(for exercise: StrengthExerciseLog, library: [ExerciseDefinitionRecord]) -> String {
        if let explicit = exercise.primaryMuscleGroup, !explicit.isEmpty { return explicit }
        if let canonicalKey = exercise.exerciseCanonicalKey,
           let definition = library.first(where: { $0.canonicalKey == canonicalKey }) {
            return definition.primaryMuscleGroup
        }
        if let definition = library.first(where: { namesMatch($0.name, exercise.name) || $0.aliases.contains(where: { namesMatch($0, exercise.name) }) }) {
            return definition.primaryMuscleGroup
        }
        let name = exercise.name.lowercased()
        if name.contains("bench") || name.contains("卧推") || name.contains("夹胸") { return "chest" }
        if name.contains("row") || name.contains("划船") || name.contains("下拉") || name.contains("引体") { return "back" }
        if name.contains("squat") || name.contains("深蹲") || name.contains("腿") { return "quads" }
        if name.contains("curl") || name.contains("弯举") { return "biceps" }
        if name.contains("press") || name.contains("推举") || name.contains("侧平举") { return "shoulders" }
        if name.contains("plank") || name.contains("卷腹") { return "core" }
        return "other"
    }

    private func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct XunjiImportSummary: Codable, Hashable, Sendable {
    var importedCount: Int
    var updatedCount: Int
    var skippedCount: Int
    var importedTitles: [String]

    static let empty = XunjiImportSummary(importedCount: 0, updatedCount: 0, skippedCount: 0, importedTitles: [])
}

struct XunjiTrainingAPIClient: Sendable {
    private let baseURL = URL(string: "https://trains.xunjiapp.cn")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchTraining(
        apiKey: String,
        datestr: String,
        includeFullData: Bool
    ) async throws -> Data {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw XunjiAPIError.missingAPIKey }

        var request = URLRequest(url: baseURL.appending(path: "api_trains_for_llm_v2"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(XunjiReadRequest(
            datestr: datestr,
            includeFullData: includeFullData
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw XunjiAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw XunjiAPIError.httpStatus(http.statusCode)
        }
        return data
    }
}

enum XunjiAPIError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先填写训记 Open API Key。"
        case .invalidResponse:
            return "训记接口返回了无法识别的响应。"
        case .httpStatus(let status):
            return "训记接口请求失败（HTTP \(status)）。"
        }
    }
}

private struct XunjiReadRequest: Encodable {
    let schemaVersion = "train_open_api_v2"
    var datestr: String
    var includeFullData: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datestr
        case includeFullData = "include_full_data"
    }
}

struct XunjiTrainingImportService: Sendable {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    @MainActor
    func importResponseData(
        _ data: Data,
        datestr: String,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> XunjiImportSummary {
        let response = try decoder.decode(XunjiTrainingAPIResponse.self, from: data)
        guard response.success else {
            throw XunjiImportError.unsuccessfulResponse
        }

        let trains = response.res.trains.filter { ($0.datestr ?? datestr) == datestr }
        guard !trains.isEmpty else { return .empty }

        let existingMirrors = try modelContext.fetch(FetchDescriptor<XunjiWorkoutMirrorRecord>())
        let existingWorkouts = try modelContext.fetch(FetchDescriptor<StrengthWorkoutRecord>())
        let existingEvents = try modelContext.fetch(FetchDescriptor<WorkoutEventRecord>())
        var imported = 0
        var updated = 0
        var skipped = 0
        var titles: [String] = []

        for train in trains {
            guard let normalized = normalize(train: train, fallbackDatestr: datestr, calendar: calendar) else {
                skipped += 1
                continue
            }

            let rawData = (try? encoder.encode(train)) ?? Data()
            let mirror = existingMirrors.first { $0.externalID == normalized.externalID }
            let workout: StrengthWorkoutRecord
            if let mirror,
               let linkedID = mirror.linkedStrengthWorkoutID,
               let existing = existingWorkouts.first(where: { $0.id == linkedID }) {
                workout = existing
                workout.title = normalized.title
                workout.startedAt = normalized.startedAt
                workout.durationMinutes = normalized.durationMinutes
                workout.notes = normalized.notes
                workout.exercises = normalized.exercises
                workout.completedAt = normalized.startedAt.addingTimeInterval(TimeInterval(normalized.durationMinutes * 60))
                updated += 1
            } else {
                workout = StrengthWorkoutRecord(
                    title: normalized.title,
                    startedAt: normalized.startedAt,
                    durationMinutes: normalized.durationMinutes,
                    notes: normalized.notes,
                    exercises: normalized.exercises
                )
                modelContext.insert(workout)
                imported += 1
            }

            let analysis = TrainingAnalyticsService().summarizeWorkout(
                workout,
                history: existingWorkouts.filter { $0.id != workout.id },
                exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
            )
            workout.analyticsJSON = (try? String(data: encoder.encode(analysis), encoding: .utf8)) ?? "{}"

            let event: WorkoutEventRecord
            if let existingEvent = existingEvents.first(where: { $0.linkedStrengthWorkoutId == workout.id && $0.source == "xunji" }) {
                event = existingEvent
            } else {
                event = WorkoutEventRecord(
                    source: "xunji",
                    startedAt: workout.startedAt,
                    endedAt: workout.endedAt,
                    activityType: "力量训练",
                    title: workout.title,
                    energyKilocalories: nil,
                    averageHeartRate: normalized.averageHeartRate,
                    rpe: normalized.sessionRPE,
                    linkedStrengthWorkoutId: workout.id,
                    calendar: calendar
                )
                modelContext.insert(event)
            }
            event.startedAt = workout.startedAt
            event.endedAt = workout.endedAt
            event.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: workout.startedAt, calendar: calendar)
            event.activityType = "力量训练"
            event.title = workout.title
            event.durationMinutes = Double(workout.durationMinutes)
            event.averageHeartRate = normalized.averageHeartRate
            event.rpe = normalized.sessionRPE
            event.updatedAt = Date()

            if let mirror {
                mirror.datestr = normalized.datestr
                mirror.linkedStrengthWorkoutID = workout.id
                mirror.linkedWorkoutEventID = event.id
                mirror.rawTrainData = rawData
                mirror.lastImportedAt = Date()
            } else {
                modelContext.insert(XunjiWorkoutMirrorRecord(
                    externalID: normalized.externalID,
                    datestr: normalized.datestr,
                    linkedStrengthWorkoutID: workout.id,
                    linkedWorkoutEventID: event.id,
                    rawTrainData: rawData
                ))
            }

            titles.append(workout.title)
        }

        try modelContext.save()
        return XunjiImportSummary(
            importedCount: imported,
            updatedCount: updated,
            skippedCount: skipped,
            importedTitles: titles
        )
    }

    func normalizedWorkouts(
        from data: Data,
        datestr: String,
        calendar: Calendar = .current
    ) throws -> [XunjiNormalizedWorkout] {
        let response = try decoder.decode(XunjiTrainingAPIResponse.self, from: data)
        guard response.success else { throw XunjiImportError.unsuccessfulResponse }
        return response.res.trains.compactMap { normalize(train: $0, fallbackDatestr: datestr, calendar: calendar) }
    }

    private func normalize(
        train: XunjiTrain,
        fallbackDatestr: String,
        calendar: Calendar
    ) -> XunjiNormalizedWorkout? {
        let trainDate = train.datestr ?? fallbackDatestr
        let start = train.startDate ?? dateFrom(datestr: trainDate, calendar: calendar)
        let end = train.endDate ?? start.addingTimeInterval(60 * 60)
        let durationMinutes = max(1, Int(end.timeIntervalSince(start) / 60))
        let exercises = flattenExercises(from: train.movements)
        guard !exercises.isEmpty else { return nil }
        let externalID = train.localid.map(String.init) ?? "\(trainDate)-\(train.title ?? "workout")-\(Int(start.timeIntervalSince1970))"
        let metrics = train.movements.flatMap(\.sets).compactMap(\.metrics)
        let averageHeartRate = metrics.compactMap(\.avgHeartRate).average
        return XunjiNormalizedWorkout(
            externalID: externalID,
            datestr: trainDate,
            title: train.title?.trimmedNonEmpty ?? "训记训练",
            startedAt: start,
            durationMinutes: durationMinutes,
            notes: train.note ?? train.remark ?? "",
            sessionRPE: train.rpe,
            averageHeartRate: averageHeartRate,
            exercises: exercises
        )
    }

    private func flattenExercises(from movements: [XunjiMovement]) -> [StrengthExerciseLog] {
        var grouped: [String: StrengthExerciseLog] = [:]
        var order: [String] = []

        func appendSet(_ set: StrengthSetLog, movementName: String) {
            let name = movementName.trimmedNonEmpty ?? "未命名动作"
            if grouped[name] == nil {
                grouped[name] = StrengthExerciseLog(
                    exerciseCanonicalKey: name.toCanonicalKey(),
                    name: name,
                    equipment: "其他",
                    primaryMuscleGroup: nil,
                    sets: []
                )
                order.append(name)
            }
            grouped[name]?.sets.append(set)
        }

        for movement in movements {
            for set in movement.sets {
                if !set.items.isEmpty {
                    for item in set.items {
                        appendSet(item.set.strengthSet(doneFallback: set.done), movementName: item.name ?? movement.name)
                    }
                } else {
                    appendSet(set.strengthSet(doneFallback: set.done), movementName: movement.name)
                }
            }
        }

        return order.compactMap { grouped[$0] }.filter { !$0.sets.isEmpty }
    }

    private func dateFrom(datestr: String, calendar: Calendar) -> Date {
        var components = DateComponents()
        let parts = datestr.split(separator: "-").compactMap { Int($0) }
        components.year = parts.count > 0 ? parts[0] : nil
        components.month = parts.count > 1 ? parts[1] : nil
        components.day = parts.count > 2 ? parts[2] : nil
        components.hour = 18
        return calendar.date(from: components) ?? Date()
    }
}

enum XunjiImportError: Error {
    case unsuccessfulResponse
}

struct XunjiNormalizedWorkout: Codable, Hashable, Sendable {
    var externalID: String
    var datestr: String
    var title: String
    var startedAt: Date
    var durationMinutes: Int
    var notes: String
    var sessionRPE: Double?
    var averageHeartRate: Double?
    var exercises: [StrengthExerciseLog]
}

private struct XunjiTrainingAPIResponse: Decodable {
    var success: Bool
    var res: XunjiTrainingResult
}

private struct XunjiTrainingResult: Decodable {
    var trains: [XunjiTrain]
}

private struct XunjiTrain: Codable {
    var datestr: String?
    var localid: Int?
    var title: String?
    var start: Int64?
    var end: Int64?
    var note: String?
    var remark: String?
    var rpe: Double?
    var movements: [XunjiMovement]

    var startDate: Date? { start.map { Date(timeIntervalSince1970: Double($0) / 1_000) } }
    var endDate: Date? { end.map { Date(timeIntervalSince1970: Double($0) / 1_000) } }

    enum CodingKeys: String, CodingKey {
        case datestr, localid, title, start, end, note, remark, rpe, movements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        datestr = try container.decodeIfPresent(String.self, forKey: .datestr)
        localid = try container.decodeFlexibleIntIfPresent(forKey: .localid)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        start = try container.decodeFlexibleInt64IfPresent(forKey: .start)
        end = try container.decodeFlexibleInt64IfPresent(forKey: .end)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)
        rpe = try container.decodeFlexibleDoubleIfPresent(forKey: .rpe)
        movements = try container.decodeIfPresent([XunjiMovement].self, forKey: .movements) ?? []
    }
}

private struct XunjiMovement: Codable {
    var name: String
    var sets: [XunjiSet]
}

private struct XunjiSet: Codable {
    var done: Bool?
    var weight: String?
    var weightKg: Double?
    var unit: String?
    var reps: String?
    var time: String?
    var durationSeconds: Double?
    var selfWeight: Bool?
    var rpe: Double?
    var rir: Double?
    var note: String?
    var metrics: XunjiSetMetrics?
    var items: [XunjiSetItem]

    enum CodingKeys: String, CodingKey {
        case done, weight, unit, reps, time, selfWeight, rpe, rir, note, metrics, items
        case weightKg = "weight_kg"
        case durationSeconds = "duration_s"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        done = try container.decodeIfPresent(Bool.self, forKey: .done)
        weight = try container.decodeIfPresent(String.self, forKey: .weight)
        weightKg = try container.decodeFlexibleDoubleIfPresent(forKey: .weightKg)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        reps = try container.decodeIfPresent(String.self, forKey: .reps)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        durationSeconds = try container.decodeFlexibleDoubleIfPresent(forKey: .durationSeconds)
        selfWeight = try container.decodeIfPresent(Bool.self, forKey: .selfWeight)
        rpe = try container.decodeFlexibleDoubleIfPresent(forKey: .rpe)
        rir = try container.decodeFlexibleDoubleIfPresent(forKey: .rir)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        metrics = try container.decodeIfPresent(XunjiSetMetrics.self, forKey: .metrics)
        items = try container.decodeIfPresent([XunjiSetItem].self, forKey: .items) ?? []
    }

    func strengthSet(doneFallback: Bool?) -> StrengthSetLog {
        StrengthSetLog(
            repetitions: reps.flatMap { Int(Double($0) ?? 0) }.flatMap { $0 > 0 ? $0 : nil } ?? 1,
            weightKilograms: resolvedWeightKilograms,
            isWarmup: false,
            rpe: rpe,
            rir: rir,
            isCompleted: done ?? doneFallback,
            completedAt: (done ?? doneFallback) == true ? Date() : nil
        )
    }

    private var resolvedWeightKilograms: Double {
        if let weightKg { return weightKg }
        let numeric = weight.flatMap(Double.init) ?? 0
        guard unit?.lowercased() == "lb" || unit?.lowercased() == "lbs" else { return numeric }
        return numeric * 0.45359237
    }
}

private struct XunjiSetItem: Codable {
    var name: String?
    var set: XunjiSet
}

private struct XunjiSetMetrics: Codable {
    var distance: Double?
    var kcal: Double?
    var calories: Double?
    var workoutTime: Double?
    var avgHeartRate: Double?
    var maxHeartRate: Double?

    enum CodingKeys: String, CodingKey {
        case distance, kcal, calories, workoutTime, avgHeartRate, maxHeartRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distance = try container.decodeFlexibleDoubleIfPresent(forKey: .distance)
        kcal = try container.decodeFlexibleDoubleIfPresent(forKey: .kcal)
        calories = try container.decodeFlexibleDoubleIfPresent(forKey: .calories)
        workoutTime = try container.decodeFlexibleDoubleIfPresent(forKey: .workoutTime)
        avgHeartRate = try container.decodeFlexibleDoubleIfPresent(forKey: .avgHeartRate)
        maxHeartRate = try container.decodeFlexibleDoubleIfPresent(forKey: .maxHeartRate)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeFlexibleInt64IfPresent(forKey key: Key) throws -> Int64? {
        if let value = try decodeIfPresent(Int64.self, forKey: key) { return value }
        if let value = try decodeIfPresent(Int.self, forKey: key) { return Int64(value) }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Int64(value) }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}
