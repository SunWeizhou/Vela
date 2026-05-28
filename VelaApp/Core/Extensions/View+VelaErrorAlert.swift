import SwiftUI

struct VelaErrorAlertModifier: ViewModifier {
    @Binding var error: VelaError?

    func body(content: Content) -> some View {
        content
            .alert(
                error?.errorDescription ?? "Error",
                isPresented: .init(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { err in
                Button("OK") { error = nil }
            } message: { err in
                if let suggestion = err.recoverySuggestion {
                    Text(suggestion)
                }
            }
    }
}

extension View {
    func velaErrorAlert(error: Binding<VelaError?>) -> some View {
        modifier(VelaErrorAlertModifier(error: error))
    }
}
