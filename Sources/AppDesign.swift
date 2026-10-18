import UIKit

enum AppDesign {

    // MARK: - Colors
    enum Color {
        // Android Vvewell design tokens: #18B6A4 and #087D73.
        static let primaryGreen = UIColor(red: 24 / 255, green: 182 / 255, blue: 164 / 255, alpha: 1.0)
        static let darkTeal = UIColor(red: 8 / 255, green: 125 / 255, blue: 115 / 255, alpha: 1.0)
        static let metricCardOverlay = UIColor(red: 0.28, green: 0.64, blue: 0.58, alpha: 0.6)
        static let gradientTop = UIColor(red: 0.13, green: 0.55, blue: 0.49, alpha: 1.0)
        static let gradientBottom = UIColor(red: 0.09, green: 0.45, blue: 0.40, alpha: 1.0)
        // Health profile card gradient (slightly different from hero gradient)
        static let profileGradientTop = UIColor(red: 0.22, green: 0.58, blue: 0.52, alpha: 1.0)
        static let profileGradientBottom = UIColor(red: 0.13, green: 0.48, blue: 0.42, alpha: 1.0)
        static let connectedGreen = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        static let scoreBarGreen = UIColor(red: 0.3, green: 0.85, blue: 0.5, alpha: 1.0)

        // MARK: - Health Metric Colors
        static let heartRate = UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1.0)
        static let bloodOxygen = UIColor(red: 0.376, green: 0.647, blue: 0.98, alpha: 1.0)
        static let temperature = UIColor(red: 0.984, green: 0.749, blue: 0.149, alpha: 1.0)
        static let stress = UIColor(red: 0.294, green: 0.855, blue: 0.498, alpha: 1.0)
        static let sleep = UIColor(red: 0.655, green: 0.545, blue: 0.98, alpha: 1.0)
        static let activity = UIColor(red: 0.984, green: 0.573, blue: 0.235, alpha: 1.0)
        static let cyan = UIColor(red: 0.133, green: 0.827, blue: 0.933, alpha: 1.0)
    }

    // MARK: - Corner Radii
    enum CornerRadius {
        static let heroCard: CGFloat = 20
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let badge: CGFloat = 10
        static let progressBar: CGFloat = 4
        static let pill: CGFloat = 14
        static let composer: CGFloat = 24
    }

    // MARK: - Shadow
    enum Shadow {
        static let cardOpacity: Float = 0.04
        static let cardOffset = CGSize(width: 0, height: 2)
        static let cardRadius: CGFloat = 8
    }

    // MARK: - Layout
    enum Layout {
        static let horizontalPadding: CGFloat = 20
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let compactSpacing: CGFloat = 8
    }

    // MARK: - Icon Size
    enum IconSize {
        static let headerControl: CGFloat = 20
        static let sectionIcon: CGFloat = 18
    }

    // MARK: - Surface
    enum Surface {
        static let canvasBackground = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.05, green: 0.07, blue: 0.08, alpha: 1.0)
            }
            return UIColor(red: 244 / 255, green: 248 / 255, blue: 247 / 255, alpha: 1.0)
        }

        static let elevatedCard = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.14, blue: 0.15, alpha: 1.0)
            }
            return .systemBackground
        }

        static let secondaryCard = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1.0)
            }
            return UIColor.secondarySystemBackground.withAlphaComponent(0.92)
        }

        static let highlightCard = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.09, green: 0.15, blue: 0.13, alpha: 1.0)
            }
            return UIColor(red: 0.94, green: 0.99, blue: 0.96, alpha: 1.0)
        }

        static let subtleTint = UIColor { traitCollection in
            let alpha: CGFloat = traitCollection.userInterfaceStyle == .dark ? 0.18 : 0.10
            return AppDesign.Color.primaryGreen.withAlphaComponent(alpha)
        }

        static let border = UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.08)
            }
            return UIColor(red: 220 / 255, green: 232 / 255, blue: 230 / 255, alpha: 1.0)
        }
    }

    // MARK: - Control
    enum ControlSize {
        static let minimumTapTarget: CGFloat = 44
        static let assistantActionButton: CGFloat = 32
    }

    // MARK: - Chat
    enum Chat {
        static let userBubbleMaxWidthRatio: CGFloat = 0.74
        static let assistantBubbleMaxWidthRatio: CGFloat = 0.9
        static let composerMinHeight: CGFloat = 44
        static let composerMaxHeight: CGFloat = 120
        static let sectionCornerRadius: CGFloat = 16
        static let latestSessionCardCornerRadius: CGFloat = 18
    }
}
