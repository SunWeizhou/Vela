import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
