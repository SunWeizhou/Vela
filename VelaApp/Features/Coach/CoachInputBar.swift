import SwiftUI
import SwiftData

struct CoachInputBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var vm: CoachChatVM
    let dashboard: DashboardSummary
    let focus: CoachContextFocus
    let dataCoverageSummary: DataCoverageSummaryModel

    @Binding var showCameraPicker: Bool
    @Binding var showPhotoLibraryPicker: Bool

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: VelaServices
    
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @Query(sort: \AIReportRecord.createdAt, order: .reverse) private var savedReports: [AIReportRecord]

    @FocusState private var inputFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                CoachDataCoverageStrip(model: dataCoverageSummary) {
                    VelaAppState.shared.showSettings = true
                }

                HStack(spacing: 10) {
                    Menu {
                        Button {
                            showCameraPicker = true
                        } label: {
                            Label(L10n.t("Take Photo", "拍照"), systemImage: "camera.fill")
                        }
                        Button {
                            showPhotoLibraryPicker = true
                        } label: {
                            Label(L10n.t("Choose from Library", "从相册选择"), systemImage: "photo.on.rectangle")
                        }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(vm.isStreaming || vm.isAnalyzingFood ? VelaTheme.muted : VelaTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(VelaTheme.borderSoft.opacity(0.5)))
                    }
                    .disabled(vm.isStreaming || vm.isAnalyzingFood)
                    .buttonStyle(.plusButton)

                    TextField(L10n.t("Ask...", "提问..."), text: $vm.draft, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.fg)
                        .padding(.vertical, 8)

                    Button {
                        if !vm.isStreaming {
                            inputFocused = false
                            vm.submit(
                                text: vm.draft,
                                dashboard: dashboard,
                                modelContext: modelContext,
                                journalEntries: journalEntries,
                                savedReports: savedReports,
                                focus: focus,
                                services: services
                            )
                        }
                    } label: {
                        Image(systemName: vm.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(
                                vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming
                                ? VelaTheme.muted
                                : VelaTheme.accent
                            )
                    }
                    .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        inputFocused ? VelaTheme.accent : VelaTheme.borderSoft,
                        lineWidth: inputFocused ? 1.5 : 0.8
                    )
            )
            .animation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion), value: inputFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
