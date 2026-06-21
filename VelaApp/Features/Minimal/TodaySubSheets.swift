import SwiftUI
import SwiftData
import CoreLocation

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
                        colors: [Color(hex: "#34C759"), Color(hex: "#2ECC71")]
                    )

                    statusOptionCard(
                        id: "sick",
                        title: "生病",
                        desc: "因病休息",
                        icon: "bed.double.fill",
                        colors: [Color(hex: "#FF9F0A"), Color(hex: "#F1C40F")]
                    )

                    statusOptionCard(
                        id: "injured",
                        title: "受伤",
                        desc: "从伤病中恢复",
                        icon: "bandage.fill",
                        colors: [Color(hex: "#FF3B30"), Color(hex: "#E74C3C")]
                    )

                    statusOptionCard(
                        id: "resting",
                        title: "休息中",
                        desc: "从训练中抽出时间休息",
                        icon: "beach.umbrella.fill",
                        colors: [Color(hex: "#4285F4"), Color(hex: "#3498DB")]
                    )

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

                    Button {
                        ActiveStatusSettings.update(status: tempStatus, duration: tempDuration)
                        activeStatusRaw = tempStatus
                        activeStatusDuration = tempDuration
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
                        .foregroundStyle(Color(hex: "#4285F4"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#E8F0FE")))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showCalendarInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
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
        case ..<40: color = Color(hex: "#FF3B30")
        case ..<70: color = Color(hex: "#FFB74D")
        default: color = Color(hex: "#34C759")
        }
        return (score, color)
    }
}
