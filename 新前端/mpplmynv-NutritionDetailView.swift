import SwiftUI
import SwiftData
import Charts

struct NutritionDetailView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodLogRecord.createdAt, order: .reverse) private var foodLogs: [FoodLogRecord]
    @Query(sort: \BiomarkerRecord.date, order: .reverse) private var biomarkers: [BiomarkerRecord]

    @State private var waterIntakeOffset = 0 // Temp offset to reflect logging immediately
    
    private var language: AppLanguage {
        AppLanguage.stored
    }

    private var todayFoodLogs: [FoodLogRecord] {
        let calendar = Calendar.current
        return foodLogs.filter { calendar.isDate($0.createdAt, inSameDayAs: dashboardVM.selectedDate) }
    }

    private var todayCalories: Int {
        todayFoodLogs.reduce(0) { $0 + $1.totalCalories }
    }

    private var todayProtein: Int {
        todayFoodLogs.reduce(0) { $0 + $1.proteinGrams }
    }

    private var todayCarbs: Int {
        todayFoodLogs.reduce(0) { $0 + $1.carbsGrams }
    }

    private var todayFat: Int {
        todayFoodLogs.reduce(0) { $0 + $1.fatGrams }
    }

    private var todayFiber: Int {
        todayFoodLogs.reduce(0) { $0 + $1.fiberGrams }
    }

    private var todayWaterLogged: Int {
        let calendar = Calendar.current
        let waterRecords = biomarkers.filter {
            $0.name == "Water" && calendar.isDate($0.date, inSameDayAs: dashboardVM.selectedDate)
        }
        return Int(waterRecords.reduce(0.0) { $0 + $1.value }) + waterIntakeOffset
    }

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("Nutrition", "营养"))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(dashboardVM.isToday ? L10n.t("Today", "今日") : dashboardVM.selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                        Spacer()
                        
                        Button {
                            VelaAppState.shared.routeToCoach(question: L10n.t(
                                "Analyze my nutrition logs today (total calories, protein, carbs, fat, fiber, water) against recovery and strain. Suggest one dietary improvement for tomorrow.",
                                "请结合我的恢复和耗力，分析我今天的营养记录（总热量、蛋白质、碳水、脂肪、纤维、饮水量），并为明天给出一个饮食改善建议。"
                            ))
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(VelaTheme.primaryText)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(VelaTheme.surface))
                                .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)

                    DateNavigationBar()

                    // Calorie Budget Hero
                    calorieHeroCard

                    // Macronutrients Breakdown Progress
                    macronutrientCard

                    // Water intake tracking
                    waterTrackerCard

                    // Food logged list
                    mealHistorySection

                    // AI advice card
                    decisionCard
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            waterIntakeOffset = 0
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            waterIntakeOffset = 0
        }
    }

    private var calorieHeroCard: some View {
        let activeBurn = dashboardVM.dashboard.strain.metrics["active_energy_raw"] ?? 350.0
        let targetCal = 2200
        let remaining = targetCal - todayCalories + Int(activeBurn)

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.05), lineWidth: 10)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: min(1.0, CGFloat(todayCalories) / CGFloat(targetCal)))
                    .stroke(
                        VelaTheme.energy.gradient,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(todayCalories)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Intake", "摄入"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Calorie Budget", "卡路里预算"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)

                HStack(spacing: 14) {
                    calorieMiniPill(title: L10n.t("Goal", "目标"), val: "\(targetCal)", color: VelaTheme.secondaryText)
                    calorieMiniPill(title: L10n.t("Active", "活动消耗"), val: "\(Int(activeBurn))", color: VelaTheme.strain)
                    calorieMiniPill(title: L10n.t("Remaining", "净剩"), val: "\(remaining)", color: VelaTheme.recovery)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.energy)
    }

    private func calorieMiniPill(title: String, val: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(val)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private var macronutrientCard: some View {
        let pGoal = 140 // protein goal grams
        let cGoal = 220 // carbs goal grams
        let fGoal = 70  // fat goal grams

        return VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Macronutrients", "宏量营养素"), systemImage: "chart.pie.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            VStack(spacing: 12) {
                macroProgressBar(label: L10n.t("Protein", "蛋白质"), value: todayProtein, goal: pGoal, tint: VelaTheme.recovery)
                macroProgressBar(label: L10n.t("Carbohydrates", "碳水化合物"), value: todayCarbs, goal: cGoal, tint: VelaTheme.sleep)
                macroProgressBar(label: L10n.t("Fat", "脂肪"), value: todayFat, goal: fGoal, tint: VelaTheme.strain)
                macroProgressBar(label: L10n.t("Fiber", "膳食纤维"), value: todayFiber, goal: 30, tint: VelaTheme.accent)
            }
        }
        .cardSurface()
    }

    private func macroProgressBar(label: String, value: Int, goal: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text("\(value)g / \(goal)g")
                    .font(.caption.bold())
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 7)
                    
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(4, min(geo.size.width, CGFloat(Double(value) / Double(goal)) * geo.size.width)), height: 7)
                }
            }
            .frame(height: 7)
        }
    }

    private var waterTrackerCard: some View {
        let goal = 2000 // ml water goal
        let current = todayWaterLogged
        let ratio = CGFloat(current) / CGFloat(goal)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Hydration", "饮水追踪"), systemImage: "drop.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text("\(current) mL / \(goal) mL")
                    .font(.subheadline.bold())
                    .foregroundStyle(VelaTheme.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VelaTheme.accent.opacity(0.08))
                        .frame(height: 12)

                    Capsule()
                        .fill(VelaTheme.accent.gradient)
                        .frame(width: max(8, min(geo.size.width, ratio * geo.size.width)), height: 12)
                        .shadow(color: VelaTheme.accent.opacity(0.25), radius: 3)
                }
            }
            .frame(height: 12)
            .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button {
                    logWater(amount: 250)
                } label: {
                    Label("+250ml", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(VelaTheme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    logWater(amount: 500)
                } label: {
                    Label("+500ml", systemImage: "plus.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(VelaTheme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .cardSurface()
    }

    private var mealHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("Logged Meals", "今日已记餐饮"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            if todayFoodLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(L10n.t("No meals logged today.", "今天还没有记录饮食。"))
                        .font(.subheadline.bold())
                        .foregroundStyle(VelaTheme.secondaryText)
                    Text(L10n.t("Tap the central '+' and take a food photo or log to see visual macros.", "点击中央的 “+” 拍照或记录饮食即可获得精细的 AI 宏量分析！"))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(VelaTheme.surface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(todayFoodLogs) { log in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(log.mealName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(VelaTheme.primaryText)
                                    Text(log.createdAt, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(VelaTheme.secondaryText)
                                }
                                Spacer()
                                
                                Text("\(log.totalCalories) kcal")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(VelaTheme.energy)
                                
                                if !log.healthScore.isEmpty {
                                    Text(log.healthScore)
                                        .font(.caption2.bold())
                                        .foregroundStyle(VelaTheme.recovery)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(VelaTheme.recovery.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }

                            if !log.foods.isEmpty {
                                Text(log.foods.map { "\($0.name) (\($0.portion))" }.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.primaryText)
                                    .lineLimit(2)
                            }

                            HStack(spacing: 6) {
                                compactMacroChip(label: "P", val: log.proteinGrams, tint: VelaTheme.recovery)
                                compactMacroChip(label: "C", val: log.carbsGrams, tint: VelaTheme.sleep)
                                compactMacroChip(label: "F", val: log.fatGrams, tint: VelaTheme.strain)
                                if log.fiberGrams > 0 {
                                    compactMacroChip(label: "Fiber", val: log.fiberGrams, tint: VelaTheme.accent)
                                }
                            }
                        }
                        .padding(14)
                        .background(VelaTheme.surface)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    private func compactMacroChip(label: String, val: Int, tint: Color) -> some View {
        Text("\(label) \(val)g")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }

    private var decisionCard: some View {
        MetricCoachCard(
            dashboard: dashboardVM.dashboard,
            focus: CoachContextFocus(
                title: L10n.t("Nutrition", "营养"),
                systemContext: L10n.t(
                    "Analyze nutrition targets, calorie intake, protein balance, carbohydrates distribution, hydration state, and meal frequency.",
                    "分析卡路里预算、卡路里开销、蛋白质补充、碳水化合物配比、今日饮水及用餐频率等营养细节。"
                )
            ),
            suggestedQuestion: L10n.t(
                "Analyze my nutrition logs today (total calories, protein, carbs, fat, fiber, water) against recovery and strain. Suggest one dietary improvement for tomorrow.",
                "请结合我的恢复和耗力，分析我今天的营养记录（总热量、蛋白质、碳水、脂肪、纤维、饮水量），并为明天给出一个饮食改善建议。"
            )
        )
    }

    private func logWater(amount: Double) {
        waterIntakeOffset += Int(amount)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let record = BiomarkerRecord(
            name: "Water",
            value: amount,
            unit: "mL",
            date: dashboardVM.selectedDate,
            isOptimal: true,
            referenceMin: 0.0,
            referenceMax: 3000.0
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}
