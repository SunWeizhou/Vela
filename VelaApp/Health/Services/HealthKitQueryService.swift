import Foundation
@preconcurrency import HealthKit

final class HealthKitQueryService: HealthQueryService {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HealthStoreProvider.shared) {
        self.healthStore = healthStore
    }

    func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let samples = try await categorySamples(type: sleepType, range: range)
        let segments = samples.map {
            SleepStageSegment(
                stage: HealthKitSleepStageMapper.map($0.value),
                start: $0.startDate,
                end: $0.endDate
            )
        }

        return SleepSampleNormalizer.mostRecentEpisodeSummary(for: range.start, segments: segments)
    }

    func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let samples = try await categorySamples(type: sleepType, range: range)
        let segments = samples.map {
            SleepStageSegment(
                stage: HealthKitSleepStageMapper.map($0.value),
                start: $0.startDate,
                end: $0.endDate
            )
        }

        return SleepSampleNormalizer.allNightlyEpisodes(segments: segments)
    }

    func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary {
        try await RecoveryMetricSummary(
            hrvMilliseconds: averageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), range: range),
            restingHeartRate: averageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), range: range),
            sleepHeartRate: averageQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), range: range),
            respiratoryRate: averageQuantity(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), range: range)
        )
    }

    func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary {
        try await StrainActivitySummary(
            activeEnergyKilocalories: sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), range: range),
            exerciseMinutes: sumQuantity(.appleExerciseTime, unit: .minute(), range: range),
            stepCount: sumQuantity(.stepCount, unit: .count(), range: range),
            workouts: workoutSummaries(in: range)
        )
    }

    func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary {
        try await BodyMetricsSummary(
            vo2Max: mostRecentQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"), range: range),
            weightKilograms: mostRecentQuantity(.bodyMass, unit: .gramUnit(with: .kilo), range: range),
            bodyFatPercentage: mostRecentQuantity(.bodyFatPercentage, unit: .percent(), range: range),
            leanBodyMassKilograms: mostRecentQuantity(.leanBodyMass, unit: .gramUnit(with: .kilo), range: range)
        )
    }

    private func categorySamples(type: HKCategoryType, range: DateRangeQuery) async throws -> [HKCategorySample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: [])
                    } else if error.localizedDescription.contains("No data available") || error.localizedDescription.contains("predicate") {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                continuation.resume(returning: samples?.compactMap { $0 as? HKCategorySample } ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, range: DateRangeQuery) async throws -> Double? {
        try await statisticsQuantity(identifier, unit: unit, options: .cumulativeSum, range: range)
    }

    private func averageQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, range: DateRangeQuery) async throws -> Double? {
        try await statisticsQuantity(identifier, unit: unit, options: .discreteAverage, range: range)
    }

    private func statisticsQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        range: DateRangeQuery
    ) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: nil)
                    } else if error.localizedDescription.contains("No data available") || error.localizedDescription.contains("predicate") {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                let quantity = options.contains(.cumulativeSum) ? statistics?.sumQuantity() : statistics?.averageQuantity()
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func mostRecentQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, range: DateRangeQuery) async throws -> Double? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: nil)
                    } else if error.localizedDescription.contains("No data available") || error.localizedDescription.contains("predicate") {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func workoutSummaries(in range: DateRangeQuery) async throws -> [WorkoutSummary] {
        let rawWorkouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: [])
                    } else if error.localizedDescription.contains("No data available") || error.localizedDescription.contains("predicate") {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var summaries: [WorkoutSummary] = []
        for workout in rawWorkouts {
            let workoutHR: Double? = try? await averageQuantity(
                .heartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                range: DateRangeQuery(start: workout.startDate, end: workout.endDate)
            )
            summaries.append(WorkoutSummary(
                start: workout.startDate,
                end: workout.endDate,
                activityName: workout.workoutActivityType.displayName,
                energyKilocalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                averageHeartRate: workoutHR,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter())
            ))
        }
        return summaries
    }

    // MARK: - Extended Metrics (30+ types)

    func extendedMetrics(in range: DateRangeQuery) async throws -> ExtendedHealthMetrics {
        var m = ExtendedHealthMetrics()

        // Personal characteristics (no range needed)
        let chars = queryCharacteristics()
        m.age = chars.age
        m.biologicalSex = chars.biologicalSex

        // Body
        m.heightCm = try await mostRecentQuantity(.height, unit: .meterUnit(with: .centi), range: range)
        m.bmi = try await mostRecentQuantity(.bodyMassIndex, unit: .count(), range: range)

        // Cardiovascular
        m.walkingHeartRateAvg = try await averageQuantity(.walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()), range: range)
        m.oxygenSaturation = try await mostRecentQuantity(.oxygenSaturation, unit: .percent(), range: range).map { $0 * 100 }
        m.bloodPressureSystolic = try await mostRecentQuantity(.bloodPressureSystolic, unit: .millimeterOfMercury(), range: range)
        m.bloodPressureDiastolic = try await mostRecentQuantity(.bloodPressureDiastolic, unit: .millimeterOfMercury(), range: range)

        // Metabolic
        m.bloodGlucose = try await mostRecentQuantity(.bloodGlucose, unit: HKUnit(from: "mg/dL"), range: range)

        // Mobility & gait
        m.walkingSpeed = try await averageQuantity(.walkingSpeed, unit: HKUnit.meter().unitDivided(by: .second()), range: range)
        m.walkingStepLength = try await averageQuantity(.walkingStepLength, unit: .meter(), range: range)
        m.walkingAsymmetry = try await averageQuantity(.walkingAsymmetryPercentage, unit: .percent(), range: range).map { $0 * 100 }
        m.walkingDoubleSupport = try await averageQuantity(.walkingDoubleSupportPercentage, unit: .percent(), range: range).map { $0 * 100 }
        m.walkingSteadiness = try await averageQuantity(.appleWalkingSteadiness, unit: .percent(), range: range).map { $0 * 100 }
        m.stairAscentSpeed = try await averageQuantity(.stairAscentSpeed, unit: HKUnit.meter().unitDivided(by: .second()), range: range)
        m.stairDescentSpeed = try await averageQuantity(.stairDescentSpeed, unit: HKUnit.meter().unitDivided(by: .second()), range: range)
        m.sixMinuteWalkDistance = try await mostRecentQuantity(.sixMinuteWalkTestDistance, unit: .meter(), range: range)

        // Activity totals
        m.exerciseMinutes = try await sumQuantity(.appleExerciseTime, unit: .minute(), range: range).map { Int($0) }
        m.standMinutes = try await sumQuantity(.appleStandTime, unit: .minute(), range: range).map { Int($0) }
        m.flightsClimbed = try await sumQuantity(.flightsClimbed, unit: .count(), range: range).map { Int($0) }
        m.distanceKm = try await sumQuantity(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), range: range)
        m.cyclingDistanceKm = try await sumQuantity(.distanceCycling, unit: .meterUnit(with: .kilo), range: range)

        // Environment
        m.environmentalNoisedB = try await averageQuantity(.environmentalAudioExposure, unit: .decibelAWeightedSoundPressureLevel(), range: range)
        m.headphoneNoisedB = try await averageQuantity(.headphoneAudioExposure, unit: .decibelAWeightedSoundPressureLevel(), range: range)
        m.timeInDaylight = try await sumQuantity(.timeInDaylight, unit: .minute(), range: range)

        // Temperature
        m.bodyTemperature = try await mostRecentQuantity(.bodyTemperature, unit: .degreeCelsius(), range: range)

        // Nutrition
        m.waterMl = try await sumQuantity(.dietaryWater, unit: .literUnit(with: .milli), range: range)
        m.caffeineMg = try await sumQuantity(.dietaryCaffeine, unit: .gramUnit(with: .milli), range: range)
        m.dietaryEnergyKcal = try await sumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), range: range)
        m.dietaryProteinG = try await sumQuantity(.dietaryProtein, unit: .gram(), range: range)
        m.dietaryCarbsG = try await sumQuantity(.dietaryCarbohydrates, unit: .gram(), range: range)
        m.dietaryFatG = try await sumQuantity(.dietaryFatTotal, unit: .gram(), range: range)

        // Wellness
        // Mindful sessions — category type, sum durations manually
        if let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            do {
                let mindfulSamples = try await categorySamples(type: mindfulType, range: range)
                let totalMinutes = mindfulSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60.0
                m.mindfulMinutes = totalMinutes > 0 ? totalMinutes : nil
            } catch {
                m.mindfulMinutes = nil
            }
        }

        // Sleep breathing disturbances (iOS 18+)
        if #available(iOS 18.0, *) {
            m.sleepBreathingDisturbances = try await averageQuantity(.appleSleepingBreathingDisturbances, unit: HKUnit.count().unitDivided(by: .hour()), range: range)
        }

        return m
    }

    func hrvHistory(in range: DateRangeQuery) async throws -> [Double] {
        try await hrvDailyAverages(in: range)
    }

    /// Fetch daily average HRV values using HKStatisticsCollectionQuery.
    /// Returns one value per day (discrete average) instead of all raw samples.
    private func hrvDailyAverages(in range: DateRangeQuery) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Anchor to a known midnight in the past for stable daily alignment
            let anchor = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var values: [Double] = []
                results?.enumerateStatistics(from: range.start, to: range.end) { statistics, _ in
                    if let avg = statistics.averageQuantity() {
                        let value = avg.doubleValue(for: .secondUnit(with: .milli))
                        values.append(value)
                    }
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    func rhrHistory(in range: DateRangeQuery) async throws -> [Double] {
        try await rhrDailyAverages(in: range)
    }

    /// Fetch daily average RHR values using HKStatisticsCollectionQuery.
    private func rhrDailyAverages(in range: DateRangeQuery) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return []
        }

        return try await withCheckedThrowingContinuation { continuation in
            let anchor = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 0))
            let predicate = HKQuery.predicateForSamples(
                withStart: range.start,
                end: range.end,
                options: []
            )
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == HKErrorDomain && (nsError.code == 4 || nsError.code == 3) {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                var values: [Double] = []
                results?.enumerateStatistics(from: range.start, to: range.end) { statistics, _ in
                    if let avg = statistics.averageQuantity() {
                        let value = avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        values.append(value)
                    }
                }
                continuation.resume(returning: values)
            }
            healthStore.execute(query)
        }
    }

    /// Read HKCharacteristicType values (age, sex) — these don't need time ranges
    func queryCharacteristics() -> (age: Int?, biologicalSex: String?) {
        var age: Int?
        var sex: String?

        if let dob = try? healthStore.dateOfBirthComponents() {
            if let year = dob.year {
                age = Calendar.current.component(.year, from: Date()) - year
            }
        }

        if let bioSex = try? healthStore.biologicalSex().biologicalSex {
            switch bioSex {
            case .male: sex = "male"
            case .female: sex = "female"
            case .other: sex = "other"
            default: sex = nil
            }
        }

        return (age, sex)
    }

    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary] {
        let rawWorkouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var summaries: [WorkoutSummary] = []
        for workout in rawWorkouts {
            let workoutHR: Double? = try? await averageQuantity(
                .heartRate,
                unit: HKUnit.count().unitDivided(by: .minute()),
                range: DateRangeQuery(start: workout.startDate, end: workout.endDate)
            )
            summaries.append(WorkoutSummary(
                id: workout.uuid,
                start: workout.startDate,
                end: workout.endDate,
                activityName: workout.workoutActivityType.displayName,
                energyKilocalories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                averageHeartRate: workoutHR,
                distanceMeters: workout.totalDistance?.doubleValue(for: .meter())
            ))
        }
        return summaries
    }

    func heartRateSamples(start: Date, end: Date) async throws -> [HeartRateSample] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(returning: [])
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample])?.map { sample in
                    HeartRateSample(
                        date: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []
                continuation.resume(returning: hrSamples)
            }
            healthStore.execute(query)
        }
    }

    func workoutRoute(workoutId: UUID) async throws -> [RouteCoordinate] {
        let workoutPredicate = HKQuery.predicateForObject(with: workoutId)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: workoutPredicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
        
        guard let workout = workouts.first else { return [] }
        
        let routeType = HKSeriesType.workoutRoute()
        let routePredicate = HKQuery.predicateForObjects(from: workout)
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: routeType, predicate: routePredicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }
        
        guard let route = routes.first else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            var coords: [RouteCoordinate] = []
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let locations = locations {
                    coords.append(contentsOf: locations.map { RouteCoordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) })
                }
                if done {
                    continuation.resume(returning: coords)
                }
            }
            healthStore.execute(query)
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .yoga:
            return "Yoga"
        case .swimming:
            return "Swimming"
        case .hiking:
            return "Hiking"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .crossTraining:
            return "Cross Training"
        case .pilates:
            return "Pilates"
        case .rowing:
            return "Rowing"
        default:
            return "Workout"
        }
    }
}
