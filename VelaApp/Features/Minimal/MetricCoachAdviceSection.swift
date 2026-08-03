import SwiftUI

struct CoreMetricCoachContext {
    var focus: CoachContextFocus
    var suggestedQuestion: String

    static func make(for metric: VelaMetricDetailView.MetricType) -> CoreMetricCoachContext {
        switch metric {
        case .strain:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "耗力",
                    systemContext: "你的心肺负荷与肌肉压力",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "今天耗力是否达标？"
            )
        case .recovery:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "恢复",
                    systemContext: "自主神经系统平衡与夜间体征",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "如何提高明天的恢复值？"
            )
        case .sleep:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "睡眠",
                    systemContext: "睡眠效率与各个睡眠周期配比",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "怎么优化深度睡眠比例？"
            )
        case .stress:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "压力",
                    systemContext: "全天慢性与急性压力负荷比率",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "我今天的压力源自何处？"
            )
        case .energy:
            return CoreMetricCoachContext(
                focus: CoachContextFocus(
                    title: "能量",
                    systemContext: "体能储备量 ATL 与 CTL 比例",
                    screenContext: metricScreenContext(metric)
                ),
                suggestedQuestion: "目前体能水平适合做大重量训练吗？"
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
