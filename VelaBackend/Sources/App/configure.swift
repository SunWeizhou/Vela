import Vapor
import Fluent
import FluentSQLiteDriver
import JWT

private struct HealthCheckResponse: Content {
    let ok: Bool
    let version: String
    let timezone: String
}

public func configure(_ app: Application) throws {
    // ── Database ──
    app.databases.use(.sqlite(.file("vela.sqlite")), as: .sqlite)

    // ── Migrations ──
    app.migrations.add(CreateUser())
    app.migrations.add(CreateConversation())
    app.migrations.add(CreateMemoryCard())
    app.migrations.add(CreateTrustAudit())
    app.migrations.add(CreateUserSettings())
    app.migrations.add(CreateDailyPlan())
    try app.autoMigrate().wait()

    // ── JWT ──
    let jwtSecret = try jwtSecret(for: app.environment)
    app.jwt.signers.use(.hs256(key: jwtSecret))

    // Native iOS clients do not require CORS. Keep permissive CORS for local
    // browser tooling only; production deployments should use an explicit
    // reverse-proxy allowlist if a web client is added.
    if app.environment != .production {
        let cors = CORSMiddleware(configuration: .init(
            allowedOrigin: .all,
            allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
            allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith]
        ))
        app.middleware.use(cors, at: .beginning)
    }

    // ── Content config (JSON only) ──
    app.routes.defaultMaxBodySize = "1mb"

    // ── Public routes (no auth required) ──
    try app.register(collection: AuthRoutes())

    // ── All other routes require an access token ──
    let protected = app.grouped(AccessTokenMiddleware())
    try protected.register(collection: CoachRoutes())
    try protected.register(collection: TodayRoutes())
    try protected.register(collection: TrainingRoutes())
    try protected.register(collection: InsightsRoutes())
    try protected.register(collection: MemoryRoutes())
    try protected.register(collection: DataRoutes())
    try protected.register(collection: TrustRoutes())
    try protected.register(collection: SettingsRoutes())

    // ── Health Check ──
    app.get("api", "health") { _ in
        HealthCheckResponse(ok: true, version: "1.0.0", timezone: "Asia/Shanghai")
    }

    app.logger.info("Vela Backend started — 北京时间 \(Date())")
}

private func jwtSecret(for environment: Environment) throws -> String {
    if let configured = Environment.get("JWT_SECRET")?.trimmingCharacters(in: .whitespacesAndNewlines),
       configured.count >= 32 {
        return configured
    }
    guard environment != .production else {
        throw Abort(
            .internalServerError,
            reason: "JWT_SECRET must be configured with at least 32 characters in production."
        )
    }
    return "vela-local-development-only-secret"
}
