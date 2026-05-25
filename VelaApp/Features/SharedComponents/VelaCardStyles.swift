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
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
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
    
    /// Shrinks the view slightly when pressed and triggers a light mechanical haptic feedback.
    func scaleOnPress() -> some View {
        modifier(ScaleOnPressModifier())
    }
}

struct ScaleOnPressModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            UISelectionFeedbackGenerator().selectionChanged()
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

struct ScaleOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
    }
}

extension ButtonStyle where Self == ScaleOnPressButtonStyle {
    static var scaleOnPress: ScaleOnPressButtonStyle {
        ScaleOnPressButtonStyle()
    }
}
