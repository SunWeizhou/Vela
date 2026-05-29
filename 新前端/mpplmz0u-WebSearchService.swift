import Foundation
import os.log

/// Fetches web search results without requiring an API key.
/// Uses DuckDuckGo's public HTML search endpoint.
@MainActor
final class WebSearchService {
    static let shared = WebSearchService()

    private let session: URLSession
    private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "WebSearch")

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    /// Returns up to `maxResults` search result snippets for the given query.
    func search(_ query: String, maxResults: Int = 5) async -> String {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return ""
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return "" }
            return parseResults(from: html, max: maxResults)
        } catch {
            logger.warning("Search failed: \(error.localizedDescription)")
            return ""
        }
    }

    /// Quick regex-based extraction of result titles and snippets from DuckDuckGo HTML.
    private func parseResults(from html: String, max: Int) -> String {
        var results: [String] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"<a[^>]*class="result__a"[^>]*>(.+?)</a>.*?<a[^>]*class="result__snippet"[^>]*>(.+?)</a>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return "" }

        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: nsRange)

        for match in matches.prefix(max) {
            guard match.numberOfRanges >= 3 else { continue }
            let titleRange = Range(match.range(at: 1), in: html)
            let snippetRange = Range(match.range(at: 2), in: html)
            let title = titleRange.map { stripHTML(html[$0]) } ?? ""
            let snippet = snippetRange.map { stripHTML(html[$0]) } ?? ""
            let trimmed = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                results.append("[\(title)] \(trimmed)")
            }
        }

        return results.isEmpty ? "" : results.joined(separator: "\n")
    }

    private func stripHTML(_ raw: Substring) -> String {
        raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
