import SwiftUI
import SwiftData

struct TrainingQuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private let workoutTypes = [
        ("running", "跑步", "figure.run", VelaTheme.recoveryColor),
        ("traditionalStrengthTraining", "力量训练", "figure.strengthtraining.traditional", VelaTheme.strainColor),
        ("cycling", "骑行", "figure.outdoor.cycle", VelaTheme.energyColor),
        ("swimming", "游泳", "figure.pool.swim", VelaTheme.energyColor),
        ("highIntensityIntervalTraining", "HIIT 间歇", "flame.fill", VelaTheme.strainColor),
        ("yoga", "瑜伽 / 拉伸", "figure.mind.and.body", VelaTheme.sleepColor),
        ("hiking", "户外徒步", "figure.hiking", VelaTheme.recoveryColor),
        ("walking", "健步走", "figure.walk", VelaTheme.recoveryColor),
        ("other", "其他运动", "sportscourt.fill", VelaTheme.rhythmDeep)
    ]

    @State private var selectedType = "traditionalStrengthTraining"
    @State private var customTitle = ""
    @State private var startedAt = Date()
    @State private var durationMinutes: Int = 45
    @State private var caloriesBurned: String = "320"
    @State private var averageHeartRate: String = "135"
    @State private var rpe: Double = 7.5
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        activityTypeSection
                        durationAndTimingSection
                        intensityAndMetricsSection
                        notesSection
                    }
                    .padding(16)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("快速记录运动")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveWorkout() }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .disabled(isSaving)
                }
            }
            .alert("无法保存记录", isPresented: Binding(
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
    private var activityTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("运动类型")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(workoutTypes, id: \.0) { key, label, icon, tint in
                    Button {
                        selectedType = key
                        if customTitle.isEmpty {
                            customTitle = label
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(selectedType == key ? Color.white : tint)

                            Text(label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selectedType == key ? Color.white : VelaTheme.rhythmInk)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedType == key ? VelaTheme.rhythmDeep : VelaTheme.rhythmCanvasRaised)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VelaTheme.rhythmMist, lineWidth: selectedType == key ? 0 : 0.75)
                        )
                    }
                    .buttonStyle(.cardPress)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("记录标题 (选填)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                TextField("例如：早起 5 公里晨跑、胸肌刺激", text: $customTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .padding(12)
                    .background(VelaTheme.rhythmCanvasRaised)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
            }
        }
    }

    private var durationAndTimingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时间与时长")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            VStack(spacing: 12) {
                DatePicker("开始时间", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                Divider().background(VelaTheme.rhythmMist)

                HStack {
                    Text("运动时长")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Spacer()
                    Stepper("\(durationMinutes) 分钟", value: $durationMinutes, in: 5...360, step: 5)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    private var intensityAndMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("负荷与生理指标")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("消耗热量 (kcal)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        TextField("320", text: $caloriesBurned)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .padding(10)
                            .background(VelaTheme.rhythmCanvas)
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("平均心率 (bpm)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        TextField("135", text: $averageHeartRate)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .padding(10)
                            .background(VelaTheme.rhythmCanvas)
                            .cornerRadius(8)
                    }
                }

                Divider().background(VelaTheme.rhythmMist)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("主观体感强度 (RPE)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Spacer()
                        Text(String(format: "RPE %.1f · %@", rpe, rpeLabel(rpe)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(rpeColor(rpe))
                    }

                    Slider(value: $rpe, in: 1.0...10.0, step: 0.5)
                        .tint(rpeColor(rpe))

                    HStack {
                        Text("1 极轻松").font(.system(size: 10)).foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("5 适度").font(.system(size: 10)).foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("10 极限力竭").font(.system(size: 10)).foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("感受与备注 (选填)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            TextField("记录训练动作状态、场地、天气或身体恢复感受...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.rhythmInk)
                .padding(14)
                .background(VelaTheme.rhythmCanvasRaised)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    // MARK: - Actions & Helpers
    private func rpeLabel(_ value: Double) -> String {
        switch value {
        case ..<4.0: return "轻松恢复"
        case 4.0..<6.0: return "稳态有氧"
        case 6.0..<7.5: return "适度推进"
        case 7.5..<9.0: return "高强度突破"
        default: return "全力力竭"
        }
    }

    private func rpeColor(_ value: Double) -> Color {
        switch value {
        case ..<5.0: return VelaTheme.sleepColor
        case 5.0..<7.5: return VelaTheme.recoveryColor
        case 7.5..<8.5: return VelaTheme.energyColor
        default: return VelaTheme.strainColor
        }
    }

    private func defaultTitleForType(_ type: String) -> String {
        workoutTypes.first(where: { $0.0 == type })?.1 ?? "运动"
    }

    private func saveWorkout() {
        isSaving = true
        let resolvedTitle = customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultTitleForType(selectedType)
            : customTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let calories = Double(caloriesBurned.trimmingCharacters(in: .whitespacesAndNewlines))
        let hr = Double(averageHeartRate.trimmingCharacters(in: .whitespacesAndNewlines))
        let endedAt = startedAt.addingTimeInterval(Double(durationMinutes) * 60)

        let record = WorkoutEventRecord(
            id: UUID(),
            source: "manual",
            startedAt: startedAt,
            endedAt: endedAt,
            activityType: selectedType,
            title: resolvedTitle,
            energyKilocalories: calories,
            averageHeartRate: hr,
            rpe: rpe
        )

        do {
            modelContext.insert(record)
            try modelContext.save()

            Task { @MainActor in
                await dashboardVM.refresh(modelContext: modelContext)
                await dashboardVM.loadFitnessActivityHistory(modelContext: modelContext)
                await dashboardVM.loadStrainTrend(modelContext: modelContext)
            }
            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            isSaving = false
        }
    }
}
