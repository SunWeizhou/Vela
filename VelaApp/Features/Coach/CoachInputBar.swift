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

    private var canSubmit: Bool {
        !vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 8) {
            // Optional Data Coverage Banner
            if dataCoverageSummary.status != .high && dataCoverageSummary.status != .unknown {
                CoachDataCoverageStrip(model: dataCoverageSummary) {
                    VelaAppState.shared.showSettings = true
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Media / Attachment Menu
                Menu {
                    Button {
                        showCameraPicker = true
                    } label: {
                        Label(L10n.t("Take Photo", "拍照分析餐食"), systemImage: "camera.fill")
                    }
                    Button {
                        showPhotoLibraryPicker = true
                    } label: {
                        Label(L10n.t("Choose from Library", "从相册选择照片"), systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(vm.isStreaming || vm.isAnalyzingFood ? VelaTheme.muted : VelaTheme.accent)
                        .frame(width: 36, height: 36)
                }
                .disabled(vm.isStreaming || vm.isAnalyzingFood)
                .buttonStyle(.plain)
                .accessibilityLabel("添加附件或图片")

                // Multi-line Input Field Container
                HStack(alignment: .center, spacing: 8) {
                    TextField(
                        L10n.t("Ask anything about your health, recovery or workouts...", "询问任何关于健康、恢复、训练或营养的问题..."),
                        text: $vm.draft,
                        axis: .vertical
                    )
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(VelaTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            inputFocused ? VelaTheme.accent.opacity(0.8) : VelaTheme.borderSoft,
                            lineWidth: inputFocused ? 1.5 : 0.8
                        )
                )

                // Send / Stop Action Button
                Button {
                    if vm.isStreaming {
                        vm.cancelActiveResponse()
                    } else if canSubmit {
                        inputFocused = false
                        vm.submit(
                            dashboard: dashboard,
                            modelContext: modelContext,
                            journalEntries: journalEntries,
                            savedReports: savedReports,
                            focus: focus,
                            services: services
                        )
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                vm.isStreaming
                                ? VelaTheme.strainColor
                                : (canSubmit ? VelaTheme.accent : VelaTheme.borderSoft.opacity(0.6))
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(
                                vm.isStreaming || canSubmit ? Color.white : VelaTheme.muted
                            )
                    }
                }
                .disabled(!vm.isStreaming && !canSubmit)
                .buttonStyle(.cardPress)
                .accessibilityLabel(vm.isStreaming ? "停止生成" : "发送消息")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .animation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion), value: inputFocused)
    }
}
