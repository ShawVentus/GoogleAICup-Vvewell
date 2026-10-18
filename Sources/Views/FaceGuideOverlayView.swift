import UIKit

/// 录制前人脸引导蒙层：椭圆镂空 + 3 秒倒计时 + 低亮度警告
final class FaceGuideOverlayView: UIView {

    /// 倒计时结束后回调（主线程）
    var onComplete: (() -> Void)?

    /// 扫描完成回调（主线程）
    var onScanComplete: (() -> Void)?

    // MARK: - 图层

    private lazy var overlayLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        l.fillRule = .evenOdd
        return l
    }()

    private lazy var borderLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        l.fillColor = UIColor.clear.cgColor
        l.lineWidth = 2.5
        return l
    }()

    // MARK: - 子视图

    private let countdownLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 64, weight: .bold)
        l.textAlignment = .center
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.9
        l.layer.shadowRadius = 4
        l.layer.shadowOffset = CGSize(width: 0, height: 1)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let guideLabel: UILabel = {
        let l = UILabel()
        l.text = "请将面部置于框内，保持稳定光线"
        l.textColor = .white
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let lowLightLabel: UILabel = {
        let l = UILabel()
        l.text = "环境较暗，请移至明亮处"
        l.textColor = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .bar)
        p.progressTintColor = .white
        p.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        p.progress = 0
        p.isHidden = true
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let scanTimerLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - 状态

    private var countdownValue = 3
    private var countdownTimer: Timer?

    private(set) var scanTimer: Timer?
    private var elapsed = 0
    private var scanDuration = 60
    private var countdownCenterYConstraint: NSLayoutConstraint?

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("不支持 Storyboard") }

    deinit {
        countdownTimer?.invalidate()
        scanTimer?.invalidate()
    }

    // MARK: - 布局

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShapePaths()
        countdownCenterYConstraint?.constant = ovalRect.midY
    }

    // MARK: - 公开方法

    /// 显示低亮度警告
    /// - Parameter show: true = 显示警告
    func showLowLightWarning(_ show: Bool) {
        lowLightLabel.isHidden = !show
    }

    /// 启动 3 秒倒计时，结束后自动隐藏并触发 onComplete
    func startCountdown() {
        countdownValue = 3
        updateCountdownLabel()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// 启动 60s 扫描进度 UI
    func startScanProgress(duration: Int = 60) {
        isHidden = false
        alpha = 1
        countdownLabel.isHidden = true
        scanTimerLabel.isHidden = false
        progressBar.isHidden = false
        overlayLayer.opacity = 0.3

        scanDuration = duration
        elapsed = 0
        updateScanProgress()

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.scanTick()
        }
    }

    // MARK: - 私有

    private func setupLayers() {
        backgroundColor = .clear
        layer.addSublayer(overlayLayer)
        layer.addSublayer(borderLayer)
    }

    private func setupSubviews() {
        [countdownLabel, guideLabel, lowLightLabel, progressBar, scanTimerLabel].forEach { addSubview($0) }
        let countdownCenterYConstraint = countdownLabel.centerYAnchor.constraint(equalTo: topAnchor, constant: ovalRect.midY)
        self.countdownCenterYConstraint = countdownCenterYConstraint
        NSLayoutConstraint.activate([
            countdownLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countdownCenterYConstraint,

            progressBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            progressBar.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),
            progressBar.bottomAnchor.constraint(equalTo: guideLabel.topAnchor, constant: -20),

            scanTimerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanTimerLabel.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -8),

            guideLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            guideLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            guideLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            lowLightLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            lowLightLabel.bottomAnchor.constraint(equalTo: guideLabel.topAnchor, constant: -8),
        ])
        bringSubviewToFront(countdownLabel)
    }

    private func updateShapePaths() {
        overlayLayer.frame = bounds
        borderLayer.frame = bounds

        let rect = ovalRect
        // 全屏路径 + 椭圆路径（偶奇规则镂空）
        let full = UIBezierPath(rect: bounds)
        let oval = UIBezierPath(ovalIn: rect)
        full.append(oval)
        overlayLayer.path = full.cgPath
        borderLayer.path = UIBezierPath(ovalIn: rect).cgPath
    }

    /// 椭圆区域：宽度 70%，高宽比 1.3，略偏上
    private var ovalRect: CGRect {
        let w = bounds.width * 0.7
        let h = w * 1.3
        return CGRect(
            x: (bounds.width - w) / 2,
            y: (bounds.height - h) / 2 - 16,
            width: w, height: h
        )
    }

    private func tick() {
        countdownValue -= 1
        if countdownValue <= 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
            dismiss()
        } else {
            updateCountdownLabel()
        }
    }

    private func updateCountdownLabel() {
        countdownLabel.text = "\(countdownValue)"
    }

    private func scanTick() {
        elapsed += 1
        updateScanProgress()
        if elapsed >= scanDuration {
            scanTimer?.invalidate()
            scanTimer = nil
            onScanComplete?()
        }
    }

    private func updateScanProgress() {
        progressBar.progress = Float(elapsed) / Float(scanDuration)
        scanTimerLabel.text = "正在检测 \(elapsed) / \(scanDuration)s"
    }

    private func dismiss() {
        UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }) { [weak self] _ in
            self?.isHidden = true
            self?.alpha = 1
            self?.onComplete?()
        }
    }
}
