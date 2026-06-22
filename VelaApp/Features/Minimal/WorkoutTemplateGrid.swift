import SwiftUI

struct WorkoutTemplateGrid: View {
    let workoutTemplates: [WorkoutTemplateRecord]
    @Binding var templatePendingDeletion: WorkoutTemplateRecord?
    let startStrengthWorkout: () -> Void
    let startStrengthWorkoutWithID: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练模板")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("从常用结构开始记录，每组数据仍可自由调整")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Button {
                    startStrengthWorkout()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("开始空白训练")
            }

            if workoutTemplates.isEmpty {
                Text("模板库正在准备。打开记录页也可以直接创建自定义模板。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(templateShortcuts) { template in
                            Button {
                                startStrengthWorkoutWithID(template.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack(spacing: 8) {
                                        Image(systemName: templateIcon(for: template))
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(VelaTheme.accent)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                                        Spacer()
                                        Text("\(template.estimatedDurationMinutes)′")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(VelaTheme.muted)
                                    }

                                    Text(localizedWorkoutTemplateTitle(template.title))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VelaTheme.fg)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)

                                    Text("\(template.exercises.count) 个动作 · \(template.exercises.reduce(0) { $0 + $1.targetSets }) 组")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VelaTheme.muted)
                                }
                                .frame(width: 132, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(VelaTheme.cardBg)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(VelaTheme.borderSoft, lineWidth: 0.7)
                                )
                            }
                            .buttonStyle(.cardPress)
                            .contextMenu {
                                Button(role: .destructive) {
                                    templatePendingDeletion = template
                                } label: {
                                    Label("删除模板", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
    }

    private var templateShortcuts: [WorkoutTemplateRecord] {
        workoutTemplates
            .sorted { lhs, rhs in
                switch (lhs.lastUsedAt, rhs.lastUsedAt) {
                case let (left?, right?):
                    return left > right
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                case (nil, nil):
                    return lhs.title < rhs.title
                }
            }
            .prefix(6)
            .map { $0 }
    }

    private func templateIcon(for template: WorkoutTemplateRecord) -> String {
        let title = template.title.lowercased()
        let exerciseNames = template.exercises.map(\.name).joined(separator: " ")
        if title.contains("leg") || exerciseNames.contains("深蹲") || exerciseNames.contains("腿") {
            return "figure.strengthtraining.functional"
        }
        if title.contains("pull") || exerciseNames.contains("划船") || exerciseNames.contains("下拉") {
            return "figure.climbing"
        }
        if title.contains("push") || exerciseNames.contains("卧推") || exerciseNames.contains("推") {
            return "dumbbell.fill"
        }
        return "figure.strengthtraining.traditional"
    }
}
