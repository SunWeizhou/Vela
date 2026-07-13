import SwiftUI
import SwiftData

@MainActor
final class CoachSessionStore: ObservableObject {
    @Published var sessions: [CoachSessionRecord] = []
    @Published var currentSession: CoachSessionRecord?
    @Published var persistenceError: String?

    init() {}

    func loadSessions(modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let descriptor = FetchDescriptor<CoachSessionRecord>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let list = (try? modelContext.fetch(descriptor)) ?? []
        self.sessions = list
        
        if list.isEmpty {
            let defaultSession = CoachSessionRecord(
                id: UUID(),
                title: "新对话",
                createdAt: Date(),
                updatedAt: Date(),
                serializedMessages: "[]"
            )
            modelContext.insert(defaultSession)
            do {
                try modelContext.save()
                self.sessions = [defaultSession]
                self.currentSession = defaultSession
                messagesHandler([])
            } catch {
                modelContext.rollback()
                persistenceError = "无法创建本地对话。请稍后重试。"
            }
        } else if self.currentSession == nil {
            self.currentSession = list.first
        }
        
        guard !isStreaming, !isAwaitingForegroundRetry else { return }

        if let currentSession {
            if let data = currentSession.serializedMessages.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([CoachChatVM.ChatMsg].self, from: data) {
                messagesHandler(decoded)
            } else {
                messagesHandler([])
            }
        }
    }

    func createNewSession(modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let newSession = CoachSessionRecord(
            id: UUID(),
            title: "新对话",
            createdAt: Date(),
            updatedAt: Date(),
            serializedMessages: "[]"
        )
        modelContext.insert(newSession)
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
            self.currentSession = newSession
            messagesHandler([])
        } catch {
            modelContext.rollback()
            persistenceError = "无法创建新对话。请稍后重试。"
        }
    }

    func selectSession(_ session: CoachSessionRecord, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        self.currentSession = session
        if let data = session.serializedMessages.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CoachChatVM.ChatMsg].self, from: data) {
            messagesHandler(decoded)
        } else {
            messagesHandler([])
        }
        loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
    }

    func deleteSession(_ session: CoachSessionRecord, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        modelContext.delete(session)
        do {
            try modelContext.save()
            if currentSession?.id == session.id {
                currentSession = nil
            }
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
        } catch {
            modelContext.rollback()
            persistenceError = "对话未删除。请稍后重试。"
        }
    }

    func renameSession(_ session: CoachSessionRecord, to newTitle: String, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let previousTitle = session.title
        let previousUpdatedAt = session.updatedAt
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title = trimmed.isEmpty ? "新对话" : trimmed
        session.updatedAt = Date()
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
        } catch {
            modelContext.rollback()
            session.title = previousTitle
            session.updatedAt = previousUpdatedAt
            persistenceError = "对话标题未保存。请稍后重试。"
        }
    }
}
