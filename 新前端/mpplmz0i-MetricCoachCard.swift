import SwiftUI

struct MetricCoachCard: View {
    let dashboard: DashboardSummary
    let focus: CoachContextFocus
    var suggestedQuestion: String?

    @State private var streamText = ""
    @State private var isStreaming = false
    @State private var hasFinished = false
    @State private var errorMessage: String? = nil
    @State private var isBouncing = false
    
    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(isStreaming ? Color.clear : VelaTheme.accent)
                    .overlay(
                        Group {
                            if isStreaming {
                                Image(systemName: "sparkles")
                                    .font(.headline)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.pink, .purple, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .scaleEffect(isBouncing ? 1.25 : 0.8)
                                    .opacity(isBouncing ? 1.0 : 0.4)
                                    .task {
                                        isBouncing = false
                                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                            isBouncing = true
                                        }
                                    }
                            }
                        }
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLanguage.stored.isChinese ? "让 Coach 实时分析" : "Vela Coach Live")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(AppLanguage.stored.isChinese ? "由 DeepSeek 提供强力支持" : "Powered by DeepSeek AI")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }

                Spacer()
                
                if isStreaming {
                    Text(AppLanguage.stored.isChinese ? "分析中..." : "Analyzing...")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(VelaTheme.accent.opacity(0.12), in: Capsule())
                }
            }

            if !streamText.isEmpty || errorMessage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(VelaTheme.stress)
                            .padding(.vertical, 4)
                    } else {
                        MarkdownText(markdown: streamText, isStreaming: isStreaming)
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(AppLanguage.stored.isChinese ? "点击下方按钮，由 AI 针对当前生命体征和最新运动数据，提供定制的训练与恢复行动建议。" : "Tap below to let AI analyze your current vitals and recent activity trends, and deliver tailored training or recovery advice.")
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(3)
            }

            if !isStreaming {
                HStack(spacing: 8) {
                    if !streamText.isEmpty {
                        Button {
                            startStreaming()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 38, height: 38)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VelaTheme.subtleFill))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(VelaTheme.primaryText)
                    }

                    Button {
                        if !hasFinished {
                            startStreaming()
                        } else {
                            VelaAppState.shared.routeToCoach(question: resolvedQuestion)
                        }
                    } label: {
                        HStack {
                            if !hasFinished {
                                Image(systemName: "sparkles")
                                Text(AppLanguage.stored.isChinese ? "获取 AI 建议" : "Get AI Advice")
                            } else {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text(AppLanguage.stored.isChinese ? "深度对话" : "Discuss with Coach")
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VelaTheme.accent)
                }
                .padding(.top, 4)
            }
        }
        .heroCardSurface(accent: VelaTheme.accent)
        .modifier(AppleIntelligenceGlowBorder(isGlowing: isStreaming))
    }

    private func startStreaming() {
        streamText = ""
        errorMessage = nil
        isStreaming = true
        hasFinished = false
        
        Task {
            do {
                guard let apiKey = try keychain.read(account: apiKeyAccount), !apiKey.isEmpty else {
                    errorMessage = AppLanguage.stored.isChinese
                        ? "请先在设置中添加 DeepSeek API Key。"
                        : "Please add your DeepSeek API key in Settings first."
                    isStreaming = false
                    return
                }

                let systemPrompt = AppLanguage.stored.isChinese ? """
                你是 Vela，一位世界顶级私人健康教练和运动科学家。你正在为用户提供针对特定身体指标 (\(focus.title)) 的定制化行动建议。
                你的语言风格必须极其专业、精准、简洁、充满人情味。
                """ : """
                You are Vela, a world-class personal health coach. You are giving the user hyper-personalized, expert advice about their \(focus.title) metric.
                Keep your style professional, concise, empathetic, and highly actionable.
                """

                let metricsPrompt = """
                Focus Metric: \(focus.title)
                Focus Metric Context: \(focus.systemContext)

                Current Daily Dashboard Context:
                - Recovery Readiness Score: \(Int(dashboard.recovery.score))
                - Sleep Quality Score: \(Int(dashboard.sleepScore.score))
                - Daily Physical Strain: \(Int(dashboard.strain.score))
                - Heart Rate Variability (HRV): \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "N/A")
                - Resting Heart Rate (RHR): \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "N/A")
                - Sleep Heart Rate: \(dashboard.recoveryMetrics.sleepHeartRate.map { "\(Int($0))bpm" } ?? "N/A")
                - Respiratory Rate: \(dashboard.recoveryMetrics.respiratoryRate.map { "\(Int($0))/min" } ?? "N/A")
                - Blood Oxygen: \(dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "N/A")
                - Daily Steps: \(dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "N/A")
                - Active Energy: \(dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "N/A")
                - Active Time: \(dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))m" } ?? "N/A")

                User Question:
                \(resolvedQuestion)
                """

                let provider = DeepSeekProvider(apiKey: apiKey)
                let messages = [
                    ChatMessage(role: .system, content: systemPrompt),
                    ChatMessage(role: .user, content: metricsPrompt)
                ]

                let stream = provider.streamChat(messages: messages)
                for try await chunk in stream {
                    streamText += chunk
                }
                
                isStreaming = false
                hasFinished = true
            } catch {
                errorMessage = AppLanguage.stored.isChinese
                    ? "分析失败：\(error.localizedDescription)"
                    : "Analysis failed: \(error.localizedDescription)"
                isStreaming = false
            }
        }
    }

    private var resolvedQuestion: String {
        if let suggestedQuestion,
           !suggestedQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return suggestedQuestion
        }

        return AppLanguage.stored.isChinese
            ? "请基于当前\(focus.title)数据，先给结论，再说明依据，最后给我今天最重要的一步行动。"
            : "Analyze my current \(focus.title) data. Start with the conclusion, then evidence, then the single most important action for today."
    }
}

struct AppleIntelligenceGlowBorder: ViewModifier {
    var isGlowing: Bool
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isGlowing {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                AngularGradient(
                                    colors: [.pink, .purple, .cyan, .orange, .pink],
                                    center: .center,
                                    angle: .degrees(rotation)
                                ),
                                lineWidth: 2.2
                            )
                            .shadow(color: .purple.opacity(0.42), radius: 6)
                            .task {
                                rotation = 0
                                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                                    rotation = 360
                                }
                            }
                    }
                }
            )
            .scaleEffect(isGlowing ? 1.012 : 1.0)
            .animation(.easeInOut(duration: 0.45), value: isGlowing)
    }
}
