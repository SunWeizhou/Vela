import XCTest
@testable import Vela

final class TrainingPlanAdaptationTests: XCTestCase {
    func testApplyPreservesExecutionMetadataAndOnlyUpdatesPlanFields() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let appliedAt = createdAt.addingTimeInterval(300)
        let completedAt = createdAt.addingTimeInterval(-3_600)
        let workoutIDs = [UUID(), UUID()]
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划动作",
            focus: "strength",
            durationMinutes: 90,
            intensity: "high",
            isCompleted: true,
            completedAt: completedAt,
            loggedStrain: 72.5,
            linkedWorkoutEventIds: workoutIDs,
            plannedExercisesJSON: "[{\"name\":\"深蹲\"}]",
            actualSummaryJSON: "{\"sets\":4}",
            adherenceScore: 0.92
        )
        let originalPlanTimestamp = createdAt.addingTimeInterval(-600)
        let plan = TrainingPlanRecord(
            title: "测试计划",
            goalDescription: "",
            days: [day],
            createdAt: originalPlanTimestamp,
            updatedAt: originalPlanTimestamp
        )
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: createdAt,
            adjustment: .reduce,
            reason: "轻度疲劳",
            suggestedAlternative: "45 分钟低容量训练"
        )

        // Applying the mutation is separate from accepting the proposal. The
        // caller still has to perform the explicit state transition.
        XCTAssertTrue(AdaptiveTrainingManager().applyAdaptation(proposal, to: plan, at: appliedAt))

        let updated = try XCTUnwrap(plan.days.first)
        XCTAssertEqual(updated.id, day.id)
        XCTAssertEqual(updated.weekNumber, day.weekNumber)
        XCTAssertEqual(updated.dayNumber, day.dayNumber)
        XCTAssertEqual(updated.title, "力量训练（减量）")
        XCTAssertEqual(updated.description, "45 分钟低容量训练")
        XCTAssertEqual(updated.focus, day.focus)
        XCTAssertEqual(updated.durationMinutes, 45)
        XCTAssertEqual(updated.intensity, "moderate")
        XCTAssertEqual(updated.isCompleted, day.isCompleted)
        XCTAssertEqual(updated.completedAt, day.completedAt)
        XCTAssertEqual(updated.loggedStrain, day.loggedStrain)
        XCTAssertEqual(updated.linkedWorkoutEventIds, day.linkedWorkoutEventIds)
        XCTAssertEqual(updated.plannedExercisesJSON, day.plannedExercisesJSON)
        XCTAssertEqual(updated.actualSummaryJSON, day.actualSummaryJSON)
        XCTAssertEqual(updated.adherenceScore, day.adherenceScore)
        XCTAssertEqual(plan.updatedAt, appliedAt)
        XCTAssertEqual(proposal.status, AdaptationStatus.proposed.rawValue)
        XCTAssertNil(proposal.acceptedAt)
    }

    func testAlreadyAcceptedProposalIsIdempotent() {
        let now = Date(timeIntervalSince1970: 1_800_001_000)
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "减量后的训练",
            description: "已应用",
            focus: "strength",
            durationMinutes: 30,
            intensity: "moderate",
            isCompleted: true,
            completedAt: now.addingTimeInterval(-900),
            loggedStrain: 28,
            linkedWorkoutEventIds: [UUID()],
            plannedExercisesJSON: "[{\"name\":\"硬拉\"}]",
            actualSummaryJSON: "{\"sets\":2}",
            adherenceScore: 0.8
        )
        let plan = TrainingPlanRecord(
            title: "测试计划",
            goalDescription: "",
            days: [day],
            updatedAt: now.addingTimeInterval(-60)
        )
        let originalPlanTimestamp = plan.updatedAt
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: now.addingTimeInterval(-300),
            adjustment: .reduce,
            reason: "轻度疲劳",
            status: .accepted,
            acceptedAt: now.addingTimeInterval(-120)
        )
        let beforeRetry = plan.days

        XCTAssertTrue(AdaptiveTrainingManager().applyAdaptation(proposal, to: plan, at: now))
        XCTAssertEqual(plan.days, beforeRetry)
        XCTAssertEqual(plan.updatedAt, originalPlanTimestamp)
        XCTAssertEqual(proposal.status, AdaptationStatus.accepted.rawValue)
        XCTAssertEqual(proposal.acceptedAt, now.addingTimeInterval(-120))
    }

    func testExpiredProposalIsRejectedWithoutMutatingPlan() {
        let now = Date(timeIntervalSince1970: 1_800_002_000)
        let originalTimestamp = now.addingTimeInterval(-3_600)
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high",
            isCompleted: true,
            completedAt: now.addingTimeInterval(-86_400),
            loggedStrain: 60,
            linkedWorkoutEventIds: [UUID()],
            plannedExercisesJSON: "[{\"name\":\"深蹲\"}]",
            actualSummaryJSON: "{\"sets\":3}",
            adherenceScore: 0.9
        )
        let plan = TrainingPlanRecord(
            title: "测试计划",
            goalDescription: "",
            days: [day],
            updatedAt: originalTimestamp
        )
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: now.addingTimeInterval(-(AdaptiveTrainingManager.proposalExpirationInterval + 1)),
            adjustment: .rest,
            reason: "恢复不足"
        )

        XCTAssertFalse(AdaptiveTrainingManager().applyAdaptation(proposal, to: plan, at: now))
        XCTAssertEqual(plan.days, [day])
        XCTAssertEqual(plan.updatedAt, originalTimestamp)
        XCTAssertEqual(proposal.status, AdaptationStatus.rejected.rawValue)
        XCTAssertEqual(proposal.rejectedAt, now)
        XCTAssertNil(proposal.acceptedAt)
    }

    func testRejectedProposalCannotBeAppliedWithoutExplicitNewProposal() {
        let now = Date(timeIntervalSince1970: 1_800_003_000)
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let plan = TrainingPlanRecord(title: "测试计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: now,
            adjustment: .rest,
            reason: "恢复不足",
            status: .rejected,
            rejectedAt: now
        )

        XCTAssertFalse(AdaptiveTrainingManager().applyAdaptation(proposal, to: plan, at: now))
        XCTAssertEqual(plan.days, [day])
        XCTAssertEqual(proposal.status, AdaptationStatus.rejected.rawValue)
    }

    func testAcceptUsesAdaptiveManagerBeforeMarkingProposalAccepted() {
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let acceptedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = TrainingPlanRecord(title: "测试计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: acceptedAt.addingTimeInterval(-300),
            adjustment: .reduce,
            reason: "轻度疲劳",
            suggestedAlternative: "30 分钟低容量训练"
        )

        XCTAssertTrue(
            TodayTrainingPlanAdaptationDecision.accept(proposal, in: plan, at: acceptedAt)
        )
        XCTAssertEqual(plan.days[0].durationMinutes, 30)
        XCTAssertEqual(proposal.status, AdaptationStatus.accepted.rawValue)
        XCTAssertEqual(proposal.acceptedAt, acceptedAt)
        XCTAssertNil(proposal.rejectedAt)
    }

    func testRejectOnlyChangesProposalStateAndDoesNotMutatePlan() {
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let plan = TrainingPlanRecord(title: "测试计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            adjustment: .rest,
            reason: "恢复不足"
        )
        let rejectedAt = Date(timeIntervalSince1970: 1_800_000_100)

        TodayTrainingPlanAdaptationDecision.reject(proposal, at: rejectedAt)

        XCTAssertEqual(plan.days, [day])
        XCTAssertEqual(proposal.status, AdaptationStatus.rejected.rawValue)
        XCTAssertEqual(proposal.rejectedAt, rejectedAt)
        XCTAssertNil(proposal.acceptedAt)
    }

    func testFailedAcceptanceLeavesProposalPending() {
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "力量训练",
            description: "原计划",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let plan = TrainingPlanRecord(title: "测试计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            adjustment: .reschedule,
            reason: "改期"
        )

        XCTAssertFalse(TodayTrainingPlanAdaptationDecision.accept(proposal, in: plan))
        XCTAssertEqual(proposal.status, AdaptationStatus.proposed.rawValue)
        XCTAssertNil(proposal.acceptedAt)
    }

    func testAcceptArtifactWithExistingProposalClosesLoop() {
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "下肢力量",
            description: "原计划深蹲组",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let acceptedAt = Date(timeIntervalSince1970: 1_800_000_200)
        let plan = TrainingPlanRecord(title: "周期力量计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            createdAt: acceptedAt.addingTimeInterval(-300),
            adjustment: .reduce,
            reason: "中枢疲劳高",
            suggestedAlternative: "减半训练时长"
        )
        let artifact = CoachArtifact(
            type: .trainingAdjustment,
            title: "训练减量建议",
            summary: "建议将训练容量减少 50%",
            decision: "reduce",
            confidence: 0.88,
            reasons: [CoachArtifactReason(signal: "fatigue", value: "high", explanation: "疲劳累积")],
            actions: [],
            sourceContextHash: "run-hash-123"
        )
        let artifactRecord = CoachArtifactRecord(artifact: artifact)

        let result = TodayTrainingPlanAdaptationDecision.acceptArtifact(
            artifactRecord,
            in: plan,
            proposal: proposal,
            at: acceptedAt
        )

        XCTAssertTrue(result)
        XCTAssertEqual(plan.days[0].durationMinutes, 30)
        XCTAssertEqual(proposal.status, AdaptationStatus.accepted.rawValue)
        XCTAssertEqual(proposal.acceptedAt, acceptedAt)
        XCTAssertEqual(artifactRecord.status, CoachArtifactStatus.acted.rawValue)
    }

    func testRejectArtifactMarksProposalAndArtifactRejected() {
        let proposal = TrainingPlanAdaptationRecord(
            planId: UUID(),
            dayId: UUID(),
            adjustment: .rest,
            reason: "恢复建议"
        )
        let artifact = CoachArtifact(
            type: .trainingAdjustment,
            title: "训练调整建议",
            summary: "建议休息",
            decision: "rest",
            confidence: 0.75,
            reasons: [],
            actions: [],
            sourceContextHash: "hash-456"
        )
        let artifactRecord = CoachArtifactRecord(artifact: artifact)
        let rejectedAt = Date(timeIntervalSince1970: 1_800_000_300)

        TodayTrainingPlanAdaptationDecision.rejectArtifact(
            artifactRecord,
            proposal: proposal,
            at: rejectedAt
        )

        XCTAssertEqual(proposal.status, AdaptationStatus.rejected.rawValue)
        XCTAssertEqual(proposal.rejectedAt, rejectedAt)
        XCTAssertEqual(artifactRecord.status, CoachArtifactStatus.dismissed.rawValue)
    }
}
