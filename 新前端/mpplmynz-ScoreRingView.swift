import SwiftUI

struct ScoreRingView: View {
    let score: Double
    let tint: Color
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10

    @State private var animatedProgress: Double = 0

    private var progress: CGFloat { min(max(score / 100, 0.02), 1) }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .stroke(tint.opacity(0.3), lineWidth: lineWidth + 6)
                .blur(radius: 12)
                .opacity(0.5)

            // Background track
            Circle()
                .stroke(tint.opacity(0.1), lineWidth: lineWidth)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.6), tint, tint.opacity(0.8)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.3), radius: 6)

            // End dot indicator with premium neon glow overlay
            if animatedProgress > 0.01 && animatedProgress < 0.99 {
                let dotAngle = Angle.degrees(-90 + animatedProgress * 360)
                Circle()
                    .fill(tint)
                    .frame(width: lineWidth - 1, height: lineWidth - 1)
                    .shadow(color: tint, radius: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                    )
                    .offset(
                        x: cos(CGFloat(dotAngle.radians)) * (size / 2),
                        y: sin(CGFloat(dotAngle.radians)) * (size / 2)
                    )
            }

            // Health scores should never show transient intermediate values.
            VStack(spacing: 0) {
                Text(Int(score).formatted())
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = min(max(newValue / 100, 0.02), 1)
            }
        }
    }
}
