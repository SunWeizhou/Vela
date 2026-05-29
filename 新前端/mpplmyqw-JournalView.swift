import SwiftData
import SwiftUI

struct TagCorrelationStat {
    let tag: String
    let count: Int
    let avgRecovery: Double
    let avgSleep: Double
    let avgStrain: Double?
    let withoutAvgRecovery: Double?
    let withoutAvgSleep: Double?

    /// Positive = tag associated with better scores, negative = worse
    var overallImpact: Double {
        var deltas: [Double] = []
        if let without = withoutAvgRecovery, avgRecovery > 0 {
            deltas.append(avgRecovery - without)
        }
        if let without = withoutAvgSleep, avgSleep > 0 {
            deltas.append(avgSleep - without)
        }
        guard !deltas.isEmpty else { return 0 }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    var impactColor: Color {
        overallImpact > 2 ? VelaTheme.recovery :
        overallImpact < -2 ? VelaTheme.stress :
        VelaTheme.secondaryText
    }
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var entries: [JournalEntryRecord]
    @Query(sort: \FoodLogRecord.createdAt, order: .reverse) private var foodLogs: [FoodLogRecord]
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse) private var healthRecords: [DailyHealthSummaryRecord]

    @State private var selectedTags: Set<String> = ["recovery"]
    @State private var note = ""
    @State private var statusMessage = ""
    @State private var doseValue = ""
    @State private var doseUnit = ""
    @State private var customTag = ""
    @State private var selectedJournalDate = Date()

    private let quickTags = ["recovery", "sleep", "training", "stress", "travel", "sick", "mood", "caffeine", "alcohol", "supplement", "late_meal", "sunlight", "mindfulness"]
    private let doseUnits = ["mg", "mL", "min", "hrs", "drinks", "cups", "score"]
    private let dailyHabits: [JournalHabitDefinition] = [
        .init(tag: "low_carb", icon: "🥖", title: L10n.t("Low carbohydrate", "低碳水化合物"), unit: "g", tint: VelaTheme.energy),
        .init(tag: "caffeine", icon: "☕️", title: L10n.t("Caffeine", "咖啡因"), unit: "mg", tint: VelaTheme.secondaryText),
        .init(tag: "mood", icon: "🙂", title: L10n.t("Daily mood", "每日心情"), unit: nil, tint: VelaTheme.recovery),
        .init(tag: "added_sugar", icon: "🍬", title: L10n.t("Added sugar", "添加糖"), unit: "g", tint: VelaTheme.sleep),
        .init(tag: "raw_food", icon: "🥑", title: L10n.t("Raw food", "生酮饮食"), unit: nil, tint: VelaTheme.recovery),
        .init(tag: "hydration", icon: "💧", title: L10n.t("Hydration", "补水"), unit: "mL", tint: VelaTheme.accent)
    ]

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    journalHeader
                    journalDateStrip
                    journalHabitBoard
                    journalOverviewCard

                    if !foodLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.t("Nutrition", "营养记录"), systemImage: "fork.knife.circle.fill")
                                .font(.headline)
                                .foregroundStyle(VelaTheme.primaryText)

                            ForEach(Array(foodLogs.prefix(5))) { log in
                                nutritionLogCard(log)
                            }
                        }
                        .cardSurface()
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Label(L10n.t("Quick Tags", "快速标签"), systemImage: "tag.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(quickTags, id: \.self) { tag in
                                Button {
                                    toggle(tag)
                                } label: {
                                    Text(tag.capitalized)
                                        .frame(maxWidth: .infinity)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedTags.contains(tag) ? VelaTheme.accent.opacity(0.22) : VelaTheme.elevatedSurface)
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedTags.contains(tag) ? VelaTheme.accent.opacity(0.14) : Color.black.opacity(0.04), lineWidth: 0.5)
                                        )
                                        .foregroundStyle(selectedTags.contains(tag) ? VelaTheme.accent : VelaTheme.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextField(L10n.t("What changed today?", "今天有什么变化？"), text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .fill(VelaTheme.elevatedSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                            .foregroundStyle(VelaTheme.primaryText)

                        // Dose tracking
                        HStack(spacing: 8) {
                            TextField(L10n.t("Value", "数值"), text: $doseValue)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: 70)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(VelaTheme.elevatedSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                                )
                                .foregroundStyle(VelaTheme.primaryText)

                            Picker("", selection: $doseUnit) {
                                Text("--").tag("")
                                ForEach(doseUnits, id: \.self) { unit in
                                    Text(unit).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(VelaTheme.accent)

                            Spacer()
                        }

                        // Custom tag
                        HStack(spacing: 8) {
                            TextField(L10n.t("Custom tag", "自定义标签"), text: $customTag)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(VelaTheme.elevatedSurface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                                )
                                .foregroundStyle(VelaTheme.primaryText)

                            if !customTag.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button {
                                    let tag = customTag.trimmingCharacters(in: .whitespaces).lowercased()
                                    selectedTags.insert(tag)
                                    customTag = ""
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(VelaTheme.accent)
                                }
                            }
                        }

                        Button {
                            saveEntry()
                        } label: {
                            Label(L10n.t("Save Entry", "保存记录"), systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(VelaTheme.accent)
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTags.isEmpty)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                    }
                    .cardSurface()

                    VStack(alignment: .leading, spacing: 12) {
                        Label(L10n.t("Recent Entries", "最近记录"), systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        // Tag correlation insights
                        if !tagCorrelations.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(L10n.t("Tag Insights (30 days)", "标签洞察（30天）"), systemImage: "chart.bar.doc.horizontal.fill")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(VelaTheme.accent)

                                ForEach(tagCorrelations.prefix(5), id: \.tag) { stat in
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Tag chip with color-coded impact indicator
                                        HStack(spacing: 8) {
                                            // Impact dot
                                            Circle()
                                                .fill(stat.impactColor)
                                                .frame(width: 8, height: 8)

                                            // Tag label
                                            Text(stat.tag.capitalized)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(VelaTheme.primaryText)

                                            Spacer()

                                            // Count badge
                                            Text("\(stat.count)d")
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(VelaTheme.secondaryText)
                                        }

                                        // Score bars
                                        HStack(spacing: 12) {
                                            scoreMeter(
                                                label: L10n.t("Sleep", "睡眠"),
                                                value: stat.avgSleep,
                                                baseline: stat.withoutAvgSleep,
                                                color: VelaTheme.sleep
                                            )
                                            scoreMeter(
                                                label: L10n.t("Recovery", "恢复"),
                                                value: stat.avgRecovery,
                                                baseline: stat.withoutAvgRecovery,
                                                color: VelaTheme.recovery
                                            )
                                        }
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(VelaTheme.elevatedSurface)
                                    )
                                }
                            }
                        }

                        if journalDaySummaries.isEmpty {
                            Text(L10n.t("No journal entries yet.", "还没有日记记录。"))
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                        } else {
                            ForEach(journalDaySummaries.prefix(10)) { summary in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(summary.date, style: .date)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(VelaTheme.secondaryText)
                                        Spacer()
                                        Text(L10n.t("\(summary.count) entries", "\(summary.count) 条"))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(VelaTheme.primaryText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Capsule(style: .continuous).fill(VelaTheme.subtleFill))
                                    }

                                    if !summary.tags.isEmpty {
                                        Text(summary.tags.joined(separator: " · "))
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(VelaTheme.accent)
                                    }

                                    Text(summary.body)
                                        .font(.subheadline)
                                        .foregroundStyle(VelaTheme.primaryText)
                                        .lineLimit(3)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                        .fill(VelaTheme.elevatedSurface)
                                )
                            }
                        }
                    }
                    .cardSurface()
                }
                .padding(VelaTheme.screenPadding)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 88)
            }
        }
        .navigationTitle("")
    }

    private struct JournalHabitDefinition: Identifiable {
        let id = UUID()
        let tag: String
        let icon: String
        let title: String
        let unit: String?
        let tint: Color
    }

    private struct JournalDaySummary: Identifiable {
        let id: String
        let date: Date
        let count: Int
        let tags: [String]
        let body: String
    }

    private var journalDaySummaries: [JournalDaySummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.createdAt)
        }

        return grouped.keys.sorted(by: >).compactMap { day in
            guard let dayEntries = grouped[day], !dayEntries.isEmpty else { return nil }
            let tagList = Array(Set(dayEntries.flatMap(\.tags)))
                .sorted()
                .prefix(5)
                .map(\.capitalized)
            
            let coachEntries = dayEntries.filter { $0.tags.contains("coach") }
            let regularEntries = dayEntries.filter { !$0.tags.contains("coach") }
            
            var notesList = regularEntries.map { entry -> String in
                if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return entry.note
                }
                if let value = entry.value, let unit = entry.unit {
                    return "\(entry.tags.first?.capitalized ?? L10n.t("Entry", "记录")) \(String(format: "%.0f", value))\(unit)"
                }
                return entry.tags.joined(separator: ", ")
            }.filter { !$0.isEmpty }

            if !coachEntries.isEmpty {
                let count = coachEntries.count
                let topics = Array(Set(coachEntries.flatMap { entry in
                    entry.tags.filter { $0 != "coach" }
                })).map { topic -> String in
                    switch topic.lowercased() {
                    case "hrv": return "HRV"
                    case "restingheartrate", "rhr": return L10n.t("Resting HR", "静息心率")
                    case "sleep": return L10n.t("Sleep", "睡眠")
                    case "strain": return L10n.t("Strain", "负荷")
                    case "stress": return L10n.t("Stress", "压力")
                    case "nutrition": return L10n.t("Nutrition", "营养")
                    case "hydration", "water": return L10n.t("Hydration", "水分补给")
                    default: return topic.capitalized
                    }
                }.sorted()

                let coachSummary: String
                if AppLanguage.stored.isChinese {
                    if topics.isEmpty {
                        coachSummary = "与 AI Coach 进行了 \(count) 次健康对话"
                    } else {
                        coachSummary = "与 AI Coach 进行了 \(count) 次对话，探讨了 \(topics.joined(separator: "、"))"
                    }
                } else {
                    if topics.isEmpty {
                        coachSummary = "\(count) conversations with AI Coach"
                    } else {
                        coachSummary = "\(count) conversations with AI Coach, covering \(topics.joined(separator: ", "))"
                    }
                }
                notesList.insert(coachSummary, at: 0)
            }

            let notes = notesList
                .prefix(3)
                .joined(separator: " / ")

            return JournalDaySummary(
                id: DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar),
                date: day,
                count: dayEntries.count,
                tags: Array(tagList),
                body: notes.isEmpty ? L10n.t("Context captured for this day.", "这一天已有上下文记录。") : notes
            )
        }
    }

    private var journalHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Log", "手记"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(L10n.t("Capture context for Vela.", "记录给 Vela 理解你的上下文。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.mutedText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Analyze today's journal entries, tags, and health context. Tell me the likely patterns and what to watch tomorrow.",
                    "请分析今天的手记、标签和健康上下文，告诉我可能的模式以及明天需要注意什么。"
                ))
            } label: {
                Label(L10n.t("Analyze", "分析"), systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule(style: .continuous).fill(Color.white.opacity(0.80)))
                    .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
    }

    private var journalDateStrip: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let dates = (-2...4).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedJournalDate.formatted(.dateTime.year().month(.wide)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)

            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedJournalDate)
                    let hasEntry = entries.contains { calendar.isDate($0.createdAt, inSameDayAs: date) }

                    Button {
                        selectedJournalDate = date
                    } label: {
                        VStack(spacing: 7) {
                            Text(weekdayLabel(for: date))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? VelaTheme.primaryText : VelaTheme.mutedText)
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isSelected ? VelaTheme.primaryText : VelaTheme.secondaryText)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(isSelected ? VelaTheme.energy.opacity(0.28) : Color.white.opacity(0.72))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(hasEntry ? VelaTheme.accent.opacity(0.6) : Color.black.opacity(0.05), lineWidth: hasEntry ? 1.2 : 0.5)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var journalHabitBoard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Today's entries", "今天的条目"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(L10n.t(
                    "These entries will be used for tomorrow's analysis and Wiki memory.",
                    "这些条目会用于明天的分析和 Wiki 记忆。"
                ))
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
            }

            VStack(spacing: 9) {
                ForEach(dailyHabits) { habit in
                    journalHabitRow(habit)
                }
            }
        }
        .cardSurface()
    }

    private func journalHabitRow(_ habit: JournalHabitDefinition) -> some View {
        let isSelected = selectedTags.contains(habit.tag)

        return Button {
            toggle(habit.tag)
        } label: {
            HStack(spacing: 12) {
                Text(habit.icon)
                    .font(.title3)
                    .frame(width: 28, height: 28)

                Text(habit.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                if let unit = habit.unit {
                    Text(isSelected ? L10n.t("logged", "已记录") : "- \(unit)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? habit.tint : VelaTheme.mutedText)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.right.circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? habit.tint : VelaTheme.mutedText.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? habit.tint.opacity(0.10) : Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? habit.tint.opacity(0.16) : Color.black.opacity(0.05), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private var journalOverviewCard: some View {
        let todayEntries = entries.filter { Calendar.current.isDateInToday($0.createdAt) }.count
        let topTag = tagCorrelations.first?.tag.capitalized ?? "--"
        let foodCount = foodLogs.filter { Calendar.current.isDateInToday($0.createdAt) }.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("Daily context", "今日上下文"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(L10n.t("Agent memory", "Agent 记忆"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(VelaTheme.accent.opacity(0.12)))
            }

            Text(L10n.t(
                "Short logs help the coach connect symptoms, training, travel, sleep, and routines without asking you the same questions again.",
                "简短记录会帮助 Coach 关联症状、训练、旅行、睡眠和日常习惯，减少重复询问。"
            ))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.secondaryText)
            .lineSpacing(3)

            HStack(spacing: 8) {
                journalStatPill(title: L10n.t("Today", "今日"), value: "\(todayEntries)", tint: VelaTheme.accent)
                journalStatPill(title: L10n.t("Top tag", "高频标签"), value: topTag, tint: VelaTheme.sleep)
                journalStatPill(title: L10n.t("Meals", "餐食"), value: "\(foodCount)", tint: VelaTheme.energy)
            }
        }
        .cardSurface()
    }

    private func journalStatPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private var tagCorrelations: [TagCorrelationStat] {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        let recentEntries = entries.filter { $0.createdAt >= thirtyDaysAgo }
        let recentHealth = healthRecords.filter { $0.date >= thirtyDaysAgo }

        // Map dates to health scores for quick lookup
        var scoresByDay: [String: (recovery: Double, sleep: Double)] = [:]
        for record in recentHealth {
            let key = DailyHealthSummaryRecord.dayIdentifier(for: record.date, calendar: calendar)
            scoresByDay[key] = (record.recoveryScore ?? 0, record.sleepScore ?? 0)
        }

        // All days with health data
        let allDays = Set(scoresByDay.keys)

        // Aggregate by tag — days WITH tag
        var tagStats: [String: (count: Int, totalRecovery: Double, totalSleep: Double, days: Set<String>)] = [:]
        for entry in recentEntries {
            let dayKey = DailyHealthSummaryRecord.dayIdentifier(for: entry.createdAt, calendar: calendar)
            guard let scores = scoresByDay[dayKey] else { continue }
            for tag in entry.tags {
                var current = tagStats[tag] ?? (0, 0, 0, [])
                current.count += 1
                current.totalRecovery += scores.recovery
                current.totalSleep += scores.sleep
                current.days.insert(dayKey)
                tagStats[tag] = current
            }
        }

        return tagStats.compactMap { tag, stats -> TagCorrelationStat? in
            guard stats.count >= 2 else { return nil }

            let daysWithTag = stats.days
            let daysWithoutTag = allDays.subtracting(daysWithTag)

            // Compute averages for days WITHOUT this tag
            var withoutRecovery: Double? = nil
            var withoutSleep: Double? = nil
            if !daysWithoutTag.isEmpty {
                let withoutRecScores = daysWithoutTag.compactMap { scoresByDay[$0]?.recovery }.filter { $0 > 0 }
                let withoutSleepScores = daysWithoutTag.compactMap { scoresByDay[$0]?.sleep }.filter { $0 > 0 }
                if !withoutRecScores.isEmpty {
                    withoutRecovery = withoutRecScores.reduce(0, +) / Double(withoutRecScores.count)
                }
                if !withoutSleepScores.isEmpty {
                    withoutSleep = withoutSleepScores.reduce(0, +) / Double(withoutSleepScores.count)
                }
            }

            return TagCorrelationStat(
                tag: tag,
                count: stats.count,
                avgRecovery: stats.totalRecovery / Double(stats.count),
                avgSleep: stats.totalSleep / Double(stats.count),
                avgStrain: nil,
                withoutAvgRecovery: withoutRecovery,
                withoutAvgSleep: withoutSleep
            )
        }.sorted { abs($0.overallImpact) > abs($1.overallImpact) }
    }

    @ViewBuilder
    private func nutritionLogCard(_ log: FoodLogRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.mealName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(log.createdAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                }

                Spacer()

                Text("\(log.totalCalories) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelaTheme.energy)
            }

            if !log.foods.isEmpty {
                Text(log.foods.map { "\($0.name) (\($0.portion))" }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                nutritionChip(label: "P", value: log.proteinGrams, color: VelaTheme.recovery)
                nutritionChip(label: "C", value: log.carbsGrams, color: VelaTheme.sleep)
                nutritionChip(label: "F", value: log.fatGrams, color: VelaTheme.strain)
                nutritionChip(label: "Fiber", value: log.fiberGrams, color: VelaTheme.accent)
            }

            if !log.suggestions.isEmpty {
                Text(log.suggestions.prefix(2).joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                .fill(VelaTheme.elevatedSurface)
        )
    }

    @ViewBuilder
    private func nutritionChip(label: String, value: Int, color: Color) -> some View {
        Text("\(label) \(value)g")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    @ViewBuilder
    private func scoreMeter(label: String, value: Double, baseline: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)
                Text(String(format: "%.0f", value))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color)
                if let baseline = baseline, baseline > 0 {
                    let delta = value - baseline
                    if abs(delta) >= 1 {
                        Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(delta > 0 ? VelaTheme.recovery : VelaTheme.stress)
                    }
                }
            }
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VelaTheme.surface)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(value) / 100.0)), height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    private func saveEntry() {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = Double(doseValue.trimmingCharacters(in: .whitespaces))
        let cleanUnit = doseUnit.isEmpty ? nil : doseUnit
        modelContext.insert(
            JournalEntryRecord(
                createdAt: Date(),
                tags: Array(selectedTags).sorted(),
                note: cleanNote,
                value: cleanValue,
                unit: cleanUnit
            )
        )
        do {
            try modelContext.save()
            note = ""
            doseValue = ""
            doseUnit = ""
            statusMessage = L10n.t("Entry saved.", "记录已保存。")
        } catch {
            statusMessage = L10n.t("Could not save entry.", "无法保存记录。")
        }
    }
}
