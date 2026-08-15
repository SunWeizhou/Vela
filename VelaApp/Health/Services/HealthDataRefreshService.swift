import Foundation

// F7：HealthDataRefreshService（第三套快照构建器）无任何调用方，实现已删除。
// 快照构建的唯一入口是 DailyHealthComputation（HealthKitSyncEngine / DailySummaryUseCase）。
// 本文件保留 DailyHealthContext 等共享类型定义，并维持 Xcode 工程引用（pbxproj 不可脚本修改）。

struct DailyHealthContext: Hashable {
    var date: Date
    var sleepSummary: SleepSummary?
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strainToday: StrainActivitySummary
    var strainBaselineDaily: StrainActivitySummary
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics = ExtendedHealthMetrics()

    var hasAnyData: Bool {
        sleepSummary != nil ||
        recoveryMetrics.hrvMilliseconds != nil ||
        recoveryMetrics.restingHeartRate != nil ||
        recoveryMetrics.sleepHeartRate != nil ||
        recoveryMetrics.respiratoryRate != nil ||
        strainToday.activeEnergyKilocalories != nil ||
        strainToday.exerciseMinutes != nil ||
        strainToday.stepCount != nil ||
        !strainToday.workouts.isEmpty ||
        bodyMetrics.vo2Max != nil ||
        bodyMetrics.weightKilograms != nil ||
        bodyMetrics.bodyFatPercentage != nil ||
        bodyMetrics.leanBodyMassKilograms != nil
    }
}

extension StrainActivitySummary {
    func dailyAverage(days: Double) -> StrainActivitySummary {
        StrainActivitySummary(
            activeEnergyKilocalories: activeEnergyKilocalories.map { $0 / days },
            exerciseMinutes: exerciseMinutes.map { $0 / days },
            stepCount: stepCount.map { $0 / days },
            workouts: workouts
        )
    }
}
