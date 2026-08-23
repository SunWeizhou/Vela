import XCTest
@testable import Vela

/// 「清空 Vela 本地数据」完整性回归测试（审计 H7）。
/// 不变量：明文归档（daily_logs）与恢复备份（VelaRecovery）必须随清除动作删除，
/// 否则用户个人健康数据（含当日 HRV/RHR/血糖等）会残留并随 iCloud 备份离机。
final class PrivacyDeletionTests: XCTestCase {

    func testDeleteLocalLogsRemovesPlaintextArchive() throws {
        let dir = try makeTempDirectory(named: "daily_logs")
        defer { try? FileManager.default.removeItem(at: dir) }
        try "body data".write(to: dir.appendingPathComponent("2026-08-20.md"), atomically: true, encoding: .utf8)
        try "chat".write(to: dir.appendingPathComponent("2026-08-21.md"), atomically: true, encoding: .utf8)

        let deleted = try DailyLogService.deleteLocalLogs(at: dir)

        XCTAssertEqual(deleted, 2, "必须删除全部明文归档文件")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: dir.path),
            "daily_logs 目录必须整体删除"
        )
    }

    func testDeleteLocalLogsWhenDirectoryMissingIsNoop() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-daily-logs-\(UUID().uuidString)")

        let deleted = try DailyLogService.deleteLocalLogs(at: missing)

        XCTAssertEqual(deleted, 0)
    }

    func testDeleteRecoveryBackupsRemovesCopies() throws {
        let root = try makeTempDirectory(named: "VelaRecovery")
        defer { try? FileManager.default.removeItem(at: root) }
        let backup = root.appendingPathComponent("20260823-101500", isDirectory: true)
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        try Data().write(to: backup.appendingPathComponent("Vela.store"))

        let deleted = try VelaModelContainer.deleteRecoveryBackups(at: root)

        XCTAssertEqual(deleted, 1, "必须删除全部恢复备份")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testDeleteRecoveryBackupsWhenMissingIsNoop() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-recovery-\(UUID().uuidString)")

        let deleted = try VelaModelContainer.deleteRecoveryBackups(at: missing)

        XCTAssertEqual(deleted, 0)
    }

    private func makeTempDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
