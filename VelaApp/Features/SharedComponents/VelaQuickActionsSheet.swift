import SwiftUI
import SwiftData

// MARK: - PlusActionSheet — Bevel Replica Quick Actions
// 3×3 circle buttons grid × Dual-eye AI Mascot center × Bottom circle cancel button

struct PlusActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 20) {
            // Spacer to replace deleted hint capsule and keep correct layout margin
            Spacer().frame(height: 16)
            
            // 2. 3×3 Grid
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 16
            ) {
                // Row 1
                circleActionButton(icon: "square.and.pencil", label: "描述食物") {
                    VelaAppState.shared.routeToCoach(question: "描述我今天吃的中餐...")
                    dismiss()
                }
                
                circleActionButton(icon: "photo.badge.plus", label: "导入食物") {
                    VelaAppState.shared.scannerType = "library"
                    VelaAppState.shared.triggerFoodScanner = true
                    dismiss()
                }
                
                circleActionButton(icon: "camera.fill", label: "拍摄食物") {
                    VelaAppState.shared.scannerType = "camera"
                    VelaAppState.shared.triggerFoodScanner = true
                    dismiss()
                }
                
                // Row 2
                circleActionButton(icon: "barcode.viewfinder", label: "扫描食物") {
                    VelaAppState.shared.scannerType = "barcode"
                    VelaAppState.shared.triggerFoodScanner = true
                    dismiss()
                }
                
                // Center: Vela AI Mascot (Indigo Sparkles Gradient Circle) - now Coach
                mascotCenterButton(label: "Coach") {
                    VelaAppState.shared.routeToCoach(question: nil)
                    dismiss()
                }
                
                circleActionButton(icon: "magnifyingglass", label: "搜索食物") {
                    VelaAppState.shared.triggerFoodSearch = true
                    dismiss()
                }
                
                // Row 3
                circleActionButton(icon: "wand.and.stars", label: "智能处方") {
                    VelaAppState.shared.routeToCoach(question: "帮我根据今日状态生成一份运动健康处方模版")
                    dismiss()
                }
                
                circleActionButton(icon: "list.bullet.clipboard.fill", label: "查看模版") {
                    VelaAppState.shared.routeToCoach(question: "我有哪些已保存的运动与习惯处方模版？")
                    dismiss()
                }
                
                circleActionButton(icon: "figure.run", label: "记录活动") {
                    VelaAppState.shared.triggerWorkoutLog = true
                    dismiss()
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 3. Circular Cancel Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.white))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
                    .overlay(Circle().stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F5F3F0")) // Warm canvas base
    }

    // MARK: - Standard Circular Action Button
    private func circleActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                    
                    Circle()
                        .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Mascot Sparkles Button
    private func mascotCenterButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#7986CB"), // Indigo
                                    Color(hex: "#42A5F5"), // Sky blue
                                    Color(hex: "#5C6BC0")  // Deep indigo
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .shadow(color: Color(hex: "#5C6BC0").opacity(0.3), radius: 8, y: 4)
                    
                    AlpacaView()
                        .offset(y: -1)
                }
                
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alpaca Vector Graphic (羊驼简笔画)

struct AlpacaShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Body back & start
        path.move(to: CGPoint(x: w * 0.40, y: h * 0.70))
        
        // Long neck up
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.35))
        
        // Left Ear
        path.addQuadCurve(to: CGPoint(x: w * 0.35, y: h * 0.15), control: CGPoint(x: w * 0.33, y: h * 0.25))
        path.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.30), control: CGPoint(x: w * 0.42, y: h * 0.20))
        
        // Right Ear
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.12), control: CGPoint(x: w * 0.46, y: h * 0.22))
        path.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.32), control: CGPoint(x: w * 0.54, y: h * 0.20))
        
        // Head / Forehead
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.35))
        
        // Muzzle / Nose
        path.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.40), control: CGPoint(x: w * 0.71, y: h * 0.37))
        // Mouth / Chin
        path.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.45), control: CGPoint(x: w * 0.68, y: h * 0.45))
        
        // Neck front
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.70))
        
        // Fluffy chest curve
        path.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.85), control: CGPoint(x: w * 0.64, y: h * 0.80))
        // Fluffy bottom curve
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.85), control: CGPoint(x: w * 0.48, y: h * 0.90))
        // Back curve
        path.addQuadCurve(to: CGPoint(x: w * 0.40, y: h * 0.70), control: CGPoint(x: w * 0.26, y: h * 0.78))
        
        return path
    }
}

struct AlpacaView: View {
    var strokeColor: Color = .white
    var size: CGFloat = 28
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            AlpacaShape()
                .stroke(strokeColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            
            // Eye
            Circle()
                .fill(strokeColor)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.18, y: -size * 0.14)
        }
        .frame(width: size, height: size)
    }
}

// ==========================================
// MARK: - ACTION SUBVIEWS IMPLEMENTATIONS
// ==========================================

// 1. Workout Activity Logger View (Saves to SwiftData to update heatmaps and strain)
struct WorkoutLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedSport = "跑步"
    @State private var durationMinutes: Double = 30.0
    @State private var caloriesBurned: Double = 250.0
    @State private var exertionScore: Double = 5.0
    
    let sports = ["跑步", "力量训练", "骑行", "游泳", "瑜伽", "HIIT", "步行"]
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(hex: "#E8E4DD"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录运动活动")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Sport Type Picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("运动类型")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                        
                        Picker("运动类型", selection: $selectedSport) {
                            ForEach(sports, id: \.self) { sport in
                                Text(sport).tag(sport)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 20)
                    
                    // Duration Slider
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("时长")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Spacer()
                            Text("\(Int(durationMinutes)) 分钟")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                        }
                        
                        Slider(value: $durationMinutes, in: 5...120, step: 5)
                            .tint(Color(hex: "#C56B4A"))
                    }
                    .padding(.horizontal, 20)
                    
                    // Active Calories
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("活跃热量消耗")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Spacer()
                            Text("\(Int(caloriesBurned)) kcal")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                        }
                        
                        Slider(value: $caloriesBurned, in: 50...1000, step: 25)
                            .tint(Color(hex: "#C56B4A"))
                    }
                    .padding(.horizontal, 20)
                    
                    // Exertion Score
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("耗力感官评分 (RPE)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Spacer()
                            Text("\(Int(exertionScore)) / 10")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                        }
                        
                        Slider(value: $exertionScore, in: 1...10, step: 1)
                            .tint(Color(hex: "#C56B4A"))
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button {
                        saveWorkoutToSwiftData()
                        dismiss()
                    } label: {
                        Text("保存活动")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#C56B4A")))
                            .shadow(color: Color(hex: "#C56B4A").opacity(0.2), radius: 6, y: 3)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
    }
    
    private func saveWorkoutToSwiftData() {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>()
        do {
            let all = try modelContext.fetch(descriptor)
            if let todaySummary = all.first(where: { calendar.isDate($0.date, inSameDayAs: targetDay) }) {
                todaySummary.workoutCount = (todaySummary.workoutCount ?? 0) + 1
                todaySummary.workoutDuration = (todaySummary.workoutDuration ?? 0) + durationMinutes
                todaySummary.activeCalories = (todaySummary.activeCalories ?? 0) + caloriesBurned
                todaySummary.strainScore = min(100.0, max(todaySummary.strainScore ?? 0.0, exertionScore * 10.0))
                todaySummary.updatedAt = Date()
            } else {
                let newSummary = DailyHealthSummaryRecord(
                    dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: targetDay, calendar: calendar),
                    date: targetDay,
                    strainScore: exertionScore * 10.0,
                    activeCalories: caloriesBurned,
                    workoutCount: 1,
                    workoutDuration: durationMinutes
                )
                modelContext.insert(newSummary)
            }
            try modelContext.save()
        } catch {
            print("Failed to save workout summary: \(error)")
        }
    }
}

// 2. Food Search Sheet View (Adds food item directly to nutrition)
struct FoodSearchSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var searchText = ""
    
    let popularFoods = [
        ("牛油果吐司", 280, 9, 32, 12),
        ("煎鸡胸肉沙拉", 350, 32, 12, 15),
        ("蛋白粉原味奶昔", 180, 25, 8, 2),
        ("水煮蛋 (2个)", 140, 12, 1, 10),
        ("黑咖啡 (Americano)", 5, 0, 1, 0),
        ("美式香煎牛排", 450, 38, 0, 32),
        ("一小碗白米饭", 200, 4, 44, 0),
        ("混合坚果一小把", 160, 5, 6, 14)
    ]
    
    var filteredFoods: [(String, Int, Int, Int, Int)] {
        if searchText.isEmpty {
            return popularFoods
        } else {
            return popularFoods.filter { $0.0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(hex: "#E8E4DD"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("搜索常见食物")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(hex: "#8E8A80"))
                TextField("搜索膳食...", text: $searchText)
                    .font(.system(size: 15))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(filteredFoods, id: \.0) { name, cal, prot, carb, fat in
                        Button {
                            logFoodItem(name: name, cal: cal, prot: prot, carb: carb, fat: fat)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color(hex: "#1A1917"))
                                    Text("P: \(prot)g · C: \(carb)g · F: \(fat)g")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "#8E8A80"))
                                }
                                
                                Spacer()
                                
                                Text("\(cal) kcal")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#C56B4A"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color(hex: "#FFF3E0")))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
    }
    
    private func logFoodItem(name: String, cal: Int, prot: Int, carb: Int, fat: Int) {
        let item = FoodLogItem(name: name, portion: "1份", calories: cal)
        let record = FoodLogRecord(
            mealName: "快捷录入",
            foods: [item],
            totalCalories: cal,
            proteinGrams: prot,
            carbsGrams: carb,
            fatGrams: fat,
            fiberGrams: 2,
            healthScore: "A",
            source: .manual
        )
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save logged food item: \(error)")
        }
    }
}

// 3. Food Camera/Library Scanner Simulator View
struct FoodScannerSimulatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let type: String
    
    @State private var scanProgress = 0.0
    @State private var isScanning = true
    @State private var scanResultName = "香煎三明治与煎蛋"
    @State private var scanResultCal = 340
    @State private var isCompleted = false
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E8E4DD"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text(type == "camera" ? "智能拍照识别" : (type == "library" ? "相册导入解析" : "条形码扫描"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            if isScanning {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#E8E4DD"), lineWidth: 2)
                            .frame(width: 140, height: 140)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(scanProgress))
                            .stroke(Color(hex: "#C56B4A"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: type == "barcode" ? "barcode.viewfinder" : "camera.metering.matrix")
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: "#C56B4A"))
                    }
                    .onAppear {
                        startScanProgress()
                    }
                    
                    Text("AI 图像处理中，正在提取宏量元素数据...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
                .padding(.vertical, 40)
            } else {
                // Scan Complete!
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#34C759").opacity(0.1))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color(hex: "#34C759"))
                    }
                    
                    VStack(spacing: 6) {
                        Text("解析识别成功！")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text("发现 1 项食物: \(scanResultName)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(scanResultCal)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                            Text("卡路里")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                        
                        VStack {
                            Text("18g")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#1A1917"))
                            Text("蛋白质")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                        
                        VStack {
                            Text("32g")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#1A1917"))
                            Text("碳水")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    
                    Button {
                        saveScannedFoodToSwiftData()
                        dismiss()
                    } label: {
                        Text("确认并记录")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#34C759")))
                            .shadow(color: Color(hex: "#34C759").opacity(0.2), radius: 6, y: 3)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
    }
    
    private func startScanProgress() {
        Task { @MainActor in
            scanProgress = 0.0
            isScanning = true
            for _ in 0..<25 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                scanProgress += 0.04
            }
            withAnimation {
                isScanning = false
            }
        }
    }
    
    private func saveScannedFoodToSwiftData() {
        let item = FoodLogItem(name: scanResultName, portion: "1份", calories: scanResultCal)
        let record = FoodLogRecord(
            mealName: "扫描导入",
            foods: [item],
            totalCalories: scanResultCal,
            proteinGrams: 18,
            carbsGrams: 32,
            fatGrams: 12,
            fiberGrams: 2,
            healthScore: "B+",
            source: .photoAnalysis
        )
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save scanned food: \(error)")
        }
    }
}
