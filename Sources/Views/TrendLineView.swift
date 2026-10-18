import UIKit

final class TrendLineView: UIView {

    var dataPoints: [Double] = [] {
        didSet { setNeedsLayout() }
    }

    var lineColor: UIColor = .systemRed {
        didSet { updateLayerColors() }
    }

    private let lineLayer = CAShapeLayer()
    private let pointsLayer = CAShapeLayer()
    private let emptyStateLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    private func commonInit() {
        backgroundColor = UIColor.systemGray6.withAlphaComponent(0.6)
        layer.cornerRadius = 12
        clipsToBounds = true

        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = 2.5
        lineLayer.lineJoin = .round
        lineLayer.lineCap = .round

        pointsLayer.fillColor = UIColor.clear.cgColor
        pointsLayer.strokeColor = UIColor.clear.cgColor

        emptyStateLayer.fillColor = UIColor.clear.cgColor
        emptyStateLayer.strokeColor = UIColor.systemGray3.cgColor
        emptyStateLayer.lineWidth = 1.5
        emptyStateLayer.lineDashPattern = [6, 4]
        emptyStateLayer.lineCap = .round

        layer.addSublayer(emptyStateLayer)
        layer.addSublayer(lineLayer)
        layer.addSublayer(pointsLayer)
        updateLayerColors()
    }

    private func updateLayerColors() {
        lineLayer.strokeColor = lineColor.cgColor
        pointsLayer.fillColor = lineColor.cgColor
    }

    private func redraw() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        if dataPoints.isEmpty {
            drawEmptyState()
            return
        }

        emptyStateLayer.path = nil

        let drawingRect = bounds.insetBy(dx: 14, dy: 16)
        guard drawingRect.width > 0, drawingRect.height > 0 else { return }

        let minValue = dataPoints.min() ?? 0
        let maxValue = dataPoints.max() ?? 0
        let rawRange = maxValue - minValue
        let padding = rawRange > 0 ? rawRange * 0.1 : max(abs(maxValue) * 0.1, 1)
        let scaledMin = minValue - padding
        let scaledMax = maxValue + padding
        let scaledRange = max(scaledMax - scaledMin, 0.0001)

        let coordinates: [CGPoint]
        if dataPoints.count == 1 {
            let y = yPosition(for: dataPoints[0], minValue: scaledMin, range: scaledRange, rect: drawingRect)
            coordinates = [CGPoint(x: drawingRect.midX, y: y)]
        } else {
            let stepX = drawingRect.width / CGFloat(dataPoints.count - 1)
            coordinates = dataPoints.enumerated().map { index, value in
                let x = drawingRect.minX + CGFloat(index) * stepX
                let y = yPosition(for: value, minValue: scaledMin, range: scaledRange, rect: drawingRect)
                return CGPoint(x: x, y: y)
            }
        }

        let linePath = UIBezierPath()
        if let firstPoint = coordinates.first {
            linePath.move(to: firstPoint)
            coordinates.dropFirst().forEach { linePath.addLine(to: $0) }
        }
        lineLayer.path = linePath.cgPath

        let pointsPath = UIBezierPath()
        coordinates.forEach { point in
            pointsPath.append(UIBezierPath(arcCenter: point, radius: 3.5, startAngle: 0, endAngle: .pi * 2, clockwise: true))
        }
        pointsLayer.path = pointsPath.cgPath
    }

    private func drawEmptyState() {
        lineLayer.path = nil
        pointsLayer.path = nil

        let drawingRect = bounds.insetBy(dx: 14, dy: 16)
        let dashedPath = UIBezierPath()
        dashedPath.move(to: CGPoint(x: drawingRect.minX, y: drawingRect.midY))
        dashedPath.addLine(to: CGPoint(x: drawingRect.maxX, y: drawingRect.midY))
        emptyStateLayer.path = dashedPath.cgPath
    }

    private func yPosition(for value: Double, minValue: Double, range: Double, rect: CGRect) -> CGFloat {
        let normalized = CGFloat((value - minValue) / range)
        return rect.maxY - normalized * rect.height
    }
}
