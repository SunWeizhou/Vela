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
        return parseResults(from: html, max: maxResults)
    }

    private func parseResults(from html: String, max: Int) -> String {
        var results: [String] = []
        guard let regex = try? NSRegularExpression(
            pattern: #"<li class="b_algo"[^>]*>(.+?)</li>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return "" }
        let nsRange = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, options: [], range: nsRange).prefix(max) {
            let block = String(html[Range(match.range(at: 1), in: html)!])
            let title = extractBingTitle(from: block)
            let snippet = extractBingSnippet(from: block)
            if !title.isEmpty {
                results.append("[\(title)] \(snippet)")
            }
        }
        return results.isEmpty ? "" : results.joined(separator: "\n")
    }

    private func extractBingTitle(from block: String) -> String {
        guard let range = block.range(of: #"<h2[^>]*>(.+?)</h2>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractBingSnippet(from block: String) -> String {
        guard let range = block.range(of: #"<p class="b_lineclamp[^"]*">(.+?)</p>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
