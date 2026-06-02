import Vapor

// MARK: - Language Support

enum SupportedLanguage: String {
    case zh, en

    static func from(_ s: String?) -> SupportedLanguage {
        switch s?.lowercased() {
        case "en": return .en
        default: return .zh
        }
    }
}

// MARK: - Auth

struct RegisterRequest: Content {
    let email: String
    let password: String
    let timezone: String?
    let lang: String?
}

struct LoginRequest: Content {
    let email: String
    let password: String
}

struct RefreshRequest: Content {
    let refreshToken: String
}

struct AuthResponse: Content {
    let accessToken: String
    let refreshToken: String
    let user: UserProfile
}

struct UserProfile: Content {
    let id: UUID
    let email: String
    let timezone: String
    let lang: String
}

// MARK: - Health Context (shared by Coach & Today)

struct HealthContext: Content {
    var date: String
    var sleep: SleepCtx?
    var recovery: RecoveryCtx?
    var strain: StrainCtx?
    var stress: StressCtx?
    var energy: EnergyCtx?
    var bodyMetrics: BodyMetricsCtx?
}

struct SleepCtx: Content {
    var score: Double?
    var totalMinutes: Int?
    var deepMinutes: Int?
    var remMinutes: Int?
    var coreMinutes: Int?
    var awakeMinutes: Int?
    var awakeEpisodeCount: Int?
    var remPct: Double?
    var deepPct: Double?
    var efficiency: Double?
    var bedtime: String?
    var wakeTime: String?
    var regularity: String?
}

struct RecoveryCtx: Content {
    var score: Double?
    var band: String?
    var hrvMs: Double?
    var hrvBaseline: Double?
    var restingHR: Double?
    var rhrBaseline: Double?
    var respiratoryRate: Double?
    var hrvZScore: Double?
    var rhrZScore: Double?
    var respiratoryRateZ: Double?
    var bodyTempDelta: Double?
    var spo2: Double?
    var hrvStatus: String?
    var rhrStatus: String?
    var sleepContrib: Double?
    var priorStrainContrib: Double?
}

struct StrainCtx: Content {
    var score: Double?
    var targetRange: String?
    var activeEnergyKcal: Double?
    var exerciseMinutes: Int?
    var stepCount: Int?
    var workoutCount: Int?
    var status: String?
}

struct StressCtx: Content {
    var index: Double?
    var band: String?
    var trend: String?
}

struct EnergyCtx: Content {
    var morningEnergy: Double?
    var currentEnergy: Double?
    var atl: Double?
    var ctl: Double?
    var tsb: Double?
    var acwr: Double?
    var status: String?
}

struct BodyMetricsCtx: Content {
    var weightKg: Double?
    var bodyFatPct: Double?
    var bmi: Double?
    var vo2Max: Double?
    var bloodPressureSystolic: Int?
    var bloodPressureDiastolic: Int?
    var bloodOxygen: Double?
}

// MARK: - Coach Chat

struct CoachChatRequest: Content {
    var message: String
    var lang: String?
    var personality: String?
    var userContext: HealthContext?
    var history: [ChatMessageDTO]?
}

struct ChatMessageDTO: Content {
    var role: String
    var content: String
}

struct CoachChatResponse: Content {
    var reply: String
    var insights: [String]
    var suggestedActions: [String]
    var toolCalls: [ToolCallInfo]?
}

struct ToolCallInfo: Content {
    var name: String
    var arguments: String
    var result: String
}

// MARK: - Today Plan

struct TodayPlanResponse: Content {
    var kind: String
    var title: String
    var body: String
    var primaryAction: String
    var secondaryAction: String?
    var limiter: LimiterInfo?
    var accent: String

    struct LimiterInfo: Content {
        var kind: String
        var title: String
        var detail: String
    }
}

// MARK: - Training

struct TrainingAdaptationRequest: Content {
    var weekPlan: [TrainingDay]
    var currentScores: HealthContext
    var lang: String?

    struct TrainingDay: Content {
        var day: String
        var title: String
        var focus: String
        var durationMinutes: Int
        var intensity: String
        var status: String
    }
}

struct TrainingAdaptationResponse: Content {
    var adaptations: [DayAdaptation]

    struct DayAdaptation: Content {
        var original: TrainingAdaptationRequest.TrainingDay
        var suggestion: TrainingAdaptationRequest.TrainingDay?
        var reason: String
        var keepOriginal: Bool
        var confidence: Double
    }
}

// MARK: - Insights

struct EvidenceRequest: Content {
    var claim: String
    var context: HealthContext
    var lang: String?
}

struct EvidenceResponse: Content {
    var evidenceChain: [EvidenceLink]
    var overallConfidence: Double
    var summary: String

    struct EvidenceLink: Content {
        var dataPoint: String
        var value: String
        var trend: String
        var reasoning: String
        var confidence: Double
    }
}

// MARK: - Memory

struct MemoryCardResponse: Content {
    var cards: [MemoryCardDTO]

    struct MemoryCardDTO: Content {
        var id: UUID
        var pattern: String
        var evidence: String
        var confidence: Double
        var status: String
        var createdAt: Date
    }
}

// MARK: - Data Coverage

struct DataCoverageResponse: Content {
    var overall: Double
    var dimensions: [DimensionCoverage]
    var missingMetrics: [String]
    var recommendations: [String]

    struct DimensionCoverage: Content {
        var name: String
        var coverage: Double
        var freshness: String
    }
}

// MARK: - Trust Audit

struct TrustAuditResponse: Content {
    var entries: [AuditEntryDTO]
    var summary: AuditSummary

    struct AuditEntryDTO: Content {
        var id: UUID
        var timestamp: Date
        var toolName: String
        var parameters: String
        var resultStatus: String
        var modelVersion: String
    }

    struct AuditSummary: Content {
        var totalOperations: Int
        var successRate: Double
        var lastModel: String
        var periodDays: Int
    }
}

// MARK: - Settings

struct SettingsRequest: Content {
    var userId: String
    var language: String?
    var notifications: NotificationSettings?
    var dataSources: [String]?
    var coachPersonality: String?
    var theme: String?

    struct NotificationSettings: Content {
        var morningBrief: Bool
        var eveningSync: Bool
        var abnormalAlerts: Bool
    }
}

struct SettingsResponse: Content {
    var ok: Bool
    var settings: UserSettingsDTO

    struct UserSettingsDTO: Content {
        var language: String
        var notifications: SettingsRequest.NotificationSettings
        var dataSources: [String]
        var coachPersonality: String
        var theme: String
    }
}
