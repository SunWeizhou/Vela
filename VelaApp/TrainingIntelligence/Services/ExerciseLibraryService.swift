import Foundation
import SwiftData

enum ExerciseLibraryService {
    
    static func defaultDefinitions() -> [ExerciseDefinitionRecord] {
        [
            exercise("barbell_bench_press", "杠铃卧推", ["bench press", "卧推"], "chest", ["triceps", "shoulders"], "barbell", "push"),
            exercise("dumbbell_bench_press", "哑铃卧推", ["dumbbell bench press"], "chest", ["triceps"], "dumbbell", "push"),
            exercise("incline_bench_press", "上斜卧推", ["incline press"], "chest", ["shoulders", "triceps"], "barbell", "push"),
            exercise("dips", "双杠臂屈伸", ["dip"], "chest", ["triceps"], "bodyweight", "push"),
            exercise("cable_fly", "绳索夹胸", ["cable fly"], "chest", [], "cable", "isolation"),
            exercise("chest_press", "器械推胸", ["chest press"], "chest", ["triceps"], "machine", "push"),
            exercise("pull_ups", "引体向上", ["pull up", "pullup"], "back", ["biceps"], "bodyweight", "pull"),
            exercise("lat_pulldown", "高位下拉", ["lat pulldown"], "back", ["biceps"], "cable", "pull"),
            exercise("barbell_row", "杠铃划船", ["barbell row"], "back", ["biceps"], "barbell", "pull"),
            exercise("seated_row", "坐姿划船", ["seated row"], "back", ["biceps"], "cable", "pull"),
            exercise("one_arm_dumbbell_row", "单臂哑铃划船", ["one arm dumbbell row"], "back", ["biceps"], "dumbbell", "pull"),
            exercise("deadlift", "硬拉", ["deadlift"], "back", ["glutes", "hamstrings"], "barbell", "hinge"),
            exercise("squat", "深蹲", ["squat"], "quads", ["glutes", "hamstrings"], "barbell", "squat"),
            exercise("leg_press", "腿举", ["leg press"], "quads", ["glutes"], "machine", "squat"),
            exercise("romanian_deadlift", "罗马尼亚硬拉", ["romanian deadlift", "rdl"], "hamstrings", ["glutes"], "barbell", "hinge"),
            exercise("leg_extension", "腿屈伸", ["leg extension"], "quads", [], "machine", "isolation"),
            exercise("leg_curl", "腿弯举", ["leg curl"], "hamstrings", [], "machine", "isolation"),
            exercise("bulgarian_split_squat", "保加利亚分腿蹲", ["bulgarian split squat"], "quads", ["glutes"], "dumbbell", "lunge"),
            exercise("hip_thrust", "臀推", ["hip thrust", "臀桥"], "glutes", ["hamstrings"], "barbell", "hinge"),
            exercise("overhead_press", "推举", ["overhead press", "shoulder press"], "shoulders", ["triceps"], "barbell", "push"),
            exercise("lateral_raise", "哑铃侧平举", ["lateral raise"], "shoulders", [], "dumbbell", "isolation"),
            exercise("rear_delt_fly", "俯身飞鸟", ["rear delt fly"], "shoulders", [], "dumbbell", "isolation"),
            exercise("face_pull", "面拉", ["face pull"], "shoulders", ["back"], "cable", "pull"),
            exercise("arnold_press", "阿诺德推举", ["arnold press"], "shoulders", ["triceps"], "dumbbell", "push"),
            exercise("barbell_curl", "杠铃弯举", ["barbell curl"], "biceps", [], "barbell", "isolation"),
            exercise("dumbbell_curl", "哑铃弯举", ["dumbbell curl"], "biceps", [], "dumbbell", "isolation"),
            exercise("triceps_pushdown", "绳索下压", ["triceps pushdown"], "triceps", [], "cable", "isolation"),
            exercise("close_grip_bench_press", "窄距卧推", ["close grip bench press"], "triceps", ["chest"], "barbell", "push"),
            exercise("triceps_extension", "臂屈伸", ["triceps extension"], "triceps", [], "bodyweight", "isolation"),
            exercise("crunch", "卷腹", ["crunch"], "core", [], "bodyweight", "core"),
            exercise("hanging_leg_raise", "悬垂举腿", ["hanging leg raise"], "core", [], "bodyweight", "core"),
            exercise("plank", "平板支撑", ["plank"], "core", [], "bodyweight", "core"),
            exercise("pallof_press", "Pallof Press", ["pallof"], "core", [], "cable", "core")
        ]
    }

    static func search(_ query: String, in library: [ExerciseDefinitionRecord]) -> [ExerciseDefinitionRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return library }
        return library.filter { definition in
            definition.name.lowercased().contains(needle)
                || definition.aliases.contains { $0.lowercased().contains(needle) }
                || definition.primaryMuscleGroup.lowercased().contains(needle)
                || definition.canonicalKey.lowercased().contains(needle)
        }
    }

    static func defaultTemplates() -> [WorkoutTemplateRecord] {
        [
            template("推力训练", [
                ("barbell_bench_press", "杠铃卧推"),
                ("overhead_press", "推举"),
                ("triceps_pushdown", "绳索下压")
            ]),
            template("拉力训练", [
                ("lat_pulldown", "高位下拉"),
                ("barbell_row", "杠铃划船"),
                ("barbell_curl", "杠铃弯举")
            ]),
            template("腿部训练", [
                ("squat", "深蹲"),
                ("romanian_deadlift", "罗马尼亚硬拉"),
                ("leg_curl", "腿弯举")
            ]),
            template("上肢训练", [
                ("barbell_bench_press", "杠铃卧推"),
                ("lat_pulldown", "高位下拉"),
                ("overhead_press", "推举"),
                ("seated_row", "坐姿划船")
            ]),
            template("下肢训练", [
                ("squat", "深蹲"),
                ("romanian_deadlift", "罗马尼亚硬拉"),
                ("leg_curl", "腿弯举")
            ]),
            template("全身训练", [
                ("squat", "深蹲"),
                ("barbell_bench_press", "杠铃卧推"),
                ("barbell_row", "杠铃划船")
            ])
        ]
    }

    @MainActor
    static func seedDefaultsIfNeeded(modelContext: ModelContext) throws {
        let existingDefinitions = try modelContext.fetch(FetchDescriptor<ExerciseDefinitionRecord>())
        let existingKeys = Set(existingDefinitions.map(\.canonicalKey))
        let existingNames = Set(existingDefinitions.map(\.name))
        
        for definition in defaultDefinitions() {
            if !existingKeys.contains(definition.canonicalKey) && !existingNames.contains(definition.name) {
                modelContext.insert(definition)
            }
        }

        let deletedRecords = try? modelContext.fetch(FetchDescriptor<DeletedWorkoutRecord>())
        let deletedTemplateTitles = Set(deletedRecords?.compactMap { rec -> String? in
            if rec.id.hasPrefix("template:") {
                return String(rec.id.dropFirst("template:".count))
            }
            return nil
        } ?? [])

        let existingTemplates = try modelContext.fetch(FetchDescriptor<WorkoutTemplateRecord>())
        let existingTitles = Set(existingTemplates.map(\.title))
        for template in defaultTemplates() where !existingTitles.contains(template.title) && !deletedTemplateTitles.contains(template.title) {
            modelContext.insert(template)
        }
        try modelContext.save()
    }

    private static func exercise(
        _ key: String,
        _ name: String,
        _ aliases: [String],
        _ primary: String,
        _ secondary: [String],
        _ equipment: String,
        _ pattern: String
    ) -> ExerciseDefinitionRecord {
        ExerciseDefinitionRecord(
            canonicalKey: key,
            name: name,
            aliases: aliases,
            primaryMuscleGroup: primary,
            secondaryMuscleGroups: secondary,
            equipment: equipment,
            movementPattern: pattern
        )
    }

    private static func template(_ title: String, _ exercises: [(String, String)]) -> WorkoutTemplateRecord {
        WorkoutTemplateRecord(
            title: title,
            goal: "hypertrophy",
            exercises: exercises.map { (key, name) in
                WorkoutTemplateExercise(
                    exerciseCanonicalKey: key,
                    name: name,
                    targetSets: 3,
                    targetReps: "8-12",
                    targetRPE: 8,
                    restSeconds: 90
                )
            }
        )
    }
}
