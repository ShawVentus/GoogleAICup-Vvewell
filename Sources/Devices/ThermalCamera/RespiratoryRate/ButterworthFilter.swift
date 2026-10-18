import Accelerate

final class ButterworthBandpass {

    private let sampleRate: Double
    private let lowCut: Double
    private let highCut: Double
    private let order: Int

    private var biquads: [BiquadCoeffs]
    private var states: [(Double, Double)]

    struct BiquadCoeffs {
        let b0: Double
        let b1: Double
        let b2: Double
        let a1: Double
        let a2: Double
    }

    init(sampleRate: Double, lowCut: Double = 0.1, highCut: Double = 0.5, order: Int = 4) {
        self.sampleRate = sampleRate
        self.lowCut = lowCut
        self.highCut = highCut
        self.order = order
        self.biquads = ButterworthBandpass.designBandpass(sampleRate: sampleRate, lowCut: lowCut, highCut: highCut, order: order)
        self.states = Array(repeating: (0, 0), count: biquads.count)
    }

    func reset() {
        states = Array(repeating: (0, 0), count: biquads.count)
    }

    func process(_ input: [Double]) -> [Double] {
        var output = input

        for (i, bq) in biquads.enumerated() {
            var x1 = states[i].0
            var x2 = states[i].1
            var y1: Double = 0
            var y2: Double = 0

            for j in 0..<output.count {
                let x0 = output[j]
                let y0 = bq.b0 * x0 + bq.b1 * x1 + bq.b2 * x2 - bq.a1 * y1 - bq.a2 * y2
                output[j] = y0
                x2 = x1
                x1 = x0
                y2 = y1
                y1 = y0
            }
            states[i] = (x1, x2)
        }

        return output
    }

    func processSample(_ x: Double) -> Double {
        var sample = x
        for (i, bq) in biquads.enumerated() {
            let x1 = states[i].0
            let x2 = states[i].1
            let y0 = bq.b0 * sample + bq.b1 * x1 + bq.b2 * x2
            // For simplicity, use a direct-form I without y history (approximation)
            states[i] = (sample, x1)
            sample = y0
        }
        return sample
    }

    // MARK: - Design

    private static func designBandpass(sampleRate: Double, lowCut: Double, highCut: Double, order: Int) -> [BiquadCoeffs] {
        let nyq = sampleRate / 2
        let w1 = lowCut / nyq
        let w2 = highCut / nyq

        let centerFreq = sqrt(w1 * w2)
        let bandwidth = w2 - w1

        let q = centerFreq / bandwidth
        let omega = 2 * .pi * centerFreq
        let alpha = sin(omega) / (2 * q)

        let cosw = cos(omega)

        let b0 = alpha
        let b1 = 0.0
        let b2 = -alpha
        let a0 = 1 + alpha
        let a1 = -2 * cosw
        let a2 = 1 - alpha

        let coeffs = BiquadCoeffs(b0: b0/a0, b1: b1/a0, b2: b2/a0, a1: a1/a0, a2: a2/a0)

        var result: [BiquadCoeffs] = []
        let stages = max(1, order / 2)
        for _ in 0..<stages {
            result.append(coeffs)
        }
        return result
    }
}
