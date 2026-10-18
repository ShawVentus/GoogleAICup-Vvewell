import Foundation
import UIKit

// 支持语言枚举
enum AppLanguage: String, CaseIterable {
    case en = "en"
    case zh = "zh"
    case ar = "ar"
    case es = "es"
    case fr = "fr"
    case id = "id"
    case th = "th"

    private struct Metadata {
        let shortDisplayName: String
        let localizedDisplayName: String
        let localeIdentifier: String
        let isRTL: Bool
        let ocrRecognitionLanguageIdentifier: String
    }

    private static let metadata: [AppLanguage: Metadata] = [
        .en: .init(
            shortDisplayName: "EN",
            localizedDisplayName: "English",
            localeIdentifier: "en_US",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "en-US"
        ),
        .zh: .init(
            shortDisplayName: "中",
            localizedDisplayName: "中文",
            localeIdentifier: "zh_CN",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "zh-Hans"
        ),
        .ar: .init(
            shortDisplayName: "AR",
            localizedDisplayName: "العربية",
            localeIdentifier: "ar_SA",
            isRTL: true,
            ocrRecognitionLanguageIdentifier: "ar-SA"
        ),
        .es: .init(
            shortDisplayName: "ES",
            localizedDisplayName: "Español",
            localeIdentifier: "es_ES",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "es-ES"
        ),
        .fr: .init(
            shortDisplayName: "FR",
            localizedDisplayName: "Français",
            localeIdentifier: "fr_FR",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "fr-FR"
        ),
        .id: .init(
            shortDisplayName: "ID",
            localizedDisplayName: "Bahasa Indonesia",
            localeIdentifier: "id_ID",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "id-ID"
        ),
        .th: .init(
            shortDisplayName: "TH",
            localizedDisplayName: "ไทย",
            localeIdentifier: "th_TH",
            isRTL: false,
            ocrRecognitionLanguageIdentifier: "th-TH"
        ),
    ]

    private var metadataValue: Metadata {
        Self.metadata[self] ?? Self.metadata[.en]!
    }

    var displayName: String {
        metadataValue.shortDisplayName
    }

    var localizedDisplayName: String {
        metadataValue.localizedDisplayName
    }

    var localeIdentifier: String {
        metadataValue.localeIdentifier
    }

    var isRTL: Bool { metadataValue.isRTL }

    var ocrRecognitionLanguageIdentifier: String {
        metadataValue.ocrRecognitionLanguageIdentifier
    }
}

// 语言切换通知名
extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
    static let appThemeDidChange = Notification.Name("appThemeDidChange")
}

// 全局语言管理器（单例）
final class LocaleManager {
    static let shared = LocaleManager()
    private let defaultsKey = "vvewell.app.language"

    private init() {
        loadSavedLanguage()
    }

    private(set) var current: AppLanguage = .en
    var isRTL: Bool { current.isRTL }
    var currentSemanticContentAttribute: UISemanticContentAttribute {
        current.isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    func loadSavedLanguage() {
        if let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
           let language = AppLanguage(rawValue: rawValue) {
            current = language
        } else {
            current = .en
        }
        applyCurrentDirection()
    }

    // 切换语言并广播通知
    func setLanguage(_ language: AppLanguage) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
        applyCurrentDirection()
        NotificationCenter.default.post(name: .appLanguageDidChange, object: language)
    }

    // 翻译入口
    func t(_ key: L10nKey) -> String {
        return L10n.string(for: key, language: current)
    }

    func apply(to window: UIWindow?) {
        window?.semanticContentAttribute = currentSemanticContentAttribute
        window?.setNeedsLayout()
        window?.layoutIfNeeded()
    }

    private func applyCurrentDirection() {
        let semantic = currentSemanticContentAttribute
        UIView.appearance().semanticContentAttribute = semantic
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                apply(to: window)
            }
        }
    }
}

// 便捷全局函数
func t(_ key: L10nKey) -> String {
    return LocaleManager.shared.t(key)
}

func directionalChevronImage(
    pointSize: CGFloat = 11,
    weight: UIImage.SymbolWeight = .semibold
) -> UIImage? {
    let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    return UIImage(systemName: "chevron.forward", withConfiguration: config)
}

enum DirectionalIconPlacement {
    case leading
    case trailing
}

func directionalSemanticContentAttribute(for placement: DirectionalIconPlacement) -> UISemanticContentAttribute {
    switch (LocaleManager.shared.isRTL, placement) {
    case (false, .leading):
        return .forceLeftToRight
    case (false, .trailing):
        return .forceRightToLeft
    case (true, .leading):
        return .forceRightToLeft
    case (true, .trailing):
        return .forceLeftToRight
    }
}

func directionalTextAlignment(trailing: Bool = false) -> NSTextAlignment {
    if trailing {
        return LocaleManager.shared.isRTL ? .left : .right
    }
    return LocaleManager.shared.isRTL ? .right : .left
}

func directionalContentHorizontalAlignment(trailing: Bool = false) -> UIControl.ContentHorizontalAlignment {
    if trailing {
        return LocaleManager.shared.isRTL ? .left : .right
    }
    return LocaleManager.shared.isRTL ? .right : .left
}

func configureTrailingChevronButton(
    _ button: UIButton,
    title: String,
    color: UIColor,
    font: UIFont,
    pointSize: CGFloat = 11,
    weight: UIImage.SymbolWeight = .semibold
) {
    button.setTitle(title, for: .normal)
    button.titleLabel?.font = font
    button.setTitleColor(color, for: .normal)
    button.tintColor = color
    button.setImage(directionalChevronImage(pointSize: pointSize, weight: weight), for: .normal)
    button.semanticContentAttribute = directionalSemanticContentAttribute(for: .trailing)
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    func title() -> String {
        switch self {
        case .system: return t(.themeSystem)
        case .light: return t(.themeLight)
        case .dark: return t(.themeDark)
        }
    }
}

final class ThemeManager {
    static let shared = ThemeManager()

    private let defaultsKey = "vvewell.app.theme"
    private init() {}

    private(set) var current: AppTheme = .system

    func loadSavedTheme() {
        guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
              let theme = AppTheme(rawValue: rawValue) else {
            current = .system
            return
        }
        current = theme
    }

    func setTheme(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: defaultsKey)
        applyToAllWindows()
        NotificationCenter.default.post(name: .appThemeDidChange, object: theme)
    }

    func apply(to window: UIWindow?) {
        window?.overrideUserInterfaceStyle = current.interfaceStyle
    }

    func applyToAllWindows() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                apply(to: window)
            }
        }
    }
}
