import SwiftUI

// MARK: - ScoreRing (Ring progress view)

struct ScoreRing: View {
    let score: Double      // 0…1
    let color: Color
    let size: CGFloat
    let strokeWidth: CGFloat?
    let value: String
    let unit: String?
    let label: String

    init(
        score: Double,
        color: Color,
        size: CGFloat = VelaTheme.ringMd,
        strokeWidth: CGFloat? = nil,
        value: String,
        unit: String? = nil,
        label: String
    ) {
        self.score = max(0, min(1, score))
        self.color = color
        self.size = size
        self.strokeWidth = strokeWidth ?? (size * 0.085)
        self.value = value
        self.unit = unit
        self.label = label
    }

    var body: some View {
        let sw = strokeWidth ?? (size * 0.085)
        ZStack {
            Circle()
                .stroke(VelaTheme.borderSoft, lineWidth: sw)

            Circle()
                .trim(from: 0, to: score)
                .stroke(color, style: StrokeStyle(lineWidth: sw, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.8), value: score)

            VStack(spacing: 0) {
                if let unit = unit {
                    Text(value)
                        .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                    Text(unit)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.meta)
                } else {
                    Text(value)
                        .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottom) {
            Text(label)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .offset(y: size * 0.2)
        }
        .padding(.bottom, size * 0.16)
    }
}

// MARK: - Bevel Score Ring (Bevel-style circular gauge)

struct BevelScoreRing: View {
    let score: Double // 0 to 1
    let color: Color
    var useGradient: Bool = false
    var size: CGFloat = 80
    let label: String
    let valueText: String

    @State private var animatedScore: Double = 0.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track
                Circle()
                    .stroke(VelaTheme.borderSoft, lineWidth: 6.5)
                    .frame(width: size, height: size)
                
                if animatedScore > 0 {
                    // Gradient or solid arc using system gradient to avoid rotation coordinate bugs
                    Circle()
                        .trim(from: 0, to: max(0.01, animatedScore))
                        .stroke(
                            useGradient 
                            ? AnyShapeStyle(color.gradient)
                            : AnyShapeStyle(color),
                            style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size, height: size)
                }
                
                // Small indicator dot at progress end aligned perfectly on stroke center path
                if animatedScore > 0 {
                    let angle = -90 + (max(0.01, animatedScore) * 360)
                    let radius = (size - 6.5) / 2
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(x: radius * cos(angle * .pi / 180), y: radius * sin(angle * .pi / 180))
                }
                
                // Center Value
                Text(valueText)
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(VelaTheme.fg)
            }
            .frame(width: size, height: size)
            
            Text(label)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = newScore
            }
        }
    }
}

// MARK: - Dotted Circle Gauge (Bevel-style circular tick gauge)

struct DottedCircleGauge: View {
    let score: Double // 0 to 100
    let labelText: String // e.g. "低"
    var size: CGFloat = 72
    let color: Color

    @State private var animatedScore: Double = 0.0

    var body: some View {
        ZStack {
            // Dotted circle track
            Circle()
                .stroke(VelaTheme.borderSoft, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, dash: [1.5, 4]))
                .frame(width: size, height: size)
            
            // Colored active dots matching score
            Circle()
                .trim(from: 0, to: max(0.02, animatedScore / 100.0))
                .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, dash: [1.5, 4]))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            
            VStack(spacing: 1) {
                Text("\(Int(animatedScore))")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(VelaTheme.fg)
                Text(labelText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = newScore
            }
        }
    }
}

// MARK: - Segmented Battery Bar (Bevel-style segmented horizontal bar)

struct SegmentedBatteryBar: View {
    let percentage: Double // 0 to 1
    var barCount: Int = 26
    let color: Color

    @State private var animatedPercentage: Double = 0.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { idx in
                let activeCount = Int(animatedPercentage * Double(barCount))
                RoundedRectangle(cornerRadius: 1)
                    .fill(idx < activeCount ? color : VelaTheme.borderSoft)
                    .frame(width: 4, height: 14)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.82, blendDuration: 0)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newPercentage in
            withAnimation(.spring(response: 1.1, dampingFraction: 0.82, blendDuration: 0)) {
                animatedPercentage = newPercentage
            }
        }
    }
}

// MARK: - Sparkline Line Graph (Bevel-style biomarker sparkline)

struct SparklineLineGraph: View {
    let data: [Double] // Normalized 0...1 values
    let color: Color
    var height: CGFloat = 36
    var width: CGFloat = 80

    var body: some View {
        if data.isEmpty {
            Color.clear.frame(width: width, height: height)
        } else {
            ZStack {
                // Shaded area
                Path { path in
                    guard data.count > 1 else { return }
                    let stepX = width / CGFloat(data.count - 1)
                    path.move(to: CGPoint(x: 0, y: height))
                    for idx in 0..<data.count {
                         let x = CGFloat(idx) * stepX
                         let y = height - (CGFloat(data[idx]) * (height - 6) + 3)
                         path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.12), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Line Path
                Path { path in
                    guard data.count > 1 else { return }
                    let stepX = width / CGFloat(data.count - 1)
                    for idx in 0..<data.count {
                        let x = CGFloat(idx) * stepX
                        let y = height - (CGFloat(data[idx]) * (height - 6) + 3)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // End Dot
                if let lastVal = data.last {
                    let stepX = width / CGFloat(data.count - 1)
                    let x = CGFloat(data.count - 1) * stepX
                    let y = height - (CGFloat(lastVal) * (height - 6) + 3)
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: x, y: y)
                }
            }
            .frame(width: width, height: height)
        }
    }
}

// MARK: - TripleConcentricScoreRing (Concentric Recovery/Sleep/Strain activity-style rings)

struct TripleConcentricScoreRing: View {
    let recovery: Double // 0...1
    let sleep: Double    // 0...1
    let strain: Double   // 0...1
    
    @State private var animRecovery: Double = 0.0
    @State private var animSleep: Double = 0.0
    @State private var animStrain: Double = 0.0
    
    var body: some View {
        ZStack {
            // Blurred depth glow backing
            RadialGradient(
                colors: [
                    VelaTheme.recoveryColor.opacity(0.12),
                    VelaTheme.sleepColor.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 50
            )
            .frame(width: 100, height: 100)
            .blur(radius: 6)

            // Recovery (Outer)
            Circle()
                .stroke(VelaTheme.recoveryColor.opacity(0.12), lineWidth: 8.5)
                .frame(width: 100, height: 100)
            Circle()
                .trim(from: 0, to: max(0.01, animRecovery))
                .stroke(
                    VelaTheme.recoveryColor.gradient,
                    style: StrokeStyle(lineWidth: 8.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 100, height: 100)
                .shadow(color: VelaTheme.recoveryColor.opacity(0.25), radius: 2)
            
            // Sleep (Middle)
            Circle()
                .stroke(VelaTheme.sleepColor.opacity(0.12), lineWidth: 8.5)
                .frame(width: 78, height: 78)
            Circle()
                .trim(from: 0, to: max(0.01, animSleep))
                .stroke(
                    VelaTheme.sleepColor.gradient,
                    style: StrokeStyle(lineWidth: 8.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 78, height: 78)
                .shadow(color: VelaTheme.sleepColor.opacity(0.25), radius: 2)
            
            // Strain (Inner)
            Circle()
                .stroke(VelaTheme.strainColor.opacity(0.12), lineWidth: 8.5)
                .frame(width: 56, height: 56)
            Circle()
                .trim(from: 0, to: max(0.01, animStrain))
                .stroke(
                    VelaTheme.strainColor.gradient,
                    style: StrokeStyle(lineWidth: 8.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 56, height: 56)
                .shadow(color: VelaTheme.strainColor.opacity(0.25), radius: 2)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) {
                animRecovery = recovery
                animSleep = sleep
                animStrain = strain
            }
        }
        .onChange(of: recovery) { _, newRecovery in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) { animRecovery = newRecovery }
        }
        .onChange(of: sleep) { _, newSleep in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) { animSleep = newSleep }
        }
        .onChange(of: strain) { _, newStrain in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.82)) { animStrain = newStrain }
        }
    }
}

// MARK: - MiniMetricRow (Row showing inline indicator bars for triple rings)

struct MiniMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double // 0...1
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 20, height: 20)
                .background(Circle().fill(color.opacity(0.12)))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                
                // Capsule Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 5)
                        
                        Capsule()
                            .fill(color.gradient)
                            .frame(width: geo.size.width * CGFloat(progress), height: 5)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 3)
    }
}
