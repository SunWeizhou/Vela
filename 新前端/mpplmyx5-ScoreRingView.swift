import SwiftUI

struct ScoreRingView: View {
    let score: Double
    let tint: Color
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10

    @State private var animatedProgress: Double = 0
    @State private var displayedScore: Double = 0

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

            // Score text with counting animation
            VStack(spacing: 0) {
                Text(Int(displayedScore).formatted())
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
            animateCount(to: score)
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = min(max(newValue / 100, 0.02), 1)
            }
            animateCount(to: newValue)
        }
    }

    private func animateCount(to target: Double) {
        let duration: TimeInterval = 0.8
        let steps = 30
        let stepDuration = duration / Double(steps)
        let startValue = displayedScore
        let delta = (target - startValue) / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    displayedScore = startValue + delta * Double(i)
                }
            }
        }
    }
}
