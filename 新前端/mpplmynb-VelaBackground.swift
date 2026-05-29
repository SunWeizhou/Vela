import SwiftUI

struct VelaBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    VelaTheme.background,
                    VelaTheme.backgroundSecondary,
                    VelaTheme.backgroundTertiary
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(VelaTheme.accent.opacity(0.055))
                .frame(width: 420, height: 420)
                .blur(radius: 72)
                .offset(y: -260)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct CardSurface: ViewModifier {
    var accentColor: Color?

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .fill(.thinMaterial)
                        .shadow(color: VelaTheme.cardShadowColor, radius: 18, y: 8)
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .fill(VelaTheme.surface.opacity(0.35))
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.8)
                }
            )
    }
}

struct HeroCardSurface: ViewModifier {
    var accentColor: Color

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.thinMaterial)
                        .shadow(color: VelaTheme.cardShadowColor, radius: 22, y: 10)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(accentColor.opacity(0.055))
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.85)
                }
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    func heroCardSurface(accent: Color) -> some View {
        modifier(HeroCardSurface(accentColor: accent))
    }
}
