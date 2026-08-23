import SwiftUI

struct CoreMetricCoachContext {
    var focus: CoachContextFocus
    var suggestedQuestion: String

    static func make(for metric: VelaMetricDetailView.MetricType) -> CoreMetricCoachContext {
        switch metric {
        case .strain:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "负荷",
                    systemContext: "当前负荷、近期训练节律，以及由恢复状态约束的参考区间",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "今天的负荷相对参考区间如何？我该怎么安排剩余活动？"
            )
        case .recovery:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "恢复",
                    systemContext: "恢复分、HRV、静息心率、睡眠和近期负荷相对个人基线的变化",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "哪些信号主要影响了我今天的恢复？我该如何安排？"
            )
        case .sleep:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "睡眠",
                    systemContext: "睡眠分、实际睡眠时长、入睡与起床节律，以及可用的睡眠阶段证据",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "昨晚的睡眠分、时长和节律分别说明了什么？"
            )
        case .stress:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "压力",
                    systemContext: "生理压力信号、计算输入和个人基线偏离；不将其当作心理状态或医疗诊断",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "哪些已记录的生理信号与今天的压力分数同时偏离？"
            )
        case .energy:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "能量",
                    systemContext: "早间储备、当前剩余，以及睡眠、恢复、压力和近期负荷的关系",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "今天的能量主要消耗在哪里？我该如何安排剩余时间？"
            )
        case .hrv:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "心率变异性",
                    systemContext: "HRV 与日常行为的相关性分析",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "哪些已记录行为与我的 HRV 变化相关？"
            )
        case .rhr:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "静息心率",
                    systemContext: "静息心率与心血管系统适应性",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "静息心率持续下降代表什么？"
            )
        case .weight:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "体重",
                    systemContext: "体重趋势与能量代谢反馈",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "如何平稳控制体重下降速度？"
            )
        case .bodyFat:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "体脂",
                    systemContext: "身体成份变化与骨骼肌质量",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "体脂率降到多少能看到腹肌？"
            )
        case .respiratoryRate:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "呼吸率",
                    systemContext: "夜间呼吸频率趋势与个人基线",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "呼吸率持续偏离个人基线时该如何记录与观察？"
            )
        case .bloodOxygen:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "血氧",
                    systemContext: "高原适应性与夜间含氧量",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "血氧处于什么范围需要注意？"
            )
        case .steps:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "今日步数",
                    systemContext: "非运动消耗 NEAT 对代谢的影响",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "今天步数是否达到最低活跃标准？"
            )
        case .activeCalories:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "活动消耗",
                    systemContext: "运动总消耗与燃脂区间时长",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "如何用低强度活动增加日常活动量？"
            )
        case .activeMinutes:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "活跃时长",
                    systemContext: "高强度中强度身体活跃总时长",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "每周要累计多少活跃分钟最健康？"
            )
        }
    }

    private static func metricScreenContext(
        _ metric: VelaMetricDetailView.MetricType
    ) -> CoachScreenContext {
        CoachScreenContext(surface: .metricDetail, entityType: metric.rawValue)
    }
}
