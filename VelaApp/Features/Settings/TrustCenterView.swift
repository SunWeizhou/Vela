import SwiftUI
import SwiftData

/// A scrollable history of all agent runs (Morning Brief, Evening Sync, Coach).
/// Shows status, duration, and what was produced.
struct TrustCenterView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: \AgentRunRecord.startedAt,
        order: .reverse
    ) private var runRecords: [AgentRunRecord]

    @State private var selectedRun: AgentRunRecord?

    var body: some View {
        ZStack {
            VelaBackground()

            if runRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(AppLanguage.stored.isChinese
                         ? "尚无 Agent 运行记录"
                         : "No agent run records yet"
                    )
                    .font(.headline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    Text(AppLanguage.stored.isChinese
                         ? "当 Morning Brief 或 Evening Sync 首次运行后，这里会显示运行日志。"
                         : "Run logs will appear here after the first Morning Brief or Evening Sync."
                    )
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
                    .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(runRecords.prefix(100)) { run in
                            runCard(run)
                        }
                    }
                    .padding(VelaTheme.screenPadding)
                }
            }
        }
        .navigationTitle(AppLanguage.stored.isChinese ? "信任中心" : "Trust Center")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedRun) { run in
            runDetailSheet(run)
        }
    }

    // MARK: - Run Card

    private func runCard(_ run: AgentRunRecord) -> some View {
        Button {
            selectedRun = run
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconFor(run.agentName))
                    .font(.title3)
                    .foregroundStyle(colorFor(run.status))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(labelFor(run.agentName))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VelaTheme.primaryText)
                        Spacer()
                        statusBadge(run.status)
                    }
                    if let endedAt = run.endedAt {
                        Text(durationText(start: run.startedAt, end: endedAt))
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                    if let reason = run.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VelaTheme.surface)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail Sheet

    private func runDetailSheet(_ run: AgentRunRecord) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    detailRow(
                        title: AppLanguage.stored.isChinese ? "Agent" : "Agent",
                        value: labelFor(run.agentName)
                    )
                    detailRow(
                        title: AppLanguage.stored.isChinese ? "状态" : "Status",
                        value: run.status
                    )
                    detailRow(
                        title: AppLanguage.stored.isChinese ? "开始时间" : "Started",
                        value: run.startedAt.formatted()
                    )
                    if let endedAt = run.endedAt {
                        detailRow(
                            title: AppLanguage.stored.isChinese ? "结束时间" : "Ended",
                            value: endedAt.formatted()
                        )
                        detailRow(
                            title: AppLanguage.stored.isChinese ? "耗时" : "Duration",
                            value: durationText(start: run.startedAt, end: endedAt)
                        )
                    }
                    if let reason = run.reason {
                        detailRow(
                            title: AppLanguage.stored.isChinese ? "原因" : "Reason",
                            value: reason
                        )
                    }
                    if !run.inputContextHash.isEmpty {
                        detailRow(
                            title: AppLanguage.stored.isChinese ? "上下文哈希" : "Context Hash",
                            value: String(run.inputContextHash.prefix(16))
                        )
                    }
                    if !run.outputSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLanguage.stored.isChinese ? "输出摘要" : "Output")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VelaTheme.mutedText)
                            Text(run.outputSummary)
                                .font(.caption)
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                    }
                    if let error = run.errorMessage {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLanguage.stored.isChinese ? "错误" : "Error")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VelaTheme.recovery)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                    }
                }
                .padding()
            }
            .background(VelaBackground())
            .navigationTitle(AppLanguage.stored.isChinese ? "运行详情" : "Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLanguage.stored.isChinese ? "完成" : "Done") { selectedRun = nil }
                }
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.primaryText)
        }
    }

    private func labelFor(_ agentName: String) -> String {
        switch agentName {
        case "morning_brief": return AppLanguage.stored.isChinese ? "早间简报" : "Morning Brief"
        case "evening_wiki_sync": return AppLanguage.stored.isChinese ? "晚间同步" : "Evening Sync"
        case "coach": return "Coach"
        default: return agentName
        }
    }

    private func iconFor(_ agentName: String) -> String {
        switch agentName {
        case "morning_brief": return "sunrise.fill"
        case "evening_wiki_sync": return "moon.stars.fill"
        case "coach": return "bubble.left.and.bubble.right.fill"
        default: return "gear"
        }
    }

    private func colorFor(_ status: String) -> Color {
        switch status {
        case "success": return VelaTheme.energy
        case "failed": return VelaTheme.recovery
        case "running": return VelaTheme.accent
        case "skipped": return VelaTheme.mutedText
        default: return VelaTheme.secondaryText
        }
    }

    private func statusBadge(_ status: String) -> some View {
        let label: String
        switch status {
        case "success": label = AppLanguage.stored.isChinese ? "成功" : "Success"
        case "failed": label = AppLanguage.stored.isChinese ? "失败" : "Failed"
        case "running": label = AppLanguage.stored.isChinese ? "运行中" : "Running"
        case "skipped": label = AppLanguage.stored.isChinese ? "已跳过" : "Skipped"
        default: label = status
        }
        return Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(colorFor(status))
    }

    private func durationText(start: Date, end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start))
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
