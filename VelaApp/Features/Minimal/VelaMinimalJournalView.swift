import SwiftUI
import SwiftData

// MARK: - Historical backfill page

/// 三年 Apple 健康历史回填页面：进度条 + 开始/停止 + 错误提示。
/// 任务由 HistoricalBackfillCoordinator.shared 持有，退出页面也会继续跑。
struct HistoricalBackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var coordinator = HistoricalBackfillCoordinator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(width: 42, height: 42)
                        .background(VelaTheme.rhythmMist, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("回填三年健康历史")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text(coordinator.stateText)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)

                Text("把 Apple 健康里近三年的静息心率、HRV、睡眠、步数、活动能量、体重与训练记录读入 Vela。回填后，长期趋势、今年 vs 去年对比与历年训练量立即可用。原始数据只留在本机。")
                    .font(.system(.footnote, design: .default))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView(value: coordinator.progress.percent)
                        .tint(VelaTheme.rhythmDeep)

                    HStack {
                        Text("\(coordinator.progress.completedDays) / \(coordinator.progress.totalDays) 天")
                            .font(.system(.caption2, design: .default, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("可随时停止，进度已保存")
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }

                if let error = coordinator.lastError {
                    Text("回填中断：\(error)")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(VelaTheme.textColor(for: .poor))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if coordinator.isRunning {
                        coordinator.cancel()
                    } else {
                        coordinator.start(
                            queryService: services.queryService,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    Text(coordinator.isRunning ? "停止回填" : "开始回填")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.cardPress)
                .disabled(coordinator.progress.isComplete && !coordinator.isRunning)

                if coordinator.progress.isComplete {
                    Text("回填已完成。三年健康轨迹与历年训练量现在都已就绪。")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("历史回填")
        .velaRhythmDetailChrome()
        .onAppear {
            coordinator.refreshState()
        }
    }
}

/// 深度专项批次 3：训记历史批量回填页——逐日拉取训记训练（动作/组数/重量），
/// 断点续传。三年 e1RM/容量/肌群频率轨迹的前置条件。
struct XunjiHistoryBackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var service = XunjiHistoryBackfillService.shared
    @State private var apiKey = ""
    @State private var loadKeyFailed = false

    private var progressPercent: Double {
        guard service.totalDays > 0 else { return 0 }
        return min(1, Double(service.completedDays) / Double(service.totalDays))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(width: 42, height: 42)
                        .background(VelaTheme.rhythmMist, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("回填训记训练历史")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("逐日补全动作、组数与重量")
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)

                Text("把训记里的历史训练（动作、组数、重量、时长）逐日读入 Vela，用于个人纪录、容量轨迹与肌群疲劳的长期分析。原始数据只留在本机；进度会保存，可随时停止续传。")
                    .font(.system(.footnote, design: .default))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if loadKeyFailed {
                    Text("未找到训记密钥。请先在训练页填写训记 API Key。")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(VelaTheme.textColor(for: .poor))
                }

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView(value: progressPercent)
                        .tint(VelaTheme.rhythmDeep)

                    HStack {
                        Text("\(service.completedDays) / \(service.totalDays) 天 · 已导入 \(service.importedCount) 条")
                            .font(.system(.caption2, design: .default, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("可随时停止，进度已保存")
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }

                if let error = service.errorMessage {
                    Text("回填暂停：\(error)")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(VelaTheme.textColor(for: .poor))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await startOrStop() }
                } label: {
                    Text(service.isRunning ? "停止回填" : "开始回填")
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.cardPress)

                if service.completedDays >= service.totalDays, service.totalDays > 0 {
                    Text("回填已完成。历史动作、组数与重量已可用于长期分析。")
                        .font(.system(.caption2, design: .default))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("训记历史回填")
        .velaRhythmDetailChrome()
        .onAppear {
            if let saved = try? KeychainService.shared.read(account: "xunji_open_api_key") {
                apiKey = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    @MainActor
    private func startOrStop() async {
        if service.isRunning { return }
        guard !apiKey.isEmpty else {
            loadKeyFailed = true
            return
        }
        loadKeyFailed = false
        try? KeychainService.shared.save(apiKey, account: "xunji_open_api_key")
        await service.run(modelContext: modelContext, apiKey: apiKey)
        VelaAppState.shared.markLocalDataChanged()
    }
}
