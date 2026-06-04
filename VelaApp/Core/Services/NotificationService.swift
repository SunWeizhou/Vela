import Foundation
import UserNotifications
import os.log

// MARK: - Notification Categories

enum VelaNotificationCategory: String, CaseIterable {
    case abnormalMetric = "ABNORMAL_METRIC"
    case morningBrief = "MORNING_BRIEF"
    case bedtimeReminder = "BEDTIME_REMINDER"

    var identifier: String { rawValue }
}

// MARK: - Notification Service

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "NotificationService")
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    // MARK: - Preference Keys

    private enum PreferenceKey {
        static let abnormalMetricAlerts = "agent_abnormal_metric_alerts"
        static let morningBriefAlerts = "agent_morning_brief_alerts"
        static let bedtimeReminders = "agent_bedtime_reminders"
        static let bedtimeHour = "agent_bedtime_hour"
        static let bedtimeMinute = "agent_bedtime_minute"
        static let lastAbnormalAlertDate = "notif_last_abnormal_alert_date"
        static let lastAbnormalAlertSeverities = "notif_last_abnormal_alert_severities"
    }

    private init() {
        // Set default preference values on first launch
        if defaults.object(forKey: PreferenceKey.abnormalMetricAlerts) == nil {
            defaults.set(true, forKey: PreferenceKey.abnormalMetricAlerts)
        }
        if defaults.object(forKey: PreferenceKey.morningBriefAlerts) == nil {
            defaults.set(true, forKey: PreferenceKey.morningBriefAlerts)
        }
        if defaults.object(forKey: PreferenceKey.bedtimeReminders) == nil {
            defaults.set(true, forKey: PreferenceKey.bedtimeReminders)
        }
    }

    // MARK: - Public Preference Access

    var abnormalMetricAlertsEnabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.abnormalMetricAlerts) }
        set { defaults.set(newValue, forKey: PreferenceKey.abnormalMetricAlerts) }
    }

    var morningBriefAlertsEnabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.morningBriefAlerts) }
        set { defaults.set(newValue, forKey: PreferenceKey.morningBriefAlerts) }
    }

    var bedtimeRemindersEnabled: Bool {
        get { defaults.bool(forKey: PreferenceKey.bedtimeReminders) }
        set {
            defaults.set(newValue, forKey: PreferenceKey.bedtimeReminders)
            if newValue {
                scheduleBedtimeReminder()
            } else {
                cancelBedtimeReminder()
            }
        }
    }

    var bedtimeHour: Int {
        get {
            let hour = defaults.integer(forKey: PreferenceKey.bedtimeHour)
            return hour == 0 ? 22 : hour
        }
        set { defaults.set(newValue, forKey: PreferenceKey.bedtimeHour) }
    }

    var bedtimeMinute: Int {
        get {
            let minute = defaults.integer(forKey: PreferenceKey.bedtimeMinute)
            return minute
        }
        set { defaults.set(newValue, forKey: PreferenceKey.bedtimeMinute) }
    }

    // MARK: - Authorization

    /// Request notification permissions and return whether authorized.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification authorization result: \(granted)")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// Check current notification authorization status.
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Register Categories

    /// Register all notification categories and their actions. Call once at app launch.
    func registerNotificationCategories() {
        // Abnormal Metric Category — with "View in Vela" action
        let viewAction = UNNotificationAction(
            identifier: "VIEW_IN_VELA",
            title: "View in Vela",
            options: .foreground
        )
        let abnormalMetricCategory = UNNotificationCategory(
            identifier: VelaNotificationCategory.abnormalMetric.identifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        // Morning Brief Category — with "Open Brief" action
        let openBriefAction = UNNotificationAction(
            identifier: "OPEN_BRIEF",
            title: "Open Brief",
            options: .foreground
        )
        let morningBriefCategory = UNNotificationCategory(
            identifier: VelaNotificationCategory.morningBrief.identifier,
            actions: [openBriefAction],
            intentIdentifiers: [],
            options: []
        )

        // Bedtime Reminder Category — dismiss only (no actions)
        let bedtimeReminderCategory = UNNotificationCategory(
            identifier: VelaNotificationCategory.bedtimeReminder.identifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            abnormalMetricCategory,
            morningBriefCategory,
            bedtimeReminderCategory
        ])
        logger.info("Notification categories registered.")
    }

    // MARK: - Morning Brief Notification

    /// Schedule a morning brief check. Called by MorningBriefScheduler after generation.
    func scheduleMorningBriefCheck() {
        guard morningBriefAlertsEnabled else {
            logger.info("Morning brief alerts disabled, skipping notification.")
            return
        }
        let content = Self.morningBriefNotificationContent(language: AppLanguage.stored)
        sendNotification(
            title: content.title,
            body: content.body,
            category: .morningBrief
        )
    }

    // MARK: - Bedtime Reminder

    /// Schedule a daily bedtime reminder notification.
    func scheduleBedtimeReminder() {
        guard bedtimeRemindersEnabled else {
            logger.info("Bedtime reminders disabled, skipping schedule.")
            return
        }

        cancelBedtimeReminder()

        let content = UNMutableNotificationContent()
        let localized = Self.bedtimeNotificationContent(language: AppLanguage.stored)
        content.title = localized.title
        content.body = localized.body
        content.sound = .default
        content.categoryIdentifier = VelaNotificationCategory.bedtimeReminder.identifier

        let scheduledHour = bedtimeHour
        let scheduledMinute = bedtimeMinute
        var dateComponents = DateComponents()
        dateComponents.hour = scheduledHour
        dateComponents.minute = scheduledMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "bedtime_reminder",
            content: content,
            trigger: trigger
        )

        center.add(request) { [logger] error in
            if let error {
                logger.error("Failed to schedule bedtime reminder: \(error.localizedDescription)")
            } else {
                logger.info("Bedtime reminder scheduled for \(scheduledHour):\(String(format: "%02d", scheduledMinute))")
            }
        }
    }

    /// Cancel the bedtime reminder notification.
    func cancelBedtimeReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["bedtime_reminder"])
        logger.info("Bedtime reminder canceled.")
    }

    // MARK: - Abnormal Metric Alerts

    /// Check for abnormal health metrics and send alerts if needed.
    /// Debounces to at most one alert per day to avoid notification fatigue.
    func checkAndAlertAbnormalMetrics(snapshot: DailyHealthSnapshot, baselines: PersonalBaselines?) {
        guard abnormalMetricAlertsEnabled else {
            logger.info("Abnormal metric alerts disabled, skipping check.")
            return
        }

        let candidates = Self.abnormalMetricAlertCandidates(
            snapshot: snapshot,
            baselines: baselines,
            language: AppLanguage.stored
        )
        let alerts = candidates.filter { shouldSendAbnormalAlert(metric: $0.metric, severity: $0.severity) }

        guard !alerts.isEmpty else {
            logger.info("No abnormal metrics detected.")
            return
        }

        // Build summary notification
        let isChinese = AppLanguage.stored.isChinese
        let title = alerts.count == 1
            ? (isChinese ? "健康信号提醒" : "Health Signal")
            : (isChinese ? "\(alerts.count) 个健康信号提醒" : "\(alerts.count) Health Signals")
        let body = alerts.map(\.message).joined(separator: isChinese ? "。" : ". ")

        sendNotification(title: title, body: body, category: .abnormalMetric)

        recordSentAbnormalAlerts(alerts)
    }

    // MARK: - Consecutive Sleep Check

    /// Synchronous check for 2+ consecutive days of low sleep score.
    func checkConsecutiveLowSleep(currentSleepScore: Double?, yesterdaySleepScore: Double?) -> Bool {
        guard let current = currentSleepScore, current < 50 else { return false }
        guard let yesterday = yesterdaySleepScore, yesterday < 50 else { return false }
        return true
    }

    // MARK: - Send Notification

    /// Send a local notification immediately.
    func sendNotification(title: String, body: String, category: VelaNotificationCategory?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category {
            content.categoryIdentifier = category.identifier
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // immediate delivery
        )

        center.add(request) { [weak self] error in
            if let error {
                self?.logger.error("Failed to send notification '\(title)': \(error.localizedDescription)")
            } else {
                self?.logger.info("Notification sent: '\(title)'")
            }
        }
    }

    private func shouldSendAbnormalAlert(metric: String, severity: String, date: Date = Date()) -> Bool {
        let key = abnormalAlertStorageKey(metric: metric, date: date)
        let lastSeverity = abnormalAlertSeverities()[key]
        return Self.severityRank(severity) > Self.severityRank(lastSeverity)
    }

    private func recordSentAbnormalAlerts(_ alerts: [AbnormalMetricAlertCandidate], date: Date = Date()) {
        var values = abnormalAlertSeverities()
        for alert in alerts {
            values[abnormalAlertStorageKey(metric: alert.metric, date: date)] = alert.severity
        }
        defaults.set(values, forKey: PreferenceKey.lastAbnormalAlertSeverities)
    }

    private func abnormalAlertSeverities() -> [String: String] {
        defaults.dictionary(forKey: PreferenceKey.lastAbnormalAlertSeverities) as? [String: String] ?? [:]
    }

    private func abnormalAlertStorageKey(metric: String, date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "\(metric)|\(formatter.string(from: date))"
    }

    static func morningBriefNotificationContent(language: AppLanguage) -> (title: String, body: String) {
        language.isChinese
            ? ("晨间简报已生成", "查看今天的恢复、睡眠和训练负荷建议。")
            : ("Your morning brief is ready", "Check today's recovery, sleep, and training guidance.")
    }

    static func bedtimeNotificationContent(language: AppLanguage) -> (title: String, body: String) {
        language.isChinese
            ? ("准备进入睡前节奏", "计划睡眠时间快到了，可以开始放松并减少刺激。")
            : ("Time to wind down", "Your planned bedtime is approaching. Start relaxing and reduce stimulation.")
    }

    static func abnormalMetricAlertCandidates(
        snapshot: DailyHealthSnapshot,
        baselines: PersonalBaselines?,
        language: AppLanguage
    ) -> [AbnormalMetricAlertCandidate] {
        var alerts: [AbnormalMetricAlertCandidate] = []
        let isChinese = language.isChinese

        if let hrv = snapshot.hrvAverage, let baseline = baselines?.hrvBaselineMean, baseline > 0 {
            let drop = (baseline - hrv) / baseline
            if drop > 0.20 {
                let severity = drop > 0.35 ? "high" : "medium"
                let pct = Int(drop * 100)
                alerts.append(.init(
                    metric: "hrv",
                    severity: severity,
                    message: isChinese
                        ? "HRV 比个人基线低 \(pct)%，今天适合降低训练压力"
                        : "HRV is \(pct)% below your baseline; consider reducing training pressure today"
                ))
            }
        }

        if let rhr = snapshot.restingHeartRate, let baseline = baselines?.rhrBaselineMean, baseline > 0 {
            let rise = (rhr - baseline) / baseline
            if rise > 0.10 {
                let severity = rise > 0.18 ? "high" : "medium"
                let pct = Int(rise * 100)
                alerts.append(.init(
                    metric: "restingHeartRate",
                    severity: severity,
                    message: isChinese
                        ? "静息心率比个人基线高 \(pct)%，建议观察恢复状态"
                        : "Resting heart rate is \(pct)% above baseline; keep an eye on recovery"
                ))
            }
        }

        if let recovery = snapshot.recoveryScore, recovery < 40 {
            alerts.append(.init(
                metric: "recovery",
                severity: recovery < 25 ? "high" : "medium",
                message: isChinese
                    ? "恢复分较低（\(String(format: "%.0f", recovery))），今天建议安排轻量或恢复性训练"
                    : "Recovery is low (\(String(format: "%.0f", recovery))); consider light or recovery-focused training today"
            ))
        }

        if let stress = snapshot.stressIndex, stress > 80 {
            alerts.append(.init(
                metric: "stress",
                severity: stress > 90 ? "high" : "medium",
                message: isChinese
                    ? "压力指数偏高（\(String(format: "%.0f", stress))），可以安排放松或呼吸练习"
                    : "Stress index is elevated (\(String(format: "%.0f", stress))); consider relaxation or breathing work"
            ))
        }

        return alerts
    }

    static func shouldSendAbnormalAlert(previousSeverity: String?, newSeverity: String) -> Bool {
        severityRank(newSeverity) > severityRank(previousSeverity)
    }

    private static func severityRank(_ severity: String?) -> Int {
        switch severity {
        case "low": return 1
        case "medium": return 2
        case "high": return 3
        default: return 0
        }
    }
}

struct AbnormalMetricAlertCandidate: Hashable {
    var metric: String
    var severity: String
    var message: String
}
