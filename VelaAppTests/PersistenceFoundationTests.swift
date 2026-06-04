import XCTest
import SwiftData
@testable import Vela

final class PersistenceFoundationTests: XCTestCase {
    func testModelContainerSchemaCreatedSuccessfully() {
        let schema = VelaModelContainer.schema
        XCTAssertNotNil(schema)
    }

    @MainActor
    func testOnboardingStatePersistsBodyModelProfiles() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let state = OnboardingState(
            currentStep: "first_brief",
            isCompleted: true,
            goalProfile: UserGoalProfile(primaryGoal: "strength", experienceLevel: "intermediate"),
            trainingPreference: TrainingPreferenceProfile(trainingStyle: "strength", weeklyTrainingDays: 4, sessionDurationMinutes: 60),
            equipmentProfile: EquipmentProfile(equipment: ["barbell", "dumbbell"], scheduleNotes: "Mon/Wed/Fri/Sun"),
            coachingPreference: CoachingPreference(style: "direct", explanationDepth: "evidence_first"),
            initialBodySnapshot: InitialBodySnapshot(
                sleepScore: 72,
                recoveryScore: 68,
                strainScore: 42,
                dataConfidence: .medium,
                missingData: ["HRV baseline"]
            ),
            missingData: ["HRV baseline"]
        )
        context.insert(state)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<OnboardingState>()).first)

        XCTAssertTrue(fetched.isCompleted)
        XCTAssertEqual(fetched.goalProfile.primaryGoal, "strength")
        XCTAssertEqual(fetched.trainingPreference.weeklyTrainingDays, 4)
        XCTAssertEqual(fetched.equipmentProfile.equipment, ["barbell", "dumbbell"])
        XCTAssertEqual(fetched.initialBodySnapshot.dataConfidence, .medium)
        XCTAssertEqual(fetched.missingData, ["HRV baseline"])
    }
}
