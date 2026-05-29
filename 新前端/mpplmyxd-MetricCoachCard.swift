import SwiftUI

struct MetricCoachCard: View {
    let dashboard: DashboardSummary
    let focus: CoachContextFocus
    @Environment(\.modelContext) private var modelContext
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(VelaTheme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppLanguage.stored.isChinese ? "让 Coach 分析" : "Ask Coach")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(AppLanguage.stored.isChinese ? "基于当前指标继续对话。" : "Continue the conversation with this metric as context.")
                        .font(.footnote)
                        .foregroundStyle(VelaTheme.secondaryText)
                }

                Spacer()
            }

            Button {
                isPresented = true
            } label: {
                Label(AppLanguage.stored.isChinese ? "Ask Coach" : "Ask Coach", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(VelaTheme.accent)
        }
        .heroCardSurface(accent: VelaTheme.accent)
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ZStack {
                    VelaBackground()
                    ScrollView {
                        CoachChatPanel(dashboard: dashboard, focus: focus)
                            .padding(VelaTheme.screenPadding)
                    }
                }
                .navigationTitle(focus.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(AppLanguage.stored.isChinese ? "关闭" : "Close") {
                            isPresented = false
                        }
                    }
                }
            }
            .modelContext(modelContext)
            .presentationDetents([.medium, .large])
        }
    }
}
