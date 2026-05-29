import SwiftUI

// MARK: - Habit Definition

private struct JournalHabit: Identifiable {
    let id: String
    let sfSymbol: String
    let nameEN: String
    let nameZH: String
    let maxCount: Int
    let unit: String

    func displayName() -> String {
        AppLanguage.stored.isChinese ? nameZH : nameEN
    }
}

// MARK: - Food Entry (Sample)

private struct FoodEntry: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let time: String
    let confidence: DataConfidence
}

// MARK: - Memory Row

private struct MemoryRow: Identifiable {
    let id: String
    let icon: String
    let titleEN: String
    let titleZH: String

    func displayTitle() -> String {
        AppLanguage.stored.isChinese ? titleZH : titleEN
    }
}

// MARK: - VelaMinimalJournalView

struct VelaMinimalJournalView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    @State private var selectedDate = Date()
    @State private var habitCounts: [String: Int] = [
        "water": 3,
        "sunlight": 2,
        "mindfulness": 1,
        "caffeine": 1
    ]

    private let habits: [JournalHabit] = [
        .init(id: "water", sfSymbol: "drop.fill", nameEN: "Water", nameZH: "饮水", maxCount: 5, unit: "glasses"),
        .init(id: "sunlight", sfSymbol: "sun.max.fill", nameEN: "Sunlight", nameZH: "日照", maxCount: 5, unit: "min"),
        .init(id: "mindfulness", sfSymbol: "brain.head.profile", nameEN: "Mindfulness", nameZH: "正念", maxCount: 5, unit: "sessions"),
        .init(id: "caffeine", sfSymbol: "cup.and.saucer.fill", nameEN: "Caffeine", nameZH: "咖啡因", maxCount: 5, unit: "cups")
    ]

    @State private var foodEntries: [FoodEntry] = [
        .init(name: "Breakfast Bowl", calories: 420, time: "08:30", confidence: .high),
        .init(name: "Protein Shake", calories: 180, time: "11:15", confidence: .high),
        .init(name: "Chicken Salad", calories: 560, time: "13:45", confidence: .medium)
    ]

    private let memoryRows: [MemoryRow] = [
        .init(id: "baselines", icon: "chart.bar.fill", titleEN: "Baselines", titleZH: "个人基线"),
        .init(id: "preferences", icon: "heart.text.square.fill", titleEN: "Preferences", titleZH: "偏好设置"),
        .init(id: "patterns", icon: "sparkle.magnifyingglass", titleEN: "Learned Patterns", titleZH: "学习到的模式"),
        .init(id: "records", icon: "trophy.fill", titleEN: "Personal Records", titleZH: "个人记录")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: VelaSpacing.xl) {
                    dateStripSection
                    habitsSection
                    foodLogSection
                    memorySection
                }
                .padding(.horizontal, VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
    }

    // MARK: - Computed Helpers

    private var totalCalories: Int {
        foodEntries.reduce(0) { $0 + $1.calories }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = AppLanguage.stored.isChinese ? "yyyy年M月" : "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-3...10).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    private var lastUpdatedFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = AppLanguage.stored.isChinese ? "MM月dd日 HH:mm" : "MMM dd, HH:mm"
        return formatter.string(from: viewModel.lastUpdated ?? Date())
    }

    private func dateToIdentifier(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func weekdayShortString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = AppLanguage.stored.isChinese ? "EEE" : "EEEEE"
        return String(formatter.string(from: date).prefix(3))
    }

    // MARK: - 1. Date Strip

    private var dateStripSection: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.sm) {
            HStack {
                Text(monthYearString)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Spacer()
                HStack(spacing: VelaSpacing.xs) {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(VelaTheme.outline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Previous month", "上个月"))

                    Button {
                        selectedDate = Date()
                    } label: {
                        Text(L10n.t("Today", "今天"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(VelaTheme.primary)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                            .overlay(Capsule(style: .continuous).stroke(VelaTheme.outline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().stroke(VelaTheme.outline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Next month", "下个月"))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: VelaSpacing.xs) {
                        ForEach(weekDates, id: \.self) { date in
                            datePill(date)
                                .id(dateToIdentifier(date))
                        }
                    }
                    .padding(.horizontal, 2)
                    .onAppear {
                        if let today = weekDates.first(where: { Calendar.current.isDateInToday($0) }) {
                            proxy.scrollTo(dateToIdentifier(today), anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func datePill(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let weekday = weekdayShortString(date)
        let day = Calendar.current.component(.day, from: date)
        let label = isToday ? L10n.t("Today", "今天") : "\(day)"

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text(weekday)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? VelaTheme.onPrimary : VelaTheme.muted)
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? VelaTheme.onPrimary : VelaTheme.onSurface)
            }
            .frame(width: 44, height: 52)
            .background(
                RoundedRectangle(cornerRadius: VelaRadius.full, style: .continuous)
                    .fill(isSelected ? VelaTheme.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.full, style: .continuous)
                    .stroke(isSelected ? Color.clear : VelaTheme.outline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    private func shiftMonth(_ delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: selectedDate) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedDate = newDate
            }
        }
    }

    // MARK: - 2. Today's Habits

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.sm) {
            VelaSectionHeader(
                title: L10n.t("Today's Habits", "今日习惯"),
                subtitle: L10n.t("Tap to track, long-press to reset", "轻点记录，长按重置")
            )

            VStack(spacing: 0) {
                ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                    habitRow(habit)
                    if index < habits.count - 1 {
                        Divider()
                            .overlay(VelaTheme.outline)
                            .padding(.leading, 48)
                    }
                }
            }
            .cardSurface()
        }
    }

    private func habitRow(_ habit: JournalHabit) -> some View {
        let count = habitCounts[habit.id] ?? 0

        return Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                habitCounts[habit.id] = (count + 1) % (habit.maxCount + 1)
            }
        } label: {
            HStack(spacing: VelaSpacing.sm) {
                Image(systemName: habit.sfSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VelaTheme.recovery)
                    .frame(width: 28, height: 28)

                Text(habit.displayName())
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(VelaTheme.onSurface)

                Spacer()

                HStack(spacing: 5) {
                    ForEach(0..<habit.maxCount, id: \.self) { i in
                        Circle()
                            .fill(i < count ? VelaTheme.recovery : VelaTheme.outline)
                            .frame(width: 8, height: 8)
                    }
                }

                Text("\(count)/\(habit.maxCount)")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .padding(.vertical, VelaSpacing.sm)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                habitCounts[habit.id] = 0
            } label: {
                Label(L10n.t("Reset", "重置"), systemImage: "arrow.counterclockwise")
            }
            Button {
                habitCounts[habit.id] = habit.maxCount
            } label: {
                Label(L10n.t("Set to max", "设为最大值"), systemImage: "checkmark")
            }
        }
        .accessibilityLabel("\(habit.displayName()), \(count) \(L10n.t("of", "共")) \(habit.maxCount)")
    }

    // MARK: - 3. Food Log

    private var foodLogSection: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.sm) {
            VelaSectionHeader(
                title: L10n.t("Today's Meals", "今日餐食"),
                subtitle: foodEntries.isEmpty
                    ? L10n.t("No meals logged yet", "尚未记录餐食")
                    : L10n.t("\(foodEntries.count) meals · \(totalCalories) kcal", "\(foodEntries.count) 餐 · \(totalCalories) 千卡")
            )

            VStack(spacing: 0) {
                ForEach(Array(foodEntries.enumerated()), id: \.element.id) { index, entry in
                    foodEntryRow(entry)
                    if index < foodEntries.count - 1 {
                        Divider()
                            .overlay(VelaTheme.outline)
                            .padding(.leading, 64)
                    }
                }

                Divider()
                    .overlay(VelaTheme.outline)

                Button {
                    // Opens camera / photo picker
                } label: {
                    HStack(spacing: VelaSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(L10n.t("Add Meal", "添加餐食"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(VelaTheme.recovery)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VelaSpacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Add Meal", "添加餐食"))
            }
            .cardSurface()
        }
    }

    private func foodEntryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: VelaSpacing.sm) {
            RoundedRectangle(cornerRadius: VelaRadius.sm, style: .continuous)
                .fill(VelaTheme.recovery.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.recovery)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                    .lineLimit(1)
                HStack(spacing: VelaSpacing.xs) {
                    Text(entry.time)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(VelaTheme.muted)
                    Text("·")
                        .foregroundStyle(VelaTheme.muted)
                    GlassChip(
                        text: confidenceLabel(entry.confidence),
                        icon: "checkmark.seal.fill"
                    )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.calories)")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(L10n.t("kcal", "千卡"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, VelaSpacing.sm)
    }

    private func confidenceLabel(_ confidence: DataConfidence) -> String {
        switch confidence {
        case .high: return AppLanguage.stored.isChinese ? "高" : "High"
        case .medium: return AppLanguage.stored.isChinese ? "中" : "Med"
        case .low: return AppLanguage.stored.isChinese ? "低" : "Low"
        case .unavailable: return AppLanguage.stored.isChinese ? "未知" : "N/A"
        }
    }

    // MARK: - 4. Vela Memory (Wiki)

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.sm) {
            VelaSectionHeader(
                title: L10n.t("Vela Memory", "Vela 记忆"),
                subtitle: L10n.t("Your health story, co-authored with AI", "你的健康故事，与 AI 共同书写")
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: VelaSpacing.md) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(VelaTheme.recovery)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("Vela Memory", "Vela 记忆"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text(L10n.t("Last updated \(lastUpdatedFormatted)", "最近更新 \(lastUpdatedFormatted)"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(VelaTheme.muted)
                    }

                    Spacer()
                }

                Divider()
                    .overlay(VelaTheme.outline)
                    .padding(.vertical, VelaSpacing.sm)

                ForEach(Array(memoryRows.enumerated()), id: \.element.id) { index, row in
                    memoryRowView(row)
                    if index < memoryRows.count - 1 {
                        Divider()
                            .overlay(VelaTheme.outline)
                            .padding(.leading, 44)
                    }
                }
            }
            .cardSurface()
            .leftAccentStrip(VelaTheme.recovery)
        }
    }

    private func memoryRowView(_ row: MemoryRow) -> some View {
        Button {
            // Navigate to Wiki detail
        } label: {
            HStack(spacing: VelaSpacing.sm) {
                Image(systemName: row.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VelaTheme.recovery)
                    .frame(width: 28, height: 28)

                Text(row.displayTitle())
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(VelaTheme.onSurface)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .contentShape(Rectangle())
            .padding(.vertical, VelaSpacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.displayTitle())
    }
}
