import Foundation
import HealthKit

/// The smallest seam needed to exercise coverage behaviour without a live
/// HealthKit database.  The production adapter below keeps all HKQuery
/// details behind this protocol, while tests can provide deterministic sample
/// counts and typed failures.
@MainActor
protocol HealthCoverageStore: AnyObject {
    var isHealthDataAvailable: Bool { get }

    func authorizationStatus(for objectType: HKObjectType) -> HKAuthorizationStatus
    func authorizationRequestStatus(for objectType: HKObjectType) async throws -> HKAuthorizationRequestStatus
    func sampleStats(
        for sampleType: HKSampleType,
        start7d: Date,
        start30d: Date,
        now: Date
    ) async throws -> HealthCoverageSampleStats
}

struct HealthCoverageSampleStats: Equatable, Sendable {
    let sampleCount7d: Int
    let sampleCount30d: Int
    let latestSampleAt: Date?

    init(sampleCount7d: Int, sampleCount30d: Int, latestSampleAt: Date?) {
        self.sampleCount7d = max(0, sampleCount7d)
        self.sampleCount30d = max(0, sampleCount30d)
        self.latestSampleAt = latestSampleAt
    }
}

/// Production implementation of the injectable coverage store.
@MainActor
final class HealthKitCoverageStore: HealthCoverageStore {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HealthStoreProvider.shared) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationStatus(for objectType: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: objectType)
    }

    func authorizationRequestStatus(for objectType: HKObjectType) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: [], read: [objectType]) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func sampleStats(
        for sampleType: HKSampleType,
        start7d: Date,
        start30d: Date,
        now: Date
    ) async throws -> HealthCoverageSampleStats {
        try await withCheckedThrowingContinuation { continuation in
            let latestPredicate = HKQuery.predicateForSamples(
                withStart: start30d,
                end: now,
                options: .strictStartDate
            )
            let sortDescriptor = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate,
                ascending: false
            )
            let latestQuery = HKSampleQuery(
                sampleType: sampleType,
                predicate: latestPredicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let latestDate = samples?.first?.startDate
                let countPredicate = HKQuery.predicateForSamples(
                    withStart: start30d,
                    end: now,
                    options: .strictStartDate
                )
                let allQuery = HKSampleQuery(
                    sampleType: sampleType,
                    predicate: countPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, allSamples, allError in
                    if let allError {
                        continuation.resume(throwing: allError)
                        return
                    }

                    let samples = allSamples ?? []
                    continuation.resume(returning: HealthCoverageSampleStats(
                        sampleCount7d: samples.filter { $0.startDate >= start7d }.count,
                        sampleCount30d: samples.count,
                        latestSampleAt: latestDate
                    ))
                }
                self.healthStore.execute(allQuery)
            }
            healthStore.execute(latestQuery)
        }
    }
}

public enum HealthSignal: String, Codable, CaseIterable, Sendable {
    case hrvSDNN = "hrv_sdnn"
    case heartRateVariabilityRMSSD = "hrv_rmssd"
    case restingHR = "resting_hr"
    case respiratoryRate = "respiratory_rate"
    case sleepAnalysis = "sleep_analysis"
    case wristTemperature = "wrist_temperature"
    case oxygenSaturation = "oxygen_saturation"
    case workouts = "workouts"
    case activeEnergy = "active_energy"
    case exerciseTime = "exercise_time"
    case stepCount = "step_count"
    case workoutHR = "workout_hr"
    case heartRateRecoveryOneMinute = "heart_rate_recovery_one_minute"
    case walkingSpeed = "walking_speed"
    case walkingAsymmetry = "walking_asymmetry"
    case doubleSupport = "double_support"
    case walkingStepLength = "walking_step_length"
    case walkingHeartRate = "walking_heart_rate"
    case walkingSteadiness = "walking_steadiness"
    case stairAscentSpeed = "stair_ascent_speed"
    case stairDescentSpeed = "stair_descent_speed"
    case sixMinuteWalkDistance = "six_minute_walk_distance"
    case vo2Max = "vo2_max"
    case height = "height"
    case bodyMassIndex = "body_mass_index"
    case bodyMass = "body_mass"
    case bodyFatPercentage = "body_fat_percentage"
    case leanBodyMass = "lean_body_mass"
    case bodyTemperature = "body_temperature"
    case bloodPressureSystolic = "blood_pressure_systolic"
    case bloodPressureDiastolic = "blood_pressure_diastolic"
    case bloodGlucose = "blood_glucose"
    case dietaryEnergy = "dietary_energy"
    case water = "water"
    case caffeine = "caffeine"
    case dietaryProtein = "dietary_protein"
    case dietaryCarbohydrates = "dietary_carbohydrates"
    case dietaryFat = "dietary_fat"
    case envNoise = "env_noise"
    case headphoneNoise = "headphone_noise"
    case daylight = "daylight"
    case standTime = "stand_time"
    case flightsClimbed = "flights_climbed"
    case walkingRunningDistance = "walking_running_distance"
    case cyclingDistance = "cycling_distance"
    case mindfulSession = "mindful_session"
    case sleepBreathingDisturbances = "sleep_breathing_disturbances"
    case workoutRoute = "workout_route"

    public var name: String {
        switch self {
        case .hrvSDNN: return "HRV (SDNN)"
        case .heartRateVariabilityRMSSD: return "HRV (RMSSD)"
        case .restingHR: return AppLanguage.stored.isChinese ? "静息心率" : "Resting HR"
        case .respiratoryRate: return AppLanguage.stored.isChinese ? "呼吸率" : "Respiratory Rate"
        case .sleepAnalysis: return AppLanguage.stored.isChinese ? "睡眠分析" : "Sleep Analysis"
        case .wristTemperature: return AppLanguage.stored.isChinese ? "腕温" : "Wrist Temperature"
        case .oxygenSaturation: return AppLanguage.stored.isChinese ? "血氧" : "Blood Oxygen"
        case .workouts: return AppLanguage.stored.isChinese ? "运动记录" : "Workouts"
        case .activeEnergy: return AppLanguage.stored.isChinese ? "活动能量" : "Active Energy"
        case .exerciseTime: return AppLanguage.stored.isChinese ? "运动时间" : "Exercise Time"
        case .stepCount: return AppLanguage.stored.isChinese ? "步数" : "Steps"
        case .workoutHR: return AppLanguage.stored.isChinese ? "运动心率" : "Workout HR"
        case .heartRateRecoveryOneMinute: return AppLanguage.stored.isChinese ? "一分钟心率恢复" : "1-minute Heart Rate Recovery"
        case .walkingSpeed: return AppLanguage.stored.isChinese ? "步行速度" : "Walking Speed"
        case .walkingAsymmetry: return AppLanguage.stored.isChinese ? "步态不对称" : "Walking Asymmetry"
        case .doubleSupport: return AppLanguage.stored.isChinese ? "双支撑比例" : "Double Support"
        case .walkingStepLength: return AppLanguage.stored.isChinese ? "步长" : "Walking Step Length"
        case .walkingHeartRate: return AppLanguage.stored.isChinese ? "步行心率" : "Walking Heart Rate"
        case .walkingSteadiness: return AppLanguage.stored.isChinese ? "步行稳定性" : "Walking Steadiness"
        case .stairAscentSpeed: return AppLanguage.stored.isChinese ? "上楼速度" : "Stair Ascent Speed"
        case .stairDescentSpeed: return AppLanguage.stored.isChinese ? "下楼速度" : "Stair Descent Speed"
        case .sixMinuteWalkDistance: return AppLanguage.stored.isChinese ? "六分钟步行距离" : "Six-Minute Walk"
        case .vo2Max: return "VO₂ Max"
        case .height: return AppLanguage.stored.isChinese ? "身高" : "Height"
        case .bodyMassIndex: return "BMI"
        case .bodyMass: return AppLanguage.stored.isChinese ? "体重" : "Body Mass"
        case .bodyFatPercentage: return AppLanguage.stored.isChinese ? "体脂率" : "Body Fat"
        case .leanBodyMass: return AppLanguage.stored.isChinese ? "瘦体重" : "Lean Body Mass"
        case .bodyTemperature: return AppLanguage.stored.isChinese ? "体温" : "Body Temperature"
        case .bloodPressureSystolic: return AppLanguage.stored.isChinese ? "收缩压" : "Systolic Pressure"
        case .bloodPressureDiastolic: return AppLanguage.stored.isChinese ? "舒张压" : "Diastolic Pressure"
        case .bloodGlucose: return AppLanguage.stored.isChinese ? "血糖" : "Blood Glucose"
        case .dietaryEnergy: return AppLanguage.stored.isChinese ? "饮食能量" : "Dietary Energy"
        case .water: return AppLanguage.stored.isChinese ? "水分" : "Water"
        case .caffeine: return AppLanguage.stored.isChinese ? "咖啡因" : "Caffeine"
        case .dietaryProtein: return AppLanguage.stored.isChinese ? "蛋白质" : "Protein"
        case .dietaryCarbohydrates: return AppLanguage.stored.isChinese ? "碳水化合物" : "Carbohydrates"
        case .dietaryFat: return AppLanguage.stored.isChinese ? "脂肪" : "Fat"
        case .envNoise: return AppLanguage.stored.isChinese ? "环境噪音" : "Environmental Audio"
        case .headphoneNoise: return AppLanguage.stored.isChinese ? "耳机音量暴露" : "Headphone Audio"
        case .daylight: return AppLanguage.stored.isChinese ? "日照时间" : "Daylight"
        case .standTime: return AppLanguage.stored.isChinese ? "站立时间" : "Stand Time"
        case .flightsClimbed: return AppLanguage.stored.isChinese ? "爬楼层数" : "Flights Climbed"
        case .walkingRunningDistance: return AppLanguage.stored.isChinese ? "步行跑步距离" : "Walking + Running Distance"
        case .cyclingDistance: return AppLanguage.stored.isChinese ? "骑行距离" : "Cycling Distance"
        case .mindfulSession: return AppLanguage.stored.isChinese ? "正念时长" : "Mindful Minutes"
        case .sleepBreathingDisturbances: return AppLanguage.stored.isChinese ? "睡眠呼吸干扰" : "Breathing Disturbances"
        case .workoutRoute: return AppLanguage.stored.isChinese ? "运动路线" : "Workout Route"
        }
    }

    public var objectType: HKObjectType? {
        HealthSignalCatalog.objectType(for: self)
    }
}

enum HealthSignalCatalog {
    struct UnitDescriptor {
        var healthKitUnit: HKUnit
        var symbol: String
    }

    static let coreSignals: [HealthSignal] = [
        .sleepAnalysis, .hrvSDNN, .restingHR, .workoutHR, .heartRateRecoveryOneMinute, .respiratoryRate,
        .activeEnergy, .exerciseTime, .stepCount, .workouts
    ]

    static let enhancedSignals: [HealthSignal] = [
        .vo2Max, .bodyMass, .bodyFatPercentage, .leanBodyMass,
        .oxygenSaturation, .bodyTemperature, .wristTemperature
    ]

    static var advancedSignals: [HealthSignal] {
        var result = HealthSignal.allCases.filter {
            !coreSignals.contains($0) && !enhancedSignals.contains($0) && $0 != .sleepBreathingDisturbances
        }
        if #available(iOS 18.0, *) {
            result.append(.sleepBreathingDisturbances)
        }
        return result
    }

    static func signals(for tier: HealthPermissionTier) -> [HealthSignal] {
        switch tier {
        case .core: coreSignals
        case .enhanced: coreSignals + enhancedSignals
        case .advanced: coreSignals + enhancedSignals + advancedSignals
        }
    }

    static func readTypes(for tier: HealthPermissionTier) -> [HKObjectType] {
        Array(Set(signals(for: tier).compactMap(objectType(for:))))
    }

    static func objectType(for signal: HealthSignal) -> HKObjectType? {
        switch signal {
        case .hrvSDNN:
            return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .heartRateVariabilityRMSSD:
            // HealthKit publicly exposes HRV as SDNN. RMSSD remains a derived
            // model input and must not be represented as an independently
            // readable HealthKit signal.
            return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .restingHR:
            return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .respiratoryRate:
            return HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        case .sleepAnalysis:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .wristTemperature:
            return HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        case .oxygenSaturation:
            return HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        case .workouts:
            return HKObjectType.workoutType()
        case .activeEnergy:
            return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .exerciseTime:
            return HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .stepCount:
            return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .workoutHR:
            return HKObjectType.quantityType(forIdentifier: .heartRate)
        case .heartRateRecoveryOneMinute:
            return HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)
        case .walkingSpeed:
            return HKObjectType.quantityType(forIdentifier: .walkingSpeed)
        case .walkingAsymmetry:
            return HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .doubleSupport:
            return HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)
        case .walkingStepLength:
            return HKObjectType.quantityType(forIdentifier: .walkingStepLength)
        case .walkingHeartRate:
            return HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .walkingSteadiness:
            return HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness)
        case .stairAscentSpeed:
            return HKObjectType.quantityType(forIdentifier: .stairAscentSpeed)
        case .stairDescentSpeed:
            return HKObjectType.quantityType(forIdentifier: .stairDescentSpeed)
        case .sixMinuteWalkDistance:
            return HKObjectType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)
        case .vo2Max:
            return HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .height:
            return HKObjectType.quantityType(forIdentifier: .height)
        case .bodyMassIndex:
            return HKObjectType.quantityType(forIdentifier: .bodyMassIndex)
        case .bodyMass:
            return HKObjectType.quantityType(forIdentifier: .bodyMass)
        case .bodyFatPercentage:
            return HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
        case .leanBodyMass:
            return HKObjectType.quantityType(forIdentifier: .leanBodyMass)
        case .bodyTemperature:
            return HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        case .bloodPressureSystolic:
            return HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .bloodPressureDiastolic:
            return HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .bloodGlucose:
            return HKObjectType.quantityType(forIdentifier: .bloodGlucose)
        case .dietaryEnergy:
            return HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .water:
            return HKObjectType.quantityType(forIdentifier: .dietaryWater)
        case .caffeine:
            return HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)
        case .dietaryProtein:
            return HKObjectType.quantityType(forIdentifier: .dietaryProtein)
        case .dietaryCarbohydrates:
            return HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)
        case .dietaryFat:
            return HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)
        case .envNoise:
            return HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)
        case .headphoneNoise:
            return HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)
        case .daylight:
            return HKObjectType.quantityType(forIdentifier: .timeInDaylight)
        case .standTime:
            return HKObjectType.quantityType(forIdentifier: .appleStandTime)
        case .flightsClimbed:
            return HKObjectType.quantityType(forIdentifier: .flightsClimbed)
        case .walkingRunningDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .cyclingDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .mindfulSession:
            return HKObjectType.categoryType(forIdentifier: .mindfulSession)
        case .sleepBreathingDisturbances:
            if #available(iOS 18.0, *) {
                return HKObjectType.quantityType(forIdentifier: .appleSleepingBreathingDisturbances)
            } else {
                return nil
            }
        case .workoutRoute:
            return HKSeriesType.workoutRoute()
        }
    }

    static func unit(for signal: HealthSignal) -> UnitDescriptor? {
        switch signal {
        case .hrvSDNN, .heartRateVariabilityRMSSD:
            UnitDescriptor(healthKitUnit: .secondUnit(with: .milli), symbol: "ms")
        case .restingHR, .workoutHR, .walkingHeartRate:
            UnitDescriptor(healthKitUnit: HKUnit.count().unitDivided(by: .minute()), symbol: "bpm")
        case .heartRateRecoveryOneMinute:
            // Apple 的 heartRateRecoveryOneMinute 样本单位是 count/min(次/分钟)。
            // 若写成 .count(),真机上 doubleValue(for:) 会抛
            // NSInvalidArgumentException 导致 App 启动崩溃。
            UnitDescriptor(healthKitUnit: HKUnit.count().unitDivided(by: .minute()), symbol: "bpm")
        case .respiratoryRate:
            UnitDescriptor(healthKitUnit: HKUnit.count().unitDivided(by: .minute()), symbol: "breaths/min")
        case .wristTemperature, .bodyTemperature:
            UnitDescriptor(healthKitUnit: .degreeCelsius(), symbol: "°C")
        case .oxygenSaturation, .bodyFatPercentage, .walkingAsymmetry, .doubleSupport, .walkingSteadiness:
            UnitDescriptor(healthKitUnit: .percent(), symbol: "%")
        case .activeEnergy, .dietaryEnergy:
            UnitDescriptor(healthKitUnit: .kilocalorie(), symbol: "kcal")
        case .exerciseTime, .standTime, .daylight:
            UnitDescriptor(healthKitUnit: .minute(), symbol: "min")
        case .stepCount, .flightsClimbed, .bodyMassIndex:
            UnitDescriptor(healthKitUnit: .count(), symbol: "count")
        case .walkingSpeed, .stairAscentSpeed, .stairDescentSpeed:
            UnitDescriptor(healthKitUnit: HKUnit.meter().unitDivided(by: .second()), symbol: "m/s")
        case .walkingStepLength, .sixMinuteWalkDistance:
            UnitDescriptor(healthKitUnit: .meter(), symbol: "m")
        case .vo2Max:
            UnitDescriptor(healthKitUnit: HKUnit(from: "ml/kg*min"), symbol: "mL/kg/min")
        case .height:
            UnitDescriptor(healthKitUnit: .meterUnit(with: .centi), symbol: "cm")
        case .bodyMass, .leanBodyMass:
            UnitDescriptor(healthKitUnit: .gramUnit(with: .kilo), symbol: "kg")
        case .bloodPressureSystolic, .bloodPressureDiastolic:
            UnitDescriptor(healthKitUnit: .millimeterOfMercury(), symbol: "mmHg")
        case .bloodGlucose:
            UnitDescriptor(healthKitUnit: HKUnit(from: "mg/dL"), symbol: "mg/dL")
        case .water:
            UnitDescriptor(healthKitUnit: .literUnit(with: .milli), symbol: "mL")
        case .caffeine:
            UnitDescriptor(healthKitUnit: .gramUnit(with: .milli), symbol: "mg")
        case .dietaryProtein, .dietaryCarbohydrates, .dietaryFat:
            UnitDescriptor(healthKitUnit: .gram(), symbol: "g")
        case .envNoise, .headphoneNoise:
            UnitDescriptor(healthKitUnit: .decibelAWeightedSoundPressureLevel(), symbol: "dB(A)")
        case .walkingRunningDistance, .cyclingDistance:
            UnitDescriptor(healthKitUnit: .meterUnit(with: .kilo), symbol: "km")
        case .sleepBreathingDisturbances:
            UnitDescriptor(
                healthKitUnit: HKUnit.count().unitDivided(by: .hour()),
                symbol: "events/h"
            )
        case .sleepAnalysis, .workouts, .mindfulSession, .workoutRoute:
            nil
        }
    }
}

public enum HealthSignalAuthorizationState: String, Codable, Sendable {
    case notRequested
    case readableSamples
    case noReadableSamples
    case readableSamplesStale
    case unavailable
    case denied
}

public struct HealthSignalCoverage: Identifiable, Codable, Hashable, Sendable {
    public var id: String { signal.rawValue }
    public let signal: HealthSignal
    public let authorizationState: HealthSignalAuthorizationState
    public let sampleCount7d: Int
    public let sampleCount30d: Int
    public let latestSampleAt: Date?
    public let freshness: DataFreshness
    public let quality: SignalQuality

    /// Typed query outcome is kept alongside authorization/sample coverage.
    /// A missing sample (`noData`) is deliberately distinct from a denied,
    /// unavailable, transient, or failed read; score kernels continue to use
    /// nil for missing values and never infer a zero from this field.
    let queryOutcome: HealthQueryOutcomeKind?

    init(
        signal: HealthSignal,
        authorizationState: HealthSignalAuthorizationState,
        sampleCount7d: Int,
        sampleCount30d: Int,
        latestSampleAt: Date?,
        freshness: DataFreshness,
        quality: SignalQuality,
        queryOutcome: HealthQueryOutcomeKind? = nil
    ) {
        self.signal = signal
        self.authorizationState = authorizationState
        self.sampleCount7d = sampleCount7d
        self.sampleCount30d = sampleCount30d
        self.latestSampleAt = latestSampleAt
        self.freshness = freshness
        self.quality = quality
        self.queryOutcome = queryOutcome
    }
    
    public var isAvailable: Bool {
        sampleCount30d > 0
    }

    /// Permission has been resolved (user has interacted with the permission prompt).
    public var isPermissionResolved: Bool {
        authorizationState != .notRequested
    }

    /// Signal has enough recent data to be analytically usable for high-confidence judgments.
    /// Stale or empty signals are not analytically usable.
    public var analyticallyUsable: Bool {
        authorizationState == .readableSamples &&
        freshness != .missing &&
        freshness != .stale &&
        quality != .insufficient
    }

    public var confidenceImpact: String {
        switch authorizationState {
        case .readableSamples:
            switch (freshness, quality) {
            case (.live, .enough), (.today, .enough):
                return AppLanguage.stored.isChinese ? "可用于高置信度判断" : "Supports high-confidence judgments"
            default:
                return AppLanguage.stored.isChinese ? "可用，但会降低判断置信度" : "Available, with reduced confidence"
            }
        case .readableSamplesStale:
            return AppLanguage.stored.isChinese ? "近期无数据，置信度较低" : "No recent data; confidence is low"
        case .noReadableSamples:
            return AppLanguage.stored.isChinese
                ? "未读取到近期数据；可能是暂无样本或读取范围受限"
                : "No recent data was readable; samples may be absent or read access may be limited"
        case .denied:
            return AppLanguage.stored.isChinese
                ? "权限已被拒绝——去系统设置开启后才能读取该数据"
                : "Permission was denied — enable it in system settings to read this data"
        case .notRequested:
            return AppLanguage.stored.isChinese ? "尚未请求权限，相关判断不可用" : "Permission not requested; related judgments are unavailable"
        case .unavailable:
            return AppLanguage.stored.isChinese ? "当前设备不支持该数据，相关判断不可用" : "This data type is unavailable on the device"
        }
    }
}

enum HealthReadStateResolver {
    static func resolve(
        requestStatus: HKAuthorizationRequestStatus,
        sharingStatus: HKAuthorizationStatus,
        sampleCount7d: Int,
        sampleCount30d: Int
    ) -> HealthSignalAuthorizationState {
        if sampleCount30d > 0 {
            return sampleCount7d > 0 ? .readableSamples : .readableSamplesStale
        }
        if sharingStatus == .sharingDenied {
            return .denied
        }
        return requestStatus == .shouldRequest ? .notRequested : .noReadableSamples
    }
}

@MainActor
public final class HealthSignalCoverageService {
    private let store: HealthCoverageStore
    private(set) var diagnostics: [HealthQueryDiagnostic] = []

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = HealthKitCoverageStore(healthStore: store)
    }

    /// Injectable initializer for deterministic coverage tests and preview
    /// providers.  The public HKHealthStore initializer above remains source
    /// compatible for production callers.
    init(coverageStore: HealthCoverageStore) {
        self.store = coverageStore
    }

    func consumeDiagnostics() -> [HealthQueryDiagnostic] {
        defer { diagnostics.removeAll(keepingCapacity: true) }
        return diagnostics
    }

    public func fetchCoverage(for signal: HealthSignal) async -> HealthSignalCoverage {
        guard let objectType = signal.objectType else {
            recordDiagnostic(
                component: signal.rawValue,
                outcome: .unavailable,
                error: nil
            )
            return HealthSignalCoverage(
                signal: signal,
                authorizationState: .unavailable,
                sampleCount7d: 0,
                sampleCount30d: 0,
                latestSampleAt: nil,
                freshness: .missing,
                quality: .insufficient,
                queryOutcome: .unavailable
            )
        }

        guard store.isHealthDataAvailable else {
            recordDiagnostic(
                component: signal.rawValue,
                outcome: .unavailable,
                error: nil
            )
            return HealthSignalCoverage(
                signal: signal,
                authorizationState: .unavailable,
                sampleCount7d: 0,
                sampleCount30d: 0,
                latestSampleAt: nil,
                freshness: .missing,
                quality: .insufficient,
                queryOutcome: .unavailable
            )
        }

        // 1. Fetch Sample Details
        let now = Date()
        let cal = Calendar.current
        let d7 = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let d30 = cal.date(byAdding: .day, value: -30, to: now) ?? now

        let stats: HealthCoverageSampleStats
        do {
            guard let sampleType = objectType as? HKSampleType else {
                // Series types (for example workout routes) do not support
                // HKSampleQuery counts. Treat that as a clean no-data read,
                // preserving missing-data semantics without a fabricated 0.
                stats = HealthCoverageSampleStats(
                    sampleCount7d: 0,
                    sampleCount30d: 0,
                    latestSampleAt: nil
                )
                let requestStatus = try await store.authorizationRequestStatus(for: objectType)
                let sharingStatus = store.authorizationStatus(for: objectType)
                let outcome: HealthQueryOutcomeKind = sharingStatus == .sharingDenied ? .denied : .noData
                recordDiagnostic(component: signal.rawValue, outcome: outcome, error: nil)
                return makeCoverage(
                    signal: signal,
                    requestStatus: requestStatus,
                    sharingStatus: sharingStatus,
                    stats: stats,
                    now: now,
                    calendar: cal,
                    queryOutcome: outcome
                )
            }
            stats = try await store.sampleStats(
                for: sampleType,
                start7d: d7,
                start30d: d30,
                now: now
            )
        } catch {
            let outcome = HealthKitQueryOutcomeClassifier.classify(error)
            recordDiagnostic(component: signal.rawValue, outcome: outcome, error: error)
            return makeUnavailableCoverage(signal: signal, outcome: outcome)
        }

        let requestStatus: HKAuthorizationRequestStatus
        do {
            requestStatus = try await store.authorizationRequestStatus(for: objectType)
        } catch {
            let outcome = HealthKitQueryOutcomeClassifier.classify(error)
            recordDiagnostic(component: signal.rawValue, outcome: outcome, error: error)
            return makeUnavailableCoverage(signal: signal, outcome: outcome)
        }
        let sharingStatus = store.authorizationStatus(for: objectType)
        let outcome: HealthQueryOutcomeKind = sharingStatus == .sharingDenied
            ? .denied
            : stats.sampleCount30d > 0 ? .data : .noData
        if outcome != .data {
            recordDiagnostic(component: signal.rawValue, outcome: outcome, error: nil)
        }
        return makeCoverage(
            signal: signal,
            requestStatus: requestStatus,
            sharingStatus: sharingStatus,
            stats: stats,
            now: now,
            calendar: cal,
            queryOutcome: outcome
        )
    }

    private func recordDiagnostic(
        component: String,
        outcome: HealthQueryOutcomeKind,
        error: Error?
    ) {
        diagnostics.append(HealthQueryDiagnostic(
            component: component,
            outcome: outcome,
            error: error
        ))
    }

    private func makeUnavailableCoverage(
        signal: HealthSignal,
        outcome: HealthQueryOutcomeKind
    ) -> HealthSignalCoverage {
        HealthSignalCoverage(
            signal: signal,
            authorizationState: outcome == .denied ? .denied : outcome == .unavailable ? .unavailable : .noReadableSamples,
            sampleCount7d: 0,
            sampleCount30d: 0,
            latestSampleAt: nil,
            freshness: .missing,
            quality: .insufficient,
            queryOutcome: outcome
        )
    }

    private func makeCoverage(
        signal: HealthSignal,
        requestStatus: HKAuthorizationRequestStatus,
        sharingStatus: HKAuthorizationStatus,
        stats: HealthCoverageSampleStats,
        now: Date,
        calendar: Calendar,
        queryOutcome: HealthQueryOutcomeKind
    ) -> HealthSignalCoverage {
        let count7d = stats.sampleCount7d
        let count30d = stats.sampleCount30d
        let latestSampleDate = stats.latestSampleAt
        let authState = HealthReadStateResolver.resolve(
            requestStatus: requestStatus,
            sharingStatus: sharingStatus,
            sampleCount7d: count7d,
            sampleCount30d: count30d
        )

        // 2. Compute Freshness & Quality
        var freshness: DataFreshness = .missing
        var quality: SignalQuality = .insufficient

        let hasData = (authState == .readableSamples || authState == .readableSamplesStale)
        if hasData {
            if let latest = latestSampleDate {
                let diffHours = now.timeIntervalSince(latest) / 3600.0
                if diffHours <= 2.0 {
                    freshness = .live
                } else if calendar.isDateInToday(latest) {
                    freshness = .today
                } else if diffHours <= 168.0 { // 7 days
                    freshness = .recent
                } else {
                    freshness = .stale
                }
            } else {
                freshness = .missing
            }

            if count7d >= 7 {
                quality = .enough
            } else if count7d >= 3 {
                quality = .partial
            } else {
                quality = .insufficient
            }
        } else {
            freshness = .missing
            quality = .insufficient
        }

        return HealthSignalCoverage(
            signal: signal,
            authorizationState: authState,
            sampleCount7d: count7d,
            sampleCount30d: count30d,
            latestSampleAt: latestSampleDate,
            freshness: freshness,
            quality: quality,
            queryOutcome: queryOutcome
        )
    }
}

public enum SignalQuality: String, Codable, Hashable, CaseIterable, Sendable {
    case enough
    case partial
    case insufficient

    public var label: String {
        switch self {
        case .enough: return AppLanguage.stored.isChinese ? "充足" : "Enough"
        case .partial: return AppLanguage.stored.isChinese ? "部分" : "Partial"
        case .insufficient: return AppLanguage.stored.isChinese ? "不足" : "Insufficient"
        }
    }
}
