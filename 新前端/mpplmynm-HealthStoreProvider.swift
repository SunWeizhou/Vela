import HealthKit

enum HealthStoreProvider {
    static let shared: HKHealthStore = {
        HKHealthStore()
    }()
}
