import SwiftUI

// MARK: - VelaAppleCoachView — Apple-style Coach Command Center
// Full-screen sheet. Body status header + quick action chips + chat interface

struct VelaMinimalCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var messages: [CoachMessage] = CoachMessage.sample
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.groupedBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat area
                    if messages.count > 2 {
                        messageList
                    } else {
                        actionHub
                    }

                    // Quick questions
                    if messages.count < 3 && !messages.isEmpty {
                        quickQuestions
                    }

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("Vela Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                    }
                }
            }
        }
    }

    // MARK: - Action Hub

    private var actionHub: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
                // Body status header
                bodyStatusHeader
                    .padding(.top, VelaTheme.spaceLG)

                // Quick actions
                VelaMinimalSectionHeader(title: "Ask Vela")

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    VelaAppleCommandCard(
                        title: "Analyze Readiness",
                        subtitle: "Recovery, sleep, strain, and today's limiter",
                        systemImage: "sparkles",
                        tint: VelaTheme.accent
                    ) { sendPreset("How am I doing today? Explain the evidence and the best next action.") }

                    VelaAppleCommandCard(
                        title: "Adjust Training",
                        subtitle: "Check whether to train, swap, or recover",
                        systemImage: "figure.run.circle.fill",
                        tint: VelaTheme.strain
                    ) { sendPreset("Should I adjust today's training based on recovery and fatigue?") }

                    VelaAppleCommandCard(
                        title: "Optimize Sleep",
                        subtitle: "Turn sleep signals into tonight's plan",
                        systemImage: "moon.stars.fill",
                        tint: VelaTheme.sleep
                    ) { sendPreset("Review my sleep and give one concrete optimization for tonight.") }

                    VelaAppleCommandCard(
                        title: "Review Memories",
                        subtitle: "Pending patterns and profile updates",
                        systemImage: "brain.head.profile",
                        tint: VelaTheme.energy
                    ) { sendPreset("What patterns has Vela noticed about me recently?") }
                }

                // Trust shortcuts
                VelaMinimalSectionHeader(title: "Trust & Data")

                HStack(spacing: 12) {
                    trustTile("Data Coverage", "Signal quality check", "waveform.path.ecg.rectangle", VelaTheme.recovery)
                    trustTile("Trust Center", "Agent audit log", "checkmark.shield.fill", VelaTheme.accent)
                }
            }
            .padding(.horizontal, VelaTheme.screenPadding)
            .padding(.bottom, 24)
        }
    }

    private var bodyStatusHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.title)
                    .foregroundStyle(VelaTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coach Command Center")
                        .font(VelaTheme.cardTitle)
                        .foregroundStyle(VelaTheme.onSurface)
                    Text("Context-aware coaching from your health data")
                        .font(VelaTheme.captionFont)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                }
            }

            HStack(spacing: 8) {
                VelaAppleMetricPill(title: "Recovery", value: "84", systemImage: "heart.fill", tint: VelaTheme.recovery)
                VelaAppleMetricPill(title: "Sleep", value: "78%", systemImage: "moon.zzz.fill", tint: VelaTheme.sleep)
                VelaAppleMetricPill(title: "Strain", value: "65", systemImage: "figure.run", tint: VelaTheme.strain)
            }
        }
        .heroCardSurface(accent: VelaTheme.accent)
    }

    private func trustTile(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.10)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(subtitle)
                    .font(VelaTheme.microFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
            Spacer()
        }
        .padding(VelaTheme.spaceSM)
        .frame(maxWidth: .infinity)
        .cardSurface(radius: VelaTheme.radiusSM)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { msg in
                        chatBubble(msg)
                    }
                }
                .padding(.horizontal, VelaTheme.screenPadding)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _ in
                if let id = messages.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }

    private func chatBubble(_ msg: CoachMessage) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if msg.isUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 6) {
                if !msg.isUser {
                    HStack(spacing: 4) {
                        Image(systemName: "apple.logo")
                            .font(.caption2)
                        Text("Vela")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(VelaTheme.accent)
                }
                Text(msg.content)
                    .font(.system(size: 15))
                    .foregroundStyle(msg.isUser ? .white : VelaTheme.onSurface)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(msg.isUser ? VelaTheme.accent : VelaTheme.surface)
                    )

                if !msg.isUser {
                    Text(msg.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                        .padding(.leading, 4)
                }
            }

            if !msg.isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Quick Questions

    private var quickQuestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickQuestionPresets, id: \.self) { q in
                    Button {
                        sendPreset(q)
                    } label: {
                        Text(q)
                            .font(VelaTheme.captionFont.weight(.medium))
                            .foregroundStyle(VelaTheme.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(VelaTheme.accent.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VelaTheme.screenPadding)
            .padding(.vertical, 8)
        }
    }

    private let quickQuestionPresets = [
        "How is my recovery today?",
        "Should I train or rest?",
        "Why am I feeling tired?",
        "What should I eat today?"
    ]

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                TextField("Ask Vela...", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(VelaTheme.onSurface)

                Button {
                    inputFocused = false
                    sendPreset(draft)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? VelaTheme.muted.opacity(0.3)
                                    : VelaTheme.accent)
                        )
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.trailing, 6)
            }
            .background(
                Capsule(style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func sendPreset(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let userMsg = CoachMessage(content: text, isUser: true)
        messages.append(userMsg)
        draft = ""

        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let resp = CoachMessage(
                content: "Based on your current HRV (48ms), resting heart rate (52bpm), and sleep score (78%), you're in a good place for moderate training. I'd recommend sticking with your Zone 2 run but capping intensity at 145bpm. Your recovery trend is positive — keep the bedtime consistent tonight.",
                isUser: false
            )
            messages.append(resp)
        }
    }
}

// MARK: - Coach Message Model

struct CoachMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()

    static let sample: [CoachMessage] = [
        CoachMessage(content: "Good morning! How am I doing today?", isUser: true),
        CoachMessage(content: "Your readiness score is 82/100. HRV is trending up to 48ms, resting heart rate is steady at 52bpm, and you got 7h 12m of sleep with 92% efficiency. This is a strong recovery day — ideal for a Zone 2 endurance session. Avoid high-intensity intervals until your sleep debt from Wednesday is cleared.", isUser: false),
        CoachMessage(content: "Got it. What about my training plan for tomorrow?", isUser: true)
    ]
}
