import Foundation
import SwiftData

public protocol PersistenceWriteGateProtocol: Sendable {
    var canPersist: Bool { get }
    func assertWritable(operation: String, modelContext: ModelContext?) throws
}

public final class PersistenceWriteGate: PersistenceWriteGateProtocol, @unchecked Sendable {
    public static let shared = PersistenceWriteGate()
    
    /// Thread-safe flag indicating read-only safety mode.
    /// Set once at startup from VelaAppState, then readable from any isolation context.
    private var _isReadOnlySafetyMode: Bool = false
    
    private init() {}
    
    /// Update the cached read-only flag. Call from app init or tests.
    public func setReadOnly(_ value: Bool) {
        _isReadOnlySafetyMode = value
    }
    
    public var canPersist: Bool {
        return !_isReadOnlySafetyMode
    }
    
    public func assertWritable(operation: String, modelContext: ModelContext? = nil) throws {
        if _isReadOnlySafetyMode {
            let error = VelaError.readOnlySafetyMode
            if let modelContext {
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "Write Blocked: \(operation)",
                    isSuccess: false,
                    summary: "Operation '\(operation)' was blocked due to Safe Read-Only Mode.",
                    error: error
                )
            }
            throw error
        }
    }
}
