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

    /// Serializes read-modify-write sequences against the shared SwiftData store
    /// (which lives on the MainActor but can be mutated by multiple in-flight
    /// async tasks: foreground refresh, BGAppRefreshTask, Settings resync,
    /// workout save, proactive/adaptive managers). Concurrent fetch-then-insert
    /// on a @Attribute(.unique) record was the root cause of corrupted rows that
    /// historically crashed `fetchSnapshots`; this lock makes each write atomic.
    private let writeLock = NSLock()

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

    /// Runs `body` exclusively against the shared store. All callers that perform
    /// a fetch-then-insert/update on `DailyHealthSummaryRecord` must be wrapped in
    /// this so two in-flight async tasks cannot interleave and both insert the same
    /// unique `dayIdentifier` row (which SwiftData then traps on at save time).
    /// If read-only mode is on, throws instead of crashing the caller.
    public func withSerializedWrite<R>(operation: String, modelContext: ModelContext? = nil, _ body: () throws -> R) throws -> R {
        try assertWritable(operation: operation, modelContext: modelContext)
        writeLock.lock()
        defer { writeLock.unlock() }
        return try body()
    }
}
