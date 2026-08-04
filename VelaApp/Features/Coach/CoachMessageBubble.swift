import SwiftUI
import SwiftData

// MARK: - CoachChatMessage
struct CoachChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    var id: UUID = UUID()
    var role: Role
    var content: String
    var createdAt: Date = Date()
}

// MARK: - CoachRecoveryActionButton
struct CoachRecoveryActionButton: View {
    let action: LLMErrorRecoveryAction
    var perform: () -> Void

    var body: some View {
        Button(action: perform) {
            Label(action.title, systemImage: action.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(VelaTheme.accent.opacity(0.10))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(VelaTheme.accent.opacity(0.22), lineWidth: 0.8)
                )
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel(action.title)
    }
}

// MARK: - CoachDataCoverageStrip
struct CoachDataCoverageStrip: View {
    let model: DataCoverageSummaryModel
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: model.actionSystemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.compactDisplayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(model.status == .unknown ? VelaTheme.fg : accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(model.status == .low
                         ? "低覆盖时 Coach 会保守回答"
                         : model.topBlockers.isEmpty ? "关键数据可用于本轮判断" : "缺口：\(model.topBlockers.joined(separator: "、"))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 0.7)
            )
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel("Coach \(model.compactDisplayTitle)")
    }

    private var accent: Color {
        switch model.status {
        case .high: return VelaTheme.energyColor
        case .moderate: return VelaTheme.accent
        case .low: return VelaTheme.strainColor
        case .unknown: return VelaTheme.muted
        }
    }
}

// MARK: - AppleIntelligenceLoaderDots
struct AppleIntelligenceLoaderDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "#9C5FF2"))
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.4 : 0.8))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(Color(hex: "#00A2FF"))
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.4 : 0.8))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: pulse)
            Circle()
                .fill(Color(hex: "#FF2D55"))
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.4 : 0.8))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: pulse)
        }
        .onAppear {
            pulse = !reduceMotion
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            pulse = !shouldReduceMotion
        }
        .onDisappear {
            pulse = false
        }
    }
}

// MARK: - MiniBubble
struct MiniBubble: View {
    let message: CoachChatVM.ChatMsg
    var onRecoveryAction: (LLMErrorRecoveryAction) -> Void = { _ in }

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.role == .user
                    ? (AppLanguage.stored.isChinese ? "你" : "You")
                    : "Vela")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(message.role == .user ? VelaTheme.muted : VelaTheme.brand)

                VStack(alignment: .leading, spacing: 4) {
                    let segments = parseMessageContent(message.content)
                    ForEach(segments) { segment in
                        switch segment {
                        case .text(let text):
                            MarkdownText(
                                markdown: text,
                                font: .subheadline,
                                color: message.role == .user ? .white : VelaTheme.fg,
                                isStreaming: message.isStreaming
                            )
                        case .artifact(let type, let key):
                            if type == "correlation" {
                                CorrelationArtifactView(key: key)
                                    .padding(.vertical, 4)
                            } else {
                                ArtifactRendererView(type: type, key: key)
                                    .padding(.vertical, 4)
                            }
                        }
                    }

                    if let action = message.recoveryAction, message.role == .assistant {
                        CoachRecoveryActionButton(action: action) {
                            onRecoveryAction(action)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                    ? AnyShapeStyle(LinearGradient(
                        colors: [VelaTheme.accent, VelaTheme.accent.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ))
                    : AnyShapeStyle(.ultraThinMaterial)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(message.role == .user ? Color.clear : VelaTheme.borderSoft, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(message.role == .user ? 0.04 : 0.02), radius: 3, y: 1.5)
            }

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - MiniStreamingBubble
struct MiniStreamingBubble: View {
    let content: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Vela")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.brand)

                VStack(alignment: .leading, spacing: 4) {
                    if content.isEmpty {
                        HStack(spacing: 8) {
                            AppleIntelligenceLoaderDots()
                            Text("Vela 正在思考...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        .padding(.vertical, 4)
                    } else {
                        MarkdownText(
                            markdown: content,
                            font: .subheadline,
                            color: VelaTheme.fg,
                            isStreaming: true
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VelaTheme.cardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.02), radius: 3, y: 1.5)
            }

            Spacer(minLength: 50)
        }
    }
}

// MARK: - Message Segment Parsing Helpers
enum MessageSegment: Identifiable {
    var id: String {
        switch self {
        case .text(let t): return "text-\(t.hashValue)"
        case .artifact(let type, let key): return "artifact-\(type)-\(key)"
        }
    }
    case text(String)
    case artifact(type: String, key: String)
}

func parseMessageContent(_ content: String) -> [MessageSegment] {
    var segments: [MessageSegment] = []
    var currentIndex = content.startIndex
    
    while let range = content[currentIndex...].range(of: "\\[ARTIFACT:[^\\]]+\\]", options: .regularExpression) {
        let prefix = content[currentIndex..<range.lowerBound]
        if !prefix.isEmpty {
            segments.append(.text(String(prefix)))
        }
        
        let tag = content[range]
        let cleanTag = tag.dropFirst().dropLast() // "ARTIFACT:correlation:hrv_vs_sleep"
        let parts = cleanTag.components(separatedBy: ":")
        if parts.count >= 2 {
            let type = parts[1]
            let key = parts.count >= 3 ? parts[2...].joined(separator: ":") : ""
            segments.append(.artifact(type: type, key: key))
        } else {
            segments.append(.text(String(tag)))
        }
        
        currentIndex = range.upperBound
    }
    
    let suffix = content[currentIndex...]
    if !suffix.isEmpty {
        segments.append(.text(String(suffix)))
    }
    
    return segments.isEmpty ? [.text(content)] : segments
}

// MARK: - ArtifactRendererView
struct ArtifactRendererView: View {
    let type: String
    let key: String
    
    @Environment(\.modelContext) private var modelContext
    @State private var artifactRecord: CoachArtifactRecord? = nil
    
    var body: some View {
        Group {
            if let record = artifactRecord {
                CoachArtifactCard(artifact: record.artifact, compact: true) { action in
                    handleArtifactAction(action, artifact: record.artifact)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.t("Loading card...", "加载建议卡片..."))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                }
                .padding(.vertical, 6)
                .onAppear {
                    loadRecord()
                }
            }
        }
    }
    
    private func loadRecord() {
        guard let id = UUID(uuidString: key) else { return }
        let descriptor = FetchDescriptor<CoachArtifactRecord>(
            predicate: #Predicate<CoachArtifactRecord> { $0.id == id }
        )
        if let record = try? modelContext.fetch(descriptor).first {
            self.artifactRecord = record
        }
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        VelaAppState.shared.logDebug("[ArtifactRendererView] handleArtifactAction: type=\(action.type), payload=\(action.payload)")
        if action.type == "start_check_in", let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: id)
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") {
            VelaAppState.shared.routeToTraining()
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }
}
