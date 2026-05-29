import SwiftUI

struct DateNavigationBar: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    @State private var dragOffset: CGFloat = 0

    /// When non-nil, the bar reads/writes this binding instead of viewModel.selectedDate.
    /// Detail views should use this to avoid polluting the shared date state.
    var date: Binding<Date>?

    private var effectiveDate: Binding<Date> {
        date ?? Binding(
            get: { viewModel.selectedDate },
            set: { viewModel.selectedDate = $0 }
        )
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(effectiveDate.wrappedValue)
    }

    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let today = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        return ninetyDaysAgo...today
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let prev = Calendar.current.date(byAdding: .day, value: -1, to: effectiveDate.wrappedValue) ?? effectiveDate.wrappedValue
                        effectiveDate.wrappedValue = prev
                    }
                    onDateChanged()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(formattedDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)

                        if isToday {
                            Text(L10n.t("Today", "今日"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(VelaTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(VelaTheme.accent.opacity(0.15))
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showDatePicker) {
                    datePickerSheet
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        let next = Calendar.current.date(byAdding: .day, value: 1, to: effectiveDate.wrappedValue) ?? effectiveDate.wrappedValue
                        if next <= Date() { effectiveDate.wrappedValue = next }
                    }
                    onDateChanged()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isToday ? VelaTheme.mutedText : VelaTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isToday)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)

            if !isToday {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        effectiveDate.wrappedValue = Date()
                    }
                    onDateChanged()
                } label: {
                    Text(L10n.t("Back to today", "回到今天"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            let prev = Calendar.current.date(byAdding: .day, value: -1, to: effectiveDate.wrappedValue) ?? effectiveDate.wrappedValue
                            effectiveDate.wrappedValue = prev
                        }
                        onDateChanged()
                    } else if value.translation.width < -threshold {
                        if !isToday {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                let next = Calendar.current.date(byAdding: .day, value: 1, to: effectiveDate.wrappedValue) ?? effectiveDate.wrappedValue
                                if next <= Date() { effectiveDate.wrappedValue = next }
                            }
                            onDateChanged()
                        }
                    }
                    dragOffset = 0
                }
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.70))
                .shadow(color: Color.black.opacity(0.05), radius: 14, y: 6)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        if AppLanguage.stored.isChinese {
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEE"
        } else {
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "EEE, MMM d"
        }
        return formatter.string(from: effectiveDate.wrappedValue)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: effectiveDate,
                    in: dateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle(L10n.t("Select Date", "选择日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func onDateChanged() {
        // When using local date binding, set the viewModel's selectedDate temporarily
        // so refresh queries the correct date. Reset it back after.
        if date != nil {
            viewModel.selectedDate = effectiveDate.wrappedValue
        }
        Task { await viewModel.refresh(modelContext: modelContext, force: true) }
    }
}
