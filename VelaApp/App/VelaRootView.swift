import SwiftUI
import UIKit

enum VelaFeatureFlags {
    static let bevelParityInterfaceKey = "vela.feature.bevelParityInterface"

    /// Product scope switches (2026-08): hide secondary feature entries while keeping
    /// the underlying code in the repo. Flip back to `true` to re-enable instantly.
    /// Nutrition (food log / photo / barcode) is hidden to narrow scope to the core
    /// train–recover loop; Biological Age is hidden because it needs 9 blood-panel
    /// inputs most users never have. Code paths stay intact behind these flags.
    static let nutritionEnabled = false
    // Wearable-only mode: BiologicalAgeEngine falls back to "健康信号参考" when
    // blood biomarkers are unavailable (isPhenoAge == false). No lab panel required.
    static let biologicalAgeEnabled = true

    static func bevelParityInterfaceEnabled(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("-velaLegacyInterface") { return false }
        if arguments.contains("-velaBevelParityInterface") { return true }
        // Rhythm is now the production information architecture. The former
        // Bevel-parity shell remains available for visual regression work, but
        // it must be opted into explicitly instead of defining the product.
        guard defaults.object(forKey: bevelParityInterfaceKey) != nil else {
            return false
        }
        return defaults.bool(forKey: bevelParityInterfaceKey)
    }
}

struct VelaRootView: View {
    var body: some View {
        VelaShell(
            parityInterfaceEnabled: VelaFeatureFlags.bevelParityInterfaceEnabled()
        )
    }
}
