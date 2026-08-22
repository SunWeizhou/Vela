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

// MARK: - CoachThinkingParser

struct ParsedMessageParts: Equatable {
    var thinkingContent: String?
    var mainContent: String
    var isStillThinking: Bool
}

enum CoachThinkingParser {
    /// 解析包含 `<think>...</think>` 的消息内容
    static func parse(_ raw: String, isStreaming: Bool = false) -> ParsedMessageParts {
        let thinkOpenTag = "<think>"
        let thinkCloseTag = "</think>"

        guard let openRange = raw.range(of: thinkOpenTag, options: .caseInsensitive) else {
            return ParsedMessageParts(thinkingContent: nil, mainContent: raw, isStillThinking: false)
        }

        let afterOpen = raw[openRange.upperBound...]

        if let closeRange = afterOpen.range(of: thinkCloseTag, options: .caseInsensitive) {
            let thinkingText = String(afterOpen[..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let mainText = String(afterOpen[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedMessageParts(
                thinkingContent: thinkingText.isEmpty ? nil : thinkingText,
                mainContent: mainText,
                isStillThinking: false
            )
        } else {
            // 尚未闭合（仍在思考阶段）
            let thinkingText = String(afterOpen).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedMessageParts(
                thinkingContent: thinkingText.isEmpty ? nil : thinkingText,
                mainContent: "",
                isStillThinking: isStreaming
            )
        }
    }
}

// MARK: - CoachThinkingView

struct CoachThinkingView: View {
    let thinkingText: String
    let isStreaming: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool = false
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isStreaming ? "brain.filled.head.profile" : "sparkle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isStreaming ? VelaTheme.accent : VelaTheme.rhythmInkSecondary)
                        .scaleEffect(isStreaming && !reduceMotion ? (pulse ? 1.15 : 0.9) : 1.0)
                        .animation(
                            isStreaming && !reduceMotion
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : nil,
                            value: pulse
                        )

                    Text(isStreaming ? "深度思考中..." : "已深度思考")
                        .font(VelaTheme.caption2().weight(.medium))
                        .foregroundStyle(isStreaming ? VelaTheme.rhythmInk : VelaTheme.rhythmInkSecondary)

                    Spacer(minLength: 4)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VelaTheme.rhythmMist.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                if isStreaming {
                    pulse = true
                }
            }
            .onChange(of: isStreaming) { _, streaming in
                pulse = streaming
            }

            if isExpanded {
                HStack(alignment: .top, spacing: 8) {
                    Rectangle()
                        .fill(VelaTheme.accent.opacity(0.35))
                        .frame(width: 2)
                        .padding(.vertical, 2)

                    MarkdownText(
                        markdown: thinkingText,
                        font: VelaTheme.caption2(),
                        color: VelaTheme.rhythmInkSecondary,
                        isStreaming: isStreaming
                    )
                    .lineSpacing(2)
                }
                .padding(.leading, 4)
                .padding(.top, 6)
                .padding(.bottom, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: model.actionSystemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(VelaTheme.rhythmMist))

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.compactDisplayTitle)
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.status == .low
                         ? "低覆盖时 Coach 会保守回答"
                         : model.topBlockers.isEmpty ? "关键数据可用于本轮判断" : "缺口：\(model.topBlockers.joined(separator: "、"))")
                    .font(VelaTheme.caption1().weight(.medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.rhythmCanvasRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
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
        HStack(spacing: 5) {
            Circle()
                .fill(VelaTheme.rhythmDeep)
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.3 : 0.75))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(VelaTheme.accent)
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.3 : 0.75))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: pulse)
            Circle()
                .fill(VelaTheme.rhythmInkSecondary)
                .frame(width: 6, height: 6)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.3 : 0.75))
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
// MARK: - MiniStreamingBubble
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

// MARK: - CoachFollowUpChipsView

struct CoachFollowUpChipsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        VelaHaptic.selection()
                        onSelect(suggestion)
                    } label: {
                        Label(suggestion, systemImage: "arrow.turn.down.right")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .padding(.horizontal, 12)
                            .frame(minHeight: VelaTheme.minimumHitTarget)
                            .background(
                                Capsule()
                                    .fill(VelaTheme.rhythmCanvasRaised)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                            )
                    }
                    .buttonStyle(.cardPress)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.leading, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
