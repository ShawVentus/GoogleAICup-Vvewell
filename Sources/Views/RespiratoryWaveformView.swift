import UIKit

final class RespiratoryWaveformView: UIView {

    private var samples: [Double] = []
    private var displayBpm: Double?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        clipsToBounds = true
    }

    func update(with signal: [Double], bpm: Double?) {
        samples = signal
        displayBpm = bpm
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)

        let bgColor = UIColor.secondarySystemBackground.cgColor
        ctx.setFillColor(bgColor)
        ctx.fill(rect)

        guard samples.count > 2 else {
            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            let text = "—" as NSString
            let size = text.size(withAttributes: attr)
            text.draw(at: CGPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2), withAttributes: attr)
            return
        }

        let midY = rect.height / 2
        let amplitude = rect.height * 0.35

        let minVal = samples.min() ?? 0
        let maxVal = samples.max() ?? 1
        let range = maxVal - minVal
        let safeRange = range > 0 ? range : 1

        let stepX = rect.width / CGFloat(samples.count - 1)

        let color = UIColor(red: 0.9, green: 0.45, blue: 0.2, alpha: 1.0)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.beginPath()
        for i in 0..<samples.count {
            let x = CGFloat(i) * stepX
            let normalized = (samples[i] - minVal) / safeRange
            let y = midY - CGFloat(normalized) * amplitude + amplitude / 2
            if i == 0 {
                ctx.move(to: CGPoint(x: x, y: y))
            } else {
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
        }
        ctx.strokePath()
    }
}
