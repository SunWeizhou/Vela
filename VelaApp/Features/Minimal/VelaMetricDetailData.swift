import SwiftUI
enum EvidenceFormat {
    case integer(String)
    case decimal(String)
    case signedDecimal(String)
}


extension VelaMetricDetailView {
    var displayDateText: String {
        let dateToUse = selectedPoint?.date ?? dashboardVM.selectedDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        if selectedRange == .day {
            let isToday = Calendar.current.isDateInToday(dateToUse)
            if selectedPoint != nil {
                formatter.dateFormat = isToday ? "今天 HH:00" : "M月d日 HH:00"
            } else {
                formatter.dateFormat = isToday ? "今天，M月d日" : "M月d日"
            }
        } else {
            formatter.dateFormat = Calendar.current.isDateInToday(dateToUse) ? "今天，M月d日" : "M月d日"
        }
        return formatter.string(from: dateToUse)
    }

    var chartPoints: [ChartPoint] {
        if selectedRange == .day {
            return []
        }
        let snapshots = dailyRecords.map { $0.toSnapshot() }
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: dashboardVM.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        let start = calendar.date(byAdding: .day, value: -selectedRange.days, to: end) ?? end
        
        let filtered = snapshots
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
            
        return filtered.compactMap { snap in
            guard let val = metricValue(for: snap) else { return nil }
            return ChartPoint(date: snap.date, value: val)
        }
    }

    func metricValue(for snapshot: DailyHealthSnapshot) -> Double? {
        switch metric {
        case .strain: return snapshot.strainScore
        case .recovery: return snapshot.recoveryScore
        case .sleep: return snapshot.sleepScore
        case .stress: return snapshot.stressIndex
        case .energy: return snapshot.currentEnergy ?? snapshot.energyBank
        case .hrv: return snapshot.hrvAverage
        case .rhr: return snapshot.restingHeartRate
        case .weight: return snapshot.bodyWeight
        case .bodyFat: return snapshot.bodyFatPercent
        case .respiratoryRate: return snapshot.respiratoryRate
        case .bloodOxygen: return snapshot.oxygenSaturation
        case .steps: return snapshot.steps
        case .activeCalories: return snapshot.activeCalories
        case .activeMinutes: return snapshot.activeMinutes ?? snapshot.workoutDuration
        }
    }

    var selectedPoint: ChartPoint? {
        guard let rawSelectedDate else { return nil }
        return chartPoints.min(by: {
            abs($0.date.timeIntervalSince(rawSelectedDate)) < abs($1.date.timeIntervalSince(rawSelectedDate))
        })
    }

    func formattedValue(_ score: Double) -> String {
        switch metric {
        case .hrv:
            return "\(Int(score)) ms"
        case .rhr:
            return "\(Int(score)) bpm"
        case .stress:
            return "\(Int(score))"
        case .weight:
            return String(format: "%.1f kg", score)
        case .bodyFat:
            return String(format: "%.1f%%", score)
        case .bloodOxygen:
            return "\(Int(score))%"
        case .respiratoryRate:
            return "\(Int(score))/min"
        case .steps:
            return "\(Int(score))"
        case .activeCalories:
            return "\(Int(score)) kcal"
        case .activeMinutes:
            return "\(Int(score))m"
        default:
            return VelaMinimalFormatting.roundedPercentage(score)
        }
    }

    var isBarChart: Bool {
        switch metric {
        case .steps, .activeCalories, .activeMinutes, .strain:
            return true
        default:
            return false
        }
    }

    var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(dashboardVM.selectedDate) ? "今天，M月d日" : "M月d日"
        return formatter.string(from: dashboardVM.selectedDate)
    }

    var selectedFullDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: dashboardVM.selectedDate)
    }

    var metricShareText: String {
        "\(selectedFullDateText) Vela \(navTitle): \(dynamicValueText) (\(metricSubtitle))"
    }

    var metricInfoText: String {
        "该页面展示由 Apple 健康数据和本地评分引擎生成的\(navTitle)摘要。暂无数据时不会展示估算值。"
    }

    var navTitle: String {
        switch metric {
        case .strain:   "耗力"
        case .recovery: "恢复"
        case .sleep:    "睡眠"
        case .stress:   "压力"
        case .energy:   "能量"
        case .hrv:      "心率变异性"
        case .rhr:      "静息心率"
        case .weight:           "体重"
        case .bodyFat:          "体脂"
        case .respiratoryRate:  "呼吸率"
        case .bloodOxygen:      "血氧"
        case .steps:            "今日步数"
        case .activeCalories:   "活动消耗"
        case .activeMinutes:    "活跃时长"
        }
    }

    var metricColor: Color {
        switch metric {
        case .strain:   VelaTheme.strainColor
        case .recovery: VelaTheme.recoveryColor
        case .sleep:    VelaTheme.sleepColor
        case .stress:   VelaTheme.stressColor
        case .energy:   VelaTheme.energyColor
        case .hrv:      VelaTheme.recoveryColor
        case .rhr:      VelaTheme.accent
        case .weight:           Color(hex: "#8E8A80")
        case .bodyFat:          Color(hex: "#8E8A80")
        case .respiratoryRate:  VelaTheme.recoveryColor
        case .bloodOxygen:      VelaTheme.accent
        case .steps:            Color(hex: "#E0A926")
        case .activeCalories:   VelaTheme.strainColor
        case .activeMinutes:    VelaTheme.sleepColor
        }
    }

    var dynamicScore: Double {
        if let selectedPoint {
            return selectedPoint.value
        }
        switch metric {
        case .strain:
            return dashboard.strain.hasData ? dashboard.strain.score : 0
        case .recovery:
            return dashboard.recovery.hasData ? dashboard.recovery.score : 0
        case .sleep:
            return dashboard.sleepScore.hasData ? dashboard.sleepScore.score : 0
        case .stress:
            return dashboard.stress.hasData ? dashboard.stress.stressIndex : 0
        case .energy:
            return dashboard.energy.hasData ? dashboard.energy.currentEnergy : 0
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds ?? 0
        case .rhr:
            return dashboard.recoveryMetrics.restingHeartRate ?? 0
        case .weight:
            return dashboard.bodyMetrics.weightKilograms ?? 0
        case .bodyFat:
            return dashboard.bodyMetrics.bodyFatPercentage ?? 0
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate ?? 0
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation ?? 0
        case .steps:
            return dashboard.strain.metrics["steps_raw"] ?? 0
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"] ?? 0
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"] ?? 0
        }
    }

    var dynamicValueText: String {
        guard hasMetricData else { return "--" }
        switch metric {
        case .hrv:
            return "\(Int(dynamicScore)) ms"
        case .rhr:
            return "\(Int(dynamicScore)) bpm"
        case .stress:
            return "\(Int(dynamicScore))"
        case .weight:
            return String(format: "%.1f kg", dynamicScore)
        case .bodyFat:
            return String(format: "%.1f%%", dynamicScore)
        case .bloodOxygen:
            return "\(Int(dynamicScore))%"
        case .respiratoryRate:
            return "\(Int(dynamicScore))/min"
        case .steps:
            return "\(Int(dynamicScore))"
        case .activeCalories:
            return "\(Int(dynamicScore)) kcal"
        case .activeMinutes:
            return "\(Int(dynamicScore))m"
        default:
            return VelaMinimalFormatting.roundedPercentage(dynamicScore)
        }
    }

    var metricSubtitle: String {
        guard hasMetricData else { return "暂无数据" }
        switch metric {
        case .strain:
            return strainTargetLabel(dashboard.strain.targetStatus)
        case .recovery:
            return scoreBandLabel(dashboard.recovery.band) + "恢复"
        case .sleep:
            return scoreBandLabel(dashboard.sleepScore.band) + "睡眠"
        case .stress:
            return stressBandLabel(dashboard.stress.band) + "压力"
        case .energy:
            return energyStatusLabel(dashboard.energy.status)
        case .hrv:
            return "正常范围"
        case .rhr:
            return "正常范围"
        case .weight:
            return "生理特征"
        case .bodyFat:
            return "身体组成"
        case .respiratoryRate:
            return "呼吸频率"
        case .bloodOxygen:
            return "血氧饱和度"
        case .steps:
            return "每日活动量"
        case .activeCalories:
            return "运动消耗"
        case .activeMinutes:
            return "活跃时长"
        }
    }

    var hasMetricData: Bool {
        switch metric {
        case .strain: return dashboard.strain.hasData
        case .recovery: return dashboard.recovery.hasData
        case .sleep: return dashboard.sleepScore.hasData
        case .stress: return dashboard.stress.hasData
        case .energy: return dashboard.energy.hasData
        case .hrv: return dashboard.recoveryMetrics.hrvMilliseconds != nil
        case .rhr: return dashboard.recoveryMetrics.restingHeartRate != nil
        case .weight: return dashboard.bodyMetrics.weightKilograms != nil
        case .bodyFat: return dashboard.bodyMetrics.bodyFatPercentage != nil
        case .respiratoryRate: return dashboard.recoveryMetrics.respiratoryRate != nil
        case .bloodOxygen: return dashboard.extendedMetrics.oxygenSaturation != nil
        case .steps: return dashboard.strain.metrics["steps_raw"] != nil
        case .activeCalories: return dashboard.strain.metrics["active_energy_raw"] != nil
        case .activeMinutes: return dashboard.strain.metrics["exercise_minutes_raw"] != nil
        }
    }

    // Double Highlights Mapping
    var leftIcon: String {
        switch metric {
        case .strain:   return "timer"
        case .sleep:    return "bed.double.fill"
        case .stress:   return "waveform.path.ecg"
        case .weight:           return "scalemass.fill"
        case .bodyFat:          return "figure.arms.open"
        case .respiratoryRate:  return "lungs.fill"
        case .bloodOxygen:      return "drop.fill"
        case .steps:            return "shoeprints.fill"
        case .activeCalories:   return "flame.fill"
        case .activeMinutes:    return "clock.fill"
        default:        return "heart.fill"
        }
    }

    var leftTitle: String {
        switch metric {
        case .strain:   return "时长"
        case .sleep:    return "卧床时间"
        case .stress:   return "上次心率变异性"
        case .recovery: return "昨日 RHR"
        case .energy:   return "日间最高"
        case .hrv:      return "基线平均"
        case .rhr:      return "基线平均"
        case .weight:           return "我的体重"
        case .bodyFat:          return "当前体脂"
        case .respiratoryRate:  return "基线平均"
        case .bloodOxygen:      return "血氧基线"
        case .steps:            return "昨日步数"
        case .activeCalories:   return "活动消耗"
        case .activeMinutes:    return "昨日活跃"
        }
    }

    var leftValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))分钟" } ?? "--"
        case .sleep:
            if let bed = dashboard.sleepSummary.bedtime, let wake = dashboard.sleepSummary.wakeTime {
                let diffMin = Int(wake.timeIntervalSince(bed) / 60)
                return VelaMinimalFormatting.duration(minutes: diffMin)
            }
            return "--"
        case .stress:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .recovery:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .energy:
            return dashboard.energy.hasData ? "\(Int(dashboard.energy.morningEnergy)) 分" : "--"
        case .hrv:
            return dashboard.recoveryBaseline.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .rhr:
            return dashboard.recoveryBaseline.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .weight:
            return dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "--"
        case .bodyFat:
            return dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "--"
        case .respiratoryRate:
            return dashboard.recoveryBaseline.respiratoryRate.map { "\(Int($0))/min" } ?? "待建立"
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "--"
        case .steps:
            return dashboard.strain.metrics["steps_raw"].map { "\(Int($0)) 步" } ?? "--"
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0)) 分钟" } ?? "--"
        }
    }

    var leftSubtitle: String? {
        if metric == .stress {
            return "更新时间: \(dashboard.stress.lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    var rightIcon: String {
        switch metric {
        case .strain:   return "flame.fill"
        case .sleep:    return "clock.fill"
        case .stress:   return "heart.fill"
        case .weight:           return "figure.body.strength"
        case .bodyFat:          return "scalemass.fill"
        case .respiratoryRate:  return "waveform.path.ecg"
        case .bloodOxygen:      return "sparkles"
        case .steps:            return "target"
        case .activeCalories:   return "flame.circle.fill"
        case .activeMinutes:    return "figure.run"
        default:        return "bolt.fill"
        }
    }

    var rightTitle: String {
        switch metric {
        case .strain:   return "总能量"
        case .sleep:    return "睡眠时长"
        case .stress:   return "上次心率"
        case .recovery: return "今日 HRV"
        case .energy:   return "日间最低"
        case .hrv:      return "今日读数"
        case .rhr:      return "今日读数"
        case .weight:           return "体脂率"
        case .bodyFat:          return "当前体重"
        case .respiratoryRate:  return "今日读数"
        case .bloodOxygen:      return "今日读数"
        case .steps:            return "今日步数"
        case .activeCalories:   return "当天负荷"
        case .activeMinutes:    return "今日活跃"
        }
    }

    var rightValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
        case .sleep:
            let mins = dashboard.sleepSummary.totalSleepMinutes
            if mins > 0 {
                return VelaMinimalFormatting.duration(minutes: mins)
            }
            return "--"
        case .stress:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .recovery:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .energy:
            return dashboard.energy.hasData ? "\(Int(dashboard.energy.currentEnergy)) 分" : "--"
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .rhr:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .weight:
            return dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "--"
        case .bodyFat:
            return dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "--"
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate.map { "\(Int($0))/min" } ?? "--"
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "--"
        case .steps:
            return dashboard.strain.metrics["steps_raw"].map { "\(Int($0)) 步" } ?? "--"
        case .activeCalories:
            return dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded())) / 100" : "--"
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0)) 分钟" } ?? "--"
        }
    }

    var rightSubtitle: String? {
        if metric == .stress {
            return "更新时间: \(dashboard.stress.lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    var hasCompleteSleepTimes: Bool {
        return dashboard.sleepSummary.bedtime != nil && dashboard.sleepSummary.wakeTime != nil
    }

    var bedtimeHour: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.hour, from: bed)
        }
        return 0
    }
    var bedtimeMinute: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.minute, from: bed)
        }
        return 0
    }
    var wakeHour: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.hour, from: wake)
        }
        return 0
    }
    var wakeMinute: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.minute, from: wake)
        }
        return 0
    }
    var bedtimeText: String {
        guard dashboard.sleepSummary.bedtime != nil else { return "--" }
        return VelaMinimalFormatting.clockTime(hour: bedtimeHour, minute: bedtimeMinute)
    }
    var wakeTimeText: String {
        guard dashboard.sleepSummary.wakeTime != nil else { return "--" }
        return VelaMinimalFormatting.clockTime(hour: wakeHour, minute: wakeMinute)
    }
    var targetBedtimeText: String {
        return VelaMinimalFormatting.clockTime(hour: targetBedtimeHour, minute: targetBedtimeMinute)
    }
    var sleepTargetMinutes: Int {
        return Int((sleepTargetHours * 60.0).rounded())
    }
    var primarySleepStartText: String {
        guard let bedtime = dashboard.sleepSummary.bedtime else { return "暂无睡眠开始时间" }
        return bedtime.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .hour()
                .minute()
                .locale(Locale(identifier: "zh_Hans_CN"))
        )
    }

    var guidanceText: String {
        guard hasMetricData else { return "完成 Apple 健康同步后，这里会展示基于真实数据的分析。" }
        return metricReasons.first ?? "当前指标已更新，请结合趋势和限制因素查看。"
    }

    var trendItems: [TrendItem] {
        guard let series = CoreMetricTrendMapper.series(
            for: metric,
            snapshots: dailyRecords.map { $0.toSnapshot() },
            endingAt: dashboardVM.selectedDate
        ) else {
            return []
        }

        return [
            TrendItem(
                title: series.title,
                value: series.valueText,
                icon: series.icon,
                statusLabel: series.statusLabel,
                statusColor: metricColor,
                graphColor: metricColor,
                history: series.history
            )
        ]
    }

    var evidenceItems: [EvidenceItem] {
        switch metric {
        case .strain:
            return [
                evidence("训练负荷", dashboard.strain.metrics["workout_load"], .decimal(""), "训练本身贡献"),
                evidence("日常活动", dashboard.strain.metrics["activity_load"], .decimal(""), "已降低重复计入权重"),
                evidence("今日总负荷", dashboard.strain.metrics["daily_load"], .decimal(""), "训练与非训练活动合计"),
                evidence("负荷比", dashboard.strain.metrics["training_load_ratio"], .decimal("x"), "近期 7 天 / 28 天等效")
            ]
        case .recovery:
            return [
                evidence("HRV 偏离", dashboard.recovery.metrics["hrv_z_score"], .signedDecimal(" z"), "相对个人基线"),
                evidence("RHR 偏离", dashboard.recovery.metrics["rhr_z_score"], .signedDecimal(" z"), "相对个人基线"),
                evidence("呼吸率偏离", dashboard.recovery.metrics["respiratory_rate_z"], .signedDecimal(" z"), "相对个人基线"),
                evidence("体温偏离", dashboard.recovery.metrics["body_temp_delta"], .signedDecimal("°C"), "夜间体温变化"),
                evidence("血氧", dashboard.recovery.metrics["spo2"] ?? dashboard.extendedMetrics.oxygenSaturation, .decimal("%"), "SpO₂")
            ]
        case .sleep:
            return [
                evidence("睡眠效率", dashboard.sleepScore.metrics["sleep_efficiency"], .decimal("%"), "睡眠 / 卧床"),
                evidence("REM 占比", dashboard.sleepScore.metrics["rem_pct"], .decimal("%"), "快速眼动睡眠"),
                evidence("深睡占比", dashboard.sleepScore.metrics["deep_pct"], .decimal("%"), "深度睡眠"),
                evidence("清醒时间", dashboard.sleepScore.metrics["awake_minutes"], .integer(" 分钟"), "睡眠期间"),
                evidence("清醒次数", dashboard.sleepScore.metrics["awake_episode_count"], .integer(" 次"), "睡眠期间")
            ]
        case .stress:
            return [
                evidence("心率压力", dashboard.stress.metrics["rhr_stress"], .integer(""), "静息心率维度"),
                evidence("HRV 压力", dashboard.stress.metrics["hrv_stress"], .integer(""), "自主神经维度"),
                evidence("呼吸压力", dashboard.stress.metrics["resp_stress"], .integer(""), "呼吸率维度"),
                evidence("睡眠债压力", dashboard.stress.metrics["sleep_debt_stress"], .integer(""), "睡眠影响")
            ]
        case .energy:
            return [
                evidence("ATL", dashboard.energy.metrics["atl"], .decimal(""), "7 天急性负荷"),
                evidence("CTL", dashboard.energy.metrics["ctl"], .decimal(""), "42 天慢性负荷"),
                evidence("TSB", dashboard.energy.metrics["tsb"], .signedDecimal(""), "CTL - ATL"),
                evidence("ACWR", dashboard.energy.metrics["acwr"], .decimal("x"), "急性 / 慢性负荷")
            ]
        case .hrv:
            return [
                evidence("今日 HRV", dashboard.recoveryMetrics.hrvMilliseconds, .integer(" ms"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.hrvMilliseconds, .integer(" ms"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["hrv_z_score"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .rhr:
            return [
                evidence("今日 RHR", dashboard.recoveryMetrics.restingHeartRate, .integer(" bpm"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.restingHeartRate, .integer(" bpm"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["rhr_z_score"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .weight:
            return [
                evidence("体重", dashboard.bodyMetrics.weightKilograms, .decimal(" kg"), "最近一次读数"),
                evidence("体脂率", dashboard.bodyMetrics.bodyFatPercentage, .decimal("%"), "身体组成"),
                evidence("BMI", dashboard.extendedMetrics.bmi, .decimal(""), "身高体重换算")
            ]
        case .bodyFat:
            return [
                evidence("体脂率", dashboard.bodyMetrics.bodyFatPercentage, .decimal("%"), "最近一次读数"),
                evidence("体重", dashboard.bodyMetrics.weightKilograms, .decimal(" kg"), "身体组成参考"),
                evidence("去脂体重", dashboard.bodyMetrics.leanBodyMassKilograms, .decimal(" kg"), "身体组成参考")
            ]
        case .respiratoryRate:
            return [
                evidence("今日呼吸率", dashboard.recoveryMetrics.respiratoryRate, .decimal("/min"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.respiratoryRate, .decimal("/min"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["respiratory_rate_z"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .bloodOxygen:
            return [
                evidence("血氧", dashboard.extendedMetrics.oxygenSaturation, .decimal("%"), "SpO₂ 最近读数"),
                evidence("恢复输入", dashboard.recovery.metrics["spo2"], .decimal("%"), "恢复评分引用"),
                evidence("呼吸率", dashboard.recoveryMetrics.respiratoryRate, .decimal("/min"), "呼吸健康参考")
            ]
        case .steps, .activeCalories, .activeMinutes:
            return [
                evidence("今日步数", dashboard.strain.metrics["steps_raw"], .integer(" 步"), "日常活动"),
                evidence("活动消耗", dashboard.strain.metrics["active_energy_raw"], .integer(" kcal"), "活动能量"),
                evidence("活跃时长", dashboard.strain.metrics["exercise_minutes_raw"], .integer(" 分钟"), "锻炼分钟"),
                evidence("日常活动负荷", dashboard.strain.metrics["activity_load"], .decimal(""), "避免与训练负荷重复计算")
            ]
        }
    }

    func evidence(
        _ title: String,
        _ value: Double?,
        _ format: EvidenceFormat,
        _ detail: String
    ) -> EvidenceItem {
        EvidenceItem(id: title, title: title, value: evidenceText(value, format: format), detail: detail)
    }

    func evidenceText(_ value: Double?, format: EvidenceFormat) -> String {
        guard let value else { return "--" }
        switch format {
        case let .integer(suffix):
            return "\(Int(value.rounded()))\(suffix)"
        case let .decimal(suffix):
            return String(format: "%.1f%@", value, suffix)
        case let .signedDecimal(suffix):
            return String(format: "%+.1f%@", value, suffix)
        }
    }

    var limitingFactors: [String] {
        let reasons = Array(metricReasons.prefix(3))
        return reasons.isEmpty ? ["暂无可用分析原因"] : reasons
    }

    var metricReasons: [String] {
        switch metric {
        case .strain:
            return dashboard.strain.reasons
        case .sleep:
            return dashboard.sleepScore.reasons
        case .stress:
            return dashboard.stress.reasons
        case .recovery, .hrv, .rhr:
            return dashboard.recovery.reasons
        case .energy:
            return dashboard.energy.reasons
        case .weight, .bodyFat, .respiratoryRate, .bloodOxygen:
            return [
                "生理体征偏离正常基线时，应当与睡眠、体能负荷 and 日间自觉症状综合关联评估。",
                "确保每天在相近时间完成测量，以便建立可信度更高的趋势分析基线。"
            ]
        case .steps, .activeCalories, .activeMinutes:
            return [
                "运动负荷与能量摄入可能影响次日恢复；结合连续几天的趋势比单次读数更有参考价值。",
                "高负荷日后可根据饥饿感、训练安排和个人目标，保证规律进食、补水与休息。"
            ]
        }
    }

    func scoreBandLabel(_ band: MetricBand) -> String {
        switch band {
        case .veryLow: return "很低"
        case .low: return "低"
        case .normal: return "正常"
        case .high: return "高"
        case .veryHigh: return "很高"
        }
    }

    func stressBandLabel(_ band: MetricBand) -> String {
        switch band {
        case .veryLow: return "平静"
        case .low: return "正常"
        case .normal: return "偏高"
        case .high, .veryHigh: return "高"
        }
    }

    func energyStatusLabel(_ status: EnergyBankStatus) -> String {
        switch status {
        case .depleted: return "耗竭"
        case .low: return "偏低"
        case .stable: return "稳定"
        case .strong: return "充足"
        }
    }

    func strainTargetLabel(_ target: StrainTargetStatus) -> String {
        switch target {
        case .belowTarget: return "低于目标"
        case .withinTarget: return "在目标范围"
        case .aboveTarget: return "高于目标"
        }
    }
}
