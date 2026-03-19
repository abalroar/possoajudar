import SwiftUI

struct ReadinessGaugeView: View {
    let score: Int
    let label: String
    let colorName: String
    let primarySignal: String
    var size: CGFloat = 200

    private var gaugeColor: Color {
        switch colorName.lowercased() {
        case "green": return .green
        case "red": return .red
        case "blue": return Color(red: 0.2, green: 0.6, blue: 1.0)
        default: return .yellow
        }
    }

    private var trimEnd: CGFloat {
        CGFloat(score) / 100.0 * 0.75 // 270° arc = 0.75 of full circle
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Track
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: size, height: size)

                // Fill
                Circle()
                    .trim(from: 0.125, to: 0.125 + trimEnd)
                    .stroke(
                        LinearGradient(
                            colors: [gaugeColor.opacity(0.6), gaugeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: size, height: size)
                    .animation(.easeOut(duration: 1.2), value: score)

                // Center content
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.8), value: score)

                    Text(label.uppercased())
                        .font(.system(size: size * 0.085, weight: .semibold, design: .rounded))
                        .foregroundColor(gaugeColor)
                        .tracking(1.5)
                }
            }
            .frame(width: size, height: size)

            if !primarySignal.isEmpty {
                Text(primarySignal)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: size)
            }
        }
    }
}

// MARK: - Compact version for history rows

struct ReadinessBadge: View {
    let score: Int
    let color: String

    private var gaugeColor: Color {
        switch color.lowercased() {
        case "green": return .green
        case "red": return .red
        case "blue": return Color(red: 0.2, green: 0.6, blue: 1.0)
        default: return .yellow
        }
    }

    var body: some View {
        Text("\(score)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(gaugeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(gaugeColor.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
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
