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
    /// Protects the safety-mode flag independently from the write lock. The gate
    /// is intentionally `@unchecked Sendable` because callers may check or
    /// update the flag from different isolation domains (foreground MainActor,
    /// background refresh, and tests). A plain Bool would race under those
    /// concurrent reads/writes even though the actual persistence operation is
    /// serialized below.
    private let safetyModeLock = NSLock()

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
        safetyModeLock.lock()
        defer { safetyModeLock.unlock() }
        _isReadOnlySafetyMode = value
    }

    public var canPersist: Bool {
        return !isReadOnlySafetyMode
    }

    private var isReadOnlySafetyMode: Bool {
        safetyModeLock.lock()
        defer { safetyModeLock.unlock() }
        return _isReadOnlySafetyMode
    }

    public func assertWritable(operation: String, modelContext: ModelContext? = nil) throws {
        if isReadOnlySafetyMode {
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
        writeLock.lock()
        defer { writeLock.unlock() }
        // Linearize the safety-mode check with other serialized writes. A
        // transition that arrives after this check cannot cancel an operation
        // already in flight, but no new operation can pass the gate between
        // checking and entering the critical section.
        try assertWritable(operation: operation, modelContext: modelContext)
        return try body()
    }
}
