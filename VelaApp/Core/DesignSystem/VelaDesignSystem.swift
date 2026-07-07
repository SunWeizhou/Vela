import SwiftUI

// MARK: - Vela 3.0 Command System Components

struct VelaPageShell<Content: View>: View {
    var bottomPadding: CGFloat = 120
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, bottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.systemGroupedBackground)
    }
}

struct VelaHeroCard<Content: View>: View {
    var title: String
    var subtitle: String?
    var systemImage: String
    var accent: Color = VelaTheme.accent
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(VelaTheme.headline())
                        .foregroundStyle(VelaTheme.fg)
                    if let subtitle {
                        Text(subtitle)
                            .font(VelaTheme.caption1())
                            .foregroundStyle(VelaTheme.muted)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }
}

struct MetricScoreCard: View {
    let title: String
    let value: String
    var subtitle: String?
    var accent: Color = VelaTheme.accent
    var confidence: DataConfidence? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(VelaTheme.caption1())
                    .fontWeight(.semibold)
                    .foregroundStyle(VelaTheme.muted)
                Spacer()
                if let confidence {
                    ConfidenceBadge(confidence: confidence)
                }
            }

            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(VelaTheme.fg)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.meta)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }
}

struct CoachArtifactCard: View {
    let artifact: CoachArtifact
    var compact = false
    var onAction: ((CoachArtifactAction) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(accent.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(artifact.title)
                        .font(compact ? VelaTheme.subheadline() : VelaTheme.headline())
                        .fontWeight(.semibold)
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(2)

                    Text(artifact.type.displayTitle)
                        .font(VelaTheme.caption2())
                        .fontWeight(.semibold)
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer(minLength: 0)

                ConfidenceBadge(score: artifact.confidence)
            }

            Text(artifact.summary)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(3)
                .lineLimit(compact ? 3 : nil)

            if !compact, !artifact.reasons.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(artifact.reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(reason.signal): \(reason.value)")
                                    .font(VelaTheme.caption1())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(VelaTheme.fg)
                                Text(reason.explanation)
                                    .font(VelaTheme.caption1())
                                    .foregroundStyle(VelaTheme.muted)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if !artifact.actions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(artifact.actions.prefix(compact ? 2 : 4)) { action in
                            ActionPill(
                                title: action.label,
                                systemImage: icon(for: action),
                                isPrimary: action.id == artifact.actions.first?.id
                            ) {
                                onAction?(action)
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .velaNativeCard(radius: 18)
    }

    private var iconName: String {
        switch artifact.type {
        case .morningBrief: return "sun.max.fill"
        case .workoutReadiness, .trainingAdjustment: return "figure.strengthtraining.traditional"
        case .postWorkoutReview: return "checkmark.seal.fill"
        case .eveningReview: return "moon.stars.fill"
        case .weeklyReview: return "calendar.badge.clock"
        case .wikiUpdateProposal: return "brain.head.profile"
        case .askCoachAnswer: return "sparkles"
        }
    }

    private var accent: Color {
        switch artifact.type {
        case .postWorkoutReview, .trainingAdjustment, .workoutReadiness: return VelaTheme.strain
        case .eveningReview: return VelaTheme.sleep
        case .wikiUpdateProposal: return Color(hex: "#FF9F0A")
        default: return VelaTheme.accent
        }
    }

    private func icon(for action: CoachArtifactAction) -> String {
        if action.type.contains("training") || action.type.contains("workout") { return "figure.run" }
        if action.type.contains("recovery") { return "heart.fill" }
        if action.type.contains("check") { return "square.and.pencil" }
        return "arrow.right"
    }
}

struct EvidenceSheet: View {
    let state: TodayCommandState

    var body: some View {
        NavigationStack {
            List {
                Section("Readiness") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(state.bodyStateTitle)
                            .font(VelaTheme.headline())
                        Text(state.summary)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(.vertical, 6)
                }

                Section("Signals") {
                    ForEach(state.keySignals) { signal in
                        SignalRow(signal: signal)
                    }
                }

                Section("Decision Reasons") {
                    ForEach(state.readinessDecision.reasons, id: \.self) { reason in
                        Text(reason)
                    }
                }
            }
            .navigationTitle("决策证据")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ActionPill: View {
    let title: String
    var systemImage: String
    var isPrimary = false
    var action: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(VelaTheme.caption1())
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(isPrimary ? .white : VelaTheme.fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(isPrimary ? VelaTheme.accent : VelaTheme.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(isPrimary ? Color.clear : VelaTheme.borderSoft, lineWidth: 0.5)
        )
        .contentShape(Capsule())
        .onTapGesture {
            VelaAppState.shared.logDebug("[ActionPill] Direct tap triggered: \(title)")
            action()
        }
    }
}

struct SignalRow: View {
    let signal: TodayHealthSignal

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: sourceIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(VelaTheme.accent.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(localizedSignalTitle(signal.title))
                        .font(VelaTheme.subheadline())
                        .fontWeight(.semibold)
                        .foregroundStyle(VelaTheme.fg)
                    DataSourceBadge(source: signal.source)
                    ConfidenceBadge(confidence: signal.confidence)
                }

                Text(localizedSignalValue(signal.value))
                    .font(VelaTheme.caption1())
                    .fontWeight(.semibold)
                    .foregroundStyle(VelaTheme.fg2)

                if let baseline = signal.baseline {
                    Text(localizedSignalBaseline(baseline))
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.meta)
                }

                Text(signal.interpretation)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var sourceIcon: String {
        switch signal.source {
        case .healthKit: return "heart.text.square"
        case .computed: return "function"
        case .userProvided: return "hand.draw"
        case .aiEstimated: return "sparkles"
        case .wikiProfile: return "brain.head.profile"
        case .biomarkerLab: return "testtube.2"
        }
    }
}

struct TrendChartCard: View {
    let title: String
    let values: [Double]
    var accent: Color = VelaTheme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(VelaTheme.subheadline())
                .fontWeight(.semibold)
                .foregroundStyle(VelaTheme.fg)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(index == values.indices.last ? accent : accent.opacity(0.24))
                        .frame(height: max(4, min(54, value)))
                }
            }
            .frame(height: 56)
        }
        .padding(14)
        .velaNativeCard(radius: 16)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(VelaTheme.meta)
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(subtitle)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .velaNativeCard(radius: 16)
    }
}

struct DataSourceBadge: View {
    let source: HealthDataSource

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(VelaTheme.muted)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(VelaTheme.surface))
    }

    private var label: String {
        switch source {
        case .healthKit: return "Health"
        case .userProvided: return "Manual"
        case .aiEstimated: return "AI"
        case .wikiProfile: return "Wiki"
        case .biomarkerLab: return "Lab"
        case .computed: return "Calc"
        }
    }
}

struct ConfidenceBadge: View {
    var confidence: DataConfidence? = nil
    var score: Double? = nil

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.1)))
    }

    private var label: String {
        if let score {
            return "\(Int((score * 100).rounded()))%"
        }
        switch confidence {
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        case .unavailable: return "MISS"
        case nil: return "N/A"
        }
    }

    private var color: Color {
        if let score {
            if score >= 0.75 { return VelaTheme.success }
            if score >= 0.5 { return Color(hex: "#FF9F0A") }
            return Color(hex: "#FF3B30")
        }
        switch confidence {
        case .high: return VelaTheme.success
        case .medium: return Color(hex: "#FF9F0A")
        case .low, .unavailable: return Color(hex: "#FF3B30")
        case nil: return VelaTheme.meta
        }
    }
}

struct WorkoutSessionCard: View {
    let title: String
    let subtitle: String
    let metric: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VelaTheme.strain)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.strain.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(VelaTheme.subheadline())
                        .fontWeight(.semibold)
                        .foregroundStyle(VelaTheme.fg)
                    Text(subtitle)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer()

                Text(metric)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.fg)
            }
            .padding(14)
            .velaNativeCard(radius: 16)
        }
        .buttonStyle(.plain)
    }
}

struct SetInputRow: View {
    let index: Int
    let reps: String
    let weight: String
    var completed: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(VelaTheme.caption1())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(completed ? VelaTheme.success : VelaTheme.meta))

            Text(reps)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg)
            Spacer()
            Text(weight)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.fg2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))
    }
}

// MARK: - Button Styles

extension ButtonStyle where Self == CardPressStyle {
    static var cardPress: CardPressStyle { CardPressStyle() }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.light()
                }
            }
    }
}

extension ButtonStyle where Self == TabItemStyle {
    static var tabItem: TabItemStyle { TabItemStyle() }
}

struct TabItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.selection()
                }
            }
    }
}

extension ButtonStyle where Self == PlusButtonStyle {
    static var plusButton: PlusButtonStyle { PlusButtonStyle() }
}

struct PlusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.medium()
                }
            }
    }
}

// MARK: - View Modifiers

struct AmbientGlowModifier: ViewModifier {
    let color: Color
    let intensity: CGFloat
    @State private var breathe = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(color)
                    .blur(radius: breathe ? 24 : 16)
                    .opacity(breathe ? intensity * 1.15 : intensity)
                    .scaleEffect(breathe ? 1.015 : 0.985)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                            breathe = true
                        }
                    }
            )
    }
}

struct VelaThemeBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base background gradient matching iOS 26 Liquid Glass
            LinearGradient(
                colors: [
                    VelaTheme.bg,
                    VelaTheme.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Dynamic background blobs
            GeometryReader { geo in
                ZStack {
                    // Blob 1: Accent (Strain/Energy)
                    Circle()
                        .fill(VelaTheme.accent.opacity(colorScheme == .dark ? 0.16 : 0.20))
                        .frame(width: geo.size.width * 0.85, height: geo.size.width * 0.85)
                        .blur(radius: 70)
                        .offset(
                            x: animate ? geo.size.width * 0.25 : -geo.size.width * 0.15,
                            y: animate ? -geo.size.height * 0.12 : geo.size.height * 0.08
                        )

                    // Blob 2: Recovery (Green)
                    Circle()
                        .fill(VelaTheme.recoveryColor.opacity(colorScheme == .dark ? 0.14 : 0.18))
                        .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                        .blur(radius: 65)
                        .offset(
                            x: animate ? -geo.size.width * 0.25 : geo.size.width * 0.25,
                            y: animate ? geo.size.height * 0.18 : -geo.size.height * 0.15
                        )

                    // Blob 3: Sleep (Indigo/Blue)
                    Circle()
                        .fill(VelaTheme.sleepColor.opacity(colorScheme == .dark ? 0.14 : 0.18))
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .offset(
                            x: animate ? geo.size.width * 0.15 : -geo.size.width * 0.25,
                            y: animate ? geo.size.height * 0.25 : geo.size.height * 0.05
                        )
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
        }
    }
}

struct VelaNativeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .glassEffect(radius: radius)
            .shadow(color: VelaTheme.cardShadow(colorScheme), radius: 8, y: 3)
    }
}

struct AppleIntelligenceGlowModifier: ViewModifier {
    let isHighlighted: Bool
    let radius: CGFloat
    @State private var rotation: Double = 0.0
    
    func body(content: Content) -> some View {
        if isHighlighted {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#9C5FF2"),
                                    Color(hex: "#00A2FF"),
                                    Color(hex: "#FF2D55"),
                                    Color(hex: "#FF9F0A"),
                                    Color(hex: "#9C5FF2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .hueRotation(.degrees(rotation))
                )
                .onAppear {
                    withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                        rotation = 360.0
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func appleIntelligenceGlow(isHighlighted: Bool = true, radius: CGFloat = 18) -> some View {
        self.modifier(AppleIntelligenceGlowModifier(isHighlighted: isHighlighted, radius: radius))
    }

    func ambientGlow(color: Color, intensity: CGFloat = 0.05) -> some View {
        self.modifier(AmbientGlowModifier(color: color, intensity: intensity))
    }

    func velaNativeCard(radius: CGFloat = 16) -> some View {
        self.modifier(VelaNativeCardModifier(radius: radius))
    }

    func cardSurface(padding: CGFloat = VelaTheme.spaceLG, radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(radius: radius)
    }

    func heroCardSurface(accent: Color = VelaTheme.accent, padding: CGFloat = VelaTheme.spaceLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
            .glassEffect(radius: VelaTheme.radiusHero)
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 0.8)
            )
    }

    func glassEffect(radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.04),
                                Color.black.opacity(0.04),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }

    func sectionSpacing() -> some View {
        self.padding(.bottom, VelaTheme.sectionGap)
    }
}

// MARK: - Screen Wrapper

struct VelaMinimalScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            VelaThemeBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content()
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.bottom, VelaTheme.tabBarHeight + 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Section Header

struct VelaMinimalSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.meta)
                .textCase(.uppercase)
                .tracking(1.0)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .padding(.top, VelaTheme.spaceSM)
        .padding(.bottom, VelaTheme.spaceSM)
    }
}

// MARK: - ImagePicker wrapper (for CoachChatPanel compat)

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

enum VelaMinimalTab: CaseIterable {
    case today, training, insights, settings
}

struct VelaMakeHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(VelaTheme.fg2)
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            Spacer(minLength: 8)
            trailing()
                .frame(minWidth: 32, minHeight: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

extension VelaMakeHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct VelaMakeCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct VelaMakeSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(VelaTheme.fg2)
            .padding(.horizontal, 4)
    }
}

struct VelaMakeIconTile: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}

struct VelaMakeRing: View {
    let value: Double
    let color: Color
    var size: CGFloat = 108
    var lineWidth: CGFloat = 8
    var valueText: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value / 100, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(valueText ?? "\(Int(value.rounded()))")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
                .monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

struct VelaMinimalNavBar: View {
    let title: String
    var body: some View {
        Text(title)
            .font(VelaTheme.title1())
            .foregroundStyle(VelaTheme.fg)
            .padding(.top, 8)
    }
}

struct VelaMinimalFloatingTabBar: View {
    @Binding var selectedTab: VelaMinimalTab
    var onCoachTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(VelaMinimalTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: tab))
                            .font(.system(size: 22))
                        Text(label(for: tab))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? VelaTheme.accent : VelaTheme.meta)
                }
                .buttonStyle(.plain)
                if tab != VelaMinimalTab.allCases.last { Spacer() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
    }

    private func icon(for tab: VelaMinimalTab) -> String {
        switch tab {
        case .today: "sun.max"
        case .training: "figure.run"
        case .insights: "heart.text.square"
        case .settings: "gearshape"
        }
    }

    private func label(for tab: VelaMinimalTab) -> String {
        switch tab {
        case .today: "Today"
        case .training: "Training"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }
}

// MARK: - Premium Shimmer & Skeleton View Modifiers

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width
                    
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.12),
                            .white.opacity(0.35),
                            .white.opacity(0.12),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(15))
                    .scaleEffect(1.5)
                    .offset(x: -width + (phase * width * 2.5))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

struct SkeletonModifier<S: Shape>: ViewModifier {
    var show: Bool
    var shape: S
    
    func body(content: Content) -> some View {
        if show {
            shape
                .fill(VelaTheme.borderSoft)
                .shimmer()
        } else {
            content
        }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
    
    func skeleton<S: Shape>(show: Bool, shape: S) -> some View {
        self.modifier(SkeletonModifier(show: show, shape: shape))
    }
}

// MARK: - VelaBackground — simple full-screen background
struct VelaBackground: View {
    var body: some View {
        VelaTheme.bg.ignoresSafeArea()
    }
}
