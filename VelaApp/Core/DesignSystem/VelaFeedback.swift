import SwiftUI

// MARK: - StatusCapsule

struct StatusCapsule: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.fg2)

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.fg)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(VelaTheme.cardBg)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    let time: String
    var isStreaming = false

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                MarkdownText(
                    markdown: text,
                    font: VelaTheme.subheadline(),
                    color: isUser ? .white : VelaTheme.fg,
                    isStreaming: isStreaming
                )
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isUser {
                                LinearGradient(
                                    colors: [VelaTheme.accent, Color(hex: "#00A2FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                VelaTheme.cardBg
                            }
                        }
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isUser ? VelaTheme.radiusLg : 4,
                            bottomLeadingRadius: VelaTheme.radiusLg,
                            bottomTrailingRadius: VelaTheme.radiusLg,
                            topTrailingRadius: isUser ? 4 : VelaTheme.radiusLg,
                            style: .continuous
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isUser ? VelaTheme.radiusLg : 4,
                            bottomLeadingRadius: VelaTheme.radiusLg,
                            bottomTrailingRadius: VelaTheme.radiusLg,
                            topTrailingRadius: isUser ? 4 : VelaTheme.radiusLg,
                            style: .continuous
                        )
                        .stroke(isUser ? Color.clear : VelaTheme.borderSoft, lineWidth: 0.8)
                    )
                    .shadow(color: isUser ? VelaTheme.accent.opacity(0.1) : Color.black.opacity(0.015), radius: 5, y: 2)
                    .frame(maxWidth: 285, alignment: isUser ? .trailing : .leading)

                if !time.isEmpty {
                    Text(time)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.meta)
                        .padding(.horizontal, 8)
                }
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.96, anchor: isUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity),
                removal: .opacity
            ))

            if !isUser { Spacer() }
        }
    }
}

// MARK: - TypingIndicator

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(VelaTheme.meta)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .opacity(animate ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.2),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: VelaTheme.radiusLg,
                bottomTrailingRadius: VelaTheme.radiusLg,
                topTrailingRadius: VelaTheme.radiusLg,
                style: .continuous
            )
            .fill(VelaTheme.surface)
        )
        .onAppear {
            animate = true
        }
    }
}

// MARK: - AppleIntelligenceOrb (Glowing Siri-like animated orb)

struct AppleIntelligenceOrb: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Glow layer 1 (Indigo/Purple)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#9C5FF2"), Color(hex: "#6B6FA0")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .blur(radius: 20)
                .scaleEffect(animate ? 1.25 : 0.8)
                .offset(x: animate ? 12 : -12, y: animate ? -6 : 6)
                .opacity(0.6)

            // Glow layer 2 (Blue/Teal)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#00A2FF"), Color(hex: "#5B8C6F")], startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: 75, height: 75)
                .blur(radius: 18)
                .scaleEffect(animate ? 0.85 : 1.3)
                .offset(x: animate ? -14 : 14, y: animate ? 8 : -8)
                .opacity(0.6)

            // Glow layer 3 (Pink/Rose/Orange)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "#FF2D55"), Color(hex: "#FF9F0A")], startPoint: .bottomLeading, endPoint: .topTrailing))
                .frame(width: 70, height: 70)
                .blur(radius: 16)
                .scaleEffect(animate ? 1.35 : 0.85)
                .offset(x: animate ? 6 : -6, y: animate ? 14 : -14)
                .opacity(0.5)

            // Core sphere (translucent glass)
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 68, height: 68)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear, .white.opacity(0.2)],
                                startPoint: .topLeading,
                                  endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 5)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#AF52DE"), Color(hex: "#FF2D55")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - VelaInlineAlert

struct VelaInlineAlertCompat: View {
    let title: String
    let message: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text(message)
                    .font(VelaTheme.captionLarge())
                    .foregroundStyle(VelaTheme.fg2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd)
                .stroke(tint.opacity(0.18), lineWidth: 0.5)
        )
    }
}
typealias VelaInlineAlert = VelaInlineAlertCompat
typealias VelaAppleInlineAlert = VelaInlineAlertCompat

// MARK: - VelaDataQualityRow

struct VelaDataQualityRowCompat: View {
    let title: String
    let subtitle: String
    var isAvailable: Bool = true
    var freshness: DataFreshness? = nil
    let qualityLabel: String
    let tint: Color

    var body: some View {
        let available = freshness.map { $0 != .missing } ?? isAvailable
        HStack(spacing: 12) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(available ? tint : VelaTheme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VelaTheme.fg)
                Text(subtitle)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.fg2)
            }
            Spacer()
            Text(qualityLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(available ? tint : VelaTheme.muted)
        }
        .padding(.vertical, 6)
    }
}
typealias VelaDataQualityRow = VelaDataQualityRowCompat
typealias VelaAppleDataQualityRow = VelaDataQualityRowCompat
