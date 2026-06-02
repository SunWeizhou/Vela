import Vapor
import JWT

struct UserJWTPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

struct RefreshTokenPayload: JWTPayload {
    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var issuedAt: IssuedAtClaim

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

struct JWTService {
    let app: Application

    func generateAccessToken(for userId: UUID) throws -> String {
        let payload = UserJWTPayload(
            subject: SubjectClaim(value: userId.uuidString),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(15 * 60)),
            issuedAt: IssuedAtClaim(value: Date())
        )
        return try app.jwt.signers.sign(payload)
    }

    func generateRefreshToken(for userId: UUID) throws -> String {
        let payload = RefreshTokenPayload(
            subject: SubjectClaim(value: userId.uuidString),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(7 * 24 * 3600)),
            issuedAt: IssuedAtClaim(value: Date())
        )
        return try app.jwt.signers.sign(payload)
    }

    func verifyAccessToken(_ token: String) throws -> UserJWTPayload {
        try app.jwt.signers.verify(token, as: UserJWTPayload.self)
    }

    func verifyRefreshToken(_ token: String) throws -> RefreshTokenPayload {
        try app.jwt.signers.verify(token, as: RefreshTokenPayload.self)
    }
}

extension Application {
    var jwtService: JWTService {
        JWTService(app: self)
    }
}

extension Request {
    var jwtService: JWTService {
        JWTService(app: application)
    }

    func authenticatedUser() throws -> UUID {
        guard let token = headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer token")
        }
        let payload = try application.jwtService.verifyAccessToken(token)
        guard let userId = UUID(uuidString: payload.subject.value) else {
            throw Abort(.unauthorized, reason: "Invalid token subject")
        }
        return userId
    }
}

struct AccessTokenMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        _ = try request.authenticatedUser()
        return try await next.respond(to: request)
    }
}
