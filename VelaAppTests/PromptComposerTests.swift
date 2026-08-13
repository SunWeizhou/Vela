import XCTest
@testable import Vela

final class PromptComposerTests: XCTestCase {
    func testPersonalTrainingAndRecoveryQuestionsDoNotTriggerWebSearch() {
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("What is my recovery today?"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("Should I train today or rest based on my recovery?"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("我今天适合训练吗？"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("帮我看看今天睡眠和恢复怎么样？"))
    }

    func testSelfReportedMetricValuesNeverTriggerWebSearch() {
        // 自报具体健康数值 + 新鲜度词混合的消息，不得把健康数值作为搜索词
        // 发送给第三方（新鲜度词判定必须先让位于个人数据保护）。
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("我的 HRV 只有 42ms，最新研究怎么说？"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("血压 150/95 的最新医学指南是什么"))
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("最新的睡眠研究有哪些发现"))
    }

    func testCurrentResearchAndSupplementQuestionsTriggerWebSearch() {
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("What does the latest research say about creatine and strength?"))
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("最新肌酸研究对力量训练有什么建议？"))
    }

    func testResponseLengthPolicyMatchesConversationIntent() {
        XCTAssertEqual(ResponseLengthPolicy.forQuery("谢谢", lang: .english), .casual)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("分析今天的数据", lang: .simplifiedChinese), .full)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("我今天适合训练吗？", lang: .simplifiedChinese), .focused)
    }

    func testTrainingPromptDefersToLocalDecisionInsteadOfFixedScores() {
        let prompt = PromptFragments.trainingPrescriptionProtocol(lang: .simplifiedChinese)

        XCTAssertTrue(prompt.contains("DailyTrainingDecision"))
        XCTAssertTrue(prompt.contains("不要仅凭恢复分或 TSB 建议高强度或突破"))
        XCTAssertFalse(prompt.contains("高状态日：推荐高强度训练"))
        XCTAssertFalse(prompt.contains("增加 10-20% 训练量"))
    }

    func testEvidenceBoundariesForbidDiagnosticClaims() {
        let prompt = PromptFragments.evidenceBoundariesBlock(lang: .simplifiedChinese)

        XCTAssertTrue(prompt.contains("不得把可穿戴数据、趋势或通用阈值表述为疾病"))
        XCTAssertTrue(prompt.contains("缺失或不可用的数据不是正常数据"))
    }

    func testEvidenceBoundariesBlockContainsFreshnessWarning() {
        let promptZh = PromptFragments.evidenceBoundariesBlock(lang: .simplifiedChinese)
        XCTAssertTrue(promptZh.contains("当整体数据新鲜度为已过期（stale）或缺失（missing）时"))
        
        let promptEn = PromptFragments.evidenceBoundariesBlock(lang: .english)
        XCTAssertTrue(promptEn.contains("When overall data freshness is stale or missing"))
    }
}
