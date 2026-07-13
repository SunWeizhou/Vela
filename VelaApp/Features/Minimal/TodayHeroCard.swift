import SwiftUI

struct TodayHeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void
    
    let generatedAt: Date?
    let safetyNotice: String?
    let isStale: Bool

    private var hasRecoveryScore: Bool {
        recoveryScoreText != "--"
    }

    private var evidenceIcon: String {
        if !hasRecoveryScore { return "circle.dotted" }
        return model.hero.confidenceLabel.contains("充分") ? "checkmark.seal.fill" : "info.circle.fill"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.34))
                .frame(width: 190, height: 190)
                .blur(radius: 18)
                .offset(x: 72, y: -88)
                .accessibilityHidden(true)

            Circle()
                .fill(Color(hex: "#6574FF").opacity(0.16))
                .frame(width: 150, height: 150)
                .blur(radius: 28)
                .offset(x: -205, y: 245)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Label(statusTitle, systemImage: statusIcon)
                        .font(VelaTheme.caption2().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.10), in: Capsule())

                    Spacer(minLength: 8)

                    if let generatedAt {
                        Text(formattedTime(generatedAt))
                            .font(VelaTheme.caption2().monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("TODAY · 今日重点")
                        .font(VelaTheme.caption2().weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.58))

                    Text(model.hero.decisionTitle)
                        .font(VelaTheme.title1())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(model.hero.summary)
                        .font(VelaTheme.subheadline())
                        .foregroundStyle(.white.opacity(0.70))
                        .lineSpacing(3)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                }

                if hasRecoveryScore {
                    HStack(spacing: 10) {
                        heroMetric(value: recoveryScoreText, label: "恢复")
                        heroMetric(
                            value: model.hero.confidenceLabel.replacingOccurrences(of: "判断依据", with: ""),
                            label: "判断依据",
                            icon: evidenceIcon
                        )
                    }
                } else {
                    Label(model.hero.confidenceLabel, systemImage: evidenceIcon)
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                }

                Button(action: onPrimaryAction) {
                    HStack(spacing: 10) {
                        Image(systemName: primaryActionIcon)
                        ViewThatFits(in: .horizontal) {
                            Text(model.hero.primaryActionTitle)
                                .lineLimit(1)
                            Text(compactPrimaryActionTitle)
                                .lineLimit(1)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(VelaTheme.headline())
                    .foregroundStyle(Color(hex: "#111629"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(minHeight: 52)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if !model.evidenceChips.isEmpty {
                    Label(
                        model.evidenceChips.prefix(2).map(localizedReason).joined(separator: " · "),
                        systemImage: "waveform.path.ecg"
                    )
                    .font(VelaTheme.caption2())
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)
                }

                if let safetyNotice, !safetyNotice.isEmpty {
                    Text(safetyNotice)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(.white.opacity(0.52))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#111629"), Color(hex: "#1A2342")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: VelaTheme.radiusFeature, style: .continuous))
        .shadow(color: Color(hex: "#111629").opacity(0.16), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func heroMetric(value: String, label: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(value.isEmpty ? "有限" : value)
            }
            .font(VelaTheme.headline().weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)

            Text(label)
                .font(VelaTheme.caption2())
                .foregroundStyle(.white.opacity(0.52))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var compactPrimaryActionTitle: String {
        if model.hero.primaryActionTitle.contains("同步") { return "立即同步" }
        if model.hero.primaryActionTitle.contains("训练") { return "开始训练" }
        return "查看行动"
    }

    private var statusTitle: String {
        if generatedAt == nil { return "正在建立身体基线" }
        if isStale { return "建议需要刷新" }
        return "今日建议已更新"
    }

    private var statusIcon: String {
        if generatedAt == nil { return "circle.dotted" }
        if isStale { return "arrow.clockwise" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if generatedAt == nil { return VelaTheme.muted }
        if isStale { return VelaTheme.warn }
        return VelaTheme.recoveryColor
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DailyDecisionFeedbackValues {
    var adoptionStatus: String
    var accuracyRating: String
    var actualAction: String
    var energyRating: Int?
    var fatigueRating: Int?
    var painRating: Int?
    var satisfactionRating: Int?
    var note: String
}

struct DailyDecisionFeedbackCard: View {
    let record: DailyDecisionFeedbackRecord?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: record?.isCompleted == true ? "checkmark.circle.fill" : "scope")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(record?.isCompleted == true ? VelaTheme.success : VelaTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(VelaTheme.secondaryGroupedBackground))

                VStack(alignment: .leading, spacing: 3) {
                    Text(record?.isCompleted == true ? "今日反馈已记录" : "这个建议适合你吗？")
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(record?.isCompleted == true ? "可随时更新，Vela 会用它校准后续建议" : "记录实际行动与体感，约 20 秒")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(record?.isCompleted == true ? "更新今日建议反馈" : "记录今日建议反馈")
    }
}

struct DailyDecisionFeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: DailyDecisionFeedbackRecord
    let onSave: (DailyDecisionFeedbackValues) -> Void

    @State private var adoptionStatus: String
    @State private var accuracyRating: String
    @State private var actualAction: String
    @State private var energyRating: Int?
    @State private var fatigueRating: Int?
    @State private var painRating: Int?
    @State private var satisfactionRating: Int?
    @State private var note: String

    init(record: DailyDecisionFeedbackRecord, onSave: @escaping (DailyDecisionFeedbackValues) -> Void) {
        self.record = record
        self.onSave = onSave
        _adoptionStatus = State(initialValue: record.adoptionStatus ?? "")
        _accuracyRating = State(initialValue: record.accuracyRating ?? "")
        _actualAction = State(initialValue: record.actualAction ?? "")
        _energyRating = State(initialValue: record.energyRating)
        _fatigueRating = State(initialValue: record.fatigueRating)
        _painRating = State(initialValue: record.painRating)
        _satisfactionRating = State(initialValue: record.satisfactionRating)
        _note = State(initialValue: record.note)
    }

    private var canSave: Bool {
        !adoptionStatus.isEmpty && !accuracyRating.isEmpty && !actualAction.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("校准 Vela 的判断")
                            .font(VelaTheme.title2())
                            .foregroundStyle(VelaTheme.fg)
                        Text(record.decisionTitle)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.muted)
                    }

                    feedbackChoiceSection(
                        title: "你采纳建议了吗？",
                        options: [("followed", "完全采纳"), ("modified", "调整后采纳"), ("not_followed", "没有采纳")],
                        selection: $adoptionStatus
                    )
                    feedbackChoiceSection(
                        title: "建议符合当时状态吗？",
                        options: [("accurate", "准确"), ("partly", "部分准确"), ("inaccurate", "不准确")],
                        selection: $accuracyRating
                    )
                    feedbackChoiceSection(
                        title: "你实际做了什么？",
                        options: [("as_planned", "按计划训练"), ("lighter", "降低强度"), ("harder", "提高强度"), ("recovery", "主动恢复"), ("rest", "休息")],
                        selection: $actualAction
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("完成后的体感（可选）")
                            .font(VelaTheme.headline())
                        DecisionRatingRow(title: "精力", lowLabel: "低", highLabel: "高", value: $energyRating)
                        DecisionRatingRow(title: "疲劳", lowLabel: "低", highLabel: "高", value: $fatigueRating)
                        DecisionRatingRow(title: "疼痛", lowLabel: "无", highLabel: "明显", value: $painRating)
                        DecisionRatingRow(title: "满意度", lowLabel: "低", highLabel: "高", value: $satisfactionRating)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充说明（可选）")
                            .font(VelaTheme.headline())
                        TextField("例如：腿部仍然酸痛，所以改成低强度", text: $note, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.secondaryGroupedBackground))
                    }
                }
                .padding(20)
            }
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("今日反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(DailyDecisionFeedbackValues(
                            adoptionStatus: adoptionStatus,
                            accuracyRating: accuracyRating,
                            actualAction: actualAction,
                            energyRating: energyRating,
                            fatigueRating: fatigueRating,
                            painRating: painRating,
                            satisfactionRating: satisfactionRating,
                            note: note
                        ))
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackChoiceSection(
        title: String,
        options: [(String, String)],
        selection: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(VelaTheme.headline())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Button {
                        selection.wrappedValue = option.0
                    } label: {
                        Text(option.1)
                            .font(VelaTheme.subheadline().weight(.semibold))
                            .foregroundStyle(selection.wrappedValue == option.0 ? Color.white : VelaTheme.fg)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(selection.wrappedValue == option.0 ? VelaTheme.accent : VelaTheme.secondaryGroupedBackground))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DecisionRatingRow: View {
    let title: String
    let lowLabel: String
    let highLabel: String
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(VelaTheme.subheadline().weight(.semibold))
                Spacer()
                Text("1 \(lowLabel) · 5 \(highLabel)")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        value = value == rating ? nil : rating
                    } label: {
                        Text("\(rating)")
                            .font(VelaTheme.subheadline().weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .foregroundStyle(value == rating ? Color.white : VelaTheme.fg2)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                                    .fill(value == rating ? VelaTheme.accent : VelaTheme.secondaryGroupedBackground)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(rating)，\(rating == 1 ? lowLabel : rating == 5 ? highLabel : "")")
                    .accessibilityAddTraits(value == rating ? .isSelected : [])
                }
            }
        }
    }
}
