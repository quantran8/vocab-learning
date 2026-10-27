import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.xs
    var lineSpacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in arrangement.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        var rows: [[(index: Int, size: CGSize)]] = [[]]
        var rowWidth: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            let isRowEmpty = rows[rows.count - 1].isEmpty
            let needed = isRowEmpty ? size.width : rowWidth + spacing + size.width
            if needed > width, !isRowEmpty {
                rows.append([(index, size)])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append((index, size))
                rowWidth = needed
            }
        }

        var frames = Array(repeating: CGRect.zero, count: subviews.count)
        var y: CGFloat = 0
        var widest: CGFloat = 0
        for row in rows where !row.isEmpty {
            let rowWidth = row.map(\.size.width).reduce(0, +) + spacing * CGFloat(row.count - 1)
            let rowHeight = row.map(\.size.height).max() ?? 0
            widest = max(widest, rowWidth)
            var x = width.isFinite ? max(0, (width - rowWidth) / 2) : 0
            for item in row {
                frames[item.index] = CGRect(
                    x: x,
                    y: y + (rowHeight - item.size.height) / 2,
                    width: item.size.width,
                    height: item.size.height
                )
                x += item.size.width + spacing
            }
            y += rowHeight + lineSpacing
        }
        return (CGSize(width: width.isFinite ? width : widest, height: max(0, y - lineSpacing)), frames)
    }
}
