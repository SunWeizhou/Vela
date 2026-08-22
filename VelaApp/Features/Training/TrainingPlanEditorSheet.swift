import SwiftUI
import SwiftData

// MARK: - Training Plan Preset Templates
enum TrainingPlanPreset: String, CaseIterable, Identifiable {
    case ppl6Day = "PPL 6天推拉腿分化"
    case upperLower4Day = "4天上下肢分化"
    case fullBody3Day = "3天全身力量平衡"
    case cardioBase3Day = "3天心肺耐力与 Zone 2"
    case broSplit5Day = "5天经典部位分化"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .ppl6Day: return "高阶肌肥大与力量周期 · 推/拉/腿循环"
        case .upperLower4Day: return "高效力量与肌肥大平衡 · 适合每周4练"
        case .fullBody3Day: return "经典复合动作全身覆盖 · 适合忙碌作息"
        case .cardioBase3Day: return "构建心肺基础与有氧底力 · Zone 2 + 节奏跑"
        case .broSplit5Day: return "胸、背、肩、手臂、腿单一部位聚焦"
        }
    }

    var icon: String {
        switch self {
        case .ppl6Day: return "flame.fill"
        case .upperLower4Day: return "figure.strengthtraining.traditional"
        case .fullBody3Day: return "bolt.shield.fill"
        case .cardioBase3Day: return "figure.run"
        case .broSplit5Day: return "trophy.fill"
        }
    }

    var weeksCount: Int {
        switch self {
        case .ppl6Day, .upperLower4Day: return 4
        case .fullBody3Day: return 6
        case .cardioBase3Day: return 8
        case .broSplit5Day: return 4
        }
    }

    func generateDays(weekNumber: Int = 1) -> [TrainingDay] {
        switch self {
        case .ppl6Day:
            return [
                makeDay(w: weekNumber, d: 1, title: "推力训练 (Push A)", focus: "strength", dur: 60, intensity: "high", desc: "主攻胸部中束、三角肌前中束及肱三头肌", exercises: [
                    .init(name: "杠铃平板卧推", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 150),
                    .init(name: "上斜哑铃卧推", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "双杠臂屈伸", targetSets: 3, targetReps: "8-12", targetRPE: 8.5, restSeconds: 90),
                    .init(name: "哑铃侧平举", targetSets: 4, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "绳索三头下压", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 2, title: "拉力训练 (Pull A)", focus: "strength", dur: 60, intensity: "high", desc: "主攻背阔肌、斜方肌中下部、三角肌后束及肱二头肌", exercises: [
                    .init(name: "传统硬拉", targetSets: 3, targetReps: "5", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "高位下拉", targetSets: 4, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "坐姿绳索划船", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "绳索面拉", targetSets: 4, targetReps: "15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "哑铃交替弯举", targetSets: 3, targetReps: "10-12", targetRPE: 8.5, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 3, title: "下肢力量 (Legs A)", focus: "strength", dur: 65, intensity: "high", desc: "主攻股四头肌、腘绳肌、臀大肌与小腿", exercises: [
                    .init(name: "杠铃深蹲", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "罗马尼亚硬拉", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "器械腿屈伸", targetSets: 3, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "俯卧腿弯举", targetSets: 3, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "站姿提踵", targetSets: 4, targetReps: "15-20", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 4, title: "推力训练 (Push B)", focus: "strength", dur: 55, intensity: "moderate", desc: "以肩部推举为主导，强化胸肌上束", exercises: [
                    .init(name: "站姿杠铃推举", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 150),
                    .init(name: "平板哑铃卧推", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "器械夹胸", targetSets: 3, targetReps: "12-15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "绳索侧平举", targetSets: 4, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "仰卧臂屈伸", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 5, title: "拉力训练 (Pull B)", focus: "strength", dur: 55, intensity: "moderate", desc: "以水平划船为主导，强化背部厚度与二头肌", exercises: [
                    .init(name: "引体向上", targetSets: 4, targetReps: "6-10", targetRPE: 8.5, restSeconds: 120),
                    .init(name: "俯身杠铃划船", targetSets: 4, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "单臂哑铃划船", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "俯身飞鸟", targetSets: 3, targetReps: "15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "杠铃牧师凳弯举", targetSets: 3, targetReps: "10-12", targetRPE: 8.5, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 6, title: "下肢肌肥大 (Legs B)", focus: "strength", dur: 55, intensity: "moderate", desc: "臀推与单腿稳定性，补充后链负荷", exercises: [
                    .init(name: "杠铃臀推", targetSets: 4, targetReps: "8-10", targetRPE: 8.5, restSeconds: 120),
                    .init(name: "哑铃保加利亚剪蹲", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "坐姿腿弯举", targetSets: 3, targetReps: "12-15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "小腿提踵", targetSets: 3, targetReps: "15-20", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 7, title: "主动恢复与拉伸", focus: "rest", dur: 30, intensity: "low", desc: "全身肌肉筋膜放松，动态拉伸，促进代谢产物清除", exercises: [])
            ]

        case .upperLower4Day:
            return [
                makeDay(w: weekNumber, d: 1, title: "上肢力量 (Upper Power)", focus: "strength", dur: 60, intensity: "high", desc: "大重量复合动作，强化上半身力量基底", exercises: [
                    .init(name: "杠铃平板卧推", targetSets: 4, targetReps: "5-6", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "杠铃划船", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 120),
                    .init(name: "站姿过顶推举", targetSets: 3, targetReps: "6-8", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "引体向上", targetSets: 3, targetReps: "6-8", targetRPE: 8.0, restSeconds: 90)
                ]),
                makeDay(w: weekNumber, d: 2, title: "下肢力量 (Lower Power)", focus: "strength", dur: 60, intensity: "high", desc: "深蹲与硬拉核心负荷，构建下肢绝对力量", exercises: [
                    .init(name: "杠铃深蹲", targetSets: 4, targetReps: "5-6", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "罗马尼亚硬拉", targetSets: 3, targetReps: "6-8", targetRPE: 8.0, restSeconds: 150),
                    .init(name: "腿举", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "提踵与核心悬垂举腿", targetSets: 3, targetReps: "15", targetRPE: 7.5, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 3, title: "主动休息 (Active Recovery)", focus: "rest", dur: 30, intensity: "low", desc: "低强度散步或轻度拉伸，调节自主神经", exercises: []),
                makeDay(w: weekNumber, d: 4, title: "上肢肌肥大 (Upper Hypertrophy)", focus: "strength", dur: 55, intensity: "moderate", desc: "中等重量多角度刺激，促进肌肥大", exercises: [
                    .init(name: "上斜哑铃卧推", targetSets: 4, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "高位下拉", targetSets: 4, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "哑铃侧平举", targetSets: 4, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "二头弯举与三头下压超级组", targetSets: 3, targetReps: "12", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 5, title: "下肢肌肥大 (Lower Hypertrophy)", focus: "strength", dur: 55, intensity: "moderate", desc: "箭步蹲与器械孤立刺激，补足肌肉细节", exercises: [
                    .init(name: "前蹲/箭步蹲", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "器械腿屈伸", targetSets: 3, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "器械腿弯举", targetSets: 3, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "站姿提踵", targetSets: 4, targetReps: "15-20", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 6, title: "休息日 (Rest Day)", focus: "rest", dur: 0, intensity: "low", desc: "充足睡眠与营养补充", exercises: []),
                makeDay(w: weekNumber, d: 7, title: "休息日 (Rest Day)", focus: "rest", dur: 0, intensity: "low", desc: "为下一周训练周期蓄力", exercises: [])
            ]

        case .fullBody3Day:
            return [
                makeDay(w: weekNumber, d: 1, title: "全身力量 A (Full Body A)", focus: "strength", dur: 50, intensity: "high", desc: "深蹲 + 平板推 + 垂直拉", exercises: [
                    .init(name: "杠铃深蹲", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 150),
                    .init(name: "杠铃平板卧推", targetSets: 4, targetReps: "6-8", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "引体向上 / 高位下拉", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "悬垂举腿", targetSets: 3, targetReps: "12-15", targetRPE: 7.5, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 2, title: "休息或轻度有氧", focus: "rest", dur: 20, intensity: "low", desc: "轻度有氧或快走 20-30 分钟", exercises: []),
                makeDay(w: weekNumber, d: 3, title: "全身力量 B (Full Body B)", focus: "strength", dur: 50, intensity: "high", desc: "硬拉 + 过顶推 + 水平拉", exercises: [
                    .init(name: "罗马尼亚硬拉", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 150),
                    .init(name: "站姿哑铃推举", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "坐姿绳索划船", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "哑铃侧平举", targetSets: 3, targetReps: "12-15", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 4, title: "休息日", focus: "rest", dur: 0, intensity: "low", desc: "肌肉恢复与放松", exercises: []),
                makeDay(w: weekNumber, d: 5, title: "全身力量 C (Full Body C)", focus: "strength", dur: 50, intensity: "moderate", desc: "单腿 + 倾斜推 + 核心", exercises: [
                    .init(name: "哑铃保加利亚剪蹲", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "上斜哑铃卧推", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "俯身哑铃划船", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "平板支撑与侧支撑", targetSets: 3, targetReps: "45秒", targetRPE: 7.5, restSeconds: 45)
                ]),
                makeDay(w: weekNumber, d: 6, title: "休息日", focus: "rest", dur: 0, intensity: "low", desc: "周末放松与主动拉伸", exercises: []),
                makeDay(w: weekNumber, d: 7, title: "休息日", focus: "rest", dur: 0, intensity: "low", desc: "准备迎接下一周", exercises: [])
            ]

        case .cardioBase3Day:
            return [
                makeDay(w: weekNumber, d: 1, title: "Zone 2 基础耐力构建", focus: "cardio", dur: 45, intensity: "moderate", desc: "心率维持在 Zone 2（储备心率 60-70%），鼻吸口呼，增强线粒体密度", exercises: []),
                makeDay(w: weekNumber, d: 2, title: "动态拉伸与核心激活", focus: "flexibility", dur: 25, intensity: "low", desc: "髋关节与踝关节活动度、核心抗伸展稳定性", exercises: []),
                makeDay(w: weekNumber, d: 3, title: "乳酸阈值节奏跑 (Tempo)", focus: "cardio", dur: 40, intensity: "high", desc: "10分钟慢跑热身 + 20分钟 Zone 3-4 节奏巡航 + 10分钟放松跑", exercises: []),
                makeDay(w: weekNumber, d: 4, title: "主动恢复休息日", focus: "rest", dur: 0, intensity: "low", desc: "充分补水与电解质", exercises: []),
                makeDay(w: weekNumber, d: 5, title: "长距离慢跑 (LSD Cardio)", focus: "cardio", dur: 60, intensity: "moderate", desc: "周末低强度有氧长距离，平稳配速", exercises: []),
                makeDay(w: weekNumber, d: 6, title: "瑜伽与全身放松", focus: "flexibility", dur: 30, intensity: "low", desc: "下肢大肌群筋膜放松与静态伸展", exercises: []),
                makeDay(w: weekNumber, d: 7, title: "休息日", focus: "rest", dur: 0, intensity: "low", desc: "恢复身体与精神状态", exercises: [])
            ]

        case .broSplit5Day:
            return [
                makeDay(w: weekNumber, d: 1, title: "胸部力量与塑形", focus: "strength", dur: 55, intensity: "high", desc: "平板卧推、上斜推、双杠与夹胸全方位刺激", exercises: [
                    .init(name: "杠铃平板卧推", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 150),
                    .init(name: "上斜哑铃卧推", targetSets: 4, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "器械夹胸", targetSets: 3, targetReps: "12-15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "俯卧撑力竭组", targetSets: 2, targetReps: "力竭", targetRPE: 9.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 2, title: "背部厚度与宽度", focus: "strength", dur: 55, intensity: "high", desc: "硬拉、引体向上与划船组合", exercises: [
                    .init(name: "传统硬拉", targetSets: 3, targetReps: "5", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "引体向上", targetSets: 4, targetReps: "8-10", targetRPE: 8.5, restSeconds: 90),
                    .init(name: "杠铃划船", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "高位下拉", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 3, title: "肩部立体雕刻", focus: "strength", dur: 50, intensity: "high", desc: "过顶推举、侧平举与后束专项", exercises: [
                    .init(name: "站姿杠铃推举", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 120),
                    .init(name: "哑铃侧平举", targetSets: 4, targetReps: "12-15", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "绳索面拉", targetSets: 4, targetReps: "15", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "哑铃阿诺德推举", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 4, title: "手臂超级组 (Arm Day)", focus: "strength", dur: 45, intensity: "moderate", desc: "二头肌与三头肌对抗肌超级组刺激", exercises: [
                    .init(name: "杠铃弯举", targetSets: 3, targetReps: "8-10", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "仰卧臂屈伸", targetSets: 3, targetReps: "8-10", targetRPE: 8.5, restSeconds: 60),
                    .init(name: "哑铃锤式弯举", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 60),
                    .init(name: "绳索下压", targetSets: 3, targetReps: "12-15", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 5, title: "下肢全面摧毁 (Leg Day)", focus: "strength", dur: 60, intensity: "high", desc: "大重量深蹲与单腿孤立", exercises: [
                    .init(name: "杠铃深蹲", targetSets: 4, targetReps: "6-8", targetRPE: 8.5, restSeconds: 180),
                    .init(name: "罗马尼亚硬拉", targetSets: 3, targetReps: "8-10", targetRPE: 8.0, restSeconds: 120),
                    .init(name: "腿举", targetSets: 3, targetReps: "10-12", targetRPE: 8.0, restSeconds: 90),
                    .init(name: "站姿提踵", targetSets: 4, targetReps: "15-20", targetRPE: 8.0, restSeconds: 60)
                ]),
                makeDay(w: weekNumber, d: 6, title: "主动休息日", focus: "rest", dur: 0, intensity: "low", desc: "轻度活动与拉伸", exercises: []),
                makeDay(w: weekNumber, d: 7, title: "休息日", focus: "rest", dur: 0, intensity: "low", desc: "完全休息以迎接下一周", exercises: [])
            ]
        }
    }

    private func makeDay(
        w: Int,
        d: Int,
        title: String,
        focus: String,
        dur: Int,
        intensity: String,
        desc: String,
        exercises: [WorkoutTemplateExercise]
    ) -> TrainingDay {
        let jsonStr: String
        if let data = try? JSONEncoder().encode(exercises), let str = String(data: data, encoding: .utf8) {
            jsonStr = str
        } else {
            jsonStr = "[]"
        }
        return TrainingDay(
            id: UUID(),
            weekNumber: w,
            dayNumber: d,
            title: title,
            description: desc,
            focus: focus,
            durationMinutes: dur,
            intensity: intensity,
            isCompleted: false,
            plannedExercisesJSON: jsonStr
        )
    }
}

// MARK: - Training Plan Editor Sheet
struct TrainingPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private let existingPlan: TrainingPlanRecord?

    @State private var title: String
    @State private var goalDescription: String
    @State private var weeksCount: Int
    @State private var startDate: Date
    @State private var isActive: Bool
    @State private var days: [TrainingDay]
    @State private var selectedPreset: TrainingPlanPreset? = nil
    @State private var showPresetPicker = false
    @State private var editingDay: TrainingDay? = nil
    @State private var currentWeekTab: Int = 1
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(plan: TrainingPlanRecord? = nil) {
        self.existingPlan = plan
        _title = State(initialValue: plan?.title ?? "自定义自适应训练计划")
        _goalDescription = State(initialValue: plan?.goalDescription ?? "基于生理恢复与渐进负荷的个性化训练周期")
        _weeksCount = State(initialValue: plan?.weeksCount ?? 4)
        _startDate = State(initialValue: plan?.startDate ?? Date())
        _isActive = State(initialValue: plan?.isActive ?? true)
        _days = State(initialValue: plan?.days ?? TrainingPlanPreset.upperLower4Day.generateDays(weekNumber: 1))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        planMetaSection
                        presetTemplatePickerSection
                        weeksAndDaysSection
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(existingPlan == nil ? "新建训练计划" : "编辑训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { savePlan() }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .sheet(item: $editingDay) { day in
                TrainingDayEditorSheet(day: day) { updatedDay in
                    if let idx = days.firstIndex(where: { $0.id == updatedDay.id }) {
                        days[idx] = updatedDay
                    } else {
                        days.append(updatedDay)
                    }
                }
            }
            .alert("无法保存计划", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections
    private var planMetaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("计划基本信息")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("计划名称")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    TextField("例如：秋季增肌 PPL 周期", text: $title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .padding(12)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("目标与说明")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    TextField("例如：提升卧推与深蹲力量，保持心肺健康", text: $goalDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .padding(12)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(10)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("周期总周数")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Stepper("\(weeksCount) 周", value: $weeksCount, in: 1...16)
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(.top, 4)

                Toggle("设为当前活跃计划", isOn: $isActive)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .padding(.top, 4)
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    private var presetTemplatePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("从经典模板快速套用")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TrainingPlanPreset.allCases) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(VelaTheme.rhythmInk)
                                    Text(preset.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(VelaTheme.rhythmCanvasRaised)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedPreset == preset ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist, lineWidth: selectedPreset == preset ? 1.5 : 0.75)
                            )
                        }
                        .buttonStyle(.cardPress)
                    }
                }
            }
        }
    }

    private var weeksAndDaysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("课表日程编排 (第 \(currentWeekTab) 周)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                Spacer()

                Button {
                    let currentDays = daysForCurrentWeek()
                    let nextDayNum = (currentDays.map(\.dayNumber).max() ?? 0) + 1
                    let newDay = TrainingDay(
                        id: UUID(),
                        weekNumber: currentWeekTab,
                        dayNumber: min(nextDayNum, 7),
                        title: "自定训练日",
                        description: "添加自定动作或有氧内容",
                        focus: "strength",
                        durationMinutes: 45,
                        intensity: "moderate",
                        isCompleted: false,
                        plannedExercisesJSON: "[]"
                    )
                    days.append(newDay)
                    editingDay = newDay
                } label: {
                    Label("添加训练日", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }

            if weeksCount > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1...weeksCount, id: \.self) { week in
                            Button {
                                currentWeekTab = week
                            } label: {
                                Text("第 \(week) 周")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(currentWeekTab == week ? Color.white : VelaTheme.rhythmInkSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(currentWeekTab == week ? VelaTheme.rhythmDeep : VelaTheme.rhythmCanvasRaised)
                                    )
                                    .overlay(
                                        Capsule().stroke(VelaTheme.rhythmMist, lineWidth: currentWeekTab == week ? 0 : 0.75)
                                    )
                            }
                        }
                    }
                }
            }

            let weekDays = daysForCurrentWeek()
            if weekDays.isEmpty {
                VStack(spacing: 12) {
                    Text("当前周暂无课表日程")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Button {
                        populateCurrentWeekFromWeek1()
                    } label: {
                        Text("复制第 1 周日程至本周")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(VelaTheme.rhythmCanvasRaised)
                .cornerRadius(14)
            } else {
                VStack(spacing: 10) {
                    ForEach(weekDays) { day in
                        dayEditorRow(day)
                    }
                }
            }
        }
    }

    private func dayEditorRow(_ day: TrainingDay) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Day \(day.dayNumber)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)

                    Text(focusName(day.focus))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(focusColor(day.focus))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(focusColor(day.focus).opacity(0.12)))

                    if day.focus != "rest" {
                        Text("\(day.durationMinutes)分钟")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }

                Text(day.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                let exerciseCount = exercisesInDay(day).count
                if exerciseCount > 0 {
                    Text("\(exerciseCount) 个预设动作")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                } else if !day.description.isEmpty {
                    Text(day.description)
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                editingDay = day
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }

            Button {
                deleteDay(day)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.red.opacity(0.7))
            }
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    // MARK: - Helpers
    private func daysForCurrentWeek() -> [TrainingDay] {
        days.filter { $0.weekNumber == currentWeekTab }.sorted(by: { $0.dayNumber < $1.dayNumber })
    }

    private func exercisesInDay(_ day: TrainingDay) -> [WorkoutTemplateExercise] {
        guard let data = day.plannedExercisesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) else {
            return []
        }
        return list
    }

    private func applyPreset(_ preset: TrainingPlanPreset) {
        selectedPreset = preset
        self.title = preset.rawValue
        self.goalDescription = preset.subtitle
        self.weeksCount = preset.weeksCount
        var allDays: [TrainingDay] = []
        for w in 1...preset.weeksCount {
            allDays.append(contentsOf: preset.generateDays(weekNumber: w))
        }
        self.days = allDays
    }

    private func populateCurrentWeekFromWeek1() {
        let week1Days = days.filter { $0.weekNumber == 1 }
        for d in week1Days {
            var clone = d
            clone.id = UUID()
            clone.weekNumber = currentWeekTab
            clone.isCompleted = false
            clone.completedAt = nil
            days.append(clone)
        }
    }

    private func deleteDay(_ day: TrainingDay) {
        withAnimation {
            days.removeAll(where: { $0.id == day.id })
        }
    }

    private func focusName(_ focus: String) -> String {
        switch focus {
        case "strength": return "力量"
        case "cardio": return "有氧"
        case "flexibility": return "柔韧"
        case "rest": return "休息"
        default: return "综合"
        }
    }

    private func focusColor(_ focus: String) -> Color {
        switch focus {
        case "strength": return VelaTheme.strainColor
        case "cardio": return VelaTheme.energyColor
        case "flexibility": return VelaTheme.recoveryColor
        case "rest": return VelaTheme.sleepColor
        default: return VelaTheme.rhythmDeep
        }
    }

    private func savePlan() {
        isSaving = true
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "计划名称不能为空"
            isSaving = false
            return
        }

        do {
            if isActive {
                // Deactivate other plans if this one is active
                let fetchDescriptor = FetchDescriptor<TrainingPlanRecord>()
                let allPlans = try modelContext.fetch(fetchDescriptor)
                for p in allPlans {
                    if p.id != existingPlan?.id {
                        p.isActive = false
                    }
                }
            }

            if let existingPlan {
                existingPlan.title = trimmedTitle
                existingPlan.goalDescription = goalDescription
                existingPlan.weeksCount = weeksCount
                existingPlan.isActive = isActive
                existingPlan.days = days
                existingPlan.updatedAt = Date()
            } else {
                let newRecord = TrainingPlanRecord(
                    id: UUID(),
                    title: trimmedTitle,
                    goalDescription: goalDescription,
                    startDate: startDate,
                    weeksCount: weeksCount,
                    isActive: isActive,
                    days: days,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                modelContext.insert(newRecord)
            }

            try modelContext.save()
            Task { @MainActor in
                await dashboardVM.refresh(modelContext: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            isSaving = false
        }
    }
}

// MARK: - Single Training Day Editor Sheet
struct TrainingDayEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var focus: String
    @State private var durationMinutes: Int
    @State private var intensity: String
    @State private var descriptionText: String
    @State private var exercises: [WorkoutTemplateExercise]
    @State private var dayNumber: Int
    @State private var weekNumber: Int

    let dayId: UUID
    let isCompleted: Bool
    let onSave: (TrainingDay) -> Void

    private let focusOptions = [
        ("strength", "力量训练", "figure.strengthtraining.traditional"),
        ("cardio", "有氧耐力", "figure.run"),
        ("flexibility", "拉伸恢复", "figure.mind.and.body"),
        ("rest", "休息蓄力", "bed.double.fill")
    ]

    private let intensityOptions = ["low", "moderate", "high"]

    init(day: TrainingDay, onSave: @escaping (TrainingDay) -> Void) {
        self.dayId = day.id
        self.isCompleted = day.isCompleted
        self.onSave = onSave

        _title = State(initialValue: day.title)
        _focus = State(initialValue: day.focus)
        _durationMinutes = State(initialValue: day.durationMinutes)
        _intensity = State(initialValue: day.intensity)
        _descriptionText = State(initialValue: day.description)
        _dayNumber = State(initialValue: day.dayNumber)
        _weekNumber = State(initialValue: day.weekNumber)

        if let data = day.plannedExercisesJSON.data(using: .utf8),
           let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) {
            _exercises = State(initialValue: list)
        } else {
            _exercises = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dayBasicInfoSection
                        exercisesListSection
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("编辑第 \(dayNumber) 天课表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveDay()
                        dismiss()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }
        }
    }

    private var dayBasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("课表信息")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("课表标题")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    TextField("例如：推力训练 (胸/肩/三头)", text: $title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .padding(12)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("训练类型")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    HStack(spacing: 8) {
                        ForEach(focusOptions, id: \.0) { key, label, icon in
                            Button {
                                focus = key
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.system(size: 14, weight: .bold))
                                    Text(label)
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(focus == key ? VelaTheme.rhythmDeep : VelaTheme.rhythmCanvas)
                                .foregroundStyle(focus == key ? Color.white : VelaTheme.rhythmInk)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.cardPress)
                        }
                    }
                }

                if focus != "rest" {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("目标时长")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            Stepper("\(durationMinutes) 分钟", value: $durationMinutes, in: 5...180, step: 5)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("建议强度")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Picker("强度", selection: $intensity) {
                            Text("低强度 (恢复/轻度)").tag("low")
                            Text("中等强度 (稳态/基线)").tag("moderate")
                            Text("高强度 (突破/极限)").tag("high")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("训练要点与指导")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    TextField("输入热身建议、心率区间或技术细节", text: $descriptionText)
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .padding(12)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(10)
                }
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    private var exercisesListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("预设动作清单 (\(exercises.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                Spacer()

                Button {
                    exercises.append(WorkoutTemplateExercise(
                        name: "动作 \(exercises.count + 1)",
                        targetSets: 3,
                        targetReps: "8-10",
                        targetRPE: 8.0,
                        restSeconds: 90,
                        notes: nil
                    ))
                } label: {
                    Label("添加动作", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }

            if exercises.isEmpty {
                VStack(spacing: 8) {
                    Text("暂无动作安排")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Text("点击上方「添加动作」为该日定制动作、组数、次数与 RPE")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(VelaTheme.rhythmCanvasRaised)
                .cornerRadius(14)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, _ in
                        exerciseCard(index: index)
                    }
                }
            }
        }
    }

    private func exerciseCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(index + 1).")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmDeep)

                TextField("动作名称", text: $exercises[index].name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                Spacer()

                Button {
                    exercises.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.red.opacity(0.7))
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("目标组数")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Stepper("\(exercises[index].targetSets) 组", value: $exercises[index].targetSets, in: 1...10)
                        .font(.system(size: 12, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("目标次数")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    TextField("8-10", text: $exercises[index].targetReps)
                        .font(.system(size: 12, weight: .bold))
                        .padding(6)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("组间休息")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Stepper("\(exercises[index].restSeconds)s", value: $exercises[index].restSeconds, in: 15...300, step: 15)
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    private func saveDay() {
        let jsonStr: String
        if let data = try? JSONEncoder().encode(exercises), let str = String(data: data, encoding: .utf8) {
            jsonStr = str
        } else {
            jsonStr = "[]"
        }

        let updated = TrainingDay(
            id: dayId,
            weekNumber: weekNumber,
            dayNumber: dayNumber,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "训练日" : title,
            description: descriptionText,
            focus: focus,
            durationMinutes: durationMinutes,
            intensity: intensity,
            isCompleted: isCompleted,
            plannedExercisesJSON: jsonStr
        )
        onSave(updated)
    }
}
