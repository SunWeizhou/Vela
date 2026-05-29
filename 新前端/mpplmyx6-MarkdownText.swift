import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var font: Font = .body
    var color: Color = VelaTheme.secondaryText
    var isStreaming: Bool = false

    var body: some View {
        if isStreaming {
            Text(markdown)
                .font(font)
                .foregroundStyle(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(lineBylineAttributed)
                .font(font)
                .foregroundStyle(color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Parse each line individually as inline markdown, then join with \n.
    /// This preserves line breaks while still rendering **bold**, *italic*, `code`, etc.
    private var lineBylineAttributed: AttributedString {
        let lines = markdown.components(separatedBy: "\n")
        var result = AttributedString()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append(AttributedString("\n"))
                continue
            }

            if let parsed = try? AttributedString(markdown: line) {
                result.append(parsed)
            } else {
                result.append(AttributedString(line))
            }

            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }
}
