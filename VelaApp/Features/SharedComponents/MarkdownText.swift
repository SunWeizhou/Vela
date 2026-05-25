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

    /// Parse each line individually as inline markdown, then join with \n.
    /// This preserves line breaks while still rendering **bold**, *italic*, `code`, etc.
    /// This performs exceptionally well for both streaming and final responses.
    private var attributedContent: AttributedString {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        let lines = normalized.components(separatedBy: "\n")
        var processedLines: [String] = []
        var inCodeBlock = false
        
        for (index, line) in lines.enumerated() {
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
            
            let isHeader = trimmed.hasPrefix("#")
            let isList = trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("+")
            let isOrderedList: Bool = {
                guard let firstDotIndex = trimmed.firstIndex(of: ".") else { return false }
                let prefix = trimmed[..<firstDotIndex].trimmingCharacters(in: .whitespaces)
                return !prefix.isEmpty && prefix.allSatisfy { $0.isNumber }
            }()
            let isBlockquote = trimmed.hasPrefix(">")
            
            if isHeader || isList || isOrderedList || isBlockquote || trimmed.hasSuffix("  ") || trimmed.hasSuffix("\\") {
                processedLines.append(line)
            } else {
                if index < lines.count - 1 {
                    processedLines.append(line + "  ")
                } else {
                    processedLines.append(line)
                }
            }
        }
        
        let processedMarkdown = processedLines.joined(separator: "\n")
        var result = (try? AttributedString(markdown: processedMarkdown)) ?? AttributedString(markdown)
        
        if isStreaming && blink {
            var cursor = AttributedString(" ▊")
            cursor.foregroundColor = VelaTheme.accent
            result.append(cursor)
        }
        
        return result
    }
}
