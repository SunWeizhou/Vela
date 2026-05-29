import SwiftUI
import SwiftData

struct WeightLogSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var weightString = ""
    @State private var bodyFatString = ""
    @State private var date = Date()
    @State private var errorMsg: String? = nil

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

                        VStack(spacing: 16) {
                            StyledTextField(
                                label: AppLanguage.stored.isChinese ? "体重 (公斤)" : "Weight (kg)",
                                placeholder: "e.g., 72.5",
                                text: $weightString
                            )
                            .keyboardType(.decimalPad)

                            StyledTextField(
                                label: AppLanguage.stored.isChinese ? "体脂率 (%) - 可选" : "Body Fat (%) - Optional",
                                placeholder: "e.g., 15.4",
                                text: $bodyFatString
                            )
                            .keyboardType(.decimalPad)

                            DatePicker(
                                AppLanguage.stored.isChinese ? "记录日期" : "Date",
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
                            saveWeight()
                        } label: {
                            Text(AppLanguage.stored.isChinese ? "保存记录" : "Save Record")
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
            .navigationTitle(AppLanguage.stored.isChinese ? "记录体重体脂" : "Log Weight & Body Fat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLanguage.stored.isChinese ? "取消" : "Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(VelaTheme.secondaryText)
                }
            }
        }
    }

    private func saveWeight() {
        guard let weightVal = Double(weightString), weightVal > 0 else {
            errorMsg = AppLanguage.stored.isChinese ? "请输入有效的体重值。" : "Please enter a valid weight."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        // 1. Save weight as BiomarkerRecord
        let weightRecord = BiomarkerRecord(
            name: "Weight",
            value: weightVal,
            unit: "kg",
            date: date,
            isOptimal: true,
            referenceMin: 45.0,
            referenceMax: 120.0
        )
        modelContext.insert(weightRecord)

        // 2. Save body fat if available
        if let fatVal = Double(bodyFatString), fatVal > 0 {
            let fatRecord = BiomarkerRecord(
                name: "Body Fat",
                value: fatVal,
                unit: "%",
                date: date,
                isOptimal: true,
                referenceMin: 8.0,
                referenceMax: 25.0
            )
            modelContext.insert(fatRecord)
        }

        // Try to update daily summary record if exists
        let calendar = Calendar.current
        let dayId = DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar)
        let summaryDescriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate { $0.dayIdentifier == dayId }
        )
        if let summaries = try? modelContext.fetch(summaryDescriptor), let first = summaries.first {
            first.bodyWeight = weightVal
            if let fatVal = Double(bodyFatString), fatVal > 0 {
                first.bodyFatPercent = fatVal
            }
        }

        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMsg = AppLanguage.stored.isChinese ? "保存失败，请重试。" : "Save failed, please try again."
        }
    }
}
