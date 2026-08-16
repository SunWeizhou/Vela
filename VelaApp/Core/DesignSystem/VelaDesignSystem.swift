import SwiftUI

// MARK: - Vela 3.0 Command System Components

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
        case .postWorkoutReview, .trainingAdjustment, .workoutReadiness: return VelaTheme.strainColor
        case .eveningReview: return VelaTheme.sleepColor
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
                    .foregroundStyle(VelaTheme.strainColor)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.strainColor.opacity(0.12)))

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .animation(
                reduceMotion
                    ? .easeOut(duration: VelaTheme.reducedMotionDuration)
                    : VelaTheme.press,
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == TabItemStyle {
    static var tabItem: TabItemStyle { TabItemStyle() }
}

struct TabItemStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.68 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.16) : VelaTheme.press, value: configuration.isPressed)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.16) : VelaTheme.press, value: configuration.isPressed)
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

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(color.opacity(intensity))
            )
    }
}

struct VelaThemeBackground: View {
    var body: some View {
        LinearGradient(
            colors: [VelaTheme.accent.opacity(0.055), VelaTheme.bg, VelaTheme.bg],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct VelaNativeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        colorSchemeContrast == .increased
                            ? VelaTheme.border
                            : VelaTheme.borderSoft.opacity(0.42),
                        lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                    )
            )
            .shadow(color: VelaTheme.cardShadow(colorScheme), radius: 12, y: 5)
    }
}

struct VelaGlassSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let needsSolidSurface = reduceTransparency || colorSchemeContrast == .increased

        content
            .background {
                if needsSolidSurface {
                    shape.fill(VelaTheme.cardBg)
                } else {
                    shape.fill(.ultraThinMaterial)
                }
            }
            .clipShape(shape)
            .overlay(
                shape.stroke(
                    colorSchemeContrast == .increased
                        ? VelaTheme.border
                        : VelaTheme.borderSoft.opacity(0.55),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                )
            )
    }
}

struct AppleIntelligenceGlowModifier: ViewModifier {
    let isHighlighted: Bool
    let radius: CGFloat
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
                                    Color(hex: "#9C5FF2")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
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

    func cardSurface(padding: CGFloat = VelaTheme.space4, radius: CGFloat = VelaTheme.radiusCardLarge) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(radius: radius)
    }

    func heroCardSurface(accent: Color = VelaTheme.accent, padding: CGFloat = VelaTheme.space4) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
            .glassEffect(radius: VelaTheme.radiusFeature)
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 0.8)
            )
    }

    func glassEffect(radius: CGFloat = VelaTheme.radiusCardLarge) -> some View {
        self.modifier(VelaGlassSurfaceModifier(radius: radius))
    }

    func sectionSpacing() -> some View {
        self.padding(.bottom, VelaTheme.space8)
    }

    func velaSheetSurface() -> some View {
        self
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(VelaTheme.radiusSheet)
            .presentationBackground(VelaTheme.rhythmCanvas)
    }
}

// MARK: - Screen Wrapper

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
        .padding(.top, VelaTheme.space2)
        .padding(.bottom, VelaTheme.space2)
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

// MARK: - Premium Shimmer & Skeleton View Modifiers

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let width = geo.size.width

                    if reduceMotion {
                        Color.white.opacity(0.08)
                    } else {
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
                }
            )
            .mask(content)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
            .onChange(of: reduceMotion) { _, shouldReduceMotion in
                phase = 0
                guard !shouldReduceMotion else { return }
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
