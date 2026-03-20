import SwiftUI

// MARK: - Color Tokens

enum AppColors {

    // Brand accent — deep blue-purple
    static let accent = dynamicColor(light: 0x5E5CE6, dark: 0x7B78F2)

    // Readiness semantic colors
    static let ready = Color.green
    static let recovering = dynamicColor(light: 0xE6A100, dark: 0xFFB340)
    static let fatigued = dynamicColor(light: 0xE85555, dark: 0xFF6B6B)
    static let inForm = dynamicColor(light: 0x50B4E6, dark: 0x64D2FF)

    // Surfaces
    static let surfacePrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0, green: 0, blue: 0, alpha: 1)
                                          : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })

    static let surfaceSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
                                          : UIColor(red: 0.949, green: 0.949, blue: 0.969, alpha: 1)
    })

    static let surfaceTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1)
                                          : UIColor(red: 0.898, green: 0.898, blue: 0.918, alpha: 1)
    })

    static let surfaceElevated = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.173, green: 0.173, blue: 0.18, alpha: 1)
                                          : UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    })

    // Text hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.4)
                                          : UIColor(white: 0, alpha: 0.35)
    })

    // MARK: - Readiness Color Mapping

    static func readinessColor(for name: String) -> Color {
        switch name.lowercased() {
        case "green": return ready
        case "red": return fatigued
        case "blue": return inForm
        case "yellow": return recovering
        default: return recovering
        }
    }

    // MARK: - Dynamic Color Helper

    private static func dynamicColor(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Spacing Tokens

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cardPadding: CGFloat = 16
    static let screenMargin: CGFloat = 20
    static let sectionGap: CGFloat = 24
    static let componentGap: CGFloat = 12
}

// MARK: - Card Elevation

enum CardElevation {
    case standard
    case prominent
    case hero
}

// MARK: - View Modifiers

struct CardStyleModifier: ViewModifier {
    let elevation: CardElevation
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .overlay(borderOverlay)
    }

    @ViewBuilder
    private var cardBackground: some View {
        switch elevation {
        case .standard:
            AppColors.surfaceElevated
        case .prominent:
            AppColors.surfaceElevated
        case .hero:
            ZStack {
                AppColors.surfaceElevated
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.08), AppColors.accent.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private var shadowColor: Color {
        let isDark = colorScheme == .dark
        switch elevation {
        case .standard:
            return isDark ? Color.clear : Color.black.opacity(0.08)
        case .prominent:
            return isDark ? Color.clear : Color.black.opacity(0.12)
        case .hero:
            return isDark ? AppColors.accent.opacity(0.08) : AppColors.accent.opacity(0.1)
        }
    }

    private var shadowRadius: CGFloat {
        switch elevation {
        case .standard: return 8
        case .prominent: return 12
        case .hero: return 16
        }
    }

    private var shadowY: CGFloat {
        switch elevation {
        case .standard: return 2
        case .prominent: return 4
        case .hero: return 6
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch elevation {
        case .prominent:
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.accent.opacity(0.1), lineWidth: 1)
        case .hero, .standard:
            EmptyView()
        }
    }
}

struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(AppColors.textSecondary)
            .textCase(.uppercase)
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle(elevation: CardElevation = .standard) -> some View {
        modifier(CardStyleModifier(elevation: elevation))
    }

    func sectionHeader() -> some View {
        modifier(SectionHeaderModifier())
    }
}

// MARK: - Gradient Definitions

enum AppGradients {

    static func gauge(for color: Color) -> AngularGradient {
        AngularGradient(
            colors: [color.opacity(0.2), color.opacity(0.6), color],
            center: .center,
            startAngle: .degrees(135),
            endAngle: .degrees(405)
        )
    }

    static var heroBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.accent.opacity(0.12), Color.clear],
            startPoint: .top,
            endPoint: .center
        )
    }

    static var trainerNote: LinearGradient {
        LinearGradient(
            colors: [AppColors.accent.opacity(0.08), AppColors.accent.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var ctaButton: LinearGradient {
        LinearGradient(
            colors: [AppColors.accent, AppColors.accent.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
