import UIKit
import ObjectiveC

/// Display-time Chinese -> English fallback for strings that are hardcoded in Chinese.
/// Active whenever the app language is not Chinese. Logic keeps working on the original
/// Chinese values; only text handed to UIKit for display is translated.
enum ZhEnTranslator {
    private struct Template {
        let regex: NSRegularExpression
        let output: String
    }

    private static let exact: [String: String] = {
        var result: [String: String] = [:]
        for (key, value) in table1.merging(table2, uniquingKeysWith: { a, _ in a })
            .merging(table3, uniquingKeysWith: { a, _ in a })
            .merging(table4, uniquingKeysWith: { a, _ in a }) where !key.contains("{}") {
            result[key] = value
        }
        return result
    }()

    private static let templates: [Template] = {
        let all = table1.merging(table2, uniquingKeysWith: { a, _ in a })
            .merging(table3, uniquingKeysWith: { a, _ in a })
            .merging(table4, uniquingKeysWith: { a, _ in a })
        return all.filter { $0.key.contains("{}") }
            .sorted { $0.key.replacingOccurrences(of: "{}", with: "").count > $1.key.replacingOccurrences(of: "{}", with: "").count }
            .compactMap { key, value in
                let parts = key.components(separatedBy: "{}").map(NSRegularExpression.escapedPattern(for:))
                let pattern = "^" + parts.joined(separator: "(.+?)") + "$"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
                return Template(regex: regex, output: value)
            }
    }()

    static func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }

    static func tr(_ text: String) -> String {
        guard containsChinese(text) else { return text }
        let text = text.replacingOccurrences(of: "王国良", with: "Test User")
        guard LocaleManager.shared.current != .zh else { return text }
        return translate(text)
    }

    static func tr(_ text: String?) -> String? { text.map { tr($0) } }

    private static func translate(_ text: String) -> String {
        guard containsChinese(text) else { return text }
        if let hit = exact[text] { return hit }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != text, !trimmed.isEmpty {
            let prefix = String(text.prefix(while: { $0.isWhitespace || $0.isNewline }))
            let suffix = String(String(text.reversed().prefix(while: { $0.isWhitespace || $0.isNewline })).reversed())
            return prefix + translate(trimmed) + suffix
        }

        let range = NSRange(text.startIndex..., in: text)
        for template in templates {
            guard let match = template.regex.firstMatch(in: text, options: [], range: range) else { continue }
            var output = template.output
            for index in 1..<match.numberOfRanges {
                guard let captured = Range(match.range(at: index), in: text), let slot = output.range(of: "{}") else { continue }
                output.replaceSubrange(slot, with: translate(String(text[captured])))
            }
            return output
        }

        for separator in ["\n", " · ", "，", "、"] where text.contains(separator) {
            let joiner = separator == "\n" || separator == " · " ? separator : (separator == "，" ? ", " : ", ")
            let pieces = text.components(separatedBy: separator)
            let translated = pieces.map { translate($0) }
            if translated != pieces { return translated.joined(separator: joiner) }
        }

#if DEBUG
        print("[ZhEn] untranslated: \(text)")
#endif
        return text
    }

    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        swap(UILabel.self, #selector(setter: UILabel.text), #selector(UILabel.vv_setText(_:)))
        swap(UILabel.self, #selector(setter: UILabel.attributedText), #selector(UILabel.vv_setAttributedText(_:)))
        swap(UIButton.self, #selector(UIButton.setTitle(_:for:)), #selector(UIButton.vv_setTitle(_:for:)))
        swap(UITextField.self, #selector(setter: UITextField.placeholder), #selector(UITextField.vv_setPlaceholder(_:)))
        swap(UISearchBar.self, #selector(setter: UISearchBar.placeholder), #selector(UISearchBar.vv_setPlaceholder(_:)))
        swap(UIViewController.self, #selector(setter: UIViewController.title), #selector(UIViewController.vv_setTitle(_:)))
        swap(UINavigationItem.self, #selector(setter: UINavigationItem.title), #selector(UINavigationItem.vv_setTitle(_:)))
        swap(UIBarItem.self, #selector(setter: UIBarItem.title), #selector(UIBarItem.vv_setTitle(_:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.setTitle(_:forSegmentAt:)), #selector(UISegmentedControl.vv_setTitle(_:forSegmentAt:)))
        swap(UISegmentedControl.self, #selector(UISegmentedControl.insertSegment(withTitle:at:animated:)), #selector(UISegmentedControl.vv_insertSegment(withTitle:at:animated:)))
        swap(UIAlertController.self, #selector(setter: UIAlertController.message), #selector(UIAlertController.vv_setMessage(_:)))
        swapClass(UIAlertController.self, Selector(("alertControllerWithTitle:message:preferredStyle:")), Selector(("vv_alertControllerWithTitle:message:preferredStyle:")))
        swapClass(UIAlertAction.self, Selector(("actionWithTitle:style:handler:")), Selector(("vv_actionWithTitle:style:handler:")))
    }

    private static func swap(_ cls: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let a = class_getInstanceMethod(cls, original), let b = class_getInstanceMethod(cls, replacement) else { return }
        method_exchangeImplementations(a, b)
    }

    private static func swapClass(_ cls: AnyClass, _ original: Selector, _ replacement: Selector) {
        guard let a = class_getClassMethod(cls, original), let b = class_getClassMethod(cls, replacement) else { return }
        method_exchangeImplementations(a, b)
    }
}

func zhEn(_ text: String) -> String { ZhEnTranslator.tr(text) }

extension UILabel {
    @objc fileprivate func vv_setText(_ text: String?) { vv_setText(ZhEnTranslator.tr(text)) }
    @objc fileprivate func vv_setAttributedText(_ text: NSAttributedString?) {
        guard let text, LocaleManager.shared.current != .zh, ZhEnTranslator.containsChinese(text.string) else {
            vv_setAttributedText(text)
            return
        }
        let mutable = NSMutableAttributedString(attributedString: text)
        mutable.mutableString.setString(ZhEnTranslator.tr(text.string))
        vv_setAttributedText(mutable)
    }
}

extension UIButton {
    @objc fileprivate func vv_setTitle(_ title: String?, for state: UIControl.State) { vv_setTitle(ZhEnTranslator.tr(title), for: state) }
}

extension UITextField {
    @objc fileprivate func vv_setPlaceholder(_ text: String?) { vv_setPlaceholder(ZhEnTranslator.tr(text)) }
}

extension UISearchBar {
    @objc fileprivate func vv_setPlaceholder(_ text: String?) { vv_setPlaceholder(ZhEnTranslator.tr(text)) }
}

extension UIViewController {
    @objc fileprivate func vv_setTitle(_ title: String?) { vv_setTitle(ZhEnTranslator.tr(title)) }
}

extension UINavigationItem {
    @objc fileprivate func vv_setTitle(_ title: String?) { vv_setTitle(ZhEnTranslator.tr(title)) }
}

extension UIBarItem {
    @objc fileprivate func vv_setTitle(_ title: String?) { vv_setTitle(ZhEnTranslator.tr(title)) }
}

extension UISegmentedControl {
    @objc fileprivate func vv_setTitle(_ title: String?, forSegmentAt segment: Int) { vv_setTitle(ZhEnTranslator.tr(title), forSegmentAt: segment) }
    @objc fileprivate func vv_insertSegment(withTitle title: String?, at segment: Int, animated: Bool) {
        vv_insertSegment(withTitle: ZhEnTranslator.tr(title), at: segment, animated: animated)
    }
}

extension UIAlertController {
    @objc fileprivate func vv_setMessage(_ message: String?) { vv_setMessage(ZhEnTranslator.tr(message)) }
    @objc(vv_alertControllerWithTitle:message:preferredStyle:)
    fileprivate class func vv_alert(title: String?, message: String?, preferredStyle: UIAlertController.Style) -> UIAlertController {
        vv_alert(title: ZhEnTranslator.tr(title), message: ZhEnTranslator.tr(message), preferredStyle: preferredStyle)
    }
}

extension UIAlertAction {
    @objc(vv_actionWithTitle:style:handler:)
    fileprivate class func vv_action(title: String?, style: UIAlertAction.Style, handler: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        vv_action(title: ZhEnTranslator.tr(title), style: style, handler: handler)
    }
}
