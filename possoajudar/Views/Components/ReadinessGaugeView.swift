import SwiftUI

struct ReadinessGaugeView: View {
    let score: Int
    let label: String
    let colorName: String
    let primarySignal: String
    var size: CGFloat = 200

    private var gaugeColor: Color {
        AppColors.readinessColor(for: colorName)
    }

    private var trimEnd: CGFloat {
        CGFloat(score) / 100.0 * 0.75
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                // Track
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(
                        AppColors.surfaceTertiary.opacity(0.5),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size, height: size)

                // Glow (blurred duplicate behind fill)
                Circle()
                    .trim(from: 0.125, to: 0.125 + trimEnd)
                    .stroke(
                        gaugeColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size, height: size)
                    .blur(radius: 10)
                    .opacity(0.4)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: score)

                // Fill arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + trimEnd)
                    .stroke(
                        AngularGradient(
                            colors: [
                                gaugeColor.opacity(0.3),
                                gaugeColor.opacity(0.7),
                                gaugeColor
                            ],
                            center: .center,
                            startAngle: .degrees(135),
                            endAngle: .degrees(135 + Double(score) / 100.0 * 270)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size, height: size)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: score)

                // Center content
                VStack(spacing: AppSpacing.xxs) {
                    Text("\(score)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.8), value: score)

                    Text(label.uppercased())
                        .font(.system(size: size * 0.085, weight: .semibold, design: .rounded))
                        .foregroundStyle(gaugeColor)
                        .tracking(1.5)
                }
            }
            .frame(width: size, height: size)

            if !primarySignal.isEmpty {
                Text(primarySignal)
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: size)
            }
        }
    }
}

// MARK: - Compact badge for history rows

struct ReadinessBadge: View {
    let score: Int
    let color: String

    private var badgeColor: Color {
        AppColors.readinessColor(for: color)
    }

    var body: some View {
        Text("\(score)")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(badgeColor)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(badgeColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        AppColors.surfacePrimary.ignoresSafeArea()
        VStack(spacing: 40) {
            ReadinessGaugeView(score: 72, label: "Pronto", colorName: "green",
                               primarySignal: "HRV estável + sono 7h")
            ReadinessGaugeView(score: 45, label: "Recuperando", colorName: "yellow",
                               primarySignal: "Sono fragmentado", size: 140)
            HStack(spacing: 12) {
                ReadinessBadge(score: 82, color: "blue")
                ReadinessBadge(score: 65, color: "green")
                ReadinessBadge(score: 40, color: "red")
            }
        }
    }
}
