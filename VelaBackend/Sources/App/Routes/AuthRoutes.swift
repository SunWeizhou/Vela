import Vapor
import Fluent

struct AuthRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let auth = routes.grouped("api", "auth")

        auth.post("register", use: register)
        auth.post("login", use: login)
        auth.post("refresh", use: refresh)
    }

    func register(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(RegisterRequest.self)

        guard input.email.contains("@") else {
            throw Abort(.badRequest, reason: "Invalid email format")
        }
        guard input.password.count >= 8 else {
            throw Abort(.badRequest, reason: "Password must be at least 8 characters")
        }

        let existing = try await User.query(on: req.db)
            .filter(\.$email == input.email.lowercased())
            .first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "Email already registered")
        }

        let passwordHash = try Bcrypt.hash(input.password)
        let user = User(
            email: input.email.lowercased(),
            passwordHash: passwordHash,
            timezone: input.timezone ?? "Asia/Shanghai",
            lang: input.lang ?? "zh"
        )
        try await user.save(on: req.db)

        // Create default settings for new user
        let settings = UserSettings(userId: user.id!)
        try await settings.save(on: req.db)

        let accessToken = try req.jwtService.generateAccessToken(for: user.id!)
        let refreshToken = try req.jwtService.generateRefreshToken(for: user.id!)

        return AuthResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: user.toProfile()
        )
    }

    func login(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(LoginRequest.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == input.email.lowercased())
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        guard try Bcrypt.verify(input.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid email or password")
        }

        let accessToken = try req.jwtService.generateAccessToken(for: user.id!)
        let refreshToken = try req.jwtService.generateRefreshToken(for: user.id!)

        return AuthResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: user.toProfile()
        )
    }

    func refresh(req: Request) async throws -> AuthResponse {
        let input = try req.content.decode(RefreshRequest.self)
        let payload = try req.jwtService.verifyRefreshToken(input.refreshToken)

        guard let userId = UUID(uuidString: payload.subject.value),
              let user = try await User.find(userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "Invalid token")
        }

        let accessToken = try req.jwtService.generateAccessToken(for: userId)
        let refreshToken = try req.jwtService.generateRefreshToken(for: userId)

        return AuthResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: user.toProfile()
        )
    }
}
