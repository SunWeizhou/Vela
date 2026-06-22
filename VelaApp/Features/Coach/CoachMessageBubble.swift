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
        .buttonStyle(.plain)
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
                    HStack(spacing: 6) {
                        Text(model.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                            .lineLimit(1)
                        Text(model.status == .unknown ? "--" : "\(model.scorePercent)%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accent)
                            .monospacedDigit()
                    }
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
        .buttonStyle(.plain)
        .accessibilityLabel("Coach 数据可信度 \(model.scorePercent)%")
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
    @State private var pulse = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "#9C5FF2"))
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            Circle()
                .fill(Color(hex: "#00A2FF"))
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: pulse)
            Circle()
                .fill(Color(hex: "#FF2D55"))
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.4), value: pulse)
        }
        .onAppear {
            pulse = true
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
                    .foregroundStyle(message.role == .user ? VelaTheme.muted : VelaTheme.recoveryColor)

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
                                Text("[Artifact: \(type) - \(key)]")
                                    .font(.caption)
                                    .foregroundStyle(message.role == .user ? .white.opacity(0.7) : VelaTheme.muted)
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
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            message.role == .user
                            ? LinearGradient(
                                colors: [VelaTheme.accent, VelaTheme.accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                colors: [VelaTheme.cardBg, VelaTheme.cardBg],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                        )
                )
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
                    .foregroundStyle(VelaTheme.recoveryColor)

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
