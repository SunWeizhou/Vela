import SwiftUI

// MARK: - VelaAppleSettingsView — Apple-style iOS Settings
// Grouped list sections: health data, notifications, appearance, privacy, about

struct VelaMinimalJournalView: View {
    @State private var notificationsEnabled = true
    @State private var morningBrief = true
    @State private var eveningSync = true
    @State private var coachingAlerts = false
    @State private var darkMode: DarkModePref = .system
    @State private var language: LanguagePref = .english
    @State private var dataSharing = false

    enum DarkModePref: String, CaseIterable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"
    }

    enum LanguagePref: String, CaseIterable {
        case english = "English"
        case chinese = "Chinese"
    }

    var body: some View {
        VelaMinimalScreen {
            // ── Connected Sources
            sectionHeader("Connected Sources")

            groupedSection {
                sourceRow("Apple Health", "Active · 7 data types", "heart.circle.fill", Color.red)
                sourceRow("Apple Watch", "Paired · Series 9", "applewatch", VelaTheme.onSurface)

                NavigationLink {
                    EmptyView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(VelaTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(VelaTheme.accent.opacity(0.10)))
                        Text("Add Data Source")
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.accent)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }

            // ── Notifications
            sectionHeader("Notifications")

            groupedSection {
                toggleRow("Push Notifications", systemImage: "bell.fill", tint: VelaTheme.stress, isOn: $notificationsEnabled)
                if notificationsEnabled {
                    Divider().background(VelaTheme.outline)
                    toggleRow("Morning Brief", systemImage: "sunrise.fill", tint: VelaTheme.energy, isOn: $morningBrief)
                    Divider().background(VelaTheme.outline)
                    toggleRow("Evening Wiki Sync", systemImage: "moon.stars.fill", tint: VelaTheme.sleep, isOn: $eveningSync)
                    Divider().background(VelaTheme.outline)
                    toggleRow("Coaching Alerts", systemImage: "bubble.left.fill", tint: VelaTheme.accent, isOn: $coachingAlerts)
                }
            }

            // ── Appearance
            sectionHeader("Appearance")

            groupedSection {
                ForEach(DarkModePref.allCases, id: \.rawValue) { mode in
                    Button {
                        darkMode = mode
                    } label: {
                        HStack {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.onSurface)
                            Spacer()
                            if darkMode == mode {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VelaTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Language
            sectionHeader("Language")

            groupedSection {
                ForEach(LanguagePref.allCases, id: \.rawValue) { lang in
                    Button {
                        language = lang
                    } label: {
                        HStack {
                            Text(lang.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.onSurface)
                            Spacer()
                            if language == lang {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VelaTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Privacy
            sectionHeader("Privacy & Data")

            groupedSection {
                toggleRow("Share Analytics", systemImage: "chart.bar.fill", tint: VelaTheme.accent, isOn: $dataSharing)
                Divider().background(VelaTheme.outline)
                navRow("Data Coverage Report", "Check signal quality", "waveform.path.ecg.rectangle", VelaTheme.recovery)
                Divider().background(VelaTheme.outline)
                navRow("Trust Center", "Agent audit log", "checkmark.shield.fill", VelaTheme.accent)
                Divider().background(VelaTheme.outline)
                navRow("Export Health Data", "JSON · CSV", "square.and.arrow.up.fill", VelaTheme.onSurfaceVariant)
            }

            // ── About
            sectionHeader("About")

            groupedSection {
                infoRow("Version", "Vela 2.0 (Apple Design)")
                Divider().background(VelaTheme.outline)
                infoRow("Build", "2026.05.29 · SF Pro")
                Divider().background(VelaTheme.outline)
                infoRow("Design System", "Apple Human Interface")
                Divider().background(VelaTheme.outline)
                navRow("Acknowledgements", "Open source licenses", "doc.text.fill", VelaTheme.muted)
            }

            Text("Vela AI Body Intelligence · Made with Apple design language\nHealth data never leaves your device without permission.")
                .font(VelaTheme.microFont)
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, VelaTheme.spaceXL)
        }
    }

    // MARK: - Row Builders

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(VelaTheme.onSurfaceVariant)
            .textCase(.uppercase)
            .tracking(1.0)
            .padding(.leading, 2)
            .padding(.top, VelaTheme.spaceSM)
    }

    private func groupedSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(VelaTheme.spaceLG)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    private func sourceRow(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.10)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(subtitle)
                    .font(VelaTheme.microFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(VelaTheme.recovery)
        }
        .padding(.vertical, 6)
    }

    private func toggleRow(_ title: String, systemImage: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.10)))
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.onSurface)
            }
        }
        .tint(VelaTheme.accent)
        .padding(.vertical, 4)
    }

    private func navRow(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        NavigationLink {
            EmptyView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.10)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.onSurface)
                    Text(subtitle)
                        .font(VelaTheme.microFont)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .padding(.vertical, 4)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.onSurface)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
        }
        .padding(.vertical, 4)
    }
}
