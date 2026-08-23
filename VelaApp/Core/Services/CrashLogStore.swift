import Foundation

/// 崩溃诊断存储（审计 H4 本地部分）：未捕获 ObjC 异常时落盘为
/// `crash_diagnostic-<时间戳>.log`，并保留最近 N 份（覆盖式单文件此前
/// 会被下一次崩溃冲掉，且无法对应时间点）。轮转与目录可注入以支持测试。
enum CrashLogStore {
    static let filePrefix = "crash_diagnostic-"
    static let keepCount = 3

    /// - Parameter directoryURL: 省略时使用 Application Support/Vela。
    static func record(
        _ message: String,
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        now: Date = Date(),
        keep: Int = CrashLogStore.keepCount
    ) -> URL? {
        let directory = directoryURL ?? URL.applicationSupportDirectory
            .appending(path: "Vela", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileURL = directory.appendingPathComponent(
                "\(filePrefix)\(formatter.string(from: now)).log"
            )
            try message.write(to: fileURL, atomically: true, encoding: .utf8)
            prune(directory: directory, fileManager: fileManager, keep: keep)
            return fileURL
        } catch {
            return nil
        }
    }

    /// 只保留最新 keep 份（按文件名字典序，时间戳格式保证有序）。
    static func prune(
        directory: URL,
        fileManager: FileManager = .default,
        keep: Int = CrashLogStore.keepCount
    ) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        let logs = contents
            .filter { $0.lastPathComponent.hasPrefix(filePrefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard logs.count > keep else { return }
        for stale in logs.prefix(logs.count - keep) {
            try? fileManager.removeItem(at: stale)
        }
    }
}
