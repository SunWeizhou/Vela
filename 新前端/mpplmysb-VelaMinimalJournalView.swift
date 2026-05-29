import SwiftUI

struct VelaMinimalJournalView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    journalHero
                    actionList
                    memoryCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var journalHero: some View {
        VelaMinimalGlassPanel(padding: 24, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                VelaMinimalSectionTitle(title: L10n.t("Journal", "手记"), subtitle: L10n.t("Context for your body", "身体状态的上下文"))

                Text(L10n.t("Log what Health data cannot see.", "记录 Apple Health 看不到的内容。"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                Text(L10n.t("Meals, symptoms, mood, travel, and training notes help Vela explain signal changes.", "饮食、症状、情绪、旅行和训练备注，会帮助 Vela 解释指标变化。"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(4)
            }
        }
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(title: L10n.t("Log", "记录"))
            VelaMinimalGlassPanel(padding: 0, radius: 22) {
                VStack(spacing: 0) {
                    NavigationLink {
                        JournalView()
                            .environmentObject(viewModel)
                    } label: {
                        VelaMinimalRecordRow(
                            title: L10n.t("Daily Journal", "每日手记"),
                            detail: L10n.t("Open", "打开"),
                            systemImage: "book.closed.fill",
                            tint: VelaTheme.accent
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56)

                    VelaMinimalRecordRow(
                        title: L10n.t("Log weight", "记录体重"),
                        detail: nil,
                        systemImage: "scalemass.fill",
                        tint: VelaTheme.recovery
                    ) {
                        VelaAppState.shared.triggerWeightLog = true
                    }

                    Divider().padding(.leading, 56)

                    VelaMinimalRecordRow(
                        title: L10n.t("Log blood data", "记录血液数据"),
                        detail: nil,
                        systemImage: "drop.fill",
                        tint: VelaTheme.stress
                    ) {
                        VelaAppState.shared.triggerBloodLog = true
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var memoryCard: some View {
        VelaMinimalGlassPanel(padding: 18, radius: 22) {
            HStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Personal memory", "个人记忆"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Journal notes feed future coaching context.", "手记会进入未来教练上下文。"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                Spacer()
            }
        }
    }
}

