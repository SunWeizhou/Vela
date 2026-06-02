import Foundation
import HealthKit

public enum HealthSignal: String, Codable, CaseIterable, Sendable {
    // Recovery
    case hrvSDNN = "hrv_sdnn"
    case restingHR = "resting_hr"
    case respiratoryRate = "respiratory_rate"
    
    // Sleep
    case sleepAnalysis = "sleep_analysis"
    case wristTemperature = "wrist_temperature"
    case oxygenSaturation = "oxygen_saturation"
    
    // Training
    case workouts = "workouts"
    case activeEnergy = "active_energy"
    case exerciseTime = "exercise_time"
    case stepCount = "step_count"
    case workoutHR = "workout_hr"
    
    // Gait
    case walkingSpeed = "walking_speed"
    case walkingAsymmetry = "walking_asymmetry"
    case doubleSupport = "double_support"
    
    // Cardio
    case vo2Max = "vo2_max"
    
    // Nutrition
    case dietaryEnergy = "dietary_energy"
    case water = "water"
    case caffeine = "caffeine"
    
    // Environment
    case envNoise = "env_noise"
    case daylight = "daylight"
    
    public var name: String {
        switch self {
        case .hrvSDNN: return "HRV (SDNN)"
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
        case .walkingSpeed: return AppLanguage.stored.isChinese ? "步行速度" : "Walking Speed"
        case .walkingAsymmetry: return AppLanguage.stored.isChinese ? "步态不对称" : "Walking Asymmetry"
        case .doubleSupport: return AppLanguage.stored.isChinese ? "双支撑比例" : "Double Support"
        case .vo2Max: return "VO₂ Max"
        case .dietaryEnergy: return AppLanguage.stored.isChinese ? "饮食能量" : "Dietary Energy"
        case .water: return AppLanguage.stored.isChinese ? "水分" : "Water"
        case .caffeine: return AppLanguage.stored.isChinese ? "咖啡因" : "Caffeine"
        case .envNoise: return AppLanguage.stored.isChinese ? "环境噪音" : "Env. Noise"
        case .daylight: return AppLanguage.stored.isChinese ? "日照时间" : "Daylight"
        }
    }
    
    public var objectType: HKObjectType? {
        switch self {
        case .hrvSDNN: return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .restingHR: return HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .respiratoryRate: return HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        case .sleepAnalysis: return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .wristTemperature: return HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        case .oxygenSaturation: return HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        case .workouts: return HKObjectType.workoutType()
        case .activeEnergy: return HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .exerciseTime: return HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .stepCount: return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .workoutHR: return HKObjectType.quantityType(forIdentifier: .heartRate)
        case .walkingSpeed: return HKObjectType.quantityType(forIdentifier: .walkingSpeed)
        case .walkingAsymmetry: return HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .doubleSupport: return HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage)
        case .vo2Max: return HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .dietaryEnergy: return HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .water: return HKObjectType.quantityType(forIdentifier: .dietaryWater)
        case .caffeine: return HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)
        case .envNoise: return HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure)
        case .daylight: return HKObjectType.quantityType(forIdentifier: .timeInDaylight)
        }
    }
}

public enum HealthSignalAuthorizationState: String, Codable, Sendable {
    case notDetermined
    case authorized
    case authorizedButNoSamples
    case noRecentSamples
    case deniedOrUnavailable
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
    
    public var isAvailable: Bool {
        authorizationState == .authorized || authorizationState == .noRecentSamples || authorizationState == .authorizedButNoSamples
    }

    /// Permission has been resolved (user has interacted with the permission prompt).
    public var isPermissionResolved: Bool {
        authorizationState != .notDetermined
    }

    /// Signal has enough recent data to be analytically usable for high-confidence judgments.
    /// Stale data (noRecentSamples) or authorized-but-empty signals are NOT analytically usable.
    public var analyticallyUsable: Bool {
        authorizationState == .authorized &&
        freshness != .missing &&
        freshness != .stale &&
        quality != .insufficient
    }

    public var confidenceImpact: String {
        switch authorizationState {
        case .authorized:
            switch (freshness, quality) {
            case (.live, .enough), (.today, .enough):
                return AppLanguage.stored.isChinese ? "可用于高置信度判断" : "Supports high-confidence judgments"
            default:
                return AppLanguage.stored.isChinese ? "可用，但会降低判断置信度" : "Available, with reduced confidence"
            }
        case .noRecentSamples:
            return AppLanguage.stored.isChinese ? "近期无数据，置信度较低" : "No recent data; confidence is low"
        case .authorizedButNoSamples:
            return AppLanguage.stored.isChinese ? "已授权但尚无数据" : "Authorized but no samples recorded"
        case .notDetermined:
            return AppLanguage.stored.isChinese ? "尚未请求权限，相关判断不可用" : "Permission not requested; related judgments are unavailable"
        case .deniedOrUnavailable:
            return AppLanguage.stored.isChinese ? "权限拒绝或设备不支持，相关判断不可用" : "Permission denied or unsupported; related judgments are unavailable"
        }
    }
}

@MainActor
public final class HealthSignalCoverageService {
    private let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    public func fetchCoverage(for signal: HealthSignal) async -> HealthSignalCoverage {
        guard let objectType = signal.objectType else {
            return HealthSignalCoverage(
                signal: signal,
                authorizationState: .deniedOrUnavailable,
                sampleCount7d: 0,
                sampleCount30d: 0,
                latestSampleAt: nil,
                freshness: .missing,
                quality: .insufficient
            )
        }

        // 1. Resolve Authorization State from HealthStore
        let status = store.authorizationStatus(for: objectType)
        var authState: HealthSignalAuthorizationState = .notDetermined

        if status == .notDetermined {
            authState = .notDetermined
        } else {
            // Note: Since read authorization cannot be directly queried, we default to deniedOrUnavailable
            authState = .deniedOrUnavailable
        }

        // 2. Fetch Sample Details
        let now = Date()
        let cal = Calendar.current
        let d7 = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let d30 = cal.date(byAdding: .day, value: -30, to: now) ?? now

        let (count7d, count30d, latestSampleDate) = await fetchSampleStats(for: objectType, start7d: d7, start30d: d30)

        if status != .notDetermined {
            if count30d > 0 {
                // If there are samples in 30d, we are authorized. Check if there are recent samples in 7d.
                if count7d > 0 {
                    authState = .authorized
                } else {
                    authState = .noRecentSamples
                }
            } else {
                // If sharing is explicitly authorized, we know the permission was prompted and accepted
                if status == .sharingAuthorized {
                    authState = .authorizedButNoSamples
                } else {
                    // HKHealthStore returns sharingDenied for read-only permissions if declined,
                    // but also sharingDenied if it's read-only and accepted (since write is denied).
                    // So we treat 0 samples in 30 days but prompt completed as authorizedButNoSamples,
                    // since the user completed onboarding.
                    authState = .authorizedButNoSamples
                }
            }
        }

        // 3. Compute Freshness & Quality
        var freshness: DataFreshness = .missing
        var quality: SignalQuality = .insufficient

        let hasData = (authState == .authorized || authState == .noRecentSamples)
        if hasData {
            if let latest = latestSampleDate {
                let diffHours = now.timeIntervalSince(latest) / 3600.0
                if diffHours <= 2.0 {
                    freshness = .live
                } else if cal.isDateInToday(latest) {
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
            quality: quality
        )
    }

    private func fetchSampleStats(for type: HKObjectType, start7d: Date, start30d: Date) async -> (Int, Int, Date?) {
        guard let sampleType = type as? HKSampleType else { return (0, 0, nil) }

        return await withCheckedContinuation { continuation in
            let now = Date()
            let pred30d = HKQuery.predicateForSamples(withStart: start30d, end: now, options: .strictStartDate)
            
            // Query the most recent sample first to get the latest date
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: pred30d,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let samples = samples else {
                    continuation.resume(returning: (0, 0, nil))
                    return
                }
                
                let latestDate = samples.first?.startDate
                
                // Now run a query to count all samples in 30d and 7d
                let countPredicate = HKQuery.predicateForSamples(withStart: start30d, end: now, options: .strictStartDate)
                let allQuery = HKSampleQuery(
                    sampleType: sampleType,
                    predicate: countPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, allSamples, allErr in
                    guard allErr == nil, let allSamples = allSamples else {
                        continuation.resume(returning: (0, 0, latestDate))
                        return
                    }
                    
                    let c30d = allSamples.count
                    let c7d = allSamples.filter { $0.startDate >= start7d }.count
                    
                    continuation.resume(returning: (c7d, c30d, latestDate))
                }
                self.store.execute(allQuery)
            }
            self.store.execute(query)
        }
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
