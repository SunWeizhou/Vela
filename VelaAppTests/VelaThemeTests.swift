import XCTest
import HealthKit
import SwiftData
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeDefinesStableProductIdentity() {
        XCTAssertEqual(VelaAppMetadata.name, "Vela")
        XCTAssertEqual(VelaAppMetadata.minimumOSVersion, "17.0")
        XCTAssertEqual(VelaTheme.cornerRadiusCard, 18)
    }

    func testDateRangeBuildsRecentCalendarWindows() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 9)))

        let range = DateRangeQuery.recentDays(7, endingAt: now, calendar: calendar)

        XCTAssertEqual(range.dayCount(calendar: calendar), 7)
        XCTAssertTrue(range.start < range.end)
        XCTAssertEqual(calendar.component(.hour, from: range.end), 0)
    }

    func testEmptyDashboardDoesNotExposePreviewScores() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 29)))
        let dashboard = DashboardSummary.empty(date: date)

        XCTAssertEqual(dashboard.source, .empty)
        XCTAssertFalse(dashboard.sleepScore.hasData)
        XCTAssertFalse(dashboard.recovery.hasData)
        XCTAssertFalse(dashboard.strain.hasData)
        XCTAssertFalse(dashboard.stress.hasData)
        XCTAssertFalse(dashboard.energy.hasData)
        XCTAssertTrue(dashboard.workouts.isEmpty)
        XCTAssertTrue(dashboard.dailyInsight.isEmpty)
    }

    func testHealthDataCatalogCoversPhaseOneReadTypes() {
        XCTAssertTrue(HealthDataTypeCatalog.sleepReadTypes.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        XCTAssertTrue(HealthDataTypeCatalog.recoveryReadTypes.contains(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        XCTAssertTrue(HealthDataTypeCatalog.strainReadTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(HealthDataTypeCatalog.biologyReadTypes.contains(HKObjectType.quantityType(forIdentifier: .vo2Max)!))
        XCTAssertEqual(Set(HealthDataTypeCatalog.readTypes).count, HealthDataTypeCatalog.readTypes.count)
    }

    func testDailyPlanRecommendsRecoveryWhenScoreLow() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 35,
            band: .low,
            confidence: .high,
            components: ["hrv": 35, "hrv_z_score": -2.0],
            componentWeights: ["hrv": 1],
            reasons: ["HRV significantly below personal baseline"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        let plan = DailyPlanEngine.recommendation(for: dashboard)
        XCTAssertEqual(plan.kind, .recovery)
        XCTAssertEqual(plan.accent, .recovery)
    }

    func testAppleThemeHasSemanticColors() {
        XCTAssertNotNil(VelaTheme.recovery)
        XCTAssertNotNil(VelaTheme.sleep)
        XCTAssertNotNil(VelaTheme.strain)
        XCTAssertNotNil(VelaTheme.stress)
        XCTAssertNotNil(VelaTheme.energy)
    }

    func testMinimalDashboardScorePercentageRoundsInsteadOfTruncating() {
        XCTAssertEqual(VelaMinimalFormatting.roundedPercentage(60.6), "61%")
    }

    func testMinimalCalendarTitleDoesNotInsertGroupingSeparatorIntoYear() {
        XCTAssertEqual(VelaMinimalFormatting.calendarTitle(year: 2026, month: 5), "2026年5月")
    }

    func testSleepDialUsesActualBedtimeAndWakeTimeAcrossMidnight() {
        XCTAssertEqual(
            VelaMinimalFormatting.sleepDurationMinutes(
                bedtimeHour: 23,
                bedtimeMinute: 30,
                wakeHour: 9,
                wakeMinute: 10
            ),
            580
        )
        XCTAssertEqual(VelaMinimalFormatting.clockTime(hour: 9, minute: 10), "09:10")
    }

    func testSleepTargetSettingsReadsConfiguredHours() {
        let suiteName = "VelaThemeTests.SleepTargetSettings"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(8.0, forKey: SleepTargetSettings.hoursKey)

        XCTAssertEqual(SleepTargetSettings.targetMinutes(defaults: defaults), 480)
    }

    func testCoreMetricTrendMapperUsesRecentPersistedHistory() throws {
        let calendar = Calendar(identifier: .gregorian)
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10)))
        let old = try XCTUnwrap(calendar.date(byAdding: .day, value: -45, to: end))
        let recent = try [2, 1, 0].map {
            try XCTUnwrap(calendar.date(byAdding: .day, value: -$0, to: end))
        }
        let snapshots = [
            DailyHealthSnapshot(date: old, strainScore: 90),
            DailyHealthSnapshot(date: recent[0], strainScore: 10),
            DailyHealthSnapshot(date: recent[1], strainScore: 20),
            DailyHealthSnapshot(date: recent[2], strainScore: 30)
        ]

        let series = try XCTUnwrap(
            CoreMetricTrendMapper.series(
                for: .strain,
                snapshots: snapshots,
                endingAt: end,
                calendar: calendar
            )
        )

        XCTAssertEqual(series.valueText, "30%")
        XCTAssertEqual(series.history, [0, 0.5, 1])
    }

    func testDailyActivityDetailCatalogExposesAllActivityMetrics() {
        XCTAssertEqual(
            DailyActivityDetailCatalog.metrics,
            [.steps, .activeCalories, .activeMinutes]
        )
    }

    func testAbsoluteMetricDetailsDoNotUseScoreGaugePresentation() {
        XCTAssertEqual(VelaMetricDetailView.MetricType.strain.heroPresentation, .scoreGauge)
        XCTAssertEqual(VelaMetricDetailView.MetricType.stress.heroPresentation, .stressGauge)

        for metric in [
            VelaMetricDetailView.MetricType.hrv,
            .rhr,
            .weight,
            .bodyFat,
            .respiratoryRate,
            .bloodOxygen,
            .steps,
            .activeCalories,
            .activeMinutes
        ] {
            XCTAssertEqual(metric.heroPresentation, .absoluteValue)
        }
    }

    func testBodyFatTrendUsesPersistedBodyFatPercentage() throws {
        let calendar = Calendar(identifier: .gregorian)
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10)))
        let snapshots = [
            DailyHealthSnapshot(date: try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: end)), bodyFatPercent: 18.2),
            DailyHealthSnapshot(date: end, bodyFatPercent: 17.5)
        ]

        let series = try XCTUnwrap(
            CoreMetricTrendMapper.series(
                for: .bodyFat,
                snapshots: snapshots,
                endingAt: end,
                calendar: calendar
            )
        )

        XCTAssertEqual(series.valueText, "17.5%")
    }

    func testActiveMinutesTrendUsesActivityMinutesInsteadOfWorkoutDuration() throws {
        let calendar = Calendar(identifier: .gregorian)
        let end = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10)))
        let snapshots = [
            DailyHealthSnapshot(date: try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: end)), activeMinutes: 42, workoutDuration: 90),
            DailyHealthSnapshot(date: end, activeMinutes: 31, workoutDuration: 75)
        ]

        let series = try XCTUnwrap(
            CoreMetricTrendMapper.series(
                for: .activeMinutes,
                snapshots: snapshots,
                endingAt: end,
                calendar: calendar
            )
        )

        XCTAssertEqual(series.valueText, "31 分钟")
    }

    func testEveryCoreMetricDetailProvidesCoachContext() {
        for metric in VelaMetricDetailView.MetricType.allCases {
            let context = CoreMetricCoachContext.make(for: metric)

            XCTAssertFalse(context.focus.title.isEmpty)
            XCTAssertFalse(context.focus.systemContext.isEmpty)
            XCTAssertFalse(context.suggestedQuestion.isEmpty)
        }
    }

    func testMetricCoachAdviceFormatterParsesPlainSectionLabelsAndBoundsOutput() {
        let raw = """
        结论今日生理压力处于中等偏高区间，但身体活跃度过低，建议采取主动恢复而非继续静止。
        依据恢复准备度49，静息心率达70bpm，提示潜在疲累。活跃时间0分钟，步数仅4194，极度静态可能放大压力感知。训练压力平衡为+19.7，且负荷比仅1.03，身体处于减载窗口，适合温和干预。
        今天行动进行一次10分钟的户外徐行，全程保持鼻吸鼻呼，步频稍低于日常，结束后即刻感受心率变化。
        """

        let advice = MetricCoachAdviceFormatter.parse(raw)

        XCTAssertEqual(advice.conclusion, "今日生理压力处于中等偏高区间，但身体活跃度过低，建议采取主动恢复而非继续静止。")
        XCTAssertEqual(advice.evidence.count, 3)
        XCTAssertTrue(advice.action.hasPrefix("进行一次10分钟"))
        XCTAssertLessThanOrEqual(advice.totalCharacterCount, 220)
    }

    func testMetricCoachAdviceFormatterFallsBackToSentenceSections() {
        let advice = MetricCoachAdviceFormatter.parse(
            "今天恢复偏低。HRV 低于基线。静息心率升高。安排十分钟轻松步行。"
        )

        XCTAssertEqual(advice.conclusion, "今天恢复偏低。")
        XCTAssertEqual(advice.evidence, ["HRV 低于基线。", "静息心率升高。"])
        XCTAssertEqual(advice.action, "安排十分钟轻松步行。")
    }

    func testUserProfileMaxHeartRateFallsBackToAgeFormulaAndPrefersOverride() {
        let suiteName = "VelaThemeTests.UserProfileSettings"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(UserProfileSettings.resolvedMaxHeartRate(age: 40, defaults: defaults), 180)

        defaults.set(176, forKey: UserProfileSettings.maxHeartRateKey)
        XCTAssertEqual(UserProfileSettings.resolvedMaxHeartRate(age: 40, defaults: defaults), 176)
    }

    func testUserProfileBodyMetricsProvideValidatedBMIFallback() throws {
        let suiteName = "VelaThemeTests.UserProfileBodyMetrics"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(72.0, forKey: UserProfileSettings.weightKey)
        defaults.set(180.0, forKey: UserProfileSettings.heightKey)

        let weight = try XCTUnwrap(UserProfileSettings.weightKilograms(defaults: defaults))
        let height = try XCTUnwrap(UserProfileSettings.heightCentimeters(defaults: defaults))
        XCTAssertEqual(weight, 72.0)
        XCTAssertEqual(height, 180.0)
        XCTAssertEqual(
            try XCTUnwrap(UserProfileSettings.bodyMassIndex(weightKilograms: weight, heightCentimeters: height)),
            22.22,
            accuracy: 0.01
        )
    }

    func testHeartRateZoneCalculatorBoundsSamplingGapsAndOrdersHighestZoneFirst() throws {
        let start = Date(timeIntervalSince1970: 1_779_000_000)
        let summary = try XCTUnwrap(HeartRateZoneCalculator.summarize(
            samples: [
                HeartRateSample(date: start, bpm: 155),
                HeartRateSample(date: start.addingTimeInterval(60), bpm: 145),
                HeartRateSample(date: start.addingTimeInterval(360), bpm: 95),
                HeartRateSample(date: start.addingTimeInterval(420), bpm: 95)
            ],
            restingHeartRate: 60,
            maxHeartRate: 160
        ))

        XCTAssertEqual(summary.zones.first?.title, "Zone 5")
        XCTAssertEqual(summary.zones.first?.minutes, 1)
        XCTAssertEqual(summary.totalMinutes, 4)
    }

    func testHeartRateZoneCalculatorDoesNotBridgeSeparateWorkouts() throws {
        let start = Date(timeIntervalSince1970: 1_779_000_000)
        let summary = try XCTUnwrap(HeartRateZoneCalculator.summarize(
            sampleGroups: [
                [
                    HeartRateSample(date: start, bpm: 155),
                    HeartRateSample(date: start.addingTimeInterval(60), bpm: 155)
                ],
                [
                    HeartRateSample(date: start.addingTimeInterval(3600), bpm: 155),
                    HeartRateSample(date: start.addingTimeInterval(3660), bpm: 155)
                ]
            ],
            restingHeartRate: 60,
            maxHeartRate: 160
        ))

        XCTAssertEqual(summary.zones.first?.minutes, 2)
        XCTAssertEqual(summary.totalMinutes, 2)
    }

    func testActiveStatusMapsToPlanFlagUntilConfiguredExpiration() throws {
        let suiteName = "VelaThemeTests.ActiveStatusSettings"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 9)))

        ActiveStatusSettings.update(
            status: "sick",
            duration: "1天",
            now: now,
            defaults: defaults,
            calendar: calendar
        )

        XCTAssertEqual(ActiveStatusSettings.journalFlags(now: now, defaults: defaults), ["sick"])
        XCTAssertTrue(
            ActiveStatusSettings.journalFlags(
                now: try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: now)),
                defaults: defaults
            ).isEmpty
        )

        ActiveStatusSettings.update(
            status: "resting",
            duration: "长期",
            now: now,
            defaults: defaults,
            calendar: calendar
        )
        XCTAssertEqual(ActiveStatusSettings.journalFlags(now: now, defaults: defaults), ["resting"])
    }

    func testBarcodeFoodLookupDecodesServingNutritionFromOpenFoodFacts() throws {
        let fixture = """
        {
          "status": 1,
          "product": {
            "product_name": "Plain Greek Yogurt",
            "serving_size": "170 g",
            "nutrition_grades": "a",
            "nutriments": {
              "energy-kcal_serving": 100,
              "proteins_serving": 17.2,
              "carbohydrates_serving": 6.4,
              "fat_serving": 0,
              "fiber_serving": 0
            }
          }
        }
        """

        let result = try BarcodeFoodLookupService.decodeProduct(
            data: try XCTUnwrap(fixture.data(using: .utf8)),
            barcode: "0123456789012"
        )

        XCTAssertEqual(result.foods.first?.name, "Plain Greek Yogurt")
        XCTAssertEqual(result.foods.first?.portion, "170 g")
        XCTAssertEqual(result.totalCalories, 100)
        XCTAssertEqual(result.macros.protein, 17)
        XCTAssertEqual(result.macros.carbs, 6)
        XCTAssertEqual(result.healthScore, "good")
    }

    func testBarcodeFoodLookupRejectsMissingProduct() throws {
        let fixture = #"{"status":0,"status_verbose":"product not found"}"#

        XCTAssertThrowsError(
            try BarcodeFoodLookupService.decodeProduct(
                data: try XCTUnwrap(fixture.data(using: .utf8)),
                barcode: "0000000000000"
            )
        )
    }

    @MainActor
    func testCoachRouteWritesPrefilledQuestionAndSelectsEmbeddedCoachTab() {
        let state = VelaAppState.shared
        state.selectedTab = 0
        state.showCoachHub = false
        state.prefilledCoachQuestion = nil

        state.routeToCoach(question: "Review my sleep and give me one action.")

        XCTAssertEqual(state.selectedTab, VelaAppState.coachTabIndex)
        XCTAssertFalse(state.showCoachHub)
        XCTAssertEqual(state.prefilledCoachQuestion, "Review my sleep and give me one action.")
    }

    @MainActor
    func testEmbeddedCoachRouteWithoutQuestionStartsBlankSession() {
        let state = VelaAppState.shared
        state.selectedTab = 0
        state.showCoachHub = false
        state.prefilledCoachQuestion = "Stale question"
        state.forceNewCoachSession = false

        state.routeToCoach(question: nil)

        XCTAssertEqual(state.selectedTab, VelaAppState.coachTabIndex)
        XCTAssertFalse(state.showCoachHub)
        XCTAssertTrue(state.forceNewCoachSession)
        XCTAssertNil(state.prefilledCoachQuestion)
    }

    @MainActor
    func testQuickCoachRouteKeepsCurrentTabAndOpensShortcutCover() {
        let state = VelaAppState.shared
        state.selectedTab = 2
        state.showCoachHub = false
        state.prefilledCoachQuestion = nil

        state.routeToQuickCoach(question: "Quick check")

        XCTAssertEqual(state.selectedTab, 2)
        XCTAssertTrue(state.showCoachHub)
        XCTAssertEqual(state.prefilledCoachQuestion, "Quick check")
    }

    @MainActor
    func testAppStateRoutesShortcutToFoodScanner() {
        let state = VelaAppState.shared
        state.triggerFoodScanner = false
        state.scannerType = "library"
        defer { state.triggerFoodScanner = false }

        state.routeToFoodScanner(type: "camera")

        XCTAssertTrue(state.triggerFoodScanner)
        XCTAssertEqual(state.scannerType, "camera")
    }

    @MainActor
    func testAppStateDefersQuickActionUntilPresentingSheetDismisses() {
        let state = VelaAppState.shared
        state.triggerFoodScanner = false
        defer { state.triggerFoodScanner = false }

        state.deferQuickActionUntilSheetDismisses(.foodScanner("barcode"))

        XCTAssertFalse(state.triggerFoodScanner)
        XCTAssertEqual(state.deferredQuickAction, .foodScanner("barcode"))

        state.runDeferredQuickAction()

        XCTAssertNil(state.deferredQuickAction)
        XCTAssertTrue(state.triggerFoodScanner)
        XCTAssertEqual(state.scannerType, "barcode")
    }

    @MainActor
    func testDeferredCoachShortcutOpensQuickCoachCover() {
        let state = VelaAppState.shared
        state.selectedTab = 1
        state.showCoachHub = false

        state.deferQuickActionUntilSheetDismisses(.coach(nil))
        state.runDeferredQuickAction()

        XCTAssertEqual(state.selectedTab, 1)
        XCTAssertTrue(state.showCoachHub)
        XCTAssertTrue(state.forceNewCoachSession)
    }

    @MainActor
    func testDeferredJournalShortcutPresentsJournalSheet() {
        let state = VelaAppState.shared
        state.triggerJournal = false
        defer { state.triggerJournal = false }

        state.deferQuickActionUntilSheetDismisses(.journal)
        state.runDeferredQuickAction()

        XCTAssertNil(state.deferredQuickAction)
        XCTAssertTrue(state.triggerJournal)
    }

    @MainActor
    func testDeferredQuickActionClearsPreviouslyTriggeredSheet() {
        let state = VelaAppState.shared
        state.triggerFoodScanner = true
        state.triggerJournal = false
        defer {
            state.triggerFoodScanner = false
            state.triggerJournal = false
        }

        state.deferQuickActionUntilSheetDismisses(.journal)
        state.runDeferredQuickAction()

        XCTAssertFalse(state.triggerFoodScanner)
        XCTAssertTrue(state.triggerJournal)
    }

    @MainActor
    func testEmbeddedCoachUsesFourthBottomTabAfterJournalMovesIntoPlusMenu() {
        XCTAssertEqual(VelaAppState.coachTabIndex, 3)
    }

    func testFloatingNavigationHidesWhileKeyboardIsVisible() {
        XCTAssertTrue(VelaNavigationVisibility.shouldShowBottomBar(keyboardVisible: false))
        XCTAssertFalse(VelaNavigationVisibility.shouldShowBottomBar(keyboardVisible: true))
    }

    func testCGMSettingsSummaryUsesLatestChronologicalReading() {
        let older = BloodGlucoseReading(
            date: Date(timeIntervalSince1970: 1_000),
            milligramsPerDeciliter: 88
        )
        let latest = BloodGlucoseReading(
            date: Date(timeIntervalSince1970: 2_000),
            milligramsPerDeciliter: 112
        )

        let summary = CGMSettingsSummary(readings: [latest, older])

        XCTAssertEqual(summary.latestReading, latest)
        XCTAssertEqual(summary.readingCount, 2)
        XCTAssertTrue(summary.hasReadings)
    }

    func testCGMSettingsSummaryReportsUnavailableWithoutReadings() {
        let summary = CGMSettingsSummary(readings: [])

        XCTAssertNil(summary.latestReading)
        XCTAssertEqual(summary.readingCount, 0)
        XCTAssertFalse(summary.hasReadings)
    }

    func testCloudKitSettingsStayHiddenUntilSyncIsConfigured() {
        XCTAssertFalse(VelaCapabilityAvailability.cloudKitSyncEnabled)
    }

    @MainActor
    func testAppStatePublishesLocalDataRevisionAfterSheetMutation() {
        let state = VelaAppState.shared
        let revision = state.localDataRevision

        state.markLocalDataChanged()

        XCTAssertEqual(state.localDataRevision, revision + 1)
    }

    @MainActor
    func testCoachHistoryExcludesCurrentPromptAndStreamingPlaceholder() {
        let messages = [
            CoachChatVM.ChatMsg(role: .user, content: "Earlier question"),
            CoachChatVM.ChatMsg(role: .assistant, content: "Earlier answer"),
            CoachChatVM.ChatMsg(role: .user, content: "Current question"),
            CoachChatVM.ChatMsg(role: .assistant, content: "", isStreaming: true)
        ]

        let history = CoachChatVM.historyBeforeCurrentPrompt(from: messages, limit: 10)

        XCTAssertEqual(history.map(\.content), ["Earlier question", "Earlier answer"])
    }

    @MainActor
    func testCoachHistorySentToModelIncludesAbsoluteLocalTimestamp() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let timestamp = calendar.date(
            from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 35)
        )!
        let message = CoachChatVM.ChatMsg(
            role: .user,
            content: "I felt tired after lunch.",
            timestamp: timestamp
        )

        let content = CoachChatVM.timestampedHistoryContent(
            for: message,
            calendar: calendar
        )

        XCTAssertTrue(content.contains("2026-06-01 14:35"))
        XCTAssertTrue(content.contains("Asia/Shanghai"))
        XCTAssertTrue(content.contains("I felt tired after lunch."))
    }

    @MainActor
    func testHealthDataToolExposesGlobalTrainingLoadAndWorkoutMetrics() async throws {
        var dashboard = DashboardSummary.preview(date: Date(timeIntervalSince1970: 1_779_000_000))
        dashboard.energy.components["tsb"] = -12
        dashboard.energy.components["acwr"] = 1.7
        dashboard.workouts = [
            WorkoutSummary(
                start: Date(timeIntervalSince1970: 1_779_000_000),
                end: Date(timeIntervalSince1970: 1_779_003_600),
                activityName: "Run"
            )
        ]

        let tsb = try await healthMetricValue("tsb", dashboard: dashboard)
        let acwr = try await healthMetricValue("acwr", dashboard: dashboard)
        let workouts = try await healthMetricValue("workouts_today", dashboard: dashboard)

        XCTAssertEqual(tsb, -12)
        XCTAssertEqual(acwr, 1.7)
        XCTAssertEqual(workouts, 1)
    }

    @MainActor
    func testStrengthWorkoutHistoryToolExposesExerciseEquipmentAndVolume() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(StrengthWorkoutRecord(
            title: "Push Day",
            startedAt: Date(timeIntervalSince1970: 1_800),
            durationMinutes: 45,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "Barbell",
                    sets: [StrengthSetLog(repetitions: 10, weightKilograms: 60)]
                )
            ]
        ))
        try context.save()

        let output = try await StrengthWorkoutHistoryTool(modelContext: context).execute(arguments: #"{"limit":4}"#)

        XCTAssertTrue(output.contains("Push Day"))
        XCTAssertTrue(output.contains("Bench Press"))
        XCTAssertTrue(output.contains("Barbell"))
        XCTAssertTrue(output.contains("600"))
    }

    @MainActor
    private func healthMetricValue(_ metric: String, dashboard: DashboardSummary) async throws -> Double? {
        let result = try await HealthDataTool(dashboard: dashboard).execute(
            arguments: #"{"metric":"\#(metric)"}"#
        )
        let data = try XCTUnwrap(result.data(using: .utf8))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return json["value"] as? Double
    }
}
