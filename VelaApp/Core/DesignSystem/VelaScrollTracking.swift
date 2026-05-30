import SwiftUI

// MARK: - VelaScrollTracking
// Provides a shared mechanism for tab views to report scroll direction to VelaShell,
// enabling the collapsible floating tab bar without modifying each view's internals.

// MARK: - Scroll Direction Environment Key

enum VelaScrollDirection {
    case up, down, idle
}

private struct VelaScrollDirectionKey: EnvironmentKey {
    static let defaultValue: Binding<VelaScrollDirection> = .constant(.idle)
}

extension EnvironmentValues {
    var velaScrollDirection: Binding<VelaScrollDirection> {
        get { self[VelaScrollDirectionKey.self] }
        set { self[VelaScrollDirectionKey.self] = newValue }
    }
}

// MARK: - ScrollView Tracking Modifier (iOS 18+)

extension View {
    /// Attach this to any ScrollView to report scroll direction into the environment.
    @ViewBuilder
    func velaTrackScroll(direction: Binding<VelaScrollDirection>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldY, newY in
                let delta = newY - oldY
                if abs(delta) > 2 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        direction.wrappedValue = delta > 0 ? .down : .up
                    }
                }
            }
        } else {
            // iOS 17 fallback: no-op (tab bar stays visible)
            self
        }
    }
}
