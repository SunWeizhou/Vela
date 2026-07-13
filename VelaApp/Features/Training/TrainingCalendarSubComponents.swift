import SwiftUI

// MARK: - Workout Detail Sheet Component
struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: TrainingDay
    let plan: TrainingPlanRecord
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            VelaTheme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header Sheet Bar
                HStack {
                    Text(L10n.t("Workout Session Details", "计划日程详情"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Day Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("Week \(day.weekNumber) Day \(day.dayNumber) • \(dayName(day.dayNumber))", "第 \(day.weekNumber) 周第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            
                            Text(day.title)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(VelaTheme.fg)
                        }

                        // Badges Row
                        HStack(spacing: 8) {
                            badgeView(text: focusName(day.focus), symbol: getFocusSymbol(day.focus), color: getFocusColor(day.focus))
                            
                            if day.focus != "rest" {
                                badgeView(text: "\(day.durationMinutes) \(L10n.t("mins", "分钟"))", symbol: "clock", color: VelaTheme.fg2)
                                badgeView(text: intensityName(day.intensity), symbol: "waveform.path.ecg", color: getIntensityColor(day.intensity))
                            }
                        }

                        Divider().background(Color.black.opacity(0.08))

                        // Workout Routine / Description Area
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.t("Training Routine", "训练内容及课表细则"), systemImage: "text.alignleft")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)

                            Text(day.description)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(VelaTheme.fg2)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VelaTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                        )

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                }

                // Check-off Action Bottom Bar
                VStack(spacing: 12) {
                    Divider().background(Color.black.opacity(0.08))
                        .padding(.bottom, 8)
                    
                    Button(action: {
                        onToggle()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .bold))
                            
                            Text(day.isCompleted ? L10n.t("Workout Completed", "此日训练已打卡") : L10n.t("Mark Workout as Completed", "完成此日训练打卡"))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(day.isCompleted ? VelaTheme.recoveryColor : VelaTheme.accent)
                        .cornerRadius(14)
                        .shadow(color: (day.isCompleted ? VelaTheme.recoveryColor : VelaTheme.accent).opacity(0.2), radius: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(VelaTheme.surface.opacity(0.4))
            }
        }
    }

    // MARK: - Badge Helper View
    private func badgeView(text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.08)))
        .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: - Helpers
    private func dayName(_ dayNumber: Int) -> String {
        switch dayNumber {
        case 1: return L10n.t("Monday", "周一")
        case 2: return L10n.t("Tuesday", "周二")
        case 3: return L10n.t("Wednesday", "周三")
        case 4: return L10n.t("Thursday", "周四")
        case 5: return L10n.t("Friday", "周五")
        case 6: return L10n.t("Saturday", "周六")
        case 7: return L10n.t("Sunday", "周日")
        default: return ""
        }
    }

    private func getFocusColor(_ focus: String) -> Color {
        switch focus.lowercased() {
        case "cardio": return VelaTheme.strainColor
        case "strength": return VelaTheme.energyColor
        case "flexibility": return VelaTheme.accent
        case "rest": return VelaTheme.sleepColor
        default: return VelaTheme.accent
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
        case "cardio": return L10n.t("Cardio", "有氧")
        case "strength": return L10n.t("Strength", "力量")
        case "flexibility": return L10n.t("Flexibility", "拉伸")
        case "rest": return L10n.t("Rest", "休息")
        default: return focus.capitalized
        }
    }

    private func intensityName(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return L10n.t("Low", "低强度")
        case "moderate": return L10n.t("Moderate", "中强度")
        case "high": return L10n.t("High", "高强度")
        default: return intensity.capitalized
        }
    }

    private func getIntensityColor(_ intensity: String) -> Color {
        switch intensity.lowercased() {
        case "low": return VelaTheme.recoveryColor
        case "moderate": return VelaTheme.energyColor
        case "high": return VelaTheme.stressColor
        default: return VelaTheme.fg2
        }
    }
}
