import SwiftUI
import AppKit

// MARK: - Apple System Settings Design Tokens

public enum AppTheme {
    // Dynamic Semantic Colors
    public static let groupCardFill = Color(nsColor: .controlBackgroundColor)
    public static let groupCardStroke = Color(nsColor: .separatorColor)
    
    public static let downloadColor = Color.blue
    public static let uploadColor = Color.orange
    public static let successColor = Color.green
    
    // SF Pro Semantic Typography
    public static let heroTitleFont = Font.title2.weight(.semibold)
    public static let heroSubtitleFont = Font.subheadline
    public static let sectionHeaderFont = Font.headline
    public static let rowTitleFont = Font.body
    public static let rowSubtitleFont = Font.subheadline
    public static let valueFont = Font.body
    public static let monoNumberFont = Font.body.monospacedDigit()
    public static let heroLargeNumberFont = Font.title.weight(.semibold).monospacedDigit()
}

// MARK: - Icon Badge (Accessible Apple Settings squircle badge)

public struct SettingsIconBadge: View {
    public let systemName: String
    public let color: Color
    public var size: CGFloat

    public init(systemName: String, color: Color, size: CGFloat = 26) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.54, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                color.gradient,
                in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Label with SettingsIconBadge

@MainActor
extension Label where Title == Text, Icon == SettingsIconBadge {
    public init(_ title: LocalizedStringKey, badge: String, color: Color) {
        self.init {
            Text(title)
        } icon: {
            SettingsIconBadge(systemName: badge, color: color)
        }
    }
    
    public init(_ title: String, badge: String, color: Color) {
        self.init {
            Text(title)
        } icon: {
            SettingsIconBadge(systemName: badge, color: color)
        }
    }
}

// MARK: - Settings Hero Header

public struct SettingsHeroHeader: View {
    public let icon: String
    public let color: Color
    public let title: LocalizedStringKey
    public let subtitle: LocalizedStringKey

    public init(
        icon: String,
        color: Color,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey
    ) {
        self.icon = icon
        self.color = color
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: 8) {
            SettingsIconBadge(systemName: icon, color: color, size: 52)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}
