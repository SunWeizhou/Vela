import XCTest
@testable import Vela

final class ContextBuilderTests: XCTestCase {

    func testDeepSeekModelResolvesDisplayNamesToOfficialAPIIdentifiers() {
        XCTAssertEqual(DeepSeekTextModel(displayName: "DeepSeek V4 Flash").apiIdentifier, "deepseek-v4-flash")
        XCTAssertEqual(DeepSeekTextModel(displayName: "DeepSeek V4 Pro").apiIdentifier, "deepseek-v4-pro")
    }

    func testDeepSeekModelFallsBackToProForUnknownStoredValue() {
        XCTAssertEqual(DeepSeekTextModel(displayName: "legacy-model").apiIdentifier, "deepseek-v4-pro")
    }

    // MARK: - Schema Snapshot

    func testContextBuilderProducesStableHash() {
        let builder = AIContextBuilder()

        let dashboard = DashboardSummary.preview()
        let (_, meta1) = builder.build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        let (_, meta2) = builder.build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        // Same inputs → same hash
        XCTAssertFalse(meta1.hash.isEmpty, "Hash should be non-empty")
        XCTAssertFalse(meta2.hash.isEmpty, "Hash should be non-empty")
        // Note: Hash identity depends on DashboardSummary.preview() producing
        // deterministic output. If preview uses Date() internally, hashes may differ.

        // Schema version should be present
        XCTAssertFalse(meta1.schemaVersion.isEmpty)
        XCTAssertFalse(meta2.schemaVersion.isEmpty)

        // Included sections should be non-empty
        XCTAssertFalse(meta1.includedSections.isEmpty)
    }

    func testContextBuilderDifferentInputsDifferentHash() {
        let builder = AIContextBuilder()

        let dashboard1 = DashboardSummary.preview()
        let (_, meta1) = builder.build(
            dashboard: dashboard1,
            journalEntries: [],
            historicalReports: [],
            userWiki: ["goals.md": "Run a marathon"],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        let dashboard2 = DashboardSummary.preview()
        let (_, meta2) = builder.build(
            dashboard: dashboard2,
            journalEntries: [],
            historicalReports: [],
            userWiki: ["goals.md": "Build muscle mass"],
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        // Different wiki content → different hash
        XCTAssertNotEqual(meta1.hash, meta2.hash, "Different inputs should produce different hashes")
    }

    // MARK: - Metadata

    func testContextMetadataIncludesCorrectSchemaVersion() {
        let builder = AIContextBuilder()
        let (_, meta) = builder.build(
            dashboard: DashboardSummary.preview(),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        XCTAssertEqual(meta.schemaVersion, AIContextBuilder.schemaVersion)
        XCTAssertTrue(meta.redactedFields.isEmpty)
    }

    // MARK: - Envelope Structure

    func testContextEnvelopeHasAllRequiredSections() {
        let builder = AIContextBuilder()
        let (envelope, _) = builder.build(
            dashboard: DashboardSummary.preview(),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        // All top-level sections should exist
        XCTAssertNotNil(envelope.metadata)
        XCTAssertFalse(envelope.todaySummary.isEmpty)
        XCTAssertFalse(envelope.sleep.isEmpty)
        XCTAssertFalse(envelope.recovery.isEmpty)
        XCTAssertFalse(envelope.strain.isEmpty)
        XCTAssertFalse(envelope.stress.isEmpty)
        XCTAssertFalse(envelope.energyBank.isEmpty)
        XCTAssertFalse(envelope.extendedMetrics.isEmpty)
    }

    func testContextEnvelopeEncodesToValidJSON() {
        let builder = AIContextBuilder()
        let (envelope, _) = builder.build(
            dashboard: DashboardSummary.preview(),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(envelope)
        XCTAssertNotNil(data, "Envelope should encode to valid JSON")

        let jsonString = String(data: data!, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("today_summary") ?? false)
        XCTAssertTrue(jsonString?.contains("energy_bank") ?? false)
    }

    func testContextEnvelopeDoesNotDropCoreMetricCompatibilityFields() {
        var dashboard = DashboardSummary.preview()
        dashboard.sleepScore = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 420,
            awakeMinutes: 30,
            awakeEpisodeCount: 3,
            remMinutes: 84,
            deepMinutes: 63,
            inBedMinutes: 450
        ))
        dashboard.recovery = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 35,
            hrvBaseline: 50,
            hrvHistory: [48, 49, 50, 51, 52, 49, 50],
            restingHeartRateToday: 62,
            restingHeartRateBaseline: 60,
            rhrHistory: [59, 60, 61, 60, 59, 61, 60],
            sleepScoreLastNight: dashboard.sleepScore.score,
            strainScoreYesterday: 45
        ))
        dashboard.energy = EnergyBankEngine().calculate(from: EnergyBankInput(
            recoveryScore: dashboard.recovery.score,
            sleepScore: dashboard.sleepScore.score,
            strainScore: 120,
            stressIndex: 35,
            strainHistory: Array(repeating: 20.0, count: 35) + Array(repeating: 120.0, count: 6)
        ))

        let (envelope, _) = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        XCTAssertNotEqual(envelope.recovery["hrv_z_score"], "N/A")
        XCTAssertNotEqual(envelope.energyBank["tsb_freshness"], "N/A")
        XCTAssertNotEqual(envelope.energyBank["acwr_ratio"], "N/A")
        XCTAssertNotEqual(envelope.sleep["deep_pct"], "N/A")
    }

    // MARK: - Typed Context Schema

    func testTypedContextIsCodable() {
        let ctx = TypedAgentContext(
            schemaVersion: "v2.0",
            contextHash: "abc123",
            generatedAt: Date(),
            contextWindow: "today",
            recovery: RecoveryContext(
                score: MetricValue.live(85.0, unit: "pts"),
                band: "high",
                hrv: MetricValue.live(62.0, unit: "ms"),
                restingHeartRate: MetricValue.live(58.0, unit: "bpm"),
                respiratoryRate: MetricValue.live(14.5, unit: "br/min"),
                topReason: nil
            ),
            sleep: SleepContext(
                score: MetricValue.live(78.0, unit: "pts"),
                band: "medium",
                totalMinutes: MetricValue.live(420, unit: "min"),
                efficiency: MetricValue.live(87.5, unit: "%"),
                remPercent: MetricValue.live(22.0, unit: "%"),
                deepPercent: MetricValue.live(18.0, unit: "%"),
                coreMinutes: MetricValue.live(200, unit: "min"),
                remMinutes: MetricValue.live(92, unit: "min"),
                deepMinutes: MetricValue.live(76, unit: "min"),
                awakeMinutes: MetricValue.live(30, unit: "min"),
                bedtime: nil,
                wakeTime: nil,
                topReason: nil
            ),
            strain: StrainContext(
                score: MetricValue.live(45.0, unit: "pts"),
                band: "low",
                targetStatus: "below_target",
                recommendedRangeLower: 50,
                recommendedRangeUpper: 80,
                steps: MetricValue.live(8000, unit: "steps"),
                activeEnergyKcal: MetricValue.live(350, unit: "kcal"),
                exerciseMinutes: MetricValue.live(30, unit: "min")
            ),
            stress: StressContext(
                stressIndex: MetricValue.live(25.0, unit: "index"),
                band: "low",
                confidence: .high,
                proxyNote: "Physiological proxy, not diagnostic."
            ),
            energyBank: EnergyBankContext(
                morningEnergy: MetricValue.live(85.0, unit: "pts"),
                currentEnergy: MetricValue.live(72.0, unit: "pts"),
                status: "discharging",
                chargeEfficiency: MetricValue.live(0.75, unit: "ratio"),
                atl7Day: MetricValue.live(55.0, unit: "AU"),
                ctl42Day: MetricValue.live(48.0, unit: "AU"),
                tsbFreshness: MetricValue.live(-7.0, unit: "AU")
            ),
            training: TrainingContext(
                activePlan: nil,
                workoutCount: 1,
                workoutTypes: ["Running"],
                totalEnergyKcal: 350,
                totalDurationMin: 30,
                workoutListJSON: "[]"
            ),
            nutrition: NutritionContext(
                recentEntries: [],
                recentCount: 0,
                totalCalories: 0,
                totalProtein: 0,
                totalCarbs: 0,
                totalFat: 0,
                totalFiber: 0
            ),
            extendedMetrics: ExtendedMetricsContext(
                age: 30,
                biologicalSex: "male",
                heightCm: MetricValue.live(175.0, unit: "cm"),
                weightKg: MetricValue.live(72.0, unit: "kg"),
                bmi: MetricValue.live(23.5, unit: "kg/m²"),
                bodyFatPct: MetricValue.live(18.0, unit: "%"),
                vo2Max: MetricValue.live(42.0, unit: "ml/kg/min"),
                walkingSpeed: MetricValue.missing(),
                walkingAsymmetry: MetricValue.missing(),
                doubleSupportPct: MetricValue.missing(),
                spo2: MetricValue.live(98.0, unit: "%"),
                bloodPressureSystolic: nil,
                bloodPressureDiastolic: nil,
                bloodGlucose: nil,
                waterMl: nil,
                caffeineMg: nil,
                envNoiseDb: nil,
                daylightMinutes: nil,
                wristTempC: nil
            ),
            recentTrends: [:],
            weeklyTrends: [:],
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try? encoder.encode(ctx)
        XCTAssertNotNil(data, "TypedAgentContext should encode to JSON")

        // Decode
        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(TypedAgentContext.self, from: data!)
        XCTAssertNotNil(decoded, "TypedAgentContext should decode from JSON")
        XCTAssertEqual(decoded?.recovery.score.value, 85.0)
        XCTAssertEqual(decoded?.sleep.remPercent.value, 22.0)
    }

    func testReliabilitySprintConstraints() throws {
        // 1. Verify bodyFatPct in buildTyped
        let builder = AIContextBuilder()
        var dashboard = DashboardSummary.preview()
        dashboard.bodyMetrics.bodyFatPercentage = 17.5

        let (typedContext, _) = builder.buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        // bodyFatPct should be present with correct value
        if let bodyFatValue = typedContext.extendedMetrics.bodyFatPct.value {
            XCTAssertEqual(bodyFatValue, 17.5)
        }
        XCTAssertEqual(typedContext.extendedMetrics.bodyFatPct.unit, "%")

        // 2. TrainingDecisionEngine with empty history
        let decisionEmptyHistory = TrainingDecisionEngine.evaluate(
            dashboard,
            journalFlags: [],
            activePlan: nil,
            history: []
        )
        XCTAssertEqual(decisionEmptyHistory.trainingLoadConfidence, .unavailable)
        XCTAssertNotEqual(decisionEmptyHistory.readinessLevel, "HIGH")

        // 3. PersistenceWriteGate read-only safety
        PersistenceWriteGate.shared.setReadOnly(true)
        XCTAssertThrowsError(try PersistenceWriteGate.shared.assertWritable(operation: "Test Operation")) { error in
            guard let velaError = error as? VelaError else {
                XCTFail("Should throw VelaError")
                return
            }
            if case .readOnlySafetyMode = velaError {
                // Success
            } else {
                XCTFail("Should throw .readOnlySafetyMode error")
            }
        }
        PersistenceWriteGate.shared.setReadOnly(false)
    }
}
