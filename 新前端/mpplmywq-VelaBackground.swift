import SwiftUI

struct VelaBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                VelaTheme.background,
                Color(red: 0.06, green: 0.05, blue: 0.08),
                Color(red: 0.05, green: 0.06, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
                                    accentColor.opacity(0.08),
                                    VelaTheme.elevatedSurface
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
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
