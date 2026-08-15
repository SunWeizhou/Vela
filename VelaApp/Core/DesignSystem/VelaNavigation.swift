import SwiftUI

// MARK: - GlassTabBar (4 tabs centered, floating capsule style with sliding active indicator)

extension View {
    func velaInteractiveGlass<S: Shape>(in shape: S) -> some View {
        modifier(VelaInteractiveGlassModifier(shape: shape))
    }
}

private struct VelaInteractiveGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency || colorSchemeContrast == .increased {
            content
                .background(VelaTheme.cardBg, in: shape)
                .overlay(
                    shape.stroke(
                        colorSchemeContrast == .increased ? VelaTheme.border : VelaTheme.borderSoft,
                        lineWidth: colorSchemeContrast == .increased ? 1 : 0.5
                    )
                )
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - DayPill (week strip day)
