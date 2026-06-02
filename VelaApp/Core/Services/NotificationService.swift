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
        sendNotification(
            title: "Your morning brief is ready",
            body: "Check your recovery, sleep, and strain insights for today.",
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
        content.title = "Time to wind down"
        content.body = "Your scheduled bedtime is approaching. Start relaxing to improve your sleep quality."
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

        // Debounce: only send abnormal alerts once per calendar day
        if let lastDateStr = defaults.string(forKey: PreferenceKey.lastAbnormalAlertDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let lastDate = formatter.date(from: lastDateStr),
               Calendar.current.isDateInToday(lastDate) {
                logger.info("Abnormal alert already sent today, skipping.")
                return
            }
        }

        var alerts: [String] = []

        // HRV drops >20% below personal baseline
        if let hrv = snapshot.hrvAverage, let baseline = baselines?.hrvBaselineMean, baseline > 0 {
            let drop = (baseline - hrv) / baseline
            if drop > 0.20 {
                let pct = Int(drop * 100)
                alerts.append("HRV dropped \(pct)% below your personal baseline (\(String(format: "%.0f", hrv)) vs \(String(format: "%.0f", baseline)) ms)")
            }
        }

        // RHR rises >10% above baseline
        if let rhr = snapshot.restingHeartRate, let baseline = baselines?.rhrBaselineMean, baseline > 0 {
            let rise = (rhr - baseline) / baseline
            if rise > 0.10 {
                let pct = Int(rise * 100)
                alerts.append("RHR elevated \(pct)% above your baseline (\(String(format: "%.0f", rhr)) vs \(String(format: "%.0f", baseline)) bpm)")
            }
        }

        // Recovery score < 40
        if let recovery = snapshot.recoveryScore, recovery < 40 {
            alerts.append("Recovery score is low (\(String(format: "%.0f", recovery))) — consider a rest day")
        }

        // Stress index > 80
        if let stress = snapshot.stressIndex, stress > 80 {
            alerts.append("Stress index is high (\(String(format: "%.0f", stress))) — consider relaxation activities")
        }

        guard !alerts.isEmpty else {
            logger.info("No abnormal metrics detected.")
            return
        }

        // Build summary notification
        let title = alerts.count == 1 ? "Health Alert" : "\(alerts.count) Health Alerts"
        let body = alerts.joined(separator: ". ")

        sendNotification(title: title, body: body, category: .abnormalMetric)

        // Record that we sent an alert today
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        defaults.set(formatter.string(from: Date()), forKey: PreferenceKey.lastAbnormalAlertDate)
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
}
