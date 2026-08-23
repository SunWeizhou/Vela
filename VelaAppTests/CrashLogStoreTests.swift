import XCTest
@testable import Vela

/// 崩溃诊断日志轮转回归测试（审计 H4）。
/// 不变量：每次记录写入独立时间戳文件；超过 keep 份时只保留最新 N 份。
final class CrashLogStoreTests: XCTestCase {

    func testRecordWritesTimestampedFile() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let url = try XCTUnwrap(CrashLogStore.record(
            "VELA_TEST_CRASH",
            directoryURL: dir,
            now: now
        ))

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("crash_diagnostic-"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "VELA_TEST_CRASH")
    }

    func testPruneKeepsNewestThree() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<5 {
            _ = try XCTUnwrap(CrashLogStore.record(
                "crash-\(i)",
                directoryURL: dir,
                now: base.addingTimeInterval(Double(i) * 60)
            ))
        }

        let remaining = (try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )).sorted { $0.lastPathComponent < $1.lastPathComponent }.filter {
            $0.lastPathComponent.hasPrefix("crash_diagnostic-")
        }

        XCTAssertEqual(remaining.count, 3)
        // 时间戳基准 1800000000 = 2027-01-15 08:00:00 UTC（+60s 递增）
        XCTAssertTrue(remaining[0].lastPathComponent.contains("080200"))
        XCTAssertTrue(remaining[1].lastPathComponent.contains("080300"))
        XCTAssertTrue(remaining[2].lastPathComponent.contains("080400"))
        // 最旧的 2 份（080000/080100）应被清理
        XCTAssertFalse(remaining.contains { $0.lastPathComponent.contains("080000") })
        XCTAssertFalse(remaining.contains { $0.lastPathComponent.contains("080100") })
    }

    func testRecordWhenDirectoryMissingCreatesIt() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashLogStore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let nested = parent.appendingPathComponent("nested")

        let url = CrashLogStore.record("x", directoryURL: nested)

        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CrashLogStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
