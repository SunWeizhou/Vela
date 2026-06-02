import SwiftUI
import SwiftData
import UIKit
@preconcurrency import AVFoundation

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
                    deferAction(.coach("描述我今天吃的中餐..."))
                }
                
                circleActionButton(icon: "photo.badge.plus", label: "导入食物") {
                    deferAction(.foodScanner("library"))
                }
                
                circleActionButton(icon: "camera.fill", label: "拍摄食物") {
                    deferAction(.foodScanner("camera"))
                }
                
                // Row 2
                circleActionButton(icon: "barcode.viewfinder", label: "扫描食物") {
                    deferAction(.foodScanner("barcode"))
                }
                
                // Center: Vela AI Mascot (Indigo Sparkles Gradient Circle) - now Coach
                mascotCenterButton(label: "Coach") {
                    deferAction(.coach(nil))
                }
                
                circleActionButton(icon: "book.pages.fill", label: "手记") {
                    deferAction(.journal)
                }
                
                // Row 3
                circleActionButton(icon: "wand.and.stars", label: "智能处方") {
                    deferAction(.coach("帮我根据今日状态生成一份运动健康处方模版"))
                }
                
                circleActionButton(icon: "list.bullet.clipboard.fill", label: "查看模版") {
                    deferAction(.coach("我有哪些已保存的运动与习惯处方模版？"))
                }
                
                circleActionButton(icon: "figure.run", label: "记录活动") {
                    deferAction(.workoutLog)
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

    private func deferAction(_ action: VelaAppState.DeferredQuickAction) {
        VelaAppState.shared.deferQuickActionUntilSheetDismisses(action)
        dismiss()
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
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
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
        let end = Date()
        let start = end.addingTimeInterval(-durationMinutes * 60)
        
        let workoutEvent = WorkoutEventRecord(
            source: "manual",
            startedAt: start,
            endedAt: end,
            activityType: selectedSport,
            energyKilocalories: caloriesBurned,
            rpe: exertionScore
        )
        
        modelContext.insert(workoutEvent)
        
        do {
            try modelContext.save()
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
        } catch {
            print("Failed to save manual workout event: \(error)")
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

// 3. Food Camera/Library Scanner
struct FoodScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let type: String

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isAnalyzing = false
    @State private var result: FoodAnalysisResult?
    @State private var errorMessage: String?
    @State private var scannedBarcode: String?
    @State private var barcodeScannerID = UUID()
    
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
            
            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(Color(hex: "#C56B4A"))
                    Text(type == "barcode" ? "正在查询食品条码..." : "正在用 Kimi 视觉模型分析餐食...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
                .padding(.vertical, 40)
            } else if let result {
                resultContent(result)
            } else if type == "barcode" {
                barcodeScannerContent
            } else {
                VStack(spacing: 16) {
                    Image(systemName: type == "camera" ? "camera.fill" : "photo.on.rectangle")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(hex: "#C56B4A"))

                    Text("使用真实照片分析营养")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))

                    Text("图片会在你确认后发送给 Kimi 视觉模型。需要先在设置中添加 Kimi API Key。")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#FF3B30"))
                    .padding(.horizontal, 20)
            }

            if type != "barcode", result == nil, !isAnalyzing {
                Button(type == "camera" ? "打开相机" : "从相册选择") {
                    openImagePicker()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#C56B4A")))
                .padding(.horizontal, 20)
                .buttonStyle(.plain)
            }
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType, selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let newImage else { return }
            Task {
                await analyze(image: newImage)
            }
        }
    }

    private var barcodeScannerContent: some View {
        VStack(spacing: 14) {
            BarcodeScannerView(
                onCode: lookupBarcode,
                onError: { errorMessage = $0 }
            )
            .id(barcodeScannerID)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
            }
            .padding(.horizontal, 20)

            Text(scannedBarcode.map { "已识别条码：\($0)" } ?? "将包装条码放入取景框内")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#8E8A80"))

            Text("营养数据来自 Open Food Facts。记录前请核对包装标示。")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "#8E8A80"))
                .padding(.horizontal, 20)

            if scannedBarcode != nil {
                Button("重新扫描") {
                    scannedBarcode = nil
                    errorMessage = nil
                    barcodeScannerID = UUID()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#C56B4A"))
            }
        }
    }

    private func resultContent(_ result: FoodAnalysisResult) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(hex: "#34C759"))

            Text("解析完成，请确认后记录")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1917"))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.foods.enumerated()), id: \.offset) { _, food in
                    Text("\(food.name) · \(food.portion) · \(food.calories) kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                Divider()
                Text("总计 \(result.totalCalories) kcal · 蛋白质 \(result.macros.protein)g · 碳水 \(result.macros.carbs)g · 脂肪 \(result.macros.fat)g")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
            .padding(.horizontal, 20)

            Button("确认并记录") {
                save(result: result)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#34C759")))
            .padding(.horizontal, 20)
            .buttonStyle(.plain)

            Button("重新选择") {
                self.result = nil
                selectedImage = nil
                openImagePicker()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color(hex: "#C56B4A"))
        }
    }

    private var imagePickerSourceType: UIImagePickerController.SourceType {
        type == "camera" ? .camera : .photoLibrary
    }

    private func openImagePicker() {
        guard UIImagePickerController.isSourceTypeAvailable(imagePickerSourceType) else {
            errorMessage = type == "camera" ? "当前设备没有可用相机。" : "当前设备无法访问相册。"
            return
        }
        errorMessage = nil
        showImagePicker = true
    }

    @MainActor
    private func analyze(image: UIImage) async {
        guard let apiKey = try? KeychainService.shared.read(account: FoodPhotoAnalyzer.keychainAccount),
              !apiKey.isEmpty else {
            errorMessage = "请先在设置中添加 Kimi API Key。"
            return
        }

        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        do {
            result = try await FoodPhotoAnalyzer(apiKey: apiKey).analyzeFoodPhoto(image)
        } catch {
            errorMessage = "餐食分析失败：\(error.localizedDescription)"
        }
    }

    private func save(result: FoodAnalysisResult) {
        let source: FoodLogSource = type == "barcode" ? .barcodeLookup : .photoAnalysis
        let journalPrefix = type == "barcode" ? "[Barcode Lookup]" : "[Photo Analysis]"
        let foodLog = FoodLogRecord(
            analysis: result,
            mealName: defaultMealName(for: Date()),
            source: source
        )
        modelContext.insert(foodLog)
        modelContext.insert(
            JournalEntryRecord(
                createdAt: Date(),
                tags: ["food", "meal"],
                note: "\(journalPrefix) \(result.plainTextSummary())",
                value: Double(result.totalCalories),
                unit: "kcal"
            )
        )

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "营养记录保存失败，请重试。"
        }
    }

    private func defaultMealName(for date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<11: return "Breakfast"
        case 11..<16: return "Lunch"
        case 16..<22: return "Dinner"
        default: return "Snack"
        }
    }

    private func lookupBarcode(_ barcode: String) {
        guard scannedBarcode == nil else { return }
        scannedBarcode = barcode
        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                result = try await BarcodeFoodLookupService().lookup(barcode: barcode)
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

// MARK: - Barcode Food Lookup

struct BarcodeFoodLookupService: Sendable {
    static let endpoint = URL(string: "https://world.openfoodfacts.org/api/v2/product")!

    func lookup(barcode: String) async throws -> FoodAnalysisResult {
        let normalized = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw BarcodeFoodLookupError.invalidBarcode
        }

        let url = Self.endpoint
            .appendingPathComponent(normalized)
            .appendingPathExtension("json")
            .appending(queryItems: [
                URLQueryItem(
                    name: "fields",
                    value: "code,product_name,product_name_zh,serving_size,nutrition_grades,nutriments"
                )
            ])
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Vela-iOS/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BarcodeFoodLookupError.requestFailed
        }
        return try Self.decodeProduct(data: data, barcode: normalized)
    }

    static func decodeProduct(data: Data, barcode: String) throws -> FoodAnalysisResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["status"] as? NSNumber)?.intValue == 1,
              let product = root["product"] as? [String: Any] else {
            throw BarcodeFoodLookupError.productNotFound
        }

        let localizedName = (product["product_name_zh"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name = [localizedName, fallbackName].compactMap({ $0 }).first(where: { !$0.isEmpty }) else {
            throw BarcodeFoodLookupError.productNotFound
        }

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]
        let usesServingValues = number(in: nutriments, key: "energy-kcal_serving") != nil
        let suffix = usesServingValues ? "_serving" : "_100g"
        let portion = usesServingValues
            ? ((product["serving_size"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "1份"
            : "100g"
        let calories = roundedInt(number(in: nutriments, key: "energy-kcal\(suffix)"))
        let protein = roundedInt(number(in: nutriments, key: "proteins\(suffix)"))
        let carbs = roundedInt(number(in: nutriments, key: "carbohydrates\(suffix)"))
        let fat = roundedInt(number(in: nutriments, key: "fat\(suffix)"))
        let fiber = roundedInt(number(in: nutriments, key: "fiber\(suffix)"))
        let grade = (product["nutrition_grades"] as? String)?.lowercased()

        return FoodAnalysisResult(
            foods: [IdentifiedFood(name: name, portion: portion, calories: calories)],
            totalCalories: calories,
            macros: MacroBreakdown(protein: protein, carbs: carbs, fat: fat, fiber: fiber),
            healthScore: healthScore(for: grade),
            suggestions: ["营养数据来自 Open Food Facts，请核对包装标示。"],
            rawAnalysis: "Open Food Facts barcode lookup: \(barcode)"
        )
    }

    private static func number(in values: [String: Any], key: String) -> Double? {
        (values[key] as? NSNumber)?.doubleValue
    }

    private static func roundedInt(_ value: Double?) -> Int {
        Int((value ?? 0).rounded())
    }

    private static func healthScore(for nutritionGrade: String?) -> String {
        switch nutritionGrade {
        case "a", "b": return "good"
        case "d", "e": return "needs_improvement"
        default: return "moderate"
        }
    }
}

enum BarcodeFoodLookupError: LocalizedError {
    case invalidBarcode
    case requestFailed
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "未识别到有效条码，请重新扫描。"
        case .requestFailed:
            return "食品条码查询失败，请检查网络后重试。"
        case .productNotFound:
            return "Open Food Facts 暂无该食品，请使用拍照或搜索录入。"
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        BarcodeScannerViewController(onCode: onCode, onError: onError)
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: BarcodeScannerViewController, coordinator: Void) {
        uiViewController.stopScanning()
    }
}

final class BarcodeScannerViewController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.sunweizhou.Vela.barcode-scanner")
    private let onCode: (String) -> Void
    private let onError: (String) -> Void
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitCode = false
    private var isConfigured = false

    init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onError = onError
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestCameraAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func stopScanning() {
        let captureSession = captureSession
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func requestCameraAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureAndStart() : self.onError("未获得相机权限，请在系统设置中允许 Vela 使用相机。")
                }
            }
        case .denied, .restricted:
            onError("未获得相机权限，请在系统设置中允许 Vela 使用相机。")
        @unknown default:
            onError("当前设备无法使用相机扫描条码。")
        }
    }

    private func configureAndStart() {
        if !isConfigured {
            guard let camera = AVCaptureDevice.default(for: .video) else {
                onError("当前设备没有可用相机。")
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                let output = AVCaptureMetadataOutput()
                guard captureSession.canAddInput(input), captureSession.canAddOutput(output) else {
                    onError("当前设备无法启动条码扫描。")
                    return
                }
                captureSession.addInput(input)
                captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]

                let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)
                self.previewLayer = previewLayer
                isConfigured = true
            } catch {
                onError("当前设备无法启动相机：\(error.localizedDescription)")
                return
            }
        }

        let captureSession = captureSession
        sessionQueue.async {
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmitCode,
              let code = metadataObjects
                .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
                .compactMap(\.stringValue)
                .first else { return }
        didEmitCode = true
        stopScanning()
        onCode(code)
    }
}
