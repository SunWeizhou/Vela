import Foundation
import SwiftData

struct DailyOperatingPlanPayload: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var volumeMultiplier: Double
    var intensityCap: Int
    var summary: String
    var targetSessionTitle: String?
}

struct DailyOperatingPlanDisplayModel: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var actionLabel: String
    var statusTitle: String
    var summary: String
    var evidenceLine: String
    var confidenceLabel: String

    static func build(
        payload: DailyOperatingPlanPayload?,
        primaryActionType: String?,
        source: String?,
        safetyNotice: String?,
        confidence: Double,
        isChinese: Bool = AppLanguage.stored.isChinese
    ) -> DailyOperatingPlanDisplayModel {
        let decision = payload?.decision
            ?? primaryActionType.flatMap(DailyTrainingDecisionType.init(rawValue:))
            ?? .keep
        let intensityCap = payload?.intensityCap ?? (decision == .rest ? 2 : 7)
        let volumeMultiplier = payload?.volumeMultiplier ?? defaultVolumeMultiplier(for: decision)
        let summary = localizedSummary(
            payloadSummary: payload?.summary,
            decision: decision,
            volumeMultiplier: volumeMultiplier,
            intensityCap: intensityCap,
            isChinese: isChinese
        )
        let evidence = localizedEvidenceLine(
            source: source,
            safetyNotice: safetyNotice,
            isChinese: isChinese
        )
        let roundedConfidence = Int((min(max(confidence, 0), 1) * 100).rounded())

        return DailyOperatingPlanDisplayModel(
            decision: decision,
            actionLabel: actionLabel(for: decision, isChinese: isChinese),
            statusTitle: statusTitle(for: decision, intensityCap: intensityCap, isChinese: isChinese),
            summary: summary,
            evidenceLine: evidence,
            confidenceLabel: isChinese ? "置信度 \(roundedConfidence)%" : "Confidence \(roundedConfidence)%"
        )
    }

    private static func defaultVolumeMultiplier(for decision: DailyTrainingDecisionType) -> Double {
        switch decision {
        case .keep: 1
        case .reduce: 0.75
        case .swap: 0.65
        case .rest: 0
        }
    }

    private static func actionLabel(for decision: DailyTrainingDecisionType, isChinese: Bool) -> String {
        switch decision {
        case .keep: return isChinese ? "按计划" : "KEEP"
        case .reduce: return isChinese ? "减量" : "REDUCE"
        case .swap: return isChinese ? "替换" : "SWAP"
        case .rest: return isChinese ? "恢复" : "REST"
        }
    }

    private static func statusTitle(
        for decision: DailyTrainingDecisionType,
        intensityCap: Int,
        isChinese: Bool
    ) -> String {
        if decision == .rest {
            return isChinese ? "建议恢复或休息" : "Recovery or rest advised"
        }
        return isChinese ? "建议训练 · RPE \(intensityCap)" : "Train today · RPE \(intensityCap)"
    }

    private static func localizedSummary(
        payloadSummary: String?,
        decision: DailyTrainingDecisionType,
        volumeMultiplier: Double,
        intensityCap: Int,
        isChinese: Bool
    ) -> String {
        if !isChinese, let payloadSummary, !payloadSummary.isEmpty {
            return payloadSummary
        }

        let volumePercent = Int((volumeMultiplier * 100).rounded())
        if isChinese {
            switch decision {
            case .keep:
                return "按计划训练，使用 RPE \(intensityCap) 作为上限，并根据动作质量做自我调节。"
            case .reduce:
                return "建议将今天训练容量降至 \(volumePercent)%，RPE 控制在 \(intensityCap) 以内；动作质量下降时停止加量。"
            case .swap:
                return "替换高疲劳部位的训练内容，保留约 \(volumePercent)% 的有效刺激，RPE 控制在 \(intensityCap) 以内。"
            case .rest:
                return "今天优先恢复：选择低强度活动、拉伸和睡眠补偿，避免追求训练量。"
            }
        }

        switch decision {
        case .keep:
            return "Keep the planned session with RPE capped at \(intensityCap) and autoregulate by technique quality."
        case .reduce:
            return "Reduce volume to \(volumePercent)% and keep RPE at or below \(intensityCap); stop adding load if technique deteriorates."
        case .swap:
            return "Swap away from highly fatigued areas, keep about \(volumePercent)% of the stimulus, and cap RPE at \(intensityCap)."
        case .rest:
            return "Prioritize recovery today with low-intensity activity, mobility, and sleep support instead of chasing volume."
        }
    }

    private static func localizedEvidenceLine(
        source: String?,
        safetyNotice: String?,
        isChinese: Bool
    ) -> String {
        if isChinese {
            let sourceText = (source?.isEmpty == false) ? "本地身体状态 + 训练决策" : "本地训练决策"
            let safetyText = (safetyNotice?.isEmpty == false) ? "一般健康与训练建议，不构成医疗诊断。" : "一般建议，不构成医疗诊断。"
            return "\(sourceText) · \(safetyText)"
        }
        let sourceText = source?.isEmpty == false ? source! : "Local training decision"
        let safetyText = safetyNotice?.isEmpty == false ? safetyNotice! : "General guidance only; not a medical diagnosis."
        return "\(sourceText) · \(safetyText)"
    }
}

@MainActor
enum DailyOperatingPlanCoordinator {
    @discardableResult
    static func upsert(
        bodyState: BodyState,
        decision: DailyTrainingDecision,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyOperatingPlanRecord {
        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: bodyState.date, calendar: calendar)
        let payload = DailyOperatingPlanPayload(
            decision: decision.decision,
            volumeMultiplier: decision.volumeMultiplier,
            intensityCap: decision.intensityCap,
            summary: decision.userFacingSummary,
            targetSessionTitle: decision.targetSessionTitle
        )
        let payloadJSON = Self.json(payload)
        let reasonsJSON = Self.json(decision.reasons)
        let descriptor = FetchDescriptor<DailyOperatingPlanRecord>(
            predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == dayIdentifier }
        )
        let record: DailyOperatingPlanRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
            record.bodyStateHash = bodyState.hash
            record.generatedAt = Date()
            record.primaryActionType = decision.decision.rawValue
            record.title = title(for: decision.decision)
            record.payloadJSON = payloadJSON
            record.reasonsJSON = reasonsJSON
            record.confidence = decision.confidence
            record.status = "active"
            record.source = decision.source
            record.safetyNotice = decision.safetyNotice
        } else {
            record = DailyOperatingPlanRecord(
                dayIdentifier: dayIdentifier,
                bodyStateHash: bodyState.hash,
                primaryActionType: decision.decision.rawValue,
                title: title(for: decision.decision),
                payloadJSON: payloadJSON,
                reasonsJSON: reasonsJSON,
                confidence: decision.confidence,
                status: "active",
                source: decision.source,
                safetyNotice: decision.safetyNotice
            )
            modelContext.insert(record)
        }

        let artifactType = AgentArtifactType.dailyPlan.rawValue
        let sourceContextHash = bodyState.hash
        let artifactDescriptor = FetchDescriptor<AgentArtifactRecord>(
            predicate: #Predicate<AgentArtifactRecord> {
                $0.type == artifactType && $0.sourceContextHash == sourceContextHash
            }
        )
        if let artifact = try modelContext.fetch(artifactDescriptor).first {
            artifact.title = record.title
            artifact.payloadJSON = payloadJSON
            artifact.confidence = decision.confidence
            artifact.status = "active"
            artifact.source = decision.source
            artifact.safetyNotice = record.safetyNotice
        } else {
            modelContext.insert(AgentArtifactRecord(
                type: AgentArtifactType.dailyPlan.rawValue,
                title: record.title,
                payloadJSON: payloadJSON,
                sourceContextHash: bodyState.hash,
                confidence: decision.confidence,
                source: decision.source,
                safetyNotice: decision.safetyNotice
            ))
        }
        try modelContext.save()
        return record
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func title(for decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: "Keep today's plan"
        case .reduce: "Reduce today's training"
        case .swap: "Swap today's session"
        case .rest: "Recovery day"
        }
    }
}

extension DailyOperatingPlanRecord {
    var operatingPlanPayload: DailyOperatingPlanPayload? {
        guard let payloadData = payloadJSON.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: payloadData)
    }

    var operatingPlanReasons: [String] {
        guard let reasonsData = reasonsJSON.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([String].self, from: reasonsData)) ?? []
    }

    var trainingDecision: DailyTrainingDecision? {
        guard let payload = operatingPlanPayload else {
            return nil
        }
        return DailyTrainingDecision(
            decision: payload.decision,
            targetSessionTitle: payload.targetSessionTitle,
            volumeMultiplier: payload.volumeMultiplier,
            intensityCap: payload.intensityCap,
            reasons: operatingPlanReasons,
            userFacingSummary: payload.summary,
            confidence: confidence,
            source: source ?? "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: safetyNotice ?? "General wellness guidance only; not a medical diagnosis."
        )
    }
}
