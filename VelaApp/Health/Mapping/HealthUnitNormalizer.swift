import Foundation

/// Enforces consistent scale and unit representations at all data boundaries.
/// - sleepEfficiency: 0...1 (proportion)
/// - deepSleepPercent: 0...1 (proportion)
/// - remSleepPercent: 0...1 (proportion)
/// - bodyFatPercentage: 0...100 (percentage)
/// - oxygenSaturation: 0...100 (percentage, e.g. 98.0)
/// - walkingAsymmetry: 0...100 (percentage)
/// - walkingDoubleSupport: 0...100 (percentage)
/// - walkingSteadiness: 0...100 (percentage)
enum HealthUnitNormalizer {
    
    /// Normalizes sleep efficiency from raw percent (0-100 or 0-1) to 0...1.
    static func normalizeSleepEfficiency(_ val: Double) -> Double {
        if val > 1.0 {
            return val / 100.0
        }
        return max(0.0, min(1.0, val))
    }

    /// Normalizes sleep stage percentages from raw percent (0-100 or 0-1) to 0...1.
    static func normalizeSleepStagePercent(_ val: Double) -> Double {
        if val > 1.0 {
            return val / 100.0
        }
        return max(0.0, min(1.0, val))
    }

    /// Normalizes oxygen saturation from raw proportion (0-1) to 0...100 (e.g., 98.0).
    static func normalizeOxygenSaturation(_ val: Double) -> Double {
        if val > 0.0 && val <= 1.0 {
            return val * 100.0
        }
        return max(0.0, min(100.0, val))
    }

    /// Normalizes body fat percentage from raw percent (0-100 or 0-1) to 0...100.
    static func normalizeBodyFatPercentage(_ val: Double) -> Double {
        if val > 0.0 && val <= 1.0 {
            return val * 100.0
        }
        return max(0.0, min(100.0, val))
    }

    /// Normalizes walking gait metrics (asymmetry, double support, steadiness) to 0...100.
    static func normalizeWalkingMetric(_ val: Double) -> Double {
        if val > 0.0 && val <= 1.0 {
            return val * 100.0
        }
        return max(0.0, min(100.0, val))
    }
}
