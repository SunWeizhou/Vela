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
        guard isHealthDataAvailable else {
            throw HealthAuthorizationError.healthDataUnavailable
        }

        let readTypes = Set(HealthDataTypeCatalog.readTypes)
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func permissionSnapshot() -> HealthPermissionSnapshot {
        HealthPermissionSnapshot(
            isHealthDataAvailable: isHealthDataAvailable,
            requestedReadTypes: HealthDataTypeCatalog.readTypes.count
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
    static var sleepReadTypes: [HKObjectType] {
        [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        ].compactMap { $0 }
    }

    static var recoveryReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .respiratoryRate),
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation),
            HKObjectType.quantityType(forIdentifier: .bodyTemperature),
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)
        ].compactMap { $0 }
    }

    static var strainReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .appleStandTime),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .distanceCycling),
            HKObjectType.quantityType(forIdentifier: .flightsClimbed),
            HKObjectType.workoutType()
        ].compactMap { $0 }
    }

    static var biologyReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .bodyFatPercentage),
            HKObjectType.quantityType(forIdentifier: .leanBodyMass),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .bodyMassIndex)
        ].compactMap { $0 }
    }

    // Movement & gait analysis
    static var mobilityReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .walkingSpeed),
            HKObjectType.quantityType(forIdentifier: .walkingStepLength),
            HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage),
            HKObjectType.quantityType(forIdentifier: .walkingDoubleSupportPercentage),
            HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness),
            HKObjectType.quantityType(forIdentifier: .stairAscentSpeed),
            HKObjectType.quantityType(forIdentifier: .stairDescentSpeed),
            HKObjectType.quantityType(forIdentifier: .sixMinuteWalkTestDistance)
        ].compactMap { $0 }
    }

    // Environmental
    static var environmentReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure),
            HKObjectType.quantityType(forIdentifier: .headphoneAudioExposure),
            HKObjectType.quantityType(forIdentifier: .timeInDaylight)
        ].compactMap { $0 }
    }

    // Nutrition (if user tracks)
    static var nutritionReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .dietaryWater),
            HKObjectType.quantityType(forIdentifier: .dietaryCaffeine),
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            HKObjectType.quantityType(forIdentifier: .dietaryProtein),
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)
        ].compactMap { $0 }
    }

    // Cardiovascular — blood pressure and glucose
    static var cardiovascularReadTypes: [HKObjectType] {
        [
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic),
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)
        ].compactMap { $0 }
    }

    // Wellness & mindfulness
    static var wellnessReadTypes: [HKObjectType] {
        var types: [HKObjectType] = [
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
        Array(Set(
            sleepReadTypes
            + recoveryReadTypes
            + strainReadTypes
            + biologyReadTypes
            + mobilityReadTypes
            + environmentReadTypes
            + nutritionReadTypes
            + cardiovascularReadTypes
            + wellnessReadTypes
        ))
    }
}
