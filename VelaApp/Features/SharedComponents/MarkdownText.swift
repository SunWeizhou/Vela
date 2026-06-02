import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var font: Font = .body
    var color: Color = VelaTheme.secondaryText
    var isStreaming: Bool = false

    @State private var blink = true
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(attributedContent)
            .font(font)
            .foregroundStyle(color)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onReceive(timer) { _ in
                if isStreaming {
                    blink.toggle()
                }
            }
    }

    /// Parse each line as inline markdown, join with paragraph breaks.
    /// A single \n is invisible in AttributedString markdown, so we convert
    /// consecutive non-empty lines to use \n\n (paragraph break) for visible separation.
    private var attributedContent: AttributedString {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
        var processedLines: [String] = []
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Preserve blank lines
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

        // Post-process: collapse consecutive empty lines to a single empty line
        var collapsed: [String] = []
        for line in processedLines {
            if line.isEmpty, collapsed.last == "" {
                continue
            }
            collapsed.append(line)
        }

        // Join non-empty lines with double newlines (\n\n) to force paragraph breaks,
        // while preserving existing paragraph breaks cleanly.
        var finalLines: [String] = []
        for line in collapsed {
            if line.isEmpty {
                continue
            }
            finalLines.append(line)
        }

        // Since we filtered out empty lines, joining with "\n\n" ensures that every single line of text
        // is separated by exactly a paragraph break, giving a clean and breathable newline layout!
        let processedMarkdown = finalLines.joined(separator: "\n\n")

        // Fallback: if AttributedString markdown parser fails, render raw
        guard let parsed = try? AttributedString(markdown: processedMarkdown) else {
            let fallback = normalized.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            var result = (try? AttributedString(markdown: fallback)) ?? AttributedString(normalized)
            appendStreamingCursor(to: &result)
            return result
        }

        var result = parsed
        appendStreamingCursor(to: &result)
        return result
    }

    private func appendStreamingCursor(to result: inout AttributedString) {
        if isStreaming && blink {
            var cursor = AttributedString(" ▊")
            cursor.foregroundColor = VelaTheme.accent
            result.append(cursor)
        }
    }
}
