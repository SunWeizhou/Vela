import SwiftUI

// MARK: - FlexStack (wrapping HStack for suggestion chips)

struct FlexStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.size.height }.max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            let rowH = row.map { $0.size.height }.max() ?? 0
            y += rowH + spacing
        }
    }

    struct Item { let index: Int; let size: CGSize }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [[Item]] {
        let maxW = proposal.width ?? .infinity
        var rows: [[Item]] = [[]]
        var currentRowW: CGFloat = 0

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let fits = rows.last?.isEmpty == true || currentRowW + size.width <= maxW
            if !fits {
                rows.append([])
                currentRowW = 0
            }
            rows[rows.count - 1].append(Item(index: i, size: size))
            currentRowW += size.width + spacing
        }
        return rows
    }
}
