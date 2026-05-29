import Foundation

/// Central configuration for all automated agent skills
final class AutoAgentConfig: ObservableObject, @unchecked Sendable {
    static let shared = AutoAgentConfig()

    private let defaults = UserDefaults.standard

    // ── Skill Toggles ──
    @Published var autoEveningWikiSync: Bool {
        didSet { defaults.set(autoEveningWikiSync, forKey: "agent_auto_evening_wiki_sync") }
    }
    @Published var autoMorningBrief: Bool {
        didSet { defaults.set(autoMorningBrief, forKey: "agent_auto_morning_brief") }
    }
    @Published var proactiveInsights: Bool {
        didSet { defaults.set(proactiveInsights, forKey: "agent_proactive_insights") }
    }

    // ── Schedule Preferences ──
    @Published var eveningSyncHour: Int {
        didSet { defaults.set(eveningSyncHour, forKey: "agent_sync_hour") }
    }
    @Published var morningBriefHour: Int {
        didSet { defaults.set(morningBriefHour, forKey: "agent_brief_hour") }
    }

    // ── Notification Preferences ──
    @Published var abnormalMetricAlerts: Bool {
        didSet {
            defaults.set(abnormalMetricAlerts, forKey: "agent_abnormal_metric_alerts")
        }
    }
    @Published var morningBriefAlerts: Bool {
        didSet {
            defaults.set(morningBriefAlerts, forKey: "agent_morning_brief_alerts")
        }
    }
    @Published var bedtimeReminders: Bool {
        didSet {
            defaults.set(bedtimeReminders, forKey: "agent_bedtime_reminders")
        }
    }
    @Published var bedtimeHour: Int {
        didSet {
            defaults.set(bedtimeHour, forKey: "agent_bedtime_hour")
        }
    }
    @Published var bedtimeMinute: Int {
        didSet {
            defaults.set(bedtimeMinute, forKey: "agent_bedtime_minute")
        }
    }

    // ── Proactive Check-in Types (Bevel-inspired) ──
    @Published var progressCheckins: Bool {
        didSet { defaults.set(progressCheckins, forKey: "agent_progress_checkins") }
    }
    @Published var progressCheckinHour: Int {
        didSet { defaults.set(progressCheckinHour, forKey: "agent_progress_checkin_hour") }
    }
    @Published var weeklySummary: Bool {
        didSet { defaults.set(weeklySummary, forKey: "agent_weekly_summary") }
    }
    @Published var weeklySummaryDay: Int {  // 1=Sun, 2=Mon...
        didSet { defaults.set(weeklySummaryDay, forKey: "agent_weekly_summary_day") }
    }
    @Published var weeklySummaryHour: Int {
        didSet { defaults.set(weeklySummaryHour, forKey: "agent_weekly_summary_hour") }
    }

    private init() {
        // Skills — all enabled by default
        if defaults.object(forKey: "agent_auto_evening_wiki_sync") == nil {
            defaults.set(true, forKey: "agent_auto_evening_wiki_sync")
        }
        if defaults.object(forKey: "agent_auto_morning_brief") == nil {
            defaults.set(true, forKey: "agent_auto_morning_brief")
        }
        if defaults.object(forKey: "agent_proactive_insights") == nil {
            defaults.set(true, forKey: "agent_proactive_insights")
        }
        self.autoEveningWikiSync = defaults.bool(forKey: "agent_auto_evening_wiki_sync")
        self.autoMorningBrief = defaults.bool(forKey: "agent_auto_morning_brief")
        self.proactiveInsights = defaults.bool(forKey: "agent_proactive_insights")

        self.eveningSyncHour = defaults.integer(forKey: "agent_sync_hour").nonZero ?? 23
        self.morningBriefHour = defaults.integer(forKey: "agent_brief_hour").nonZero ?? 7

        // Notification preferences — all enabled by default
        if defaults.object(forKey: "agent_abnormal_metric_alerts") == nil {
            defaults.set(true, forKey: "agent_abnormal_metric_alerts")
        }
        if defaults.object(forKey: "agent_morning_brief_alerts") == nil {
            defaults.set(true, forKey: "agent_morning_brief_alerts")
        }
        if defaults.object(forKey: "agent_bedtime_reminders") == nil {
            defaults.set(true, forKey: "agent_bedtime_reminders")
        }
        self.abnormalMetricAlerts = defaults.bool(forKey: "agent_abnormal_metric_alerts")
        self.morningBriefAlerts = defaults.bool(forKey: "agent_morning_brief_alerts")
        self.bedtimeReminders = defaults.bool(forKey: "agent_bedtime_reminders")

        self.bedtimeHour = defaults.integer(forKey: "agent_bedtime_hour").nonZero ?? 22
        self.bedtimeMinute = defaults.integer(forKey: "agent_bedtime_minute")

        // Proactive check-ins
        if defaults.object(forKey: "agent_progress_checkins") == nil { defaults.set(true, forKey: "agent_progress_checkins") }
        if defaults.object(forKey: "agent_weekly_summary") == nil { defaults.set(true, forKey: "agent_weekly_summary") }
        self.progressCheckins = defaults.bool(forKey: "agent_progress_checkins")
        self.progressCheckinHour = defaults.integer(forKey: "agent_progress_checkin_hour").nonZero ?? 12
        self.weeklySummary = defaults.bool(forKey: "agent_weekly_summary")
        self.weeklySummaryDay = defaults.integer(forKey: "agent_weekly_summary_day").nonZero ?? 2
        self.weeklySummaryHour = defaults.integer(forKey: "agent_weekly_summary_hour").nonZero ?? 9
    }
}

/// Display model for the skills config UI
struct AgentSkillInfo: Identifiable {
    let id: String
    let name: String          // e.g. "夜间 Wiki 同步"
    let enName: String
    let icon: String
    let description: String
    let enDescription: String
    let schedule: String      // e.g. "每晚 23:00"
    var isEnabled: Bool
    let configKey: WritableKeyPath<AutoAgentConfig, Bool>
}

extension AutoAgentConfig {
    func skillList(isChinese: Bool) -> [AgentSkillInfo] {
        [
            AgentSkillInfo(
                id: "evening_wiki_sync",
                name: "夜间 Wiki 同步",
                enName: "Nightly Wiki Sync",
                icon: "moon.stars.fill",
                description: "每晚自动总结当日健康数据和对话，更新 Wiki 档案",
                enDescription: "Auto-summarize daily health & chat into your Wiki each night",
                schedule: isChinese ? "每晚 \(eveningSyncHour):00" : "Nightly at \(eveningSyncHour):00",
                isEnabled: autoEveningWikiSync,
                configKey: \.autoEveningWikiSync
            ),
            AgentSkillInfo(
                id: "morning_brief",
                name: "晨间简报",
                enName: "Morning Brief",
                icon: "sunrise.fill",
                description: "早晨自动生成当日的健康状态简报",
                enDescription: "Auto-generate your morning health brief at wake time",
                schedule: isChinese ? "每天早上 \(morningBriefHour):00 发送" : "Every morning at \(morningBriefHour):00",
                isEnabled: autoMorningBrief,
                configKey: \.autoMorningBrief
            ),
            AgentSkillInfo(
                id: "proactive_insights",
                name: "主动洞察",
                enName: "Proactive Insights",
                icon: "sparkle.magnifyingglass",
                description: "根据异常数据自动推送健康提醒和建议",
                enDescription: "Auto-push health alerts based on abnormal physiological data",
                schedule: isChinese ? "持续监测" : "Continuous",
                isEnabled: proactiveInsights,
                configKey: \.proactiveInsights
            )
        ]
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
