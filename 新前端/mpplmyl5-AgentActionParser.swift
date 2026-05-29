import Foundation
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "AgentActionParser")

enum AgentActionType: String, Codable, Hashable, CaseIterable {
    case updateWiki = "update_wiki"
    case createDailyLog = "create_daily_log"
}

struct AgentAction: Identifiable, Hashable {
    let id = UUID()
    var type: AgentActionType
    var target: String
    var content: String
    var timestamp: Date = Date()
}

struct AgentParsedResponse: Hashable {
    var displayText: String
    var actions: [AgentAction]
}

enum AgentActionParser {
    private static var actionPattern: NSRegularExpression {
        try! NSRegularExpression(
            pattern: "\\[ACTION:(\\w+)\\]\\s*(.*?)\\s*\\[/ACTION\\]",
            options: [.dotMatchesLineSeparators]
        )
    }

    static func parse(_ rawResponse: String) -> AgentParsedResponse {
        let range = NSRange(rawResponse.startIndex..<rawResponse.endIndex, in: rawResponse)
        let matches = actionPattern.matches(in: rawResponse, options: [], range: range)

        var actions: [AgentAction] = []
        var cleanedText = rawResponse

        for match in matches.reversed() {
            guard let typeRange = Range(match.range(at: 1), in: rawResponse),
                  let bodyRange = Range(match.range(at: 2), in: rawResponse) else { continue }

            let typeString = String(rawResponse[typeRange])
            guard let type = AgentActionType(rawValue: typeString) else { continue }

            let body = String(rawResponse[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            let parsed = parseActionBody(body, type: type)
            actions.append(AgentAction(type: type, target: parsed.target, content: parsed.content))

            // Remove the action block from display text
            if let matchRange = Range(match.range, in: rawResponse) {
                cleanedText = cleanedText.replacingOccurrences(of: String(rawResponse[matchRange]), with: "")
            }
        }

        logger.info("Parsed \(actions.count) actions from response (\(rawResponse.count) chars)")
        for action in actions {
            logger.info("  Action: \(action.type.rawValue) → \(action.target)")
        }

        return AgentParsedResponse(
            displayText: cleanedText.trimmingCharacters(in: .whitespacesAndNewlines),
            actions: actions
        )
    }

    private static func parseActionBody(_ body: String, type: AgentActionType) -> (target: String, content: String) {
        switch type {
        case .updateWiki:
            let filePattern = try! NSRegularExpression(
                pattern: "^(?:file|File|FILE|文件):\\s*(\\S+)",
                options: [.anchorsMatchLines]
            )
            let fileRange = NSRange(body.startIndex..<body.endIndex, in: body)
            var target = "notes.md"
            var content = body

            if let match = filePattern.firstMatch(in: body, options: [], range: fileRange),
               let capRange = Range(match.range(at: 1), in: body) {
                target = String(body[capRange])
                content = body.replacingOccurrences(of: String(body[Range(match.range, in: body)!]), with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return (target, content)

        case .createDailyLog:
            return ("daily", body)
        }
    }
}
