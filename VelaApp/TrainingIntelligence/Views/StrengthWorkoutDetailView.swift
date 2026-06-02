import SwiftUI
import SwiftData

struct StrengthWorkoutDetailView: View {
    let workout: StrengthWorkoutRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.system(size: 26, weight: .bold))
                    Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                    HStack(spacing: 12) {
                        strengthSummary("时长", "\(workout.durationMinutes) 分钟")
                        strengthSummary("组数", "\(workout.totalSetCount)")
                        strengthSummary("容量", "\(Int(workout.totalVolumeKilograms.rounded())) kg")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))

                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text(exercise.equipment)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                        }

                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text("第 \(index + 1) 组")
                                Spacer()
                                Text((set.isWarmup) ? "热身" : "\(set.repetitions) 次 × \(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                }

                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                }
            }
            .padding(16)
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("力量训练详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func strengthSummary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "#8E8A80"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
