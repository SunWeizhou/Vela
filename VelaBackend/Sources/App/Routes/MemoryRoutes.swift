import Vapor
import Fluent

struct MemoryRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let memory = routes.grouped("api", "memory")
        memory.get("inbox", use: getInbox)
        memory.put("card", ":cardId", use: updateCard)
    }

    /// GET /api/memory/inbox?user_id=xxx&lang=zh
    func getInbox(req: Request) async throws -> MemoryCardResponse {
        let userId = try req.query.get(UUID.self, at: "user_id")
        guard userId == (try req.authenticatedUser()) else {
            throw Abort(.forbidden)
        }
        let cards = try await MemoryCard.query(on: req.db)
            .filter(\.$userId == userId)
            .filter(\.$status == "pending")
            .sort(\.$createdAt, .descending)
            .all()

        return MemoryCardResponse(cards: cards.map { c in
            MemoryCardResponse.MemoryCardDTO(
                id: c.id ?? UUID(), pattern: c.pattern,
                evidence: c.evidence, confidence: c.confidence,
                status: c.status, createdAt: c.createdAt ?? Date()
            )
        })
    }

    /// PUT /api/memory/card/:cardId
    /// Body: { status: "confirmed" | "rejected" }
    func updateCard(req: Request) async throws -> HTTPStatus {
        guard let cardId = req.parameters.get("cardId", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let status = try req.content.get(String.self, at: "status")
        guard ["confirmed", "rejected"].contains(status) else {
            throw Abort(.badRequest, reason: "Status must be confirmed or rejected")
        }

        guard let card = try await MemoryCard.find(cardId, on: req.db) else {
            throw Abort(.notFound)
        }
        guard card.userId == (try req.authenticatedUser()) else {
            throw Abort(.forbidden)
        }
        card.status = status
        try await card.save(on: req.db)
        return .ok
    }
}
