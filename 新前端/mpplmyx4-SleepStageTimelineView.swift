import SwiftUI

struct SleepStageTimelineView: View {
    let segments: [SleepStageSegment]
    let bedtime: Date?
    let wakeTime: Date?

    private let stageOrder: [SleepStage] = [.awake, .rem, .core, .deep]
    private let timelineHeight: CGFloat = 140

    private var stageColors: [SleepStage: Color] {
        [
            .awake: VelaTheme.stress.opacity(0.7),
            .rem: VelaTheme.recovery,
            .core: VelaTheme.accent,
            .deep: VelaTheme.sleep
        ]
    }

    private var stageLabels: [SleepStage: String] {
        [
            .awake: L10n.t("Awake", "清醒"),
            .rem: "REM",
            .core: L10n.t("Core", "核心"),
            .deep: L10n.t("Deep", "深睡")
        ]
    }

    var body: some View {
        if segments.isEmpty || bedtime == nil || wakeTime == nil {
            Text(L10n.t("Sleep stage data will appear after your next sleep.", "睡眠阶段数据将在下次睡眠后出现。"))
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            timelineContent
        }
    }

    private var timelineContent: some View {
        let bed = bedtime!
        let wake = wakeTime!
        let totalDuration = wake.timeIntervalSince(bed)
        guard totalDuration > 0 else {
            return AnyView(emptyView)
        }

        let stages = stageOrder
        let rowHeight: CGFloat = (timelineHeight - 30) / CGFloat(stages.count)

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                // Left labels + stage rows
                ForEach(Array(stages.enumerated()), id: \.element) { _, stage in
                    HStack(spacing: 8) {
                        // Stage label
                        Text(stageLabels[stage] ?? "")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                            .frame(width: 40, alignment: .trailing)

                        // Stage row
                        GeometryReader { geo in
                            let rowWidth = geo.size.width
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                                    .frame(height: rowHeight - 4)

                                // Stage segments
                                ForEach(segments.filter { $0.stage == stage }) { segment in
                                    let xStart = CGFloat(segment.start.timeIntervalSince(bed) / totalDuration) * rowWidth
                                    let xEnd = CGFloat(segment.end.timeIntervalSince(bed) / totalDuration) * rowWidth
                                    let segWidth = max(xEnd - xStart, 4)

                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(stageColors[stage] ?? VelaTheme.mutedText)
                                        .frame(width: segWidth, height: rowHeight - 4)
                                        .position(x: xStart + segWidth / 2, y: (rowHeight - 4) / 2)
                                }
                            }
                        }
                        .frame(height: rowHeight)
                    }
                }

                // Time axis
                timeAxis(bed: bed, wake: wake, totalDuration: totalDuration)
            }
            .frame(height: timelineHeight)
        )
    }

    private func generateTicks(bed: Date, wake: Date) -> [Date] {
        let interval: TimeInterval = 7200
        let startOfSecond = bed.timeIntervalSince1970 - bed.timeIntervalSince1970.truncatingRemainder(dividingBy: interval)
        var ticks: [Date] = []
        var t = startOfSecond
        while t <= wake.timeIntervalSince1970 + interval {
            if t >= bed.timeIntervalSince1970 - 60 {
                ticks.append(Date(timeIntervalSince1970: t))
            }
            t += interval
        }
        return ticks
    }

    private func timeAxis(bed: Date, wake: Date, totalDuration: TimeInterval) -> some View {
        let ticks = generateTicks(bed: bed, wake: wake)

        return HStack(spacing: 8) {
            Color.clear.frame(width: 40)

            GeometryReader { geo in
                let w = geo.size.width

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(VelaTheme.mutedText.opacity(0.25))
                        .frame(height: 1)

                    ForEach(ticks, id: \.self) { tick in
                        let frac = CGFloat(tick.timeIntervalSince(bed) / totalDuration)
                        let x = frac * w

                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(VelaTheme.mutedText.opacity(0.3))
                                .frame(width: 1, height: 4)

                            Text(tick.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 9))
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                        .position(x: x, y: 16)
                    }
                }
            }
            .frame(height: 30)
        }
    }

    private var emptyView: some View {
        Text(L10n.t("Sleep stage data will appear after your next sleep.", "睡眠阶段数据将在下次睡眠后出现。"))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 40)
    }
}

#if DEBUG
struct SleepStageTimelinePreview: View {
    var body: some View {
        VStack(spacing: 20) {
            SleepStageTimelineView(
                segments: previewSegments,
                bedtime: previewBedtime,
                wakeTime: previewWakeTime
            )
            .padding(.horizontal, 20)
        }
        .padding()
        .background(VelaTheme.background)
        .previewLayout(.sizeThatFits)
    }

    private var previewBedtime: Date {
        Calendar.current.date(bySettingHour: 23, minute: 15, second: 0, of: Date()) ?? Date()
    }

    private var previewWakeTime: Date {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: Date().addingTimeInterval(86400)) ?? Date()
    }

    private var previewSegments: [SleepStageSegment] {
        let bed = previewBedtime
        return [
            SleepStageSegment(stage: .awake, start: bed, end: bed.addingTimeInterval(600)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(600), end: bed.addingTimeInterval(2400)),
            SleepStageSegment(stage: .deep, start: bed.addingTimeInterval(2400), end: bed.addingTimeInterval(4200)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(4200), end: bed.addingTimeInterval(6000)),
            SleepStageSegment(stage: .rem, start: bed.addingTimeInterval(6000), end: bed.addingTimeInterval(7800)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(7800), end: bed.addingTimeInterval(10200)),
            SleepStageSegment(stage: .rem, start: bed.addingTimeInterval(10200), end: bed.addingTimeInterval(12600)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(12600), end: bed.addingTimeInterval(15000)),
            SleepStageSegment(stage: .deep, start: bed.addingTimeInterval(15000), end: bed.addingTimeInterval(16800)),
            SleepStageSegment(stage: .awake, start: bed.addingTimeInterval(16800), end: bed.addingTimeInterval(17400)),
            SleepStageSegment(stage: .rem, start: bed.addingTimeInterval(17400), end: bed.addingTimeInterval(19800)),
            SleepStageSegment(stage: .awake, start: bed.addingTimeInterval(19800), end: bed.addingTimeInterval(20100)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(20100), end: bed.addingTimeInterval(22200)),
            SleepStageSegment(stage: .rem, start: bed.addingTimeInterval(22200), end: bed.addingTimeInterval(24300)),
            SleepStageSegment(stage: .awake, start: bed.addingTimeInterval(24300), end: bed.addingTimeInterval(24900)),
            SleepStageSegment(stage: .core, start: bed.addingTimeInterval(24900), end: previewWakeTime)
        ]
    }
}

#Preview {
    SleepStageTimelinePreview()
}
#endif
