import SwiftUI
import SwiftData

struct VelaMeView: View {
    @Environment(\.velaScrollDirection) private var scrollDirection
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]

    private var onboarding: OnboardingState? { onboardingStates.first }
    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileHeader
                bodyModelCard
                coachMemoryCard
                personalToolsCard
                dataAndTrustCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileHeader: some View {
        VelaHeroCard(
            title: "Body Model",
            subtitle: onboarding?.firstBrief.isEmpty == false ? onboarding?.firstBrief : "你的训练目标、偏好、设备和健康数据会合并成 Coach 的个人上下文。",
            systemImage: "person.crop.circle.fill",
            accent: VelaTheme.accent
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricScoreCard(
                    title: "Goal",
                    value: displayGoal(onboarding?.goalProfile.primaryGoal ?? "maintain"),
                    subtitle: onboarding?.goalProfile.experienceLevel ?? "unknown",
                    accent: VelaTheme.accent
                )
                MetricScoreCard(
                    title: "Training",
                    value: "\(onboarding?.trainingPreference.weeklyTrainingDays ?? 3)x",
                    subtitle: "\(onboarding?.trainingPreference.sessionDurationMinutes ?? 45) min/session",
                    accent: VelaTheme.strain
                )
            }
        }
    }

    private var bodyModelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile")
                .font(VelaTheme.caption1())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.muted)
                .textCase(.uppercase)

            profileLine("训练风格", onboarding?.trainingPreference.trainingStyle ?? "mixed", icon: "figure.run")
            profileLine("可用设备", equipmentText, icon: "dumbbell.fill")
            profileLine("教练风格", onboarding?.coachingPreference.style ?? "explanatory", icon: "brain.head.profile")
            profileLine("数据可信度", onboarding?.initialBodySnapshot.dataConfidence.rawValue.uppercased() ?? dashboard.recovery.confidence.rawValue.uppercased(), icon: "checkmark.seal.fill")

            if let missing = onboarding?.missingData, !missing.isEmpty {
                Text("待补充: \(missing.joined(separator: ", "))")
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var coachMemoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Coach Memory")
                    .font(VelaTheme.caption1())
                    .fontWeight(.bold)
                    .foregroundStyle(VelaTheme.muted)
                    .textCase(.uppercase)
                Spacer()
                Text("\(coachArtifacts.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.accent)
            }

            if let artifact = coachArtifacts.first?.artifact {
                CoachArtifactCard(artifact: artifact, compact: true)
            } else {
                EmptyStateView(
                    icon: "tray",
                    title: "暂无 Coach Artifact",
                    subtitle: "完成训练、查看 Today 或与 Coach 对话后，这里会显示可追溯的建议。"
                )
            }
        }
    }

    private var personalToolsCard: some View {
        VStack(spacing: 0) {
            settingsLink("手记与主观反馈", value: "Journal", icon: "book.pages.fill", color: Color(hex: "#FF9F0A"), destination: VelaJournalView())
            Divider().padding(.leading, 54)
            settingsLink("用户健康档案", value: "Wiki", icon: "doc.text.fill", color: VelaTheme.muted, destination: UserWikiArchiveView())
            Divider().padding(.leading, 54)
            settingsLink("生物学资料", value: "Biology", icon: "person.text.rectangle.fill", color: Color(hex: "#00A896"), destination: BiologyView())
            Divider().padding(.leading, 54)
            settingsLink("完整设置", value: "Settings", icon: "gearshape.fill", color: Color(hex: "#5C6BC0"), destination: VelaSettingsView())
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }

    private var dataAndTrustCard: some View {
        VStack(spacing: 0) {
            settingsLink("数据覆盖", value: "Signals", icon: "waveform.path.ecg.rectangle.fill", color: Color(hex: "#30A2FF"), destination: DataCoverageView())
            Divider().padding(.leading, 54)
            settingsLink("信任中心", value: "Logs", icon: "checkmark.shield.fill", color: VelaTheme.success, destination: TrustCenterView())
            Divider().padding(.leading, 54)
            settingsLink("AI 模型设置", value: "Model", icon: "cpu.fill", color: Color(hex: "#AF52DE"), destination: AIModelSettingsView())
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }

    private var equipmentText: String {
        guard let equipment = onboarding?.equipmentProfile.equipment, !equipment.isEmpty else {
            return "home + gym"
        }
        return equipment.prefix(3).joined(separator: ", ")
    }

    private func profileLine(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(VelaTheme.accent.opacity(0.1)))
            Text(title)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg)
            Spacer()
            Text(value)
                .font(VelaTheme.subheadline())
                .fontWeight(.semibold)
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(1)
        }
    }

    private func settingsLink<Destination: View>(
        _ title: String,
        value: String,
        icon: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(color))
                Text(title)
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text(value)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func displayGoal(_ goal: String) -> String {
        switch goal {
        case "muscle_gain": return "Muscle"
        case "fat_loss": return "Fat loss"
        case "performance": return "Performance"
        case "health": return "Health"
        default: return "Maintain"
        }
    }
}

// MARK: - VelaJournalView — Bevel Replica Journal Tab
// Persisted journal checklist × Golden calendar checks strip × Segments cluster toggles

struct VelaJournalView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var entries: [JournalEntryRecord]

    // Local states for custom segmented values (0:✕, 1:–, 2:✓)
    @State private var lowCarbState: Int = 1
    @State private var addedSugarState: Int = 1
    @State private var ketoDietState: Int = 1
    @State private var bedDeviceState: Int = 1
    
    // Log row dynamic display values
    @State private var caffeineValueText: String = "- mg"
    @State private var hydrationValueText: String = "- ml"
    @State private var moodValueText: String = "-"
    @State private var alcoholValueText: String = "- 杯"
    
    // For navigation/sheet triggers
    @State private var showCaffeineLogger = false
    @State private var showMoodLogger = false
    @State private var showWaterLogger = false
    @State private var showAlcoholLogger = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Journal Header Title Row
                journalHeader
                
                // 2. Weekly Calendar Checks strip
                weeklyChecksStrip
                
                // 3. Category daytime title
                VStack(alignment: .leading, spacing: 12) {
                    Text(dateSectionTitle(for: dashboardVM.selectedDate))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .padding(.top, 4)
                    
                    Text("习惯与记录")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                        .textCase(.uppercase)
                        .padding(.leading, 2)
                    
                    // Checklist Rows
                    VStack(spacing: 10) {
                        // Row 1: 低碳水化合物 (Bread icon + segment)
                        segmentedJournalRow(
                            icon: "fork.knife",
                            title: "低碳水化合物",
                            state: $lowCarbState
                        )
                        
                        // Row 2: 咖啡因 (Coffee cup icon + log chevron)
                        inputJournalRow(
                            icon: "cup.and.saucer.fill",
                            title: "咖啡因",
                            valuePlaceholder: caffeineValueText,
                            onTap: { showCaffeineLogger = true }
                        )
                        
                        // Row 3: 每日心情 (Smiling face icon + log chevron)
                        inputJournalRow(
                            icon: "face.smiling.fill",
                            title: "每日心情",
                            valuePlaceholder: moodValueText,
                            onTap: { showMoodLogger = true }
                        )
                        
                        // Row 4: 添加糖 (Candy icon + segment)
                        segmentedJournalRow(
                            icon: "birthday.cake.fill",
                            title: "添加糖",
                            state: $addedSugarState
                        )
                        
                        // Row 5: 生酮饮食 (Avocado/Leaf icon + segment)
                        segmentedJournalRow(
                            icon: "leaf.fill",
                            title: "生酮饮食",
                            state: $ketoDietState
                        )
                        
                        // Row 6: 补水 (Water drop icon + log chevron)
                        inputJournalRow(
                            icon: "drop.fill",
                            title: "补水",
                            valuePlaceholder: hydrationValueText,
                            onTap: { showWaterLogger = true }
                        )
                        
                        // Row 7: 酒 (Wine glass icon + log chevron)
                        inputJournalRow(
                            icon: "wineglass.fill",
                            title: "酒",
                            valuePlaceholder: alcoholValueText,
                            onTap: { showAlcoholLogger = true }
                        )
                        
                        // Row 8: 在床上使用设备 (Phone icon + segment)
                        segmentedJournalRow(
                            icon: "iphone",
                            title: "在床上使用设备",
                            state: $bedDeviceState
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            loadRealJournalData()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            loadRealJournalData()
        }
        .onChange(of: entries) { _, _ in
            loadRealJournalData()
        }
        .sheet(isPresented: $showCaffeineLogger) {
            CaffeineLoggerView { amount in
                saveQuickEntry(tags: ["caffeine", "咖啡因"], note: "摄入咖啡因 \(Int(amount)) mg", value: amount, unit: "mg")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showWaterLogger) {
            WaterLoggerView { amount in
                saveQuickEntry(tags: ["hydration", "补水"], note: "饮水 \(Int(amount)) ml", value: amount, unit: "ml")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showMoodLogger) {
            MoodLoggerView { score, note in
                let moodText = formatMoodValue(score)
                saveQuickEntry(tags: ["mood", "每日心情"], note: "心情: \(moodText). 备注: \(note)", value: score)
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showAlcoholLogger) {
            AlcoholLoggerView { amount in
                saveQuickEntry(tags: ["alcohol", "酒"], note: "饮酒 \(amount) 标准杯", value: amount, unit: "杯")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
    }

    // MARK: - Date Formatting Helpers
    private func headerDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func dateSectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天的条目"
        } else if calendar.isDateInYesterday(date) {
            return "昨天的条目"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日的条目"
            return formatter.string(from: date)
        }
    }

    private func formatMoodValue(_ val: Double) -> String {
        let intVal = Int(val)
        switch intVal {
        case 1: return "😞 糟糕"
        case 2: return "😐 平淡"
        case 3: return "🙂 还行"
        case 4: return "😃 开心"
        case 5: return "🤩 极佳"
        default: return "🙂 还行"
        }
    }

    // MARK: - SwiftData Loading Engine
    private func loadRealJournalData() {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        
        let dayEntries = entries.filter { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: targetDay)
        }
        
        // Reset local states to default (1: –)
        lowCarbState = 1
        addedSugarState = 1
        ketoDietState = 1
        bedDeviceState = 1
        
        caffeineValueText = "- mg"
        hydrationValueText = "- ml"
        moodValueText = "-"
        alcoholValueText = "- 杯"
        
        let sortedDayEntries = dayEntries.sorted(by: { $0.createdAt > $1.createdAt })
        
        // Populate habit states (latest entry for each habit)
        for entry in sortedDayEntries {
            if entry.tags.contains("低碳水化合物"), let val = entry.value {
                lowCarbState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("添加糖"), let val = entry.value {
                addedSugarState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("生酮饮食"), let val = entry.value {
                ketoDietState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("在床上使用设备"), let val = entry.value {
                bedDeviceState = Int(val)
                break
            }
        }
        
        // Sum logger values
        let caffeineSum = dayEntries.filter { $0.tags.contains("caffeine") || $0.tags.contains("咖啡因") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if caffeineSum > 0 {
            caffeineValueText = "\(Int(caffeineSum)) mg"
        }
        
        let hydrationSum = dayEntries.filter { $0.tags.contains("hydration") || $0.tags.contains("补水") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if hydrationSum > 0 {
            hydrationValueText = "\(Int(hydrationSum)) ml"
        }
        
        let alcoholSum = dayEntries.filter { $0.tags.contains("alcohol") || $0.tags.contains("酒") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if alcoholSum > 0 {
            alcoholValueText = String(format: "%.1f 杯", alcoholSum)
        }
        
        // Latest mood
        if let latestMoodEntry = sortedDayEntries.first(where: { $0.tags.contains("mood") || $0.tags.contains("每日心情") }) {
            if let moodVal = latestMoodEntry.value {
                moodValueText = formatMoodValue(moodVal)
            }
        }
    }

    // MARK: - Journal Header Title Row
    private var journalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(headerDateString(for: dashboardVM.selectedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Analysis button
                Button {
                    VelaAppState.shared.routeToCoach(question: journalAnalysisQuestion)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("分析")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .velaNativeCard(radius: 16)
                }
                .buttonStyle(.plain)
                
                // Ellipsis actions
                Menu {
                    Button("记录咖啡因") {
                        showCaffeineLogger = true
                    }
                    Button("记录饮水") {
                        showWaterLogger = true
                    }
                    Button("记录心情") {
                        showMoodLogger = true
                    }
                    Button("记录饮酒") {
                        showAlcoholLogger = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.cardBg))
                        .overlay(Circle().stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var journalAnalysisQuestion: String {
        "请结合我在 \(dateSectionTitle(for: dashboardVM.selectedDate)) 的手记、标签和健康数据，分析可能影响恢复、睡眠和训练状态的模式，并给出下一步建议。"
    }

    // MARK: - Weekly Calendar Checks strip
    private var weeklyChecksStrip: some View {
        let calendar = Calendar.current
        let selected = dashboardVM.selectedDate
        let weekday = calendar.component(.weekday, from: selected) // 1 = Sunday, 7 = Saturday
        let daysToSubtract = weekday - 1
        let sunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: selected)) ?? selected
        
        let weekDates: [Date] = (0..<7).compactMap { idx in
            calendar.date(byAdding: .day, value: idx, to: sunday)
        }
        
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { idx in
                let date = weekDates[idx]
                let isSelected = calendar.isDate(date, inSameDayAs: selected)
                let isToday = calendar.isDate(date, inSameDayAs: Date())
                let dayNumber = calendar.component(.day, from: date)
                
                // Let's check if there are habit entries on this day to show the golden checkmark!
                let hasEntry = entries.contains { entry in
                    calendar.isDate(entry.createdAt, inSameDayAs: date)
                }
                
                Button {
                    dashboardVM.selectedDate = date
                } label: {
                    VStack(spacing: 8) {
                        Text(weekdays[idx])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                        
                        Text("\(dayNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : VelaTheme.fg)
                            .frame(width: 26, height: 26)
                            .background(
                                Group {
                                    if isSelected {
                                        Circle()
                                            .fill(VelaTheme.accent) // Selected circle
                                    } else if isToday {
                                        Circle()
                                            .stroke(VelaTheme.accent, lineWidth: 1.5) // Today indicator
                                    }
                                }
                            )
                        
                        // Golden Circle Checkmark indicator
                        if hasEntry {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "#FFB74D")) // Soft gold/amber
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "#E5E5EA")) // Gray empty circle
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .velaNativeCard(radius: 18)
    }

    // MARK: - Segmented Action Row (✕, –, ✓ toggles)
    private func segmentedJournalRow(icon: String, title: String, state: Binding<Int>) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                // Colored icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            
            Spacer()
            
            // Custom segment selector container (✕, –, ✓)
            HStack(spacing: 0) {
                segmentButton(title: title, label: "✕", index: 0, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, label: "–", index: 1, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, label: "✓", index: 2, state: state)
            }
            .background(VelaTheme.systemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .velaNativeCard(radius: 16)
    }

    private func segmentButton(title: String, label: String, index: Int, state: Binding<Int>) -> some View {
        Button {
            state.wrappedValue = index
            saveQuickEntry(tags: [title], note: "习惯打卡: \(title) - \(label)", value: Double(index))
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(state.wrappedValue == index ? VelaTheme.fg : VelaTheme.meta)
                .frame(width: 32, height: 30)
                .background(
                    Group {
                        if state.wrappedValue == index {
                            VelaTheme.cardBg
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input logger Row (Caffeine, water, mood logs)
    private func inputJournalRow(icon: String, title: String, valuePlaceholder: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(valuePlaceholder)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.meta)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.meta)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(VelaTheme.systemGroupedBackground))
                        .overlay(Circle().stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .velaNativeCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - SwiftData saving engine
    private func saveQuickEntry(tags: [String], note: String, value: Double? = nil, unit: String? = nil) {
        let calendar = Calendar.current
        let now = Date()
        let selected = dashboardVM.selectedDate
        
        var components = calendar.dateComponents([.year, .month, .day], from: selected)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        let targetDate = calendar.date(from: components) ?? selected
        
        let entry = JournalEntryRecord(createdAt: targetDate, tags: tags, note: note, value: value, unit: unit)
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save journal entry: \(error)")
        }
        loadRealJournalData()
    }
}

// MARK: - CaffeineLoggerView
struct CaffeineLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customAmount: Double = 80.0
    
    let quickOptions = [
        ("浓缩咖啡", "espresso", 64.0, "cup.and.saucer.fill"),
        ("美式咖啡", "americano", 120.0, "cup.and.saucer"),
        ("拿铁", "latte", 80.0, "cup.and.saucer.fill"),
        ("绿茶", "greentea", 35.0, "leaf.fill")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录咖啡因")
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
                VStack(spacing: 24) {
                    Text("输入或选择摄入的咖啡因量。这会有助于 AI 预测它对你深度睡眠和能量水平的长期影响。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(customAmount))")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(VelaTheme.accent)
                            Text("mg")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        Slider(value: $customAmount, in: 0...400, step: 5)
                            .tint(VelaTheme.accent)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷选项")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickOptions, id: \.1) { name, key, val, icon in
                                    Button {
                                        customAmount = val
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(VelaTheme.accent)
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                                            
                                            Text(name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(VelaTheme.fg)
                                            
                                            Text("\(Int(val)) mg")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(VelaTheme.meta)
                                        }
                                        .frame(width: 90, height: 110)
                                        .velaNativeCard(radius: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(customAmount == val ? VelaTheme.accent : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        onSave(customAmount)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                            .shadow(color: VelaTheme.accent.opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - WaterLoggerView
struct WaterLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customAmount: Double = 250.0
    
    let quickOptions = [
        ("小杯", 250.0, "drop.fill"),
        ("中杯", 350.0, "drop.fill"),
        ("大杯", 500.0, "drop.fill"),
        ("整瓶", 750.0, "drop.fill")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录补水")
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
                VStack(spacing: 24) {
                    Text("记录今天摄入的水分。水分补充充足可以提高身体在睡眠期间的自我恢复效能。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(customAmount))")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#4285F4"))
                            Text("ml")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        Slider(value: $customAmount, in: 0...1000, step: 50)
                            .tint(Color(hex: "#4285F4"))
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷选项")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickOptions, id: \.1) { name, val, icon in
                                    Button {
                                        customAmount = val
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color(hex: "#4285F4"))
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(Color(hex: "#E8F0FE")))
                                            
                                            Text(name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(VelaTheme.fg)
                                            
                                            Text("\(Int(val)) ml")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(VelaTheme.meta)
                                        }
                                        .frame(width: 90, height: 110)
                                        .velaNativeCard(radius: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(customAmount == val ? Color(hex: "#4285F4") : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        onSave(customAmount)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#4285F4")))
                            .shadow(color: Color(hex: "#4285F4").opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - MoodLoggerView
struct MoodLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double, String) -> Void
    
    @State private var selectedScore: Double = 3.0
    @State private var noteText: String = ""
    
    let moodOptions = [
        (1.0, "😞", "糟糕"),
        (2.0, "😐", "平淡"),
        (3.0, "🙂", "还行"),
        (4.0, "😃", "开心"),
        (5.0, "🤩", "极佳")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录心情")
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
                VStack(spacing: 24) {
                    Text("记录今天你的整体情绪感受。AI 会基于心率变异性(HRV)等生理指标与心境波动建立深度习惯网络模型。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 10) {
                        ForEach(moodOptions, id: \.0) { score, emoji, label in
                            Button {
                                selectedScore = score
                            } label: {
                                VStack(spacing: 6) {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                    Text(label)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(selectedScore == score ? VelaTheme.fg : VelaTheme.meta)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(selectedScore == score ? Color.white : Color(hex: "#E5E5EA").opacity(0.2))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedScore == score ? VelaTheme.accent : Color.clear, lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(selectedScore == score ? 0.03 : 0.0), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日备注 (可选)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 4)
                        
                        TextField("记录一些让你开心或焦虑的小事...", text: $noteText)
                            .font(.system(size: 14))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Button {
                        onSave(selectedScore, noteText)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                            .shadow(color: VelaTheme.accent.opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - AlcoholLoggerView
struct AlcoholLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customDrinks: Double = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录饮酒")
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
                VStack(spacing: 24) {
                    Text("酒精摄入会强烈抑制副交感神经系统，导致夜间静息心率(RHR)升高，HRV 暴跌，深度及 REM 睡眠显著减少。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f", customDrinks))
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#8B0000"))
                            Text("标准杯")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        HStack(spacing: 40) {
                            Button {
                                if customDrinks > 0 {
                                    customDrinks -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(VelaTheme.muted)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                customDrinks += 0.5
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(VelaTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("💡 什么是 1 标准杯？")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Text("一标准杯大约含有 10 克纯酒精：\n· 1 杯普通啤酒 (约 330ml, 4.5%)\n· 1 杯红葡萄酒 (约 150ml, 12%)\n· 1 盎司烈性白酒 (约 45ml, 40%)")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(5)
                    }
                    .padding(18)
                    .velaNativeCard(radius: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    
                    Button {
                        onSave(customDrinks)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#8B0000")))
                            .shadow(color: Color(hex: "#8B0000").opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}
