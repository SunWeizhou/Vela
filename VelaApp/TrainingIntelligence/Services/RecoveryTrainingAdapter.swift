import Foundation

/// C3：用真实训练后的次日恢复变化校准容量系数——
/// 平均恢复变化正向（练后恢复良好）→ 略放宽；负向（练后吃力）→ 收紧。
enum TrainingResponseCalibrator {
    static func calibratedVolumeMultiplier(
        base: Double,
        recoveryDeltas: [Double],
        minimumSamples: Int = 6,
        floor: Double = 0.85,
        ceiling: Double = 1.1
    ) -> Double {
        guard recoveryDeltas.count >= minimumSamples else { return base }
        let meanDelta = recoveryDeltas.reduce(0, +) / Double(recoveryDeltas.count)
        let adjustment = ScoringMath.clamp(1.0 + meanDelta / 100.0, min: floor, max: ceiling)
        return base * adjustment
    }
}
