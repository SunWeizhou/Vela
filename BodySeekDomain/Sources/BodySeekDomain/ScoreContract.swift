import Foundation

/// The numeric estimate and its explainable component breakdown. An absent
/// value is intentionally different from zero: it means the estimate is not
/// available for this evaluation.
public struct ScoreEstimate: Codable, Hashable, Sendable {
    public let value: Double?
    public let band: MetricBand
    public let components: [String: Double]
    public let componentWeights: [String: Double]

    public init(
        value: Double?,
        band: MetricBand,
        components: [String: Double] = [:],
        componentWeights: [String: Double] = [:]
    ) {
        self.value = value
        self.band = band
        self.components = components
        self.componentWeights = componentWeights
    }
}

public struct ScoreConfidenceReport: Codable, Hashable, Sendable {
    public let level: MetricConfidence
    public let reasons: [String]
    public let limitingInputs: [String]

    public init(
        level: MetricConfidence,
        reasons: [String] = [],
        limitingInputs: [String] = []
    ) {
        self.level = level
        self.reasons = reasons
        self.limitingInputs = limitingInputs
    }
}

/// A value-only description of one required input. Freshness and observation
/// lineage are optional until the upstream snapshot seam supplies them.
public struct SignalCoverage: Codable, Hashable, Sendable {
    public let signalID: String
    public let observedAt: Date?
    public let isFresh: Bool?
    public let isUsable: Bool

    public init(
        signalID: String,
        observedAt: Date? = nil,
        isFresh: Bool? = nil,
        isUsable: Bool
    ) {
        self.signalID = signalID
        self.observedAt = observedAt
        self.isFresh = isFresh
        self.isUsable = isUsable
    }
}

public struct ScoreCoverageReport: Codable, Hashable, Sendable {
    public let status: ScoreDataCoverage
    public let requiredSignals: [SignalCoverage]

    public init(
        status: ScoreDataCoverage,
        requiredSignals: [SignalCoverage] = []
    ) {
        self.status = status
        self.requiredSignals = requiredSignals
    }
}

public struct ScoreProvenance: Codable, Hashable, Sendable {
    public let source: MetricSource
    public let dataWindow: DateInterval
    public let evaluatedAt: Date
    public let algorithmVersion: String
    public let inputFingerprint: String?

    public init(
        source: MetricSource,
        dataWindow: DateInterval,
        evaluatedAt: Date,
        algorithmVersion: String,
        inputFingerprint: String? = nil
    ) {
        self.source = source
        self.dataWindow = dataWindow
        self.evaluatedAt = evaluatedAt
        self.algorithmVersion = algorithmVersion
        self.inputFingerprint = inputFingerprint
    }
}

public struct ScoreEvidence: Codable, Hashable, Sendable {
    public let domain: ScoredHealthDomain
    public let estimate: ScoreEstimate
    public let confidence: ScoreConfidenceReport
    public let coverage: ScoreCoverageReport
    public let provenance: ScoreProvenance
    public let reasons: [String]

    public init(
        domain: ScoredHealthDomain,
        estimate: ScoreEstimate,
        confidence: ScoreConfidenceReport,
        coverage: ScoreCoverageReport,
        provenance: ScoreProvenance,
        reasons: [String] = []
    ) {
        self.domain = domain
        self.estimate = estimate
        self.confidence = confidence
        self.coverage = coverage
        self.provenance = provenance
        self.reasons = reasons
    }
}

/// Pure compatibility mapping from the legacy package result to the PR7
/// value contract. It deliberately does not infer freshness, signal lineage,
/// or an input fingerprint from component names.
public enum ScoreEvidenceAdapter {
    public static func makeEvidence(
        from metric: MetricResult,
        inputFingerprint: String? = nil
    ) -> ScoreEvidence {
        let missingSignals = metric.missingInputs.map {
            SignalCoverage(signalID: $0, isUsable: false)
        }
        let status: ScoreDataCoverage
        if metric.value == nil {
            status = .unavailable
        } else if metric.missingInputs.isEmpty {
            status = .complete
        } else {
            // Coverage is an evidence fact, not a confidence alias. The
            // first adapter has no freshness/lineage inputs, so any explicit
            // missing signal is conservatively represented as partial,
            // regardless of the engine's confidence assessment.
            status = .partial
        }

        return ScoreEvidence(
            domain: metric.domain,
            estimate: ScoreEstimate(
                value: metric.value,
                band: metric.band,
                components: metric.components,
                componentWeights: metric.componentWeights
            ),
            confidence: ScoreConfidenceReport(
                level: metric.confidence,
                reasons: metric.reasons,
                limitingInputs: metric.missingInputs
            ),
            coverage: ScoreCoverageReport(
                status: status,
                requiredSignals: missingSignals
            ),
            provenance: ScoreProvenance(
                source: metric.source,
                dataWindow: metric.dataWindow,
                evaluatedAt: metric.lastUpdated,
                algorithmVersion: metric.algorithmVersion,
                inputFingerprint: inputFingerprint
            ),
            reasons: metric.reasons
        )
    }
}

/// Named Sleep-first seam. Keeping the domain check here prevents an adapter
/// intended for the migrated Sleep engine from silently accepting another
/// score slot.
public enum SleepScoreEvidenceAdapter {
    public static func makeEvidence(
        from metric: MetricResult,
        inputFingerprint: String? = nil
    ) -> ScoreEvidence? {
        guard metric.domain == .sleep else { return nil }
        return ScoreEvidenceAdapter.makeEvidence(from: metric, inputFingerprint: inputFingerprint)
    }
}
