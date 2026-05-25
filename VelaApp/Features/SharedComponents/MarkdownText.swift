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

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Preserve blank lines as paragraph separators
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

            // For markdown structures that AttributedString handles natively,
            // don't inject extra spacing
            let isHeader = trimmed.hasPrefix("#")
            let isList = trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+")
            let isOrderedList: Bool = {
                guard let firstDotIndex = trimmed.firstIndex(of: ".") else { return false }
                let prefix = trimmed[..<firstDotIndex].trimmingCharacters(in: .whitespaces)
                return !prefix.isEmpty && prefix.allSatisfy { $0.isNumber }
            }()
            let isBlockquote = trimmed.hasPrefix(">")
            let isTable = trimmed.hasPrefix("|")
            let isDivider = trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___")

            if isHeader || isList || isOrderedList || isBlockquote || isTable || isDivider {
                // Ensure blank line before headers for proper markdown parsing
                if isHeader, index > 0, !processedLines.isEmpty, processedLines.last != "" {
                    processedLines.append("")
                }
                processedLines.append(line)
            } else {
                // Regular text: use two trailing spaces + newline = hard break in markdown
                if index < lines.count - 1 {
                    processedLines.append(line + "  ")
                } else {
                    processedLines.append(line)
                }
            }
        }

        // Post-process: collapse runs of blank lines (max 1 blank line)
        var collapsed: [String] = []
        for line in processedLines {
            if line.isEmpty, collapsed.last == "" {
                continue
            }
            collapsed.append(line)
        }

        let processedMarkdown = collapsed.joined(separator: "\n")

        // Fallback: if AttributedString markdown parser fails, render raw with \n → \n\n
        guard let parsed = try? AttributedString(markdown: processedMarkdown) else {
            let fallback = normalized
                .replacingOccurrences(of: "\n\n\n", with: "\n\n")
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
