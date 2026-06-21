import SwiftUI
import SwiftData
import UIKit

struct BiologyView: View {
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BiomarkerRecord.date, order: .reverse) private var biomarkers: [BiomarkerRecord]
    
    @State private var showLogSheet = false
    @State private var hoverFactorId: UUID? = nil
    
    private var language: AppLanguage {
        AppLanguage.stored
    }

    private var chronologicalAge: Int? {
        WikiFileService.getAgeFromWiki() ?? dashboardVM.dashboard.extendedMetrics.age
    }

    private var hasHealthAgeInput: Bool {
        let dashboard = dashboardVM.dashboard
        return dashboard.recoveryMetrics.restingHeartRate != nil
            || dashboard.bodyMetrics.vo2Max != nil
            || dashboard.sleepSummary.totalSleepMinutes > 0
            || dashboard.sleepScore.metrics["sleep_efficiency"] != nil
            || dashboard.strain.metrics["steps_raw"] != nil
            || !biomarkers.isEmpty
    }
    
    // Calculated Result
    private var bioAgeResult: BiologicalAgeResult {
        let chronologicalAge = Double(chronologicalAge ?? 0)
        let restingHR = dashboardVM.dashboard.recoveryMetrics.restingHeartRate
        let vo2Max = dashboardVM.dashboard.bodyMetrics.vo2Max
        let sleepMinutes = dashboardVM.dashboard.sleepSummary.totalSleepMinutes
        let sleepHours = sleepMinutes > 0 ? Double(sleepMinutes) / 60.0 : nil
        let steps = dashboardVM.dashboard.strain.metrics["steps_raw"]
        let sleepEfficiency = dashboardVM.dashboard.sleepScore.metrics["sleep_efficiency"].map { $0 / 100 }
        
        let input = BiologicalAgeInput(
            chronologicalAge: chronologicalAge,
            restingHR: restingHR,
            vo2Max: vo2Max,
            sleepHours: sleepHours,
            sleepEfficiency: sleepEfficiency,
            steps: steps,
            biomarkers: Array(biomarkers)
        )
        
        return BiologicalAgeEngine().calculate(input: input)
    }

    // MARK: - Biology Title Header
    private var biologyHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(hasHealthAgeInput && bioAgeResult.isPhenoAge
                    ? L10n.t("Biological Age Estimate", "生物年龄估算")
                    : L10n.t("Health Signal Reference", "健康信号参考")
                )
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                Text(L10n.t("BIOLOGY DASHBOARD", "生物特征仪表盘"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                    .tracking(0.8)
            }
            Spacer()
            
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                showLogSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(VelaTheme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if chronologicalAge == nil {
                    profileSetupCard
                } else if !hasHealthAgeInput {
                    healthSignalSetupCard
                } else {
                    // Arc Gauge Hero Card
                    bioAgeArcCard
                    
                    // Stats Breakdown Grid
                    statsGrid
                    
                    // Wearables and Biomarkers Sections
                    VStack(alignment: .leading, spacing: 16) {
                        SectionLabel(title: L10n.t("Wearable Physiology", "生理可穿戴指标"), icon: "appletwatch")
                        wearableFactorsSection
                        
                        HStack {
                            SectionLabel(title: L10n.t("Lab Blood Biomarkers", "血检生化指标"), icon: "drop.fill")
                            Spacer()
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                showLogSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text(L10n.t("Add Lab Results", "录入血检"))
                                }
                                .font(.caption.bold())
                                .foregroundStyle(VelaTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(VelaTheme.accent.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 8)
                        
                        biomarkersSection
                    }
                    .padding(.horizontal, VelaTheme.screenPadding)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                biologyHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                
                Divider()
                    .opacity(0.4)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .sheet(isPresented: $showLogSheet) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Subviews

    private var profileSetupCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(VelaTheme.accent)
            Text(L10n.t("Set up your profile first", "请先完成个人档案初始设置"))
                .font(.headline)
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t(
                "Biological age needs your real chronological age. Vela reads it from Apple Health or your personal Wiki profile.",
                "生物年龄需要你的真实年龄。Vela 会优先读取个人 Wiki 档案，也可以读取 Apple 健康中的年龄。"
            ))
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(VelaTheme.secondaryText)
            NavigationLink(destination: WikiProfileView()) {
                Text(L10n.t("Open personal Wiki", "打开个人 Wiki 档案"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(VelaTheme.accent))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard).fill(VelaTheme.surface))
        .padding(.horizontal, VelaTheme.screenPadding)
    }

    private var healthSignalSetupCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 34))
                .foregroundStyle(VelaTheme.accent)
            Text("健康信号尚未形成")
                .font(.headline)
                .foregroundStyle(VelaTheme.primaryText)
            Text("同步至少一项静息心率、睡眠、活动、最大摄氧量或化验记录后，才会显示健康信号参考。完整 PhenoAge 化验组合齐全后才生成生物年龄估算。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard).fill(VelaTheme.surface))
        .padding(.horizontal, VelaTheme.screenPadding)
    }
    
    private var bioAgeArcCard: some View {
        let result = bioAgeResult
        let chronologicalAge = Double(chronologicalAge ?? 0)
        let diff = chronologicalAge - result.biologicalAge
        let isPositive = result.isPhenoAge
            ? result.biologicalAge <= chronologicalAge
            : result.healthAgeTrend != "worsening"
        
        return VStack(spacing: 20) {
            ZStack {
                // Glow Backdrop
                Circle()
                    .fill(isPositive ? VelaTheme.recovery.opacity(0.08) : VelaTheme.stress.opacity(0.08))
                    .frame(width: 170, height: 170)
                    .blur(radius: 20)
                
                // 270 degree Gauge Arc
                Circle()
                    .trim(from: 0.0, to: 0.75)
                    .stroke(
                        Color.black.opacity(0.05),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(135))
                
                // Value Arc
                Circle()
                    .trim(from: 0.0, to: 0.75 * CGFloat(result.overallScore / 100))
                    .stroke(
                        LinearGradient(
                            colors: isPositive
                                ? [VelaTheme.accent, VelaTheme.recovery] 
                                : [VelaTheme.energy, VelaTheme.stress],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(135))
                
                // End Dot Pointer with Neon Glow
                let progressAngle = 135.0 + (result.overallScore / 100.0) * 270.0
                let radius = 170.0 / 2.0
                Circle()
                    .fill(isPositive ? VelaTheme.recovery : VelaTheme.stress)
                    .frame(width: 14, height: 14)
                    .shadow(color: isPositive ? VelaTheme.recovery : VelaTheme.stress, radius: 6)
                    .offset(
                        x: cos(CGFloat(progressAngle * .pi / 180.0)) * radius,
                        y: sin(CGFloat(progressAngle * .pi / 180.0)) * radius
                    )
                
                // Center Data Display
                VStack(spacing: 2) {
                    if result.isPhenoAge {
                        Text(String(format: "%.1f", result.biologicalAge))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                            .monospacedDigit()

                        Text(L10n.t("Years Old", "岁 (生物年龄)"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.mutedText)
                            .tracking(1)

                        HStack(spacing: 4) {
                            Image(systemName: isPositive ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.forward.and.arrow.down.backward")
                            Text(String(format: "%.1f", chronologicalAge))
                                .bold()
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .padding(.top, 4)
                    } else {
                        Text(result.healthAgeTrendLabel)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)

                        Text(L10n.t("Health Signal Reference", "健康信号参考"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.mutedText)
                            .tracking(1)
                    }
                }
            }
            .frame(width: 200, height: 200)
            
            // Age Comparison Banner
            HStack(spacing: 8) {
                Image(systemName: isPositive ? "leaf.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isPositive ? VelaTheme.recovery : VelaTheme.stress)
                
                Text(result.isPhenoAge
                    ? (diff >= 0
                        ? L10n.t(String(format: "Estimated biological age is %.1f years below chronological age.", diff), String(format: "生物年龄估算比实际年龄低 %.1f 岁。", diff))
                        : L10n.t(String(format: "Estimated biological age is %.1f years above chronological age.", -diff), String(format: "生物年龄估算比实际年龄高 %.1f 岁。", -diff)))
                    : L10n.t("Current health signals: \(result.healthAgeTrendLabel)", "当前健康信号：\(result.healthAgeTrendLabel)")
                )
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isPositive ? VelaTheme.recovery.opacity(0.08) : VelaTheme.stress.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isPositive ? VelaTheme.recovery.opacity(0.15) : VelaTheme.stress.opacity(0.15), lineWidth: 1)
            )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .velaNativeCard(radius: 24)
        .appleIntelligenceGlow(isHighlighted: isPositive, radius: 24)
        .padding(.horizontal, VelaTheme.screenPadding)
    }
    
    private var statsGrid: some View {
        let result = bioAgeResult
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatGridCard(
                title: L10n.t("Overall Score", "综合活力分"),
                value: String(format: "%.0f", result.overallScore),
                unit: "/100",
                icon: "bolt.heart.fill",
                color: VelaTheme.accent
            )
            
            StatGridCard(
                title: L10n.t("Biomarkers Status", "指标正常数"),
                value: "\(result.optimalCount)",
                unit: "/\(result.factors.count)",
                icon: "checkmark.shield.fill",
                color: VelaTheme.recovery
            )
        }
        .padding(.horizontal, VelaTheme.screenPadding)
    }
    
    private var wearableFactorsSection: some View {
        let result = bioAgeResult
        let wearables = result.factors.filter { $0.type == .wearable }
        
        return VStack(spacing: 12) {
            if wearables.isEmpty {
                Text(L10n.t("No wearable logs found for calculation.", "暂无生理指标数据。"))
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
                    .padding()
            } else {
                ForEach(wearables) { factor in
                    FactorRowView(factor: factor)
                }
            }
        }
        .padding(14)
        .velaNativeCard(radius: 16)
    }
    
    private var biomarkersSection: some View {
        let result = bioAgeResult
        let bios = result.factors.filter { $0.type == .biomarker }
        
        return VStack(spacing: 12) {
            if bios.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "drop.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(VelaTheme.mutedText)
                    
                    Text(L10n.t("No blood records entered.", "还没有录入过血检指标。"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    
                    Text(L10n.t("Record lab values here for reference. A biological-age estimate appears only when the complete PhenoAge laboratory set is available.", "可在这里记录化验指标供参考；只有完整的 PhenoAge 化验组合齐全后才会生成生物年龄估算。"))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            } else {
                // Grid of circular glowing badges
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 14) {
                    ForEach(biomarkers) { bm in
                        BiomarkerBadgeView(biomarker: bm)
                    }
                }
                .padding(.vertical, 8)
                
                Divider().background(VelaTheme.stroke)
                
                // Detailed biomarker list
                VStack(spacing: 12) {
                    ForEach(bios) { factor in
                        FactorRowView(factor: factor)
                    }
                }
            }
        }
        .padding(14)
        .velaNativeCard(radius: 16)
    }
}

// MARK: - Section Label
struct SectionLabel: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(VelaTheme.accent)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VelaTheme.primaryText)
        }
    }
}

// MARK: - Grid Card
struct StatGridCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.body)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding(14)
        .velaNativeCard(radius: 16)
    }
}

// MARK: - Factor Row
struct FactorRowView: View {
    let factor: BiologicalAgeFactor
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(factor.isOptimal ? VelaTheme.recovery.opacity(0.12) : VelaTheme.stress.opacity(0.12))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: factor.isOptimal ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(factor.isOptimal ? VelaTheme.recovery : VelaTheme.stress)
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(factor.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                
                Text(factor.description)
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.mutedText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f", factor.score))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(factor.isOptimal ? VelaTheme.recovery : VelaTheme.stress)
                
                Text(L10n.t("Score", "得分"))
                    .font(.system(size: 8))
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.01))
    }
}

// MARK: - Biomarker Badge View
struct BiomarkerBadgeView: View {
    let biomarker: BiomarkerRecord
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Glowing outer ring
                Circle()
                    .stroke(biomarker.isOptimal ? VelaTheme.recovery.opacity(0.15) : VelaTheme.stress.opacity(0.15), lineWidth: 4)
                    .frame(width: 66, height: 66)
                    .shadow(color: biomarker.isOptimal ? VelaTheme.recovery.opacity(0.2) : VelaTheme.stress.opacity(0.2), radius: 4)
                
                Circle()
                    .fill(VelaTheme.background.opacity(0.8))
                    .frame(width: 58, height: 58)
                
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", biomarker.value))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    
                    Text(biomarker.unit)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .frame(width: 70, height: 70)
            
            Text(biomarker.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.02))
        )
    }
}

// MARK: - Manual Blood Log Sheet Form
struct BloodLogSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var valueString = ""
    @State private var unit = "ng/mL"
    @State private var refMinString = ""
    @State private var refMaxString = ""
    @State private var date = Date()
    @State private var errorMsg: String? = nil
    
    private let commonBiomarkers = [
        "Albumin", "Creatinine", "Glucose", "CRP", "Lymphocyte Percentage", "MCV", "RDW",
        "Alkaline Phosphatase", "WBC", "Vitamin D", "Cortisol", "Ferritin", "Cholesterol",
        "Testosterone", "TSH", "HbA1c"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let errorMsg = errorMsg {
                            HStack {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundStyle(VelaTheme.stress)
                                Text(errorMsg)
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.primaryText)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(VelaTheme.stress.opacity(0.12))
                            .cornerRadius(10)
                        }
                        
                        // Suggestion chips
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("Common Biomarkers", "常用血检指标"))
                                .font(.caption.bold())
                                .foregroundStyle(VelaTheme.secondaryText)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(commonBiomarkers, id: \.self) { item in
                                        Button {
                                            UISelectionFeedbackGenerator().selectionChanged()
                                            name = item
                                            autoFillDefaults(for: item)
                                        } label: {
                                            Text(item)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(name == item ? VelaTheme.background : VelaTheme.primaryText)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(name == item ? VelaTheme.accent : Color.black.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Fields
                        VStack(spacing: 16) {
                            StyledTextField(label: L10n.t("BIOMARKER NAME", "指标名称"), placeholder: "e.g., Vitamin D", text: $name)
                            
                            HStack(spacing: 12) {
                                StyledTextField(label: L10n.t("VALUE", "数值"), placeholder: "e.g., 42.5", text: $valueString)
                                    .keyboardType(.decimalPad)
                                
                                StyledTextField(label: L10n.t("UNIT", "单位"), placeholder: "e.g., ng/mL", text: $unit)
                            }
                            
                            HStack(spacing: 12) {
                                StyledTextField(label: L10n.t("MIN REFERENCE", "标准下限"), placeholder: "e.g., 30", text: $refMinString)
                                    .keyboardType(.decimalPad)
                                
                                StyledTextField(label: L10n.t("MAX REFERENCE", "标准上限"), placeholder: "e.g., 100", text: $refMaxString)
                                    .keyboardType(.decimalPad)
                            }
                            
                            DatePicker(
                                L10n.t("TEST DATE", "检测日期"),
                                selection: $date,
                                displayedComponents: .date
                            )
                            .tint(VelaTheme.accent)
                            .font(.subheadline.bold())
                            .foregroundStyle(VelaTheme.primaryText)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(VelaTheme.cardBackground.opacity(0.6))
                            )
                        }
                        
                        Spacer(minLength: 20)
                        
                        Button {
                            saveBiomarker()
                        } label: {
                            Text(L10n.t("Save Biomarker", "保存指标"))
                                .font(.system(.body, design: .rounded).bold())
                                .foregroundStyle(VelaTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(VelaTheme.accent)
                                .cornerRadius(99)
                        }
                    }
                    .padding(VelaTheme.screenPadding)
                }
            }
            .navigationTitle(L10n.t("Log Lab Biomarker", "录入血检数据"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) {
                        dismiss()
                    }
                    .foregroundStyle(VelaTheme.secondaryText)
                }
            }
        }
    }
    
    private func autoFillDefaults(for bName: String) {
        switch bName {
        case "Albumin":
            unit = "g/dL"
            refMinString = "3.5"
            refMaxString = "5.0"
        case "Creatinine":
            unit = "mg/dL"
            refMinString = "0.6"
            refMaxString = "1.2"
        case "Glucose":
            unit = "mg/dL"
            refMinString = "70"
            refMaxString = "100"
        case "CRP":
            unit = "mg/L"
            refMinString = "0"
            refMaxString = "3"
        case "Lymphocyte Percentage":
            unit = "%"
            refMinString = "20"
            refMaxString = "40"
        case "MCV":
            unit = "fL"
            refMinString = "80"
            refMaxString = "100"
        case "RDW":
            unit = "%"
            refMinString = "11"
            refMaxString = "15"
        case "Alkaline Phosphatase":
            unit = "U/L"
            refMinString = "44"
            refMaxString = "147"
        case "WBC":
            unit = "10^3/uL"
            refMinString = "4"
            refMaxString = "11"
        case "Vitamin D":
            unit = "ng/mL"
            refMinString = "30"
            refMaxString = "100"
        case "Cortisol":
            unit = "mcg/dL"
            refMinString = "6"
            refMaxString = "23"
        case "Ferritin":
            unit = "ng/mL"
            refMinString = "30"
            refMaxString = "400"
        case "Cholesterol":
            unit = "mg/dL"
            refMinString = "100"
            refMaxString = "199"
        case "Testosterone":
            unit = "ng/dL"
            refMinString = "300"
            refMaxString = "1000"
        case "TSH":
            unit = "uIU/mL"
            refMinString = "0.4"
            refMaxString = "4.0"
        case "HbA1c":
            unit = "%"
            refMinString = "4.0"
            refMaxString = "5.6"
        default:
            break
        }
    }
    
    private func saveBiomarker() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMsg = L10n.t("Name is required.", "请输入指标名称。")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard let val = Double(valueString) else {
            errorMsg = L10n.t("Invalid value format.", "请输入有效的数值。")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard let rMin = Double(refMinString), let rMax = Double(refMaxString) else {
            errorMsg = L10n.t("Reference min and max are required.", "请输入标准上限和下限。")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMsg = L10n.t("Unit is required.", "请输入单位。")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        guard rMin <= rMax else {
            errorMsg = L10n.t("Reference minimum must not exceed maximum.", "标准下限不能高于上限。")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
        
        let isOptimal = val >= rMin && val <= rMax
        let record = BiomarkerRecord(
            name: name,
            value: val,
            unit: unit,
            date: date,
            isOptimal: isOptimal,
            referenceMin: rMin,
            referenceMax: rMax
        )
        
        modelContext.insert(record)

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMsg = L10n.t("Could not save biomarker.", "指标保存失败，请重试。")
        }
    }
}

// MARK: - Styled Text Field Helper
struct StyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VelaTheme.mutedText)
                .tracking(1)
            
            TextField(placeholder, text: $text)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VelaTheme.cardBackground.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 1)
                )
                .foregroundStyle(VelaTheme.primaryText)
        }
    }
}
