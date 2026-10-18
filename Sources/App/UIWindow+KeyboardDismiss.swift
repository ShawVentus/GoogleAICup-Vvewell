import UIKit

// MARK: - Keyboard Handling Protocols

enum KeyboardAdjustmentType {
    case none          // 完全不调整布局（适用于固定视觉的登录页等）
    case contentInset  // 调整 ScrollView 的内边距（适用于标准表单滚动页）
}

protocol KeyboardBehaviorCustomizable: AnyObject {
    var keyboardAdjustmentType: KeyboardAdjustmentType { get }
}

// MARK: - GlobalKeyboardHandler

final class GlobalKeyboardHandler {

    static let shared = GlobalKeyboardHandler()
    private weak var window: UIWindow?
    private weak var lastAdjustedScrollView: UIScrollView?

    private init() {}

    func start(for window: UIWindow) {
        self.window = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardChange(_ notification: Notification) {
        guard let window,
              let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }

        guard let topVC = Self.topViewController(from: window.rootViewController) else { return }

        // 检查页面是否通过协议声明了豁免或特殊的避让行为
        let behavior = (topVC as? KeyboardBehaviorCustomizable)?.keyboardAdjustmentType ?? .contentInset

        if behavior == .none {
            // 如果页面声明不需要调整（如 Login），则全局处理器保持沉默
            return
        }

        let isHiding = endFrame.minY >= window.bounds.height
        let keyboardHeight = isHiding ? 0 : (window.bounds.height - endFrame.minY)

        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)

        // 方案核心：不再修改 additionalSafeAreaInsets (会导致布局压缩和内容漂移)
        // 而是直接修改当前页面内 ScrollView 的 contentInset
        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) {
            self.adjustScrollViews(in: topVC.view, keyboardHeight: keyboardHeight, isHiding: isHiding)
            topVC.view.layoutIfNeeded()
        } completion: { _ in
            if !isHiding {
                self.scrollFirstResponderVisible(in: topVC.view)
            }
        }
    }

    private func adjustScrollViews(in rootView: UIView, keyboardHeight: CGFloat, isHiding: Bool) {
        // 寻找页面中的主 ScrollView
        if let scrollView = rootView.findMainScrollView() {
            // 补偿底部安全区高度，确保 contentInset 刚好覆盖键盘
            let bottomSafeArea = scrollView.safeAreaInsets.bottom
            let newBottomInset = max(0, keyboardHeight - bottomSafeArea)

            var contentInset = scrollView.contentInset
            contentInset.bottom = newBottomInset
            scrollView.contentInset = contentInset

            var indicatorInset = scrollView.verticalScrollIndicatorInsets
            indicatorInset.bottom = newBottomInset
            scrollView.verticalScrollIndicatorInsets = indicatorInset

            if isHiding {
                // 修复 contentOffset 卡在顶部的问题
                let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom + scrollView.contentInset.top)
                if scrollView.contentOffset.y > maxOffsetY {
                    scrollView.contentOffset.y = maxOffsetY
                }
            }

            lastAdjustedScrollView = scrollView
        }
    }

    private func scrollFirstResponderVisible(in rootView: UIView) {
        guard let firstResponder = rootView.findFirstResponder(),
              let scrollView = firstResponder.findEnclosingScrollView() else { return }
        let rect = firstResponder.convert(firstResponder.bounds, to: scrollView)
        scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -20), animated: true)
    }

    private static func topViewController(from vc: UIViewController?) -> UIViewController? {
        guard let vc else { return nil }
        if let presented = vc.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = vc as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return vc
    }
}

// MARK: - UIView + Helpers

extension UIView {
    func findFirstResponder() -> UIView? {
        if isFirstResponder { return self }
        for subview in subviews {
            if let responder = subview.findFirstResponder() {
                return responder
            }
        }
        return nil
    }

    func findMainScrollView() -> UIScrollView? {
        if let sv = self as? UIScrollView { return sv }
        for subview in subviews {
            if let found = subview.findMainScrollView() {
                return found
            }
        }
        return nil
    }

    func findEnclosingScrollView() -> UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let sv = view as? UIScrollView { return sv }
            current = view.superview
        }
        return nil
    }
}

// MARK: - UIWindow + Global Keyboard Dismiss

extension UIWindow {
    
    func enableGlobalKeyboardDismissOnTap() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboardOnTap)
        )
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboardOnTap() {
        endEditing(true)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension UIWindow: @retroactive UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        var currentView: UIView? = view
        while let v = currentView {
            if v is UITextField || v is UITextView || v is UISearchBar {
                return false
            }
            currentView = v.superview
        }
        return true
    }
}
