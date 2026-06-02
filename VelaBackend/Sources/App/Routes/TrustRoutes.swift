import Vapor
import Fluent

struct TrustRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "trust", "audit", use: getAudit)
    }

    /// GET /api/trust/audit?user_id=xxx&days=30
    func getAudit(req: Request) async throws -> TrustAuditResponse {
        let userId = try req.query.get(UUID.self, at: "user_id")
        guard userId == (try req.authenticatedUser()) else {
            throw Abort(.forbidden)
        }
        let days = req.query[String.self, at: "days"].flatMap { Int($0) } ?? 30

        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let entries = try await TrustAuditEntry.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$timestamp >= cutoff)
            .sort(\.$timestamp, .descending)
            .all()

        let totalOps = entries.count
        let successes = entries.filter { $0.resultStatus == "success" }.count
        let lastModel = entries.first?.modelVersion ?? "N/A"

        return TrustAuditResponse(
            entries: entries.map { e in
                TrustAuditResponse.AuditEntryDTO(
                    id: e.id ?? UUID(),
                    timestamp: e.timestamp ?? Date(),
                    toolName: e.toolName,
                    parameters: e.parameters,
                    resultStatus: e.resultStatus,
                    modelVersion: e.modelVersion
                )
            },
            summary: TrustAuditResponse.AuditSummary(
                totalOperations: totalOps,
                successRate: totalOps > 0 ? Double(successes) / Double(totalOps) : 0,
                lastModel: lastModel,
                periodDays: days
            )
        )
    }
}
