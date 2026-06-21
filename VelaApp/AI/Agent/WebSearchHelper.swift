import Foundation

/// Minimal web search via Bing.com HTML results.
actor WebSearchHelper {
    static let shared = WebSearchHelper()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    func search(_ query: String, maxResults: Int = 4) async -> String {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.bing.com/search?q=\(encoded)&setlang=en") else {
            return ""
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: request),
              let html = String(data: data, encoding: .utf8) else {
            return ""
        }
        return Self.formatResults(Self.parseResults(from: html, max: maxResults))
    }

    static func parseResults(from html: String, max: Int) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"<li class="b_algo"[^>]*>(.+?)</li>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return [] }
        let nsRange = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, options: [], range: nsRange).prefix(max) {
            guard let blockRange = Range(match.range(at: 1), in: html) else { continue }
            let block = String(html[blockRange])
            let title = extractBingTitle(from: block)
            let url = extractBingURL(from: block)
            let snippet = extractBingSnippet(from: block)
            if !title.isEmpty {
                results.append(WebSearchResult(title: title, url: url, snippet: snippet))
            }
        }
        return results
    }

    static func formatResults(_ results: [WebSearchResult]) -> String {
        let lines = results.map { result in
            let title = result.url.isEmpty ? "[\(result.title)]" : "[\(result.title)](\(result.url))"
            return result.snippet.isEmpty ? title : "\(title) \(result.snippet)"
        }
        return lines.joined(separator: "\n")
    }

    private static func extractBingTitle(from block: String) -> String {
        guard let range = block.range(of: #"<h2[^>]*>(.+?)</h2>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractBingURL(from block: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<a[^>]*href="([^"]+)""#,
            options: [.dotMatchesLineSeparators]
        ) else { return "" }
        let nsRange = NSRange(block.startIndex..., in: block)
        guard let match = regex.firstMatch(in: block, options: [], range: nsRange),
              let urlRange = Range(match.range(at: 1), in: block) else {
            return ""
        }
        return decodeHTMLEntities(String(block[urlRange]))
    }

    private static func extractBingSnippet(from block: String) -> String {
        guard let range = block.range(of: #"<p[^>]*>(.+?)</p>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

struct WebSearchResult: Equatable, Sendable {
    let title: String
    let url: String
    let snippet: String
}
