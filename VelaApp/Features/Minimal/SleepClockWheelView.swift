import SwiftUI

struct SleepClockWheelView: View {
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let wakeHour: Int
    let wakeMinute: Int
    let targetSleepMinutes: Int

    private var bedtimeAngle: Double {
        VelaMinimalFormatting.sleepDialAngle(hour: bedtimeHour, minute: bedtimeMinute)
    }

    private var wakeAngle: Double {
        VelaMinimalFormatting.sleepDialAngle(hour: wakeHour, minute: wakeMinute)
    }

    private var sleepDurationFraction: Double {
        Double(
            VelaMinimalFormatting.sleepDurationMinutes(
                bedtimeHour: bedtimeHour,
                bedtimeMinute: bedtimeMinute,
                wakeHour: wakeHour,
                wakeMinute: wakeMinute
            )
        ) / Double(24 * 60)
    }
    
    var body: some View {
        ZStack {
            // Dial background
            Circle()
                .fill(Color(hex: "#100F0D").opacity(0.8))
                .frame(width: 170, height: 170)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#2E2B25"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                )
            
            // Hour markings around the circle (12am, 6am, 12pm, 6pm)
            dialHourText("12am", angle: -90, radius: 68)
            dialHourText("6am", angle: 0, radius: 68)
            dialHourText("12pm", angle: 90, radius: 68)
            dialHourText("6pm", angle: 180, radius: 68)
            
            // Tiny tick dots
            ForEach(0..<12) { idx in
                let deg = Double(idx) * 30.0 - 90.0
                let r = 76.0
                Circle()
                    .fill(Color(hex: "#2E2B25"))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: r * cos(deg * .pi / 180), y: r * sin(deg * .pi / 180))
            }

            // Sleep Duration Indicator Arc
            Circle()
                .trim(from: 0.0, to: sleepDurationFraction)
                .stroke(
                    LinearGradient(colors: [VelaTheme.sleepColor, Color(hex: "#87BAC5")], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7.5, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(bedtimeAngle - 90.0))

            // Center icons (moon and sun)
            VStack(spacing: 16) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.sleepColor)
                    .shadow(color: VelaTheme.sleepColor.opacity(0.6), radius: 3)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#D6BF74"))
            }
            .offset(y: -4)

            // Bedtime Indicator Icon overlay (bed)
            dialIndicatorPill(icon: "bed.double.fill", color: VelaTheme.sleepColor)
                .offset(x: 70 * cos((bedtimeAngle - 90.0) * .pi / 180), y: 70 * sin((bedtimeAngle - 90.0) * .pi / 180))
            
            // Wake Indicator Icon overlay (clock)
            dialIndicatorPill(icon: "alarm.fill", color: Color(hex: "#87BAC5"))
                .offset(x: 70 * cos((wakeAngle - 90.0) * .pi / 180), y: 70 * sin((wakeAngle - 90.0) * .pi / 180))
        }
        .overlay(alignment: .bottom) {
            Text("今晚睡眠目标: \(VelaMinimalFormatting.duration(minutes: targetSleepMinutes))")
                .font(VelaTheme.caption2())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.mistGray)
                .offset(y: 12)
        }
    }
    
    private func dialHourText(_ label: String, angle: Double, radius: Double) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(VelaTheme.inkGray)
            .position(x: 85 + radius * cos(angle * .pi / 180), y: 85 + radius * sin(angle * .pi / 180))
    }
    
    private func dialIndicatorPill(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 15, height: 15)
            .background(Circle().fill(color).shadow(color: color.opacity(0.4), radius: 3))
    }
}
