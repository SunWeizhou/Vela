import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var font: Font = .body
    var color: Color = VelaTheme.secondaryText
    var isStreaming: Bool = false

    @State private var blink = true
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let paragraphs = parsedParagraphs
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, attrStr in
                Text(attrStr)
                    .font(font)
                    .foregroundStyle(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onReceive(timer) { _ in
            if isStreaming {
                blink.toggle()
            }
        }
    }

    // MARK: - Paragraph Splitting

    /// Splits raw markdown into paragraphs (separated by blank lines),
    /// parses each paragraph individually via AttributedString(markdown:),
    /// and appends the streaming cursor to the final paragraph.
    private var parsedParagraphs: [AttributedString] {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Phase 1 — split into lines, preserving code blocks
        let lines = normalized.components(separatedBy: "\n")
        var processedLines: [String] = []
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                processedLines.append("")
                continue
            }

            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                processedLines.append(line)
                continue
            }

            if inCodeBlock {
                processedLines.append(line)
                continue
            }

            processedLines.append(line)
        }

        // Phase 2 — collapse consecutive blank lines into one
        var collapsed: [String] = []
        for line in processedLines {
            if line.isEmpty, collapsed.last == "" {
                continue
            }
            collapsed.append(line)
        }

        // Phase 3 — group into paragraphs (blank lines are the separator)
        var paragraphGroups: [[String]] = []
        var current: [String] = []

        for line in collapsed {
            if line.isEmpty {
                if !current.isEmpty {
                    paragraphGroups.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            paragraphGroups.append(current)
        }

        // Phase 4 — parse each paragraph group into an AttributedString
        // Lines within the same paragraph are joined with single \n
        // so AttributedString markdown parser applies soft wrapping within
        // the paragraph while keeping inline markdown (bold, italic) working.
        var result: [AttributedString] = []
        for (index, group) in paragraphGroups.enumerated() {
            let paraText = group.joined(separator: "\n")
            let isLast = index == paragraphGroups.count - 1

            if let parsed = try? AttributedString(markdown: paraText) {
                var attrStr = parsed
                if isLast { appendStreamingCursor(to: &attrStr) }
                result.append(attrStr)
            } else {
                var plain = AttributedString(paraText)
                if isLast { appendStreamingCursor(to: &plain) }
                result.append(plain)
            }
        }

        return result
    }

    // MARK: - Streaming Cursor

    private func appendStreamingCursor(to result: inout AttributedString) {
        if isStreaming && blink {
            var cursor = AttributedString(" ▊")
            cursor.foregroundColor = VelaTheme.accent
            result.append(cursor)
        }
    }
}
