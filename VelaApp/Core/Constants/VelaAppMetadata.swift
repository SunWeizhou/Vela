import Foundation

enum VelaAppMetadata {
    static let name = "Vela"
    static let minimumOSVersion = "17.0"
    static let configVersion = "v0.1"

    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "4.0.0"
    }
}
