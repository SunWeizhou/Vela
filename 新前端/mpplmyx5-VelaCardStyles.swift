import SwiftUI

struct StandardCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}

struct CompactCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.elevatedSurface)
            )
    }
}

extension View {
    func standardCard() -> some View {
        modifier(StandardCardModifier())
    }

    func compactCard() -> some View {
        modifier(CompactCardModifier())
    }
}
