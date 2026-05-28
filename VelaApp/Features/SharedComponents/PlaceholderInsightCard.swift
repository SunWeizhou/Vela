import SwiftUI

struct PlaceholderInsightCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(VelaTheme.accent.opacity(0.7))
                    .frame(width: 3, height: 16)
                    .cornerRadius(1.5)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
            }

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}
