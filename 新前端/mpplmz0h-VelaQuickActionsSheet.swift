import SwiftUI

struct VelaQuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appState = VelaAppState.shared
    
    var body: some View {
        ZStack {
            VelaTheme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(VelaTheme.accent)
                    
                    Text(AppLanguage.stored.isChinese ? "快速操作" : "Quick Actions")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                
                // Grid layout
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    // 1. Ask Coach
                    actionButton(
                        title: L10n.t("Ask Coach", "问 AI 助手"),
                        subtitle: L10n.t("Personal advice", "获得个性化建议"),
                        icon: "sparkles",
                        tint: VelaTheme.recovery
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appState.showCoachHub = true
                        }
                    }
                    
                    // 2. Photo food log
                    actionButton(
                        title: L10n.t("Log Food", "饮食拍照识别"),
                        subtitle: L10n.t("AI macro log", "AI 智能记录饮食"),
                        icon: "camera.fill",
                        tint: VelaTheme.energy
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appState.triggerFoodCamera = true
                        }
                    }
                    
                    // 3. Lab Biomarker
                    actionButton(
                        title: L10n.t("Log Biomarker", "录入血检"),
                        subtitle: L10n.t("Standard metrics", "建立长期指标记录"),
                        icon: "drop.fill",
                        tint: VelaTheme.stress
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appState.triggerBloodLog = true
                        }
                    }
                    
                    // 4. Weight log
                    actionButton(
                        title: L10n.t("Log Weight", "记录体重体脂"),
                        subtitle: L10n.t("Track body changes", "追踪每日身体变化"),
                        icon: "scalemass.fill",
                        tint: VelaTheme.strain
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            appState.triggerWeightLog = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Bottom Tab Jump helper
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        appState.selectedTab = 1 // Switch to Journal tab
                    }
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text(AppLanguage.stored.isChinese ? "前往手记记录日常行为" : "Go to Journal to log habits")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(VelaTheme.accent)
                    .padding(14)
                    .background(VelaTheme.accent.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(tint.opacity(0.12)))
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(VelaTheme.surface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
