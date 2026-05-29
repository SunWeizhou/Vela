import Charts
import SwiftUI

struct DetailScreenScaffold<Hero: View, Content: View>: View {
    let title: String
    let subtitle: String
    var showDateNavigation: Bool = false
    @ViewBuilder let hero: Hero
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: title, subtitle: subtitle)

                        if showDateNavigation {
                            DateNavigationBar()
                        }

                        hero
                        content
                    }
                    .padding(VelaTheme.screenPadding)
                }
            }
        }
    }
}

struct MetricRowItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var tint: Color = VelaTheme.accent
}

struct MetricRow: View {
    let items: [MetricRowItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)

                    Text(item.value)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                        .fill(VelaTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                .stroke(item.tint.opacity(0.15), lineWidth: 0.5)
                        )
                )
            }
        }
    }
}

struct PlaceholderInsightCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(VelaTheme.accent.opacity(0.4))
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
