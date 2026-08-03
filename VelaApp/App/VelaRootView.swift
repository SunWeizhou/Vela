import SwiftUI
import UIKit

enum VelaFeatureFlags {
    static let bevelParityInterfaceKey = "vela.feature.bevelParityInterface"

    static func bevelParityInterfaceEnabled(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        if arguments.contains("-velaLegacyInterface") { return false }
        if arguments.contains("-velaBevelParityInterface") { return true }
        guard defaults.object(forKey: bevelParityInterfaceKey) != nil else {
            return true
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
