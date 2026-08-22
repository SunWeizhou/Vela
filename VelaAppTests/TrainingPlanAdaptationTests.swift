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
}
