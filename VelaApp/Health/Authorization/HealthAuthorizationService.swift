import Foundation
import HealthKit

@MainActor
protocol HealthStoreProviding {
    var isHealthDataAvailable: Bool { get }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
}

extension HKHealthStore: HealthStoreProviding {
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
}

public enum HealthPermissionTier: String, Codable, CaseIterable {
    case core
    case enhanced
    case advanced
}

public struct HealthPermissionMatrix: Codable, Hashable {
    public var hasSleepAnalysis: Bool
    public var hasHRV: Bool
    public var hasRestingHR: Bool
    public var hasHeartRate: Bool
    public var hasRespiratoryRate: Bool
    public var hasActiveEnergy: Bool
    public var hasExerciseTime: Bool
    public var hasStepCount: Bool
    public var hasWorkout: Bool
    
    // Enhanced
    public var hasVO2Max: Bool
    public var hasBodyMass: Bool
    public var hasBodyFat: Bool
    public var hasLeanBodyMass: Bool
    public var hasOxygenSaturation: Bool
    public var hasBodyTemperature: Bool
    
    // Advanced
    public var hasBloodGlucose: Bool
    public var hasBloodPressure: Bool
    public var hasNutrition: Bool
    public var hasWalkingSteadiness: Bool
    public var hasEnvironmentalAudio: Bool
    public var hasMindfulSession: Bool
}

@MainActor
final class HealthAuthorizationService {
    private let healthStore: HealthStoreProviding

    init(healthStore: HealthStoreProviding = HealthStoreProvider.shared) {
        self.healthStore = healthStore
    }

    var isHealthDataAvailable: Bool {
        healthStore.isHealthDataAvailable
    }

    func requestAuthorization() async throws {
        try await requestAuthorization(tier: .core)
    }

    func requestAuthorization(tier: HealthPermissionTier) async throws {
        guard isHealthDataAvailable else {
            throw HealthAuthorizationError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType>
        switch tier {
        case .core:
            readTypes = Set(HealthDataTypeCatalog.coreTypes)
        case .enhanced:
            readTypes = Set(HealthDataTypeCatalog.enhancedTypes)
        case .advanced:
            readTypes = Set(HealthDataTypeCatalog.advancedTypes)
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func permissionSnapshot() -> HealthPermissionSnapshot {
        HealthPermissionSnapshot(
            isHealthDataAvailable: isHealthDataAvailable,
            requestedReadTypes: HealthDataTypeCatalog.readTypes.count
        )
    }

    func permissionMatrix() -> HealthPermissionMatrix {
        func check(_ identifier: HKCategoryTypeIdentifier) -> Bool {
            guard let type = HKObjectType.categoryType(forIdentifier: identifier) else { return false }
            return healthStore.authorizationStatus(for: type) != .notDetermined
        }
        func check(_ identifier: HKQuantityTypeIdentifier) -> Bool {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return false }
            return healthStore.authorizationStatus(for: type) != .notDetermined
        }
        func checkWorkout() -> Bool {
            let type = HKObjectType.workoutType()
            return healthStore.authorizationStatus(for: type) != .notDetermined
        }

        return HealthPermissionMatrix(
            hasSleepAnalysis: check(.sleepAnalysis),
            hasHRV: check(.heartRateVariabilitySDNN),
            hasRestingHR: check(.restingHeartRate),
            hasHeartRate: check(.heartRate),
            hasRespiratoryRate: check(.respiratoryRate),
            hasActiveEnergy: check(.activeEnergyBurned),
            hasExerciseTime: check(.appleExerciseTime),
            hasStepCount: check(.stepCount),
            hasWorkout: checkWorkout(),
            
            hasVO2Max: check(.vo2Max),
            hasBodyMass: check(.bodyMass),
            hasBodyFat: check(.bodyFatPercentage),
            hasLeanBodyMass: check(.leanBodyMass),
            hasOxygenSaturation: check(.oxygenSaturation),
            hasBodyTemperature: check(.bodyTemperature),
            
            hasBloodGlucose: check(.bloodGlucose),
            hasBloodPressure: check(.bloodPressureSystolic),
            hasNutrition: check(.dietaryWater),
            hasWalkingSteadiness: check(.appleWalkingSteadiness),
            hasEnvironmentalAudio: check(.environmentalAudioExposure),
            hasMindfulSession: check(.mindfulSession)
        )
    }
}

enum HealthAuthorizationError: Error {
    case healthDataUnavailable
}

struct HealthPermissionSnapshot: Hashable {
    let isHealthDataAvailable: Bool
    let requestedReadTypes: Int
}

enum HealthDataTypeCatalog {
    static var coreTypes: [HKObjectType] {
        [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.workoutType()
        ].compactMap { $0 }
    }

    static var enhancedTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .leanBodyMass),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        ].compactMap { $0 }
    }

    static var advancedTypes: [HKObjectType] {
        var types = [
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
            HKObjectType.quantityType(forIdentifier: .bloodGlucose),
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .dietaryCaffeine),
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
            HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness),
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure),
            HKObjectType.categoryType(forIdentifier: .mindfulSession)
        ].compactMap { $0 }
        if #available(iOS 18.0, *) {
            if let disturbances = HKObjectType.quantityType(forIdentifier: .appleSleepingBreathingDisturbances) {
                types.append(disturbances)
            }
        }
        return types
    }

    static var readTypes: [HKObjectType] {
        Array(Set(coreTypes + enhancedTypes + advancedTypes))
    }

    // Legacy helpers for backward compatibility with existing tests
    static var sleepReadTypes: [HKObjectType] {
        [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)].compactMap { $0 }
    }
    static var recoveryReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        ].compactMap { $0 }
    }
    static var strainReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.workoutType()
        ].compactMap { $0 }
    }
    static var biologyReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .leanBodyMass)
        ].compactMap { $0 }
    }
}
