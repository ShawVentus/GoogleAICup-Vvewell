import Accelerate

final class WelchEstimator {

    private let sampleRate: Double
    private let windowSize: Int
    private let overlap: Double

    init(sampleRate: Double, windowSize: Int = 150, overlap: Double = 0.5) {
        self.sampleRate = sampleRate
        self.windowSize = windowSize
        self.overlap = overlap
    }

    struct SpectralResult {
        let dominantFreq: Double
        let power: Double
        let spectralConcentration: Double
    }

    func estimate(from signal: [Double]) -> SpectralResult? {
        guard signal.count >= windowSize else { return nil }

        let hopSize = Int(Double(windowSize) * (1 - overlap))
        var periodograms: [[Double]] = []
        let n = windowSize
        let fftSize = nextPowerOfTwo(n)
        let halfSize = fftSize / 2

        var pos = 0
        while pos + n <= signal.count {
            var segment = Array(signal[pos..<(pos + n)])

            applyHannWindow(&segment, n: n)

            var realPart = segment
            var imagPart = [Double](repeating: 0, count: fftSize)
            var splitComplex = DSPDoubleSplitComplex(realp: &realPart, imagp: &imagPart)

            let log2n = vDSP_Length(log2(Double(fftSize)).rounded())
            guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(2)) else { break }

            vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            vDSP_destroy_fftsetupD(fftSetup)

            var magnitudes = [Double](repeating: 0, count: halfSize)
            vDSP_zvabsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))

            var psd = [Double](repeating: 0, count: halfSize)
            vDSP_svesqD(&magnitudes, 1, &psd[0], vDSP_Length(halfSize))
            for i in 0..<halfSize {
                psd[i] = magnitudes[i] * magnitudes[i]
            }

            periodograms.append(psd)
            pos += hopSize
        }

        guard !periodograms.isEmpty else { return nil }

        let avgPsd = averagePeriodograms(periodograms, length: halfSize)

        let freqResolution = sampleRate / Double(fftSize)
        let minFreq: Double = 0.1
        let maxFreq: Double = 0.5
        let minBin = Int(minFreq / freqResolution)
        let maxBin = min(Int(maxFreq / freqResolution), halfSize - 1)

        guard maxBin > minBin else { return nil }

        var maxPower: Double = 0
        var maxBinIdx = minBin
        var totalPower: Double = 0

        for i in minBin...maxBin {
            totalPower += avgPsd[i]
            if avgPsd[i] > maxPower {
                maxPower = avgPsd[i]
                maxBinIdx = i
            }
        }

        let dominantFreq = Double(maxBinIdx) * freqResolution
        let spectralConcentration = totalPower > 0 ? maxPower / totalPower : 0

        return SpectralResult(
            dominantFreq: dominantFreq,
            power: maxPower,
            spectralConcentration: spectralConcentration
        )
    }

    private func applyHannWindow(_ data: inout [Double], n: Int) {
        var window = [Double](repeating: 0, count: n)
        var output = [Double](repeating: 0, count: n)
        vDSP_hann_windowD(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmulD(&data, 1, &window, 1, &output, 1, vDSP_Length(n))
        data = output
    }

    private func averagePeriodograms(_ periodograms: [[Double]], length: Int) -> [Double] {
        var sum = [Double](repeating: 0, count: length)
        for p in periodograms {
            var nextSum = [Double](repeating: 0, count: length)
            vDSP_vaddD(&sum, 1, p, 1, &nextSum, 1, vDSP_Length(length))
            sum = nextSum
        }
        var count = Double(periodograms.count)
        var average = [Double](repeating: 0, count: length)
        vDSP_vsdivD(&sum, 1, &count, &average, 1, vDSP_Length(length))
        return average
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var p = 1
        while p < n { p *= 2 }
        return p
    }
}
