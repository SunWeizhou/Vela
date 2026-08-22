import SwiftUI

// MARK: - Workout Detail Sheet Component
struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: TrainingDay
    let plan: TrainingPlanRecord
    let onToggle: () -> Void
    var onEdit: (() -> Void)? = nil
    var onStartWorkout: (() -> Void)? = nil

    private var plannedExercises: [WorkoutTemplateExercise] {
        guard let data = day.plannedExercisesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) else {
            return []
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Title & Day Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("第 \(day.weekNumber) 周第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)

                            Text(day.title)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.rhythmInk)
                        }

                        // Badges Row
                        HStack(spacing: 8) {
                            badgeView(text: focusName(day.focus), symbol: getFocusSymbol(day.focus), color: getFocusColor(day.focus))

                            if day.focus != "rest" {
                                badgeView(text: "\(day.durationMinutes) 分钟", symbol: "clock", color: VelaTheme.rhythmInkSecondary)
                                badgeView(text: intensityName(day.intensity), symbol: "waveform.path.ecg", color: getIntensityColor(day.intensity))
                            }

                            if day.isCompleted {
                                badgeView(text: "已打卡", symbol: "checkmark.circle.fill", color: VelaTheme.recoveryColor)
                            }
                        }

                        // Workout Routine / Description Area
                        if !day.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("训练细则与指导", systemImage: "text.alignleft")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)

                                Text(day.description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(VelaTheme.rhythmCanvasRaised)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                        }

                        // Planned Exercises Breakdown
                        if !plannedExercises.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("预设动作安排 (\(plannedExercises.count))", systemImage: "dumbbell.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)

                                VStack(spacing: 8) {
                                    ForEach(Array(plannedExercises.enumerated()), id: \.element.id) { index, exercise in
                                        HStack(spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(VelaTheme.rhythmDeep)
                                                .frame(width: 24, height: 24)
                                                .background(Circle().fill(VelaTheme.rhythmDeep.opacity(0.12)))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(exercise.name)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(VelaTheme.rhythmInk)

                                                HStack(spacing: 8) {
                                                    Text("\(exercise.targetSets) 组 × \(exercise.targetReps) 次")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)

                                                    if let rpe = exercise.targetRPE {
                                                        Text("RPE \(String(format: "%.1f", rpe))")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundStyle(VelaTheme.energyColor)
                                                    }

                                                    if exercise.restSeconds > 0 {
                                                        Text("休息 \(exercise.restSeconds)s")
                                                            .font(.system(size: 10))
                                                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                                    }
                                                }
                                            }

                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(VelaTheme.rhythmCanvasRaised)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                                    }
                                }
                            }
                        }

                        // Actions Area
                        VStack(spacing: 10) {
                            if day.focus == "strength" && onStartWorkout != nil {
                                Button {
                                    dismiss()
                                    onStartWorkout?()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("开始本次力量训练")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(VelaTheme.rhythmDeep)
                                    .cornerRadius(14)
                                }
                                .buttonStyle(.cardPress)
                            }

                            HStack(spacing: 10) {
                                Button(action: onToggle) {
                                    HStack(spacing: 6) {
                                        Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                                        Text(day.isCompleted ? "取消打卡" : "标记完成")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(day.isCompleted ? VelaTheme.recoveryColor : VelaTheme.rhythmInk)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(VelaTheme.rhythmCanvasRaised)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                                }
                                .buttonStyle(.cardPress)

                                if let onEdit {
                                    Button {
                                        dismiss()
                                        onEdit()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "pencil")
                                            Text("编辑此日")
                                        }
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(VelaTheme.rhythmDeep)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(VelaTheme.rhythmCanvasRaised)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                                    }
                                    .buttonStyle(.cardPress)
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("课表日程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
            }
        }
    }

    // MARK: - Badge Helper View
    private func badgeView(text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Helpers
    private func dayName(_ dayNumber: Int) -> String {
        switch dayNumber {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        case 7: return "周日"
        default: return ""
        }
    }

    private func getFocusColor(_ focus: String) -> Color {
        switch focus.lowercased() {
        case "cardio": return VelaTheme.energyColor
        case "strength": return VelaTheme.strainColor
        case "flexibility": return VelaTheme.recoveryColor
        case "rest": return VelaTheme.sleepColor
        default: return VelaTheme.rhythmDeep
        }
    }

    private func getFocusSymbol(_ focus: String) -> String {
        switch focus.lowercased() {
        case "cardio": return "flame.fill"
        case "strength": return "dumbbell.fill"
        case "flexibility": return "figure.cooldown"
        case "rest": return "moon.zzz.fill"
        default: return "figure.run"
        }
    }

    private func focusName(_ focus: String) -> String {
        switch focus.lowercased() {
        case "cardio": return "有氧"
        case "strength": return "力量"
        case "flexibility": return "柔韧"
        case "rest": return "休息"
        default: return "综合"
        }
    }

    private func intensityName(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return "低强度"
        case "moderate": return "中强度"
        case "high": return "高强度"
        default: return intensity.capitalized
        }
    }

    private func getIntensityColor(_ intensity: String) -> Color {
        switch intensity.lowercased() {
        case "low": return VelaTheme.recoveryColor
        case "moderate": return VelaTheme.energyColor
        case "high": return VelaTheme.strainColor
        default: return VelaTheme.rhythmInkSecondary
        }
    }
}
