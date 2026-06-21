import SwiftUI
import SwiftData
import CoreLocation

// MARK: - VelaTodayView Extension for Data Operations
extension VelaTodayView {
    
    func persistDailyOperatingPlan() {
        _ = try? DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: trainingDecision,
            modelContext: modelContext
        )
    }

    func readinessColor(_ decision: ReadinessDecisionKind) -> Color {
        switch decision {
        case .keep: return VelaTheme.success
        case .reduce: return Color(hex: "#FF9F0A")
        case .swap: return Color(hex: "#5C6BC0")
        case .recover: return VelaTheme.sleep
        }
    }

    func icon(for action: TodayAction) -> String {
        switch action.kind {
        case .training: return "figure.run"
        case .recovery: return "heart.fill"
        case .checkIn: return "square.and.pencil"
        case .coach: return "sparkles"
        case .insight: return "list.bullet.clipboard"
        }
    }

    func icon(for action: CoachArtifactAction) -> String {
        if action.type.contains("training") || action.type.contains("workout") { return "figure.run" }
        if action.type.contains("recovery") { return "heart.fill" }
        if action.type.contains("check") { return "square.and.pencil" }
        return "arrow.right"
    }

    func handleTodayAction(_ action: TodayAction) {
        switch action.kind {
        case .training:
            appState.routeToTab(1)
        case .recovery, .insight:
            showTodayEvidence = true
        case .checkIn:
            appState.triggerJournal = true
        case .coach:
            appState.routeToCoach(question: action.detail)
        }
    }

    func handleCoachArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        switch action.type {
        case "open_training_summary":
            appState.routeToTab(1)
        case "start_check_in":
            appState.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        case "open_recovery_detail":
            appState.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        default:
            if action.type.contains("training") || action.type.contains("workout") {
                appState.routeToTab(1)
            } else if action.type.contains("check") || action.type.contains("journal") {
                appState.triggerJournal = true
            } else if action.type.contains("recovery") {
                appState.routeToRecoveryDetail()
            } else {
                appState.routeToCoach(question: action.label)
            }
        }
    }

    func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    // MARK: - Date formatting helpers
    func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天, " + formatMonthDayString(date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天, " + formatMonthDayString(date)
        } else {
            return formatMonthDayString(date)
        }
    }

    func formatMonthDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    // MARK: - Weather Sync
    func requestWeatherUpdate() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            weatherLocation = "正在请求定位"
            locationManager.requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdating()
            fetchLocalWeather()
        case .denied, .restricted:
            weatherLocation = "定位未授权"
        @unknown default:
            weatherLocation = "天气暂不可用"
        }
    }

    func fetchLocalWeather() {
        Task {
            let cached = WeatherLocationStore.load()
            let live = await weatherLocationSnapshot(
                for: locationManager.location,
                fallbackDisplayName: cached?.displayName
            )

            guard let location = WeatherLocationPolicy.preferredSnapshot(
                live: live,
                cached: cached
            ) else {
                return
            }

            if live != nil {
                WeatherLocationStore.save(location)
            }

            do {
                let weather = try await WeatherService.shared.fetchWeather(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                guard !Task.isCancelled else {
                    return
                }

                weatherTemp = "\(Int(weather.temperature.rounded()))°C"
                weatherLocation = location.displayName
            } catch {
                print("Failed to sync weather locally: \(error.localizedDescription)")
            }
        }
    }

    func weatherLocationSnapshot(
        for location: CLLocation?,
        fallbackDisplayName: String?
    ) async -> WeatherLocationSnapshot? {
        guard let location else {
            return nil
        }

        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(location)
            .first
        let locationName = weatherLocationName(
            locality: placemark?.locality,
            administrativeArea: placemark?.administrativeArea,
            fallback: fallbackDisplayName
        )

        return WeatherLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: locationName,
            capturedAt: location.timestamp
        )
    }

    func weatherLocationName(
        locality: String?,
        administrativeArea: String?,
        fallback: String?
    ) -> String {
        let parts = [locality, administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let uniqueParts = parts.reduce(into: [String]()) { result, item in
            if !result.contains(item) {
                result.append(item)
            }
        }

        return uniqueParts.isEmpty
            ? fallback ?? "当前位置"
            : uniqueParts.joined(separator: ", ")
    }

    // MARK: - SwiftData nutrition sync
    func loadRealNutritionData() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dashboardVM.selectedDate)

        let descriptor = FetchDescriptor<FoodLogRecord>()
        do {
            let allLogs = try modelContext.fetch(descriptor)
            let todayLogs = allLogs.filter { log in
                calendar.isDate(log.createdAt, inSameDayAs: start)
            }

            todayCalories = todayLogs.map(\.totalCalories).reduce(0, +)
            todayProtein = todayLogs.map(\.proteinGrams).reduce(0, +)
            todayCarbs = todayLogs.map(\.carbsGrams).reduce(0, +)
            todayFat = todayLogs.map(\.fatGrams).reduce(0, +)
        } catch {
            print("Failed to fetch food logs: \(error)")
        }
    }

    func loadDynamicData() {
        let calendar = Calendar.current
        let refDate = dashboardVM.selectedDate
        let startOfDayRef = calendar.startOfDay(for: refDate)
        
        let startLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -Self.healthLookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let trainingStartLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -Self.trainingLookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let endLimit = calendar.date(byAdding: .day, value: 1, to: startOfDayRef) ?? startOfDayRef
        
        let artifactsDesc = FetchDescriptor<CoachArtifactRecord>(
            predicate: #Predicate<CoachArtifactRecord> { $0.createdAt >= trainingStartLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.coachArtifacts = (try? modelContext.fetch(artifactsDesc)) ?? []

        let strengthDesc = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= trainingStartLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        self.strengthWorkouts = (try? modelContext.fetch(strengthDesc)) ?? []

        let eventsDesc = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= trainingStartLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        self.workoutEvents = (try? modelContext.fetch(eventsDesc)) ?? []

        let responsesDesc = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        self.trainingResponses = (try? modelContext.fetch(responsesDesc)) ?? []

        let foodDesc = FetchDescriptor<FoodLogRecord>(
            predicate: #Predicate<FoodLogRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.foodLogs = (try? modelContext.fetch(foodDesc)) ?? []

        let journalDesc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.journalEntries = (try? modelContext.fetch(journalDesc)) ?? []

        let summaryDesc = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        self.dailySummaries = (try? modelContext.fetch(summaryDesc)) ?? []

        var plansDesc = FetchDescriptor<TrainingPlanRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        plansDesc.fetchLimit = 10
        self.trainingPlans = (try? modelContext.fetch(plansDesc)) ?? []

        var opPlansDesc = FetchDescriptor<DailyOperatingPlanRecord>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        opPlansDesc.fetchLimit = 50
        self.operatingPlans = (try? modelContext.fetch(opPlansDesc)) ?? []
    }

    func refreshDashboard(force: Bool = false) async {
        await dashboardVM.refresh(modelContext: modelContext, force: force)
        loadRealNutritionData()
        loadDynamicData()
        fetchLocalWeather()
    }

    func loadDataCoverageSummary() async {
        let groups = await DataCoverageGroupFactory.loadPriorityGroups()
        let summary = DataCoverageSummaryModel.build(groups: groups)
        withAnimation(VelaTheme.smooth) {
            dataCoverageSummary = summary
        }
    }
}
