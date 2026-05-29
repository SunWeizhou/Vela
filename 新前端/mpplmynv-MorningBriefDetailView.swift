import SwiftUI

struct MorningBriefDetailView: View {
    let report: AIReportRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Dark elegant background
            VelaBackground()
            
            // Soft gold background glow
            VStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.80, blue: 0.28).opacity(0.04))
                    .frame(width: 300, height: 300)
                    .blur(radius: 50)
                    .offset(y: -100)
                Spacer()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.title3.bold())
                                .foregroundStyle(LinearGradient(
                                    colors: [VelaTheme.energy, VelaTheme.strain],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: VelaTheme.energy.opacity(0.5), radius: 8)
                            
                            Text(L10n.t("DAILY INTELLIGENCE", "今日健康简报"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)
                                .tracking(1.5)
                        }
                        
                        Text(report.title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Text(report.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                    .padding(.top, 24)
                    
                    Divider().background(VelaTheme.stroke)
                    
                    // Detailed Report Content
                    VStack(alignment: .leading, spacing: 16) {
                        MarkdownText(
                            markdown: report.markdownContent,
                            font: .body,
                            color: VelaTheme.primaryText,
                            isStreaming: false
                        )
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                            .fill(VelaTheme.cardBackground.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                            .stroke(VelaTheme.stroke, lineWidth: 1)
                    )
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, VelaTheme.screenPadding)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(VelaTheme.energy)
                    Text(L10n.t("Morning Brief", "晨间简报"))
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(VelaTheme.primaryText)
                }
            }
        }
    }
}
