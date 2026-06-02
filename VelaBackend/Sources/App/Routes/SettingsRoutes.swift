import Vapor
import Fluent

struct SettingsRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let settings = routes.grouped("api", "settings")
        settings.put(use: updateSettings)
        settings.get(":userId", use: getSettings)
    }

    /// PUT /api/settings
    func updateSettings(req: Request) async throws -> SettingsResponse {
        let input = try req.content.decode(SettingsRequest.self)
        guard let userId = UUID(uuidString: input.userId) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        guard userId == (try req.authenticatedUser()) else {
            throw Abort(.forbidden)
        }

        // Upsert settings
        let existing = try await UserSettings.query(on: req.db)
            .filter(\.$userId == userId)
            .first()

        let settings: UserSettings
        if let existing {
            settings = existing
        } else {
            settings = UserSettings(userId: userId)
        }
        if let lang = input.language { settings.language = lang }
        if let notif = input.notifications {
            settings.notificationsJson = (try? String(data: JSONEncoder().encode(notif), encoding: .utf8)) ?? "{}"
        }
        if let sources = input.dataSources {
            settings.dataSources = (try? String(data: JSONEncoder().encode(sources), encoding: .utf8)) ?? "[]"
        }
        if let personality = input.coachPersonality { settings.coachPersonality = personality }
        if let theme = input.theme { settings.theme = theme }
        try await settings.save(on: req.db)

        let notif: SettingsRequest.NotificationSettings = {
            if let data = settings.notificationsJson.data(using: .utf8),
               let n = try? JSONDecoder().decode(SettingsRequest.NotificationSettings.self, from: data) {
                return n
            }
            return SettingsRequest.NotificationSettings(morningBrief: true, eveningSync: true, abnormalAlerts: true)
        }()

        let sources: [String] = {
            if let data = settings.dataSources.data(using: .utf8),
               let s = try? JSONDecoder().decode([String].self, from: data) {
                return s
            }
            return ["apple_watch"]
        }()

        return SettingsResponse(ok: true, settings: SettingsResponse.UserSettingsDTO(
            language: settings.language,
            notifications: notif,
            dataSources: sources,
            coachPersonality: settings.coachPersonality,
            theme: settings.theme
        ))
    }

    /// GET /api/settings/:userId
    func getSettings(req: Request) async throws -> SettingsResponse {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard userId == (try req.authenticatedUser()) else {
            throw Abort(.forbidden)
        }
        let settings = try await UserSettings.query(on: req.db)
            .filter(\.$userId == userId)
            .first()

        let s = settings ?? UserSettings(userId: userId)
        return SettingsResponse(ok: true, settings: toDTO(s))
    }

    private func toDTO(_ s: UserSettings) -> SettingsResponse.UserSettingsDTO {
        let notif: SettingsRequest.NotificationSettings = {
            if let data = s.notificationsJson.data(using: .utf8),
               let n = try? JSONDecoder().decode(SettingsRequest.NotificationSettings.self, from: data) {
                return n
            }
            return SettingsRequest.NotificationSettings(morningBrief: true, eveningSync: true, abnormalAlerts: true)
        }()
        let sources: [String] = {
            if let data = s.dataSources.data(using: .utf8),
               let src = try? JSONDecoder().decode([String].self, from: data) {
                return src
            }
            return ["apple_watch"]
        }()
        return SettingsResponse.UserSettingsDTO(
            language: s.language, notifications: notif,
            dataSources: sources, coachPersonality: s.coachPersonality, theme: s.theme
        )
    }
}
