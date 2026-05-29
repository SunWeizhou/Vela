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
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse) private var healthRecords: [DailyHealthSummaryRecord]

    @State private var selectedTags: Set<String> = ["recovery"]
    @State private var note = ""
    @State private var statusMessage = ""
    @State private var doseValue = ""
    @State private var doseUnit = ""
    @State private var customTag = ""

    private let quickTags = ["recovery", "sleep", "training", "stress", "travel", "sick", "mood", "caffeine", "alcohol", "supplement", "late_meal", "sunlight", "mindfulness"]
    private let doseUnits = ["mg", "mL", "min", "hrs", "drinks", "cups", "score"]

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SectionHeader(
                        title: L10n.t("Journal", "日记"),
                        subtitle: L10n.t("Short notes for context-aware coaching.", "为上下文感知 Coach 提供简短记录。")
                    )

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

                        if entries.isEmpty {
                            Text(L10n.t("No journal entries yet.", "还没有日记记录。"))
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                        } else {
                            ForEach(Array(entries.prefix(12))) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.createdAt, style: .date)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(VelaTheme.secondaryText)

                                    Text(entry.tags.map(\.capitalized).joined(separator: " · "))
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(VelaTheme.accent)

                                    if let v = entry.value, let u = entry.unit {
                                        Text("\(String(format: "%.0f", v))\(u)")
                                            .font(.caption)
                                            .foregroundStyle(VelaTheme.energy)
                                    }

                                    if !entry.note.isEmpty {
                                        Text(entry.note)
                                            .font(.subheadline)
                                            .foregroundStyle(VelaTheme.primaryText)
                                    }
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
        }
        .navigationTitle("")
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
