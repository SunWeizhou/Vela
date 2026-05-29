import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let tint: Color
    var height: CGFloat = 32

    private var normalizedData: [Double] {
        guard let minVal = data.min(), let maxVal = data.max(), maxVal > minVal else {
            return data.map { _ in 0.5 }
        }
        return data.map { ($0 - minVal) / (maxVal - minVal) }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let points = normalizedData.enumerated().map { i, val -> CGPoint in
                let step = data.count > 1 ? w / CGFloat(data.count - 1) : w
                return CGPoint(x: CGFloat(i) * step, y: h - CGFloat(val) * h)
            }

            ZStack {
                // Filled area
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: points[0].x, y: h))
                    path.addLine(to: points[0])

                    for i in 1..<points.count {
                        let p0 = points[max(0, i - 1)]
                        let p1 = points[i]
                        let cp1 = CGPoint(x: (p0.x + p1.x) / 2, y: p0.y)
                        let cp2 = CGPoint(x: (p0.x + p1.x) / 2, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }

                    path.addLine(to: CGPoint(x: points[points.count - 1].x, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.18), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Stroke line
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: points[0])

                    for i in 1..<points.count {
                        let p0 = points[max(0, i - 1)]
                        let p1 = points[i]
                        let cp1 = CGPoint(x: (p0.x + p1.x) / 2, y: p0.y)
                        let cp2 = CGPoint(x: (p0.x + p1.x) / 2, y: p1.y)
                        path.addCurve(to: p1, control1: cp1, control2: cp2)
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
    }
}

#if DEBUG
struct SparklinePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            SparklineView(
                data: [72, 68, 75, 80, 73, 78, 82],
                tint: VelaTheme.recovery
            )
            .frame(width: 200)

            SparklineView(
                data: [62, 65, 60, 58, 63, 67, 70],
                tint: VelaTheme.sleep
            )
            .frame(width: 200)

            SparklineView(
                data: [40, 45, 42, 48, 50],
                tint: VelaTheme.strain
            )
            .frame(width: 200)
        }
        .padding()
        .background(VelaTheme.background)
        .previewLayout(.sizeThatFits)
    }
}

#Preview {
    SparklinePreview()
}
#endif
