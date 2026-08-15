import Foundation

struct TrainingDecision: Codable, Hashable, Sendable {
    var kind: DailyPlanKind
    var accent: DailyPlanAccent
    var title: String
    var body: String
    var primaryActionTitle: String
    var secondaryActionTitle: String?
    var coachQuestion: String
    var limiter: DailyPlanLimiter?
    
    // Core Metrics v1.3 / Limiter Integration
    var readinessLevel: String // "HIGH", "MODERATE", "LOW"
    var readinessGuidance: String
    var limiters: [PlanLimiter]
    var trainingLoadConfidence: DataConfidence
    var atl: Double?
    var ctl: Double?
    var tsb: Double?
    var volumeMultiplier: Double
    var maxIntensity: String
    var recommendedTrainingType: String
    var whyThis: String
}

extension TrainingDecision {
    static func compatibilityView(
        of decision: DailyTrainingDecision,
        bodyState: BodyState
    ) -> TrainingDecision {
        let presentation: (
            kind: DailyPlanKind,
            accent: DailyPlanAccent,
            title: String,
            primaryActionTitle: String
        )

        switch decision.decision {
        case .keep:
            presentation = (.train, .strain, "Keep planned session", "Start planned session")
        case .reduce:
            presentation = (.maintain, .energy, "Reduce planned session", "Start reduced session")
        case .swap:
            presentation = (.downshift, .stress, "Swap planned session", "Choose an easier session")
        case .rest:
            presentation = (.rest, .recovery, "Prioritize recovery", "Start recovery")
        }

        let readinessLevel: String
        switch bodyState.readiness {
        case .ready:
            readinessLevel = "HIGH"
        case .caution, .unknown:
            readinessLevel = "MODERATE"
        case .recovering:
            readinessLevel = "LOW"
        }

        let whyThis = decision.reasons.joined(separator: " ")

        return TrainingDecision(
            kind: presentation.kind,
            accent: presentation.accent,
            title: presentation.title,
            body: decision.userFacingSummary,
            primaryActionTitle: presentation.primaryActionTitle,
            secondaryActionTitle: nil,
            coachQuestion: whyThis.isEmpty
                ? decision.userFacingSummary
                : "\(whyThis) \(decision.userFacingSummary)",
            limiter: nil,
            readinessLevel: readinessLevel,
            readinessGuidance: decision.userFacingSummary,
            limiters: [],
            trainingLoadConfidence: bodyState.confidence,
            atl: nil,
            ctl: nil,
            tsb: nil,
            volumeMultiplier: decision.volumeMultiplier,
            maxIntensity: "RPE \(decision.intensityCap)",
            recommendedTrainingType: decision.targetSessionTitle ?? decision.decision.rawValue,
            whyThis: whyThis
        )
    }
}

