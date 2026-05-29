import SwiftUI

struct VelaOnboardingView: View {
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false

    var body: some View {
        ZStack {
            VelaBackground()

            // Top glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VelaTheme.recovery.opacity(0.12),
                            VelaTheme.recovery.opacity(0.02),
                            .clear
                        ],
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

                // Hero section
                VStack(spacing: 14) {
                    Text(L10n.t("Welcome to", "欢迎使用"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                        .tracking(2)
                        .textCase(.uppercase)

                    VelaLogoMark(size: 88)

                    Text("VELA")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(VelaTheme.onSurface)
                        .tracking(-1)

                    Text(L10n.t("Your private health analyst", "你的私人健康分析师"))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(VelaTheme.muted)

                    Text(L10n.t(
                        "Turn your Apple Watch into recovery, sleep, strain, and coaching insights — all processed on-device.",
                        "将 Apple Watch 数据转化为恢复、睡眠、负荷和教练建议——一切都在设备本地处理。"
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.muted.opacity(0.7))
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
                        title: L10n.t("Recovery & Readiness", "恢复与准备度"),
                        detail: L10n.t(
                            "Daily score from HRV, resting heart rate, and sleep",
                            "基于 HRV、静息心率和睡眠的每日评分"
                        )
                    )
                    featureCard(
                        icon: "moon.fill",
                        bgColor: VelaTheme.sleep.opacity(0.12),
                        fgColor: VelaTheme.sleep,
                        title: L10n.t("Sleep Analysis", "睡眠分析"),
                        detail: L10n.t(
                            "Sleep stages, duration, and consistency scoring",
                            "睡眠阶段、时长和规律性评分"
                        )
                    )
                    featureCard(
                        icon: "flame.fill",
                        bgColor: VelaTheme.strain.opacity(0.12),
                        fgColor: VelaTheme.strain,
                        title: L10n.t("Strain & Activity", "负荷与活动"),
                        detail: L10n.t(
                            "Training load from energy, exercise, and workouts",
                            "来自能量消耗、锻炼和训练的活动负荷"
                        )
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA buttons
                VStack(spacing: 14) {
                    Button {
                        onboardingCompleted = true
                    } label: {
                        Text(L10n.t("Connect Apple Health", "连接 Apple 健康"))
                            .font(.system(.body, design: .rounded).weight(.bold))
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
                        Text(L10n.t("Skip for now", "稍后再说"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .buttonStyle(.plain)
                }

                Text(L10n.t(
                    "Your health data stays on-device. Nothing leaves without permission.",
                    "你的健康数据保留在设备本地，不会未经允许离开你的手机。"
                ))
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted.opacity(0.5))
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
                    .foregroundStyle(VelaTheme.onSurface)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.outline, lineWidth: 0.5)
                )
        )
    }
}
