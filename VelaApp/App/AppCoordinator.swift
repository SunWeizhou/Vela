import SwiftUI

struct AppCoordinator: View {
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var appState = VelaAppState.shared
    @StateObject private var services = VelaServices()

    var body: some View {
        ZStack {
            if onboardingCompleted {
                VelaRootView()
                    .environmentObject(dashboardVM)
                    .environmentObject(services)
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
                    .id(language.rawValue)
            } else {
                onboardingContent
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
            }

            if appState.isFallbackStore {
                VStack {
                    storeWarningBanner
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isFallbackStore)
        .task {
            BackgroundTaskManager.schedule()
        }
    }

    private var onboardingContent: some View {
        ZStack {
            VelaBackground()

            // Top glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VelaTheme.recovery.opacity(0.12), VelaTheme.recovery.opacity(0.02), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -240)
                .blur(radius: 20)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Hero
                VStack(spacing: 14) {
                    Text(language.isChinese ? "欢迎使用" : "Welcome to")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .tracking(2)
                        .textCase(.uppercase)

                    VelaLogoMark(size: 88)

                    Text("VELA")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .tracking(-1)

                    Text(language.isChinese
                        ? "你的私人健康分析师" : "Your private health analyst")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(VelaTheme.mutedText)

                    Text(language.isChinese
                        ? "将 Apple Watch 数据转化为恢复、睡眠、负荷和教练建议——一切都在设备本地处理。"
                        : "Turn your Apple Watch into recovery, sleep, strain, and coaching insights — all processed on-device.")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.mutedText.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 28)
                        .padding(.top, 4)
                }

                Spacer()

                // Feature cards
                VStack(spacing: 10) {
                    featureCard(
                        icon: "heart.fill",
                        bgColor: VelaTheme.recovery.opacity(0.12),
                        fgColor: VelaTheme.recovery,
                        title: language.isChinese ? "恢复与准备度" : "Recovery & Readiness",
                        detail: language.isChinese
                            ? "基于 HRV、静息心率和睡眠的每日评分"
                            : "Daily score from HRV, resting heart rate, and sleep"
                    )
                    featureCard(
                        icon: "moon.fill",
                        bgColor: VelaTheme.sleep.opacity(0.12),
                        fgColor: VelaTheme.sleep,
                        title: language.isChinese ? "睡眠分析" : "Sleep Analysis",
                        detail: language.isChinese
                            ? "睡眠阶段、时长和规律性评分"
                            : "Sleep stages, duration, and consistency scoring"
                    )
                    featureCard(
                        icon: "flame.fill",
                        bgColor: VelaTheme.strain.opacity(0.12),
                        fgColor: VelaTheme.strain,
                        title: language.isChinese ? "负荷与活动" : "Strain & Activity",
                        detail: language.isChinese
                            ? "来自能量消耗、锻炼和训练的活动负荷"
                            : "Training load from energy, exercise, and workouts"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA buttons
                VStack(spacing: 14) {
                    Button {
                        onboardingCompleted = true
                    } label: {
                        Text(language.isChinese ? "连接 Apple 健康" : "Connect Apple Health")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .foregroundStyle(VelaTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 99, style: .continuous)
                            .fill(VelaTheme.recovery)
                    )
                    .padding(.horizontal, 24)

                    Button {
                        onboardingCompleted = true
                    } label: {
                        Text(language.isChinese ? "稍后再说" : "Skip for now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                    .buttonStyle(.plain)
                }

                Text(language.isChinese
                    ? "你的健康数据保留在设备本地，不会未经允许离开你的手机。"
                    : "Your health data stays on-device. Nothing leaves without permission.")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.mutedText.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                Spacer()
            }
        }
    }

    private func featureCard(icon: String, bgColor: Color, fgColor: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(fgColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(bgColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.mutedText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.5)
                )
        )
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .simplifiedChinese
    }

    private var storeWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VelaTheme.energy)
            Text(language.isChinese
                 ? "存储不可用，数据不会跨启动保存。"
                 : "Storage unavailable. Data won't persist across launches.")
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.primaryText)
            Spacer()
            Button {
                withAnimation { appState.isFallbackStore = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(VelaTheme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VelaTheme.elevatedSurface)
    }
}
