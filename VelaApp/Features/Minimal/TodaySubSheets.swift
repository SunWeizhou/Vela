import SwiftUI
import SwiftData
import CoreLocation
@preconcurrency import AVFoundation

// MARK: - ProactiveInsightDetailSheet
struct ProactiveInsightDetailSheet: View {
    let insight: ProactiveInsight
    var onAskCoach: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var actionText: String {
        insight.suggestedAction ?? "先观察今天的身体反馈，保持当前节奏。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: insight.focus.icon)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(insight.focus.color)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(insight.focus.color.opacity(0.10))
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    Text(insight.focus.title)
                                    Text("·")
                                    Text(insight.severity.contextLabel)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(insight.severity.color)

                                Text(insight.displayTitle)
                                    .font(.system(size: 23, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }

                        Text(insight.body)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VelaTheme.meta)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .velaNativeCard(radius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("身体信号")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VelaTheme.muted)

                        VStack(spacing: 0) {
                            ForEach(Array(insight.evidenceItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .frame(width: 24, height: 24)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(VelaTheme.fg)

                                        Text(item.subtitle)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(VelaTheme.meta)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 12)

                                if index < insight.evidenceItems.count - 1 {
                                    Divider()
                                        .padding(.leading, 49)
                                }
                            }
                        }
                        .velaNativeCard(radius: 18)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("行动安排")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VelaTheme.muted)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(insight.focus.color)
                                    .padding(.top, 1)

                                Text(actionText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .lineSpacing(4)

                                Spacer()
                            }

                            Text("这不是医疗诊断；Vela 会把建议限制在训练、恢复、睡眠和日常节奏调整上。")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(VelaTheme.meta)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .velaNativeCard(radius: 18)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(VelaTheme.systemGroupedBackground)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        onAskCoach(insight.coachPresetQuestion)
                    } label: {
                        Label("和 Coach 讨论", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VelaTheme.accent)

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("智能建议")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension ProactiveInsight {
    var displayTitle: String {
        title.replacingOccurrences(
            of: #"^[^\p{L}\p{N}]+\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    var evidenceItems: [(title: String, subtitle: String, icon: String)] {
        if !evidence.isEmpty {
            return evidence.prefix(3).enumerated().map { index, text in
                let metric = relatedMetrics.indices.contains(index) ? relatedMetrics[index] : relatedMetrics.first
                return (
                    title: text,
                    subtitle: index == 0 ? "主要判断依据" : "辅助判断依据",
                    icon: metric?.insightMetricIcon ?? focus.icon
                )
            }
        }

        return relatedMetrics.prefix(3).map { metric in
            (
                title: metric.localizedInsightMetricName,
                subtitle: "来自今日健康与训练数据",
                icon: metric.insightMetricIcon
            )
        }
    }
}

private extension ProactiveInsight.Severity {
    var contextLabel: String {
        switch self {
        case .info: return "状态良好"
        case .warning: return "需要留意"
        case .alert: return "建议调整"
        }
    }
}

private extension String {
    var localizedInsightMetricName: String {
        switch lowercased() {
        case "hrv": return "HRV"
        case "rhr", "resting_heart_rate": return "静息心率"
        case "recovery": return "恢复"
        case "sleep": return "睡眠"
        case "energy": return "能量"
        case "strain": return "训练负荷"
        case "stress": return "压力"
        case "walking_asymmetry": return "步态"
        default: return self.replacingOccurrences(of: "_", with: " ")
        }
    }

    var insightMetricIcon: String {
        switch lowercased() {
        case "hrv", "rhr", "resting_heart_rate": return "heart.text.square"
        case "recovery": return "arrow.clockwise.heart"
        case "sleep": return "moon.zzz.fill"
        case "energy": return "bolt.fill"
        case "strain": return "figure.strengthtraining.traditional"
        case "stress": return "waveform.path.ecg"
        case "walking_asymmetry": return "figure.walk"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - ActiveStatusSelectionSheetView
struct ActiveStatusSelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var activeStatusRaw: String
    @Binding var activeStatusDuration: String

    @State private var tempStatus: String = "resting"
    @State private var tempDuration: String = "明天之前"

    let durationOptions = ["明天之前", "1天", "3天", "5天", "7天", "长期"]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(VelaTheme.borderSoft)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.systemGroupedBackground))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("活动状态")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 14) {
                    statusOptionCard(
                        id: "active",
                        title: "活跃",
                        desc: "保持忙碌和健康",
                        icon: "figure.run",
                        colors: [VelaTheme.systemGreen, Color(hex: "#2ECC71")]
                    )

                    statusOptionCard(
                        id: "sick",
                        title: "生病",
                        desc: "因病休息",
                        icon: "bed.double.fill",
                        colors: [VelaTheme.systemOrange, Color(hex: "#F1C40F")]
                    )

                    statusOptionCard(
                        id: "injured",
                        title: "受伤",
                        desc: "从伤病中恢复",
                        icon: "bandage.fill",
                        colors: [VelaTheme.systemRed, Color(hex: "#E74C3C")]
                    )

                    statusOptionCard(
                        id: "resting",
                        title: "休息中",
                        desc: "从训练中抽出时间休息",
                        icon: "beach.umbrella.fill",
                        colors: [VelaTheme.accent, VelaTheme.accentHover]
                    )

                    if tempStatus != "active" {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 15))
                                    .foregroundStyle(VelaTheme.muted)
                                Text("保持状态")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                            }

                            Spacer()

                            Menu {
                                ForEach(durationOptions, id: \.self) { opt in
                                    Button(opt) {
                                        tempDuration = opt
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tempDuration)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(VelaTheme.fg2)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(VelaTheme.meta)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Button {
                        ActiveStatusSettings.update(status: tempStatus, duration: tempDuration)
                        activeStatusRaw = tempStatus
                        activeStatusDuration = tempStatus == "active" ? "" : tempDuration
                        dismiss()
                    } label: {
                        Text("更新")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(VelaTheme.accent))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            tempStatus = activeStatusRaw
            tempDuration = activeStatusDuration
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }

    private func statusOptionCard(id: String, title: String, desc: String, icon: String, colors: [Color]) -> some View {
        Button {
            tempStatus = id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(tempStatus == id ? VelaTheme.accent : VelaTheme.borderSoft, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if tempStatus == id {
                        Circle()
                            .fill(VelaTheme.accent)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .shadow(color: Color.black.opacity(tempStatus == id ? 0.02 : 0.0), radius: 6, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tempStatus == id ? VelaTheme.accent : Color.clear, lineWidth: 1.5)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CalendarOverviewSheetView
struct CalendarOverviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @State private var healthRecords: [DailyHealthSummaryRecord] = []

    @State private var selectedMetric: String = "恢复"
    @State private var calendarYear = Calendar.current.component(.year, from: Date())
    @State private var calendarMonth = Calendar.current.component(.month, from: Date())
    @State private var showCalendarInfo = false

    let metrics = ["耗力", "恢复", "睡眠", "压力", "能量", "营养"]
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(VelaTheme.borderSoft)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Menu {
                    ForEach(0..<12, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
                        Button(monthTitle(for: date)) {
                            calendarYear = Calendar.current.component(.year, from: date)
                            calendarMonth = Calendar.current.component(.month, from: date)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: VelaMinimalFormatting.calendarTitle(year: calendarYear, month: calendarMonth))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        prevMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(VelaTheme.cardBg))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)

                    Button {
                        nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(VelaTheme.cardBg))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveToNextMonth)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(metrics, id: \.self) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Text(metric)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(selectedMetric == metric ? VelaTheme.accentOn : VelaTheme.muted)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedMetric == metric ? VelaTheme.fg : VelaTheme.systemGroupedBackground)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedMetric == metric ? Color.clear : VelaTheme.borderSoft, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            let paddingDays = paddingDaysForDisplayedMonth

            ScrollView {
                LazyVGrid(columns: gridLayout, spacing: 14) {
                    ForEach((0..<paddingDays).map { "padding-\($0)" }, id: \.self) { _ in
                        Color.clear.frame(height: 52)
                    }

                    ForEach(1...daysInDisplayedMonth, id: \.self) { day in
                        let date = makeDate(year: calendarYear, month: calendarMonth, day: day)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: dashboardVM.selectedDate)
                        let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
                        let scoreInfo = scoreInfo(for: date)

                        Button {
                            dashboardVM.selectDate(date)
                            dismiss()
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .stroke(VelaTheme.borderSoft, lineWidth: 4)
                                        .frame(width: 36, height: 36)

                                    if let scoreInfo {
                                        Circle()
                                            .trim(from: 0.0, to: CGFloat(scoreInfo.score / 100.0))
                                            .stroke(scoreInfo.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                            .frame(width: 36, height: 36)
                                            .rotationEffect(.degrees(-90))
                                    }

                                    Text("\(day)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isFuture ? VelaTheme.meta : (isSelected ? VelaTheme.accent : VelaTheme.fg))
                                }

                                Color.clear.frame(height: 8)
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(VelaTheme.accent.opacity(0.08))
                                            .frame(width: 44, height: 48)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }

            HStack {
                Button {
                    dashboardVM.goToToday()
                    dismiss()
                } label: {
                    Text("今天")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showCalendarInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.cardBg))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#F2F2F7").ignoresSafeArea())
        .onAppear {
            calendarYear = Calendar.current.component(.year, from: dashboardVM.selectedDate)
            calendarMonth = Calendar.current.component(.month, from: dashboardVM.selectedDate)
            loadHealthRecords()
        }
        .onChange(of: calendarYear) {
            loadHealthRecords()
        }
        .onChange(of: calendarMonth) {
            loadHealthRecords()
        }
        .onChange(of: appState.localDataRevision) {
            loadHealthRecords()
        }
        .alert("日历指标说明", isPresented: $showCalendarInfo) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("选择顶部指标可查看每日趋势。圆环越完整，表示该指标分数越高；没有圆环表示当天缺少对应数据。")
        }
    }

    private var displayedMonthDate: Date {
        makeDate(year: calendarYear, month: calendarMonth, day: 1)
    }

    private var daysInDisplayedMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: displayedMonthDate)?.count ?? 0
    }

    private var paddingDaysForDisplayedMonth: Int {
        Calendar.current.component(.weekday, from: displayedMonthDate) - 1
    }

    private var canMoveToNextMonth: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return displayedMonthDate < currentMonth
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        return Calendar.current.date(from: comp) ?? Date()
    }

    private func prevMonth() {
        if calendarMonth == 1 {
            calendarMonth = 12
            calendarYear -= 1
        } else {
            calendarMonth -= 1
        }
    }

    private func nextMonth() {
        guard canMoveToNextMonth else { return }
        if calendarMonth == 12 {
            calendarMonth = 1
            calendarYear += 1
        } else {
            calendarMonth += 1
        }
    }

    private func loadHealthRecords() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = calendarYear
        components.month = calendarMonth
        components.day = 1
        
        guard let startOfMonth = calendar.date(from: components) else { return }
        guard let startLimit = calendar.date(byAdding: .day, value: -7, to: startOfMonth) else { return }
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return }
        guard let endLimit = calendar.date(byAdding: .day, value: 7, to: endOfMonth) else { return }
        
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        if let fetched = try? modelContext.fetch(descriptor) {
            self.healthRecords = fetched
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func scoreInfo(for date: Date) -> (score: Double, color: Color)? {
        guard let record = healthRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let score: Double?
        switch selectedMetric {
        case "耗力": score = record.strainScore
        case "恢复": score = record.recoveryScore
        case "睡眠": score = record.sleepScore
        case "压力": score = record.stressIndex
        case "能量": score = record.energyBank
        default: score = nil
        }
        guard let score else { return nil }
        let color: Color
        switch score {
        case ..<40: color = VelaTheme.systemRed
        case ..<70: color = VelaTheme.systemYellow
        default: color = VelaTheme.systemGreen
        }
        return (score, color)
    }
}


// MARK: - Extracted Post-Workout Sheets

struct PostWorkoutCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutID: UUID?

    @State private var workout: StrengthWorkoutRecord?
    @State private var selectedTags: Set<String> = []
    @State private var rpe: Double = 7
    @State private var note = ""
    @State private var saveError: String?

    private let tagOptions: [(key: String, label: String)] = [
        ("felt_strong", "状态很好"),
        ("normal", "正常完成"),
        ("fatigued", "明显疲劳"),
        ("muscle_soreness", "肌肉酸痛"),
        ("joint_discomfort", "关节不适"),
        ("poor_sleep", "睡眠影响"),
        ("good_pump", "泵感明显"),
        ("low_motivation", "动力不足")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                tagGrid
                rpeSection
                noteSection
                if let saveError {
                    Text(saveError)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.stressColor)
                }
                saveButton
            }
            .padding(16)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("训练后感受")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
        .task {
            loadExistingState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout?.title ?? "训练后复盘")
                .font(VelaTheme.title2())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.fg)
            Text("这些反馈会进入训练响应模型，用来判断不同训练对恢复、HRV 和次日状态的代价。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var tagGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主观感受")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(tagOptions, id: \.key) { option in
                    Button {
                        if selectedTags.contains(option.key) {
                            selectedTags.remove(option.key)
                        } else {
                            selectedTags.insert(option.key)
                        }
                    } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedTags.contains(option.key) ? .white : VelaTheme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedTags.contains(option.key) ? VelaTheme.accent : VelaTheme.cardBg)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var rpeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("整体用力程度")
                    .font(VelaTheme.headline())
                Spacer()
                Text("\(Int(rpe.rounded())) / 10")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
            }
            Slider(value: $rpe, in: 1...10, step: 1)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("补充说明")
                .font(VelaTheme.headline())
            TextField("例如：深蹲最后两组腰背紧张，整体还可以。", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
        }
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存训练反馈")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.accent))
        }
        .buttonStyle(.plain)
    }

    private func loadExistingState() {
        guard let workoutID else { return }
        let workoutDescriptor = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.id == workoutID }
        )
        workout = try? modelContext.fetch(workoutDescriptor).first

        let responseDescriptor = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.workoutId == workoutID }
        )
        guard let response = try? modelContext.fetch(responseDescriptor).first else {
            if let sessionRPE = workout?.sessionRPE {
                rpe = sessionRPE
            }
            return
        }

        rpe = response.sessionRPE ?? workout?.sessionRPE ?? 7
        let tags = response.subjectiveTags
        selectedTags = Set(tags.filter { !$0.hasPrefix("note:") })
        note = tags.first(where: { $0.hasPrefix("note:") })?
            .replacingOccurrences(of: "note:", with: "") ?? ""
    }

    private func save() {
        guard let workoutID else {
            saveError = "没有找到关联训练，无法保存训练反馈。"
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var tags = Array(selectedTags).sorted()
        if !trimmedNote.isEmpty {
            tags.append("note:\(trimmedNote)")
        }

        let responseDescriptor = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.workoutId == workoutID }
        )

        do {
            if let existing = try modelContext.fetch(responseDescriptor).first {
                existing.sessionRPE = rpe
                existing.subjectiveTags = tags
            } else if let workout {
                let completedSets = workout.exercises
                    .flatMap(\.sets)
                    .filter { $0.isCompleted != false && !$0.isWarmup }
                    .count
                let muscles = Set(workout.exercises.compactMap(\.primaryMuscleGroup).filter { !$0.isEmpty })
                modelContext.insert(TrainingResponseRecord(
                    workoutId: workout.id,
                    date: workout.startedAt,
                    nextDayDate: Calendar.current.date(byAdding: .day, value: 1, to: workout.startedAt) ?? workout.startedAt,
                    primaryMuscleGroups: Array(muscles).sorted(),
                    totalEffectiveSets: completedSets,
                    totalVolumeKg: workout.totalVolumeKilograms,
                    sessionRPE: rpe,
                    subjectiveTags: tags
                ))
            } else {
                saveError = "没有找到关联训练，无法保存训练反馈。"
                return
            }

            workout?.sessionRPE = rpe
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
            let wID = workoutID
            let ctx = modelContext
            Task { @MainActor in
                try? await WorkoutAdaptationService().processWorkoutCompletion(workoutID: wID, modelContext: ctx)
            }
            dismiss()
        } catch {
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }
}

struct PostWorkoutImpactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workoutID: UUID?

    @State private var impact: PostWorkoutImpact?
    @State private var isLoading = true
    @State private var errorText: String?

    private let queryService = HealthKitQueryService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLoading {
                    VStack(alignment: .leading, spacing: 16) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 100)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 140)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 120)
                            .shimmer()
                    }
                    .frame(maxWidth: .infinity)
                } else if let impact {
                    trendSection(impact)
                    summaryGrid(impact)
                    shortWindowSection(impact)
                    nextDaySection(impact)
                    interpretationSection(impact)
                } else {
                    emptyState
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("恢复影响")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") { dismiss() }
            }
        }
        .task {
            await loadImpact()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(impact?.title ?? "训练后恢复影响")
                .font(VelaTheme.title2())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(2)
            Text("这里看的是训练结束后 2 小时内的恢复、耗力和电量趋势，以及次日恢复反应。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func summaryGrid(_ impact: PostWorkoutImpact) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            impactCard(title: "训练负荷估算", value: impact.strainCostText, caption: impact.strainSourceText)
            impactCard(title: "能量消耗", value: impact.energyText, caption: "训练记录")
            impactCard(title: "训练后心率", value: impact.postHeartRateText, caption: "0-2 小时实测均值")
        }
    }

    private func trendSection(_ impact: PostWorkoutImpact) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("训练后心率")
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.fg)
                Text("仅展示训练结束后 2 小时内 Apple 健康实际采集的心率，不补全或推算缺失时段。")
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
            }

            if impact.postWorkoutHeartRateTrend.count >= 2 {
                observedHeartRateTrendCard(impact)
            } else {
                Text("训练结束后尚无足够的心率采样。同步完成后，这里只会补充实际记录。")
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VelaTheme.elevatedBg)
                    )
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func observedHeartRateTrendCard(_ impact: PostWorkoutImpact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("心率变化")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("\(impact.postWorkoutHeartRateTrend.count) 个实际采样点")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Text(impact.postPeakHeartRateText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.strainColor)
            }

            PostWorkoutTrendLine(
                points: impact.postWorkoutHeartRateTrend,
                color: VelaTheme.strainColor,
                valueRange: impact.postWorkoutHeartRateRange
            )
                .frame(height: 86)

            HStack {
                Text("0m")
                Spacer()
                Text("60m")
                Spacer()
                Text("120m")
            }
            .font(VelaTheme.caption2())
            .foregroundStyle(VelaTheme.muted)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
    }

    private func impactCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.muted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(caption)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .velaNativeCard(radius: 16)
    }

    private func shortWindowSection(_ impact: PostWorkoutImpact) -> some View {
        sectionCard(title: "短期窗口") {
            metricRow("训练后平均心率", impact.postAverageHeartRateText)
            metricRow("训练后峰值心率", impact.postPeakHeartRateText)
            metricRow("当日总压力", impact.todayStrainText)
            metricRow("当前电量", impact.energyBankText)
        }
    }

    private func nextDaySection(_ impact: PostWorkoutImpact) -> some View {
        sectionCard(title: "次日反应") {
            metricRow("恢复分变化", impact.recoveryDeltaText)
            metricRow("HRV 变化", impact.hrvDeltaText)
            metricRow("静息心率变化", impact.rhrDeltaText)
            metricRow("睡眠分", impact.sleepScoreText)
        }
    }

    private func interpretationSection(_ impact: PostWorkoutImpact) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("判断")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(impact.interpretation)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            content()
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.fg)
                .multilineTextAlignment(.trailing)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有找到这次训练的恢复影响数据")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(errorText ?? "请等待健康数据同步完成后再查看。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .lineSpacing(3)
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    @MainActor
    private func loadImpact() async {
        isLoading = true
        defer { isLoading = false }

        guard let workoutID else {
            errorText = "这个复盘没有关联到具体训练。"
            impact = nil
            return
        }

        do {
            let workouts = try modelContext.fetch(FetchDescriptor<StrengthWorkoutRecord>())
            let events = try modelContext.fetch(FetchDescriptor<WorkoutEventRecord>())
            let responses = try modelContext.fetch(FetchDescriptor<TrainingResponseRecord>())
            let summaries = try modelContext.fetch(FetchDescriptor<DailyHealthSummaryRecord>())

            let workout = workouts.first { $0.id == workoutID }
            let event = events.first {
                $0.id == workoutID || $0.linkedStrengthWorkoutId == workoutID || $0.linkedHealthKitWorkoutId == workoutID
            } ?? workout.flatMap { strength in
                events.first { $0.linkedStrengthWorkoutId == strength.id }
            }
            let response = responses.first { $0.workoutId == workoutID }
            guard workout != nil || event != nil || response != nil else {
                errorText = "没有找到关联的力量训练或统一训练记录。"
                impact = nil
                return
            }

            let start = workout?.startedAt ?? event?.startedAt ?? response?.date ?? Date()
            let end = workout?.endedAt ?? event?.endedAt ?? start
            let calendar = Calendar.current
            let todayID = DailyHealthSummaryRecord.dayIdentifier(for: start, calendar: calendar)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            let nextDayID = DailyHealthSummaryRecord.dayIdentifier(for: nextDay, calendar: calendar)
            let todaySummary = summaries.first { $0.dayIdentifier == todayID }
            let nextDaySummary = summaries.first { $0.dayIdentifier == nextDayID }

            let postWindowEnd = min(Date(), end.addingTimeInterval(2 * 3600))
            let postSamples: [HeartRateSample]
            if postWindowEnd > end {
                postSamples = (try? await queryService.heartRateSamples(start: end, end: postWindowEnd)) ?? []
            } else {
                postSamples = []
            }

            impact = PostWorkoutImpact(
                workout: workout,
                event: event,
                response: response,
                todaySummary: todaySummary,
                nextDaySummary: nextDaySummary,
                postWorkoutStart: end,
                postWorkoutHeartRates: postSamples
            )
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            impact = nil
        }
    }
}

private struct PostWorkoutImpact {
    let title: String
    let strainCost: Double?
    let strainSourceText: String
    let energyKilocalories: Double?
    let postAverageHeartRate: Double?
    let postPeakHeartRate: Double?
    let todayStrain: Double?
    let energyBank: Double?
    let nextDayRecoveryDelta: Double?
    let nextDayHRVDelta: Double?
    let nextDayRHRDelta: Double?
    let nextDaySleepScore: Double?
    let postWorkoutHeartRateTrend: [PostWorkoutTrendPoint]

    init(
        workout: StrengthWorkoutRecord?,
        event: WorkoutEventRecord?,
        response: TrainingResponseRecord?,
        todaySummary: DailyHealthSummaryRecord?,
        nextDaySummary: DailyHealthSummaryRecord?,
        postWorkoutStart: Date,
        postWorkoutHeartRates: [HeartRateSample]
    ) {
        title = workout?.title ?? event?.title ?? "训练后恢复影响"
        let rpe = response?.sessionRPE ?? workout?.sessionRPE ?? event?.rpe
        let duration = Double(workout?.durationMinutes ?? Int(event?.durationMinutes ?? 0))
        if let response {
            strainCost = Double(response.totalEffectiveSets) * (response.sessionRPE ?? rpe ?? 6)
            strainSourceText = "按有效组 x RPE 估算"
        } else if duration > 0 {
            strainCost = duration * (rpe ?? 6) / 10
            strainSourceText = "按时长 x RPE 估算"
        } else {
            strainCost = nil
            strainSourceText = "待同步"
        }

        energyKilocalories = event?.energyKilocalories
        postAverageHeartRate = Self.average(postWorkoutHeartRates.map(\.bpm))
        postPeakHeartRate = postWorkoutHeartRates.map(\.bpm).max()
        todayStrain = todaySummary?.strainScore
        energyBank = todaySummary?.currentEnergy ?? todaySummary?.energyBank ?? todaySummary?.morningEnergy
        nextDayRecoveryDelta = response?.nextDayRecoveryDelta ?? Self.delta(nextDaySummary?.recoveryScore, todaySummary?.recoveryScore)
        nextDayHRVDelta = response?.nextDayHRVDelta ?? Self.delta(nextDaySummary?.hrvAverage, todaySummary?.hrvAverage)
        nextDayRHRDelta = response?.nextDayRHRDelta ?? Self.delta(nextDaySummary?.restingHeartRate, todaySummary?.restingHeartRate)
        nextDaySleepScore = response?.nextDaySleepScore ?? nextDaySummary?.sleepScore
        postWorkoutHeartRateTrend = postWorkoutHeartRates
            .map { sample in
                PostWorkoutTrendPoint(
                    minute: max(0, min(120, sample.date.timeIntervalSince(postWorkoutStart) / 60)),
                    value: sample.bpm
                )
            }
            .sorted { $0.minute < $1.minute }
    }

    var strainCostText: String { roundedText(strainCost, suffix: "") }
    var energyText: String { roundedText(energyKilocalories, suffix: " kcal") }
    var postHeartRateText: String { postAverageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--" }
    var postAverageHeartRateText: String { postHeartRateText }
    var postPeakHeartRateText: String { postPeakHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--" }
    var todayStrainText: String { roundedText(todayStrain, suffix: "/100") }
    var energyBankText: String { roundedText(energyBank, suffix: "/100") }
    var recoveryDeltaText: String { signedText(nextDayRecoveryDelta, suffix: " 分") }
    var hrvDeltaText: String { signedText(nextDayHRVDelta, suffix: " ms") }
    var rhrDeltaText: String { signedText(nextDayRHRDelta, suffix: " bpm") }
    var sleepScoreText: String { roundedText(nextDaySleepScore, suffix: "/100") }
    var postWorkoutHeartRateRange: ClosedRange<Double> {
        let values = postWorkoutHeartRateTrend.map(\.value)
        guard let minimum = values.min(), let maximum = values.max() else { return 40...180 }
        let lower = max(30, floor((minimum - 8) / 10) * 10)
        let upper = max(lower + 20, ceil((maximum + 8) / 10) * 10)
        return lower...upper
    }

    var interpretation: String {
        if nextDayRecoveryDelta == nil && nextDayHRVDelta == nil && nextDayRHRDelta == nil {
            return "次日恢复数据还没补全。当前只能看这次训练的耗力和训练后心率，等睡眠、HRV、静息心率同步后会更准确。"
        }
        if (nextDayRecoveryDelta ?? 0) <= -8 || (nextDayRHRDelta ?? 0) >= 5 || (nextDayHRVDelta ?? 0) <= -8 {
            return "这次训练的恢复代价偏高。下一次训练应降低同肌群容量或强度，优先看睡眠、HRV 和静息心率是否回到基线。"
        }
        if (todayStrain ?? 0) >= 75 || (strainCost ?? 0) >= 70 {
            return "这次训练本身耗力较高，目前未见明确的次日恢复下降信号。下一次同肌群训练先观察睡眠、HRV、静息心率和主观疲劳，再决定是否加量。"
        }
        return "这次训练的恢复代价目前看可控。可以按计划推进，但仍建议结合主观疲劳和睡眠质量判断是否加量。"
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func delta(_ next: Double?, _ current: Double?) -> Double? {
        guard let next, let current else { return nil }
        return next - current
    }

    private func roundedText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))\(suffix)"
    }

    private func signedText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "--" }
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)\(suffix)"
        }
        return "\(rounded)\(suffix)"
    }

}

private struct PostWorkoutTrendPoint: Identifiable, Hashable {
    var id: Double { minute }
    let minute: Double
    let value: Double
}

private struct PostWorkoutTrendLine: View {
    let points: [PostWorkoutTrendPoint]
    let color: Color
    let valueRange: ClosedRange<Double>

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                grid(size: size)
                trendPath(size: size)
            }
        }
    }

    private func grid(size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(VelaTheme.borderSoft), lineWidth: 0.6)
        }
    }

    private func trendPath(size: CGSize) -> some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }

            var line = Path()
            for (index, point) in points.enumerated() {
                let x = size.width * point.minute / 120
                let normalized = (point.value - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)
                let y = size.height * (1 - min(max(normalized, 0), 1))
                let cgPoint = CGPoint(x: x, y: y)
                if index == 0 {
                    line.move(to: cgPoint)
                } else {
                    line.addLine(to: cgPoint)
                }
            }

            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            if let last = points.last {
                let x = size.width * last.minute / 120
                let normalized = (last.value - valueRange.lowerBound) / (valueRange.upperBound - valueRange.lowerBound)
                let y = size.height * (1 - min(max(normalized, 0), 1))
                let marker = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
                context.fill(Path(ellipseIn: marker), with: .color(color))
            }
        }
    }
}


// MARK: - Extracted Quick Action Sheets

struct WorkoutLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
    @State private var selectedSport = "跑步"
    @State private var durationMinutes: Double = 30.0
    @State private var caloriesBurned: Double = 250.0
    @State private var exertionScore: Double = 5.0
    @State private var saveError: String?
    
    let sports = ["跑步", "力量训练", "骑行", "游泳", "瑜伽", "HIIT", "步行"]
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(VelaTheme.borderSoft)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录运动活动")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
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
                            .foregroundStyle(VelaTheme.muted)
                        
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
                                .foregroundStyle(VelaTheme.muted)
                            Spacer()
                            Text("\(Int(durationMinutes)) 分钟")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)
                        }
                        
                        Slider(value: $durationMinutes, in: 5...120, step: 5)
                            .tint(VelaTheme.accent)
                    }
                    .padding(.horizontal, 20)
                    
                    // Active Calories
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("活跃热量消耗")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Spacer()
                            Text("\(Int(caloriesBurned)) kcal")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)
                        }
                        
                        Slider(value: $caloriesBurned, in: 50...1000, step: 25)
                            .tint(VelaTheme.accent)
                    }
                    .padding(.horizontal, 20)
                    
                    // Exertion Score
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("耗力感官评分 (RPE)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Spacer()
                            Text("\(Int(exertionScore)) / 10")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)
                        }
                        
                        Slider(value: $exertionScore, in: 1...10, step: 1)
                            .tint(VelaTheme.accent)
                    }
                    .padding(.horizontal, 20)
                    
                    // Save Button
                    Button {
                        if saveWorkoutToSwiftData() {
                            dismiss()
                        }
                    } label: {
                        Text("保存活动")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                            .shadow(color: VelaTheme.accent.opacity(0.2), radius: 6, y: 3)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(VelaTheme.bg.ignoresSafeArea())
        .alert("无法保存活动", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }
    
    private func saveWorkoutToSwiftData() -> Bool {
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
        VelaEventService.shared.log(
            modelContext: modelContext,
            type: "workout_log",
            title: AppLanguage.stored.isChinese ? "手动记录运动：\(selectedSport)" : "Logged workout: \(selectedSport)",
            detail: AppLanguage.stored.isChinese
                ? "持续时间: \(Int(durationMinutes))分钟, 消耗: \(Int(caloriesBurned))kcal, RPE: \(Int(exertionScore))"
                : "Duration: \(Int(durationMinutes))m, Calories: \(Int(caloriesBurned))kcal, RPE: \(Int(exertionScore))",
            metadata: ["duration": durationMinutes, "calories": caloriesBurned, "rpe": exertionScore]
        )
        do {
            try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: modelContext)
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
            return true
        } catch {
            modelContext.delete(workoutEvent)
            saveError = "活动暂时无法保存，请稍后再试。\(error.localizedDescription)"
            return false
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
                .fill(VelaTheme.borderSoft)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("搜索常见食物（估算）")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VelaTheme.muted)
                TextField("搜索膳食...", text: $searchText)
                    .font(.system(size: 15))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
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
                                        .foregroundStyle(VelaTheme.fg)
                                    Text("P: \(prot)g · C: \(carb)g · F: \(fat)g")
                                        .font(.system(size: 11))
                                        .foregroundStyle(VelaTheme.muted)
                                }
                                
                                Spacer()
                                
                                Text("\(cal) kcal")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(VelaTheme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(VelaTheme.accent.opacity(0.12)))
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(VelaTheme.bg.ignoresSafeArea())
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
            fiberGrams: 0,
            healthScore: "",
            source: .manual
        )
        modelContext.insert(record)
        VelaEventService.shared.log(
            modelContext: modelContext,
            type: "food_log",
            title: AppLanguage.stored.isChinese ? "快捷记录餐食：\(name)" : "Quick food log: \(name)",
            detail: AppLanguage.stored.isChinese
                ? "能量: \(cal)kcal, 蛋白质: \(prot)g, 碳水: \(carb)g, 脂肪: \(fat)g"
                : "Calories: \(cal)kcal, Protein: \(prot)g, Carbs: \(carb)g, Fat: \(fat)g",
            metadata: ["calories": cal, "protein": prot, "carbs": carb, "fat": fat]
        )
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
                .fill(VelaTheme.borderSoft)
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text(type == "camera" ? "智能拍照识别" : (type == "library" ? "相册导入解析" : "条形码扫描"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(VelaTheme.accent)
                    Text(type == "barcode" ? "正在查询食品条码..." : "正在用 Kimi 视觉模型分析餐食...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
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
                        .foregroundStyle(VelaTheme.accent)

                    Text("使用真实照片分析营养")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)

                    Text("图片会在你确认后发送给 Kimi 视觉模型。需要先在设置中添加 Kimi API Key。")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(VelaTheme.muted)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(VelaTheme.systemRed)
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
                .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                .padding(.horizontal, 20)
                .buttonStyle(.plain)
            }
        }
        .background(VelaTheme.bg.ignoresSafeArea())
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
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            }
            .padding(.horizontal, 20)

            Text(scannedBarcode.map { "已识别条码：\($0)" } ?? "将包装条码放入取景框内")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.muted)

            Text("营养数据来自 Open Food Facts。记录前请核对包装标示。")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(VelaTheme.muted)
                .padding(.horizontal, 20)

            if scannedBarcode != nil {
                Button("重新扫描") {
                    scannedBarcode = nil
                    errorMessage = nil
                    barcodeScannerID = UUID()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
            }
        }
    }

    private func resultContent(_ result: FoodAnalysisResult) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(VelaTheme.systemGreen)

            Text("解析完成，请确认后记录")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VelaTheme.fg)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(result.foods.enumerated()), id: \.offset) { _, food in
                    Text("\(food.name) · \(food.portion) · \(food.calories) kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.fg)
                }
                Divider()
                Text("总计 \(result.totalCalories) kcal · 蛋白质 \(result.macros.protein)g · 碳水 \(result.macros.carbs)g · 脂肪 \(result.macros.fat)g")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            .padding(.horizontal, 20)

            Button("确认并记录") {
                save(result: result)
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.systemGreen))
            .padding(.horizontal, 20)
            .buttonStyle(.plain)

            Button("重新选择") {
                self.result = nil
                selectedImage = nil
                openImagePicker()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(VelaTheme.accent)
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
        VelaEventService.shared.log(
            modelContext: modelContext,
            type: "food_log",
            title: AppLanguage.stored.isChinese ? "记录分析餐食：\(defaultMealName(for: Date()))" : "Logged analyzed food: \(defaultMealName(for: Date()))",
            detail: result.plainTextSummary(),
            metadata: ["calories": result.totalCalories, "protein": result.macros.protein, "carbs": result.macros.carbs, "fat": result.macros.fat]
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
        let micronutrients = [
            micronutrient("sodium", label: "钠", unit: "mg", multiplier: 1_000, values: nutriments, suffix: suffix),
            micronutrient("potassium", label: "钾", unit: "mg", multiplier: 1_000, values: nutriments, suffix: suffix),
            micronutrient("calcium", label: "钙", unit: "mg", multiplier: 1_000, values: nutriments, suffix: suffix),
            micronutrient("iron", label: "铁", unit: "mg", multiplier: 1_000, values: nutriments, suffix: suffix),
            micronutrient("vitamin-c", label: "维生素 C", unit: "mg", multiplier: 1_000, values: nutriments, suffix: suffix),
            micronutrient("vitamin-d", label: "维生素 D", unit: "μg", multiplier: 1_000_000, values: nutriments, suffix: suffix)
        ].compactMap { $0 }

        return FoodAnalysisResult(
            foods: [IdentifiedFood(name: name, portion: portion, calories: calories)],
            totalCalories: calories,
            macros: MacroBreakdown(protein: protein, carbs: carbs, fat: fat, fiber: fiber),
            micronutrients: micronutrients,
            healthScore: healthScore(for: grade),
            suggestions: ["营养数据来自 Open Food Facts，请核对包装标示。"],
            rawAnalysis: "Open Food Facts barcode lookup: \(barcode)"
        )
    }

    private static func micronutrient(
        _ key: String,
        label: String,
        unit: String,
        multiplier: Double,
        values: [String: Any],
        suffix: String
    ) -> NutritionMicronutrientAmount? {
        guard let grams = number(in: values, key: "\(key)\(suffix)"), grams >= 0 else { return nil }
        return NutritionMicronutrientAmount(
            key: key,
            label: label,
            value: grams * multiplier,
            unit: unit,
            source: "Open Food Facts"
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
