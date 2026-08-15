import SwiftData
import SwiftUI

struct TagCorrelationStat {
    let tag: String
    let count: Int
    let avgRecovery: Double
    let avgSleep: Double
    let avgStrain: Double?
    let withoutAvgRecovery: Double?
    let withoutAvgSleep: Double?

    /// Positive = tag associated with better scores, negative = worse
    var overallImpact: Double {
        var deltas: [Double] = []
        if let without = withoutAvgRecovery, avgRecovery > 0 {
            deltas.append(avgRecovery - without)
        }
        if let without = withoutAvgSleep, avgSleep > 0 {
            deltas.append(avgSleep - without)
        }
        guard !deltas.isEmpty else { return 0 }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    var impactColor: Color {
        overallImpact > 2 ? VelaTheme.recoveryColor :
        overallImpact < -2 ? VelaTheme.stressColor :
        VelaTheme.fg2
    }
}
