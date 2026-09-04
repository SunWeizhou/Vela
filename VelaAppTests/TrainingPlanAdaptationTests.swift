import XCTest
@testable import Vela

final class TrainingPlanAdaptationTests: XCTestCase {
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
        let plan = TrainingPlanRecord(title: "测试计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            adjustment: .reduce,
            reason: "轻度疲劳",
            suggestedAlternative: "30 分钟低容量训练"
        )
        let acceptedAt = Date(timeIntervalSince1970: 1_800_000_000)

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
        let plan = TrainingPlanRecord(title: "周期力量计划", goalDescription: "", days: [day])
        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
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
        let acceptedAt = Date(timeIntervalSince1970: 1_800_000_200)

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
