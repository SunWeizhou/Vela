import Foundation
import HealthKit

@MainActor
protocol HealthStoreProviding {
    var isHealthDataAvailable: Bool { get }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func authorizationRequestStatus(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
}

extension HKHealthStore: HealthStoreProviding {
    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func authorizationRequestStatus(
        toShare typesToShare: Set<HKSampleType>,
        read typesToRead: Set<HKObjectType>
    ) async throws -> HKAuthorizationRequestStatus {
        try await withCheckedThrowingContinuation { continuation in
            getRequestStatusForAuthorization(toShare: typesToShare, read: typesToRead) { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

public enum HealthPermissionTier: String, Codable, CaseIterable {
    case core
    case enhanced
    case advanced
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

        let readTypes = Set(HealthSignalCatalog.readTypes(for: tier))

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func shouldDeferBackgroundSync() async -> Bool {
        guard isHealthDataAvailable else { return true }
        do {
            let status = try await healthStore.authorizationRequestStatus(
                toShare: [],
                read: Set(HealthDataTypeCatalog.coreTypes)
            )
            return status == .shouldRequest
        } catch {
            return false
        }
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
    static var coreTypes: [HKObjectType] {
        HealthSignalCatalog.readTypes(for: .core)
    }

    static var enhancedTypes: [HKObjectType] {
        Array(Set(HealthSignalCatalog.enhancedSignals.compactMap(\.objectType)))
    }

    static var advancedTypes: [HKObjectType] {
        Array(Set(HealthSignalCatalog.advancedSignals.compactMap(\.objectType)))
    }

    static var readTypes: [HKObjectType] {
        HealthSignalCatalog.readTypes(for: .advanced)
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
            HKObjectType.quantityType(forIdentifier: .bodyTemperature),
            HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
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
