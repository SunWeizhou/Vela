import SwiftData
import SwiftUI
import UIKit

// MARK: - Shared Types

// MARK: - CoachChatVM and helper structures have been moved to CoachChatVM.swift

// Note: CoachChatMessage, CoachRecoveryActionButton, and CoachDataCoverageStrip have been moved to CoachMessageBubble.swift

// MARK: - Mini Coach Panel (for MetricCoachCard sheets)

struct CoachChatPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: VelaServices
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @Query(sort: \AIReportRecord.createdAt, order: .reverse) private var savedReports: [AIReportRecord]

    let dashboard: DashboardSummary
    let focus: CoachContextFocus
    @StateObject private var vm = CoachChatVM()

    // Camera / Food Photo
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var capturedImage: UIImage? = nil
    @State private var dataCoverageSummary = DataCoverageSummaryModel.unknown

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        // Welcome
                        if vm.messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundStyle(VelaTheme.accent)
                                Text(L10n.t("Ask about \(focus.title)", "询问关于\(focus.title)"))
                                    .font(.headline)
                                    .foregroundStyle(VelaTheme.fg)
                            }
                            .padding(.top, 20)
                        }

                        ForEach(vm.messages.filter { !$0.isStreaming }) { msg in
                            MiniBubble(message: msg) { action in
                                handleRecoveryAction(action)
                            }
                                .id(msg.id)
                        }

                        if vm.isStreaming {
                            MiniStreamingBubble(content: vm.streamingContent)
                                .id("streaming")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: vm.messages.count) {
                    if let id = vm.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .onChange(of: vm.streamingContent) {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            CoachInputBar(
                vm: vm,
                dashboard: dashboard,
                focus: focus,
                dataCoverageSummary: dataCoverageSummary,
                showCameraPicker: $showCameraPicker,
                showPhotoLibraryPicker: $showPhotoLibraryPicker
            )
        }
        .onAppear { vm.refreshKeyState() }
        .task {
            await loadDataCoverageSummary()
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera, selectedImage: $capturedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            Task {
                await vm.analyzeFoodPhoto(
                    image,
                    dashboard: dashboard,
                    modelContext: modelContext,
                    journalEntries: journalEntries,
                    savedReports: savedReports,
                    focus: focus,
                    services: services
                )
            }
        }
        .alert("对话未保存", isPresented: Binding(
            get: { vm.persistenceError != nil },
            set: { if !$0 { vm.persistenceError = nil } }
        )) {
            Button("好", role: .cancel) { vm.persistenceError = nil }
        } message: {
            Text(vm.persistenceError ?? "")
        }
    }

    private func handleRecoveryAction(_ action: LLMErrorRecoveryAction) {
        switch action.destination {
        case .settings:
            VelaAppState.shared.showSettings = true
        case .retry:
            vm.retryLastFailedRequest(
                dashboard: dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                services: services
            )
        }
    }

    private func loadDataCoverageSummary() async {
        let groups = await DataCoverageGroupFactory.loadPriorityGroups()
        let summary = DataCoverageSummaryModel.build(groups: groups)
        withAnimation(VelaTheme.smooth) {
            dataCoverageSummary = summary
        }
    }
}

// Note: MessageSegment, parseMessageContent, AppleIntelligenceLoaderDots, MiniBubble, and MiniStreamingBubble have been moved to CoachMessageBubble.swift

// MARK: - Journal Correlation Tool

/// Queries how a specific journal tag correlates with health scores by running
/// the JournalCorrelationEngine against SwiftData records.
struct JournalCorrelationTool: AgentTool {
    let name = "journal_correlation"
    let description = "Query how a specific journal tag (e.g., caffeine, alcohol, meditation, late_meal) correlates with sleep, recovery, strain scores, HRV, and RHR. Returns real correlation data computed from the user's journal entries and daily health snapshots."

    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "tag": .object([
                    "type": .string("string"),
                    "description": .string("The journal tag to analyze. Common tags: caffeine, alcohol, late_meal, heavy_meal, exercise, stressed, meditation, hydration, supplements, sick, travel, menstruation, sleep, recovery, training, mood."),
                ]),
            ]),
            "required": .array([.string("tag")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag"] as? String else {
            return "Error: missing 'tag' argument."
        }
        return await MainActor.run {
            let modelContext = executionContext.modelContext
            // Fetch recent journal entries and health snapshots
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
            let journalDescriptor = FetchDescriptor<JournalEntryRecord>(
                predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= thirtyDaysAgo },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let journalEntries = (try? modelContext.fetch(journalDescriptor)) ?? []
            let healthDescriptor = FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= thirtyDaysAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let healthRecords = (try? modelContext.fetch(healthDescriptor)) ?? []
            let healthSnapshots = healthRecords.map { $0.toSnapshot() }

            // Run the correlation engine
            let engine = JournalCorrelationEngine()
            let allCorrelations = engine.correlateTags(journalEntries: journalEntries, snapshots: healthSnapshots)
            let topCorrelations = engine.topCorrelations(correlations: allCorrelations)

            // Extract results for the requested tag
            let matched = topCorrelations.filter { $0.tag.lowercased() == tag.lowercased() }
            guard !matched.isEmpty else {
                let availableTags = topCorrelations.prefix(8).map(\.tag).joined(separator: ", ")
                return availableTags.isEmpty
                    ? "No correlation data found. Need more journal entries and health snapshots to compute behavior-impact relationships."
                    : "No correlation data for '\(tag)'. Available tags with correlations: \(availableTags)."
            }

            let formatted = engine.formatCorrelationsForAI(matched)
            return formatted.isEmpty ? "Correlation data computed but formatting produced empty output. Try a different tag." : formatted
        }
    }
}
