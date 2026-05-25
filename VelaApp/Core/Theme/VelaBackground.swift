import SwiftUI

struct VelaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                VelaTheme.background,
                VelaTheme.backgroundSecondary,
                VelaTheme.backgroundTertiary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
                        .fill(VelaTheme.surface)
                        .shadow(color: VelaTheme.cardShadowColor, radius: 20, y: 9)
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.5)
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
                        .fill(
                            LinearGradient(
                                colors: [
                                    VelaTheme.elevatedSurface,
                                    accentColor.opacity(0.10),
                                    VelaTheme.elevatedSurface
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: VelaTheme.cardShadowColor, radius: 24, y: 10)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.8)
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
