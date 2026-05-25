import Foundation
@preconcurrency import HealthKit

enum HealthKitSleepStageMapper {
    static func map(_ value: Int) -> SleepStage {
        guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: value) else {
            return .asleep
        }

        switch sleepValue {
        case .inBed:
            return .inBed
        case .awake:
            return .awake
        case .asleepREM:
            return .rem
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .asleepUnspecified:
            return .asleep
        @unknown default:
            return .asleep
        }
    }
}
