package com.vvewell.health.core.rppg

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

internal class RppgRespirationEstimator(
    private val history: RppgMetricHistory = RppgMetricHistory(),
) {
    fun beginSegment(segmentId: Long) = history.beginSegment(segmentId)

    fun clearHistory() = history.clear()

    fun estimate(samples: List<TimedRppgSample>, segmentId: Long): MetricEstimate {
        val prepared = RppgSignalResampler.resample(samples)
        if (prepared is RppgResampleOutcome.Rejected) {
            return MetricEstimate.rejected(TYPE, prepared.reason, prepared.diagnostics)
        }
        val uniform = (prepared as RppgResampleOutcome.Success).signal
        return estimateUniform(uniform, segmentId)
    }

    private fun estimateUniform(signal: UniformRppgSignal, segmentId: Long): MetricEstimate {
        val diagnostics = signal.diagnostics
        val duration = diagnostics.durationSeconds ?: 0.0
        if (duration < MIN_DURATION_SECONDS) {
            return rejected(MetricRejectionReason.InsufficientDuration, diagnostics)
        }
        if (signal.sampleRateHz < MIN_SAMPLE_RATE_HZ) {
            return rejected(MetricRejectionReason.SampleRateTooLow, diagnostics)
        }
        if (signal.values.size < MIN_UNIFORM_SAMPLES) {
            return rejected(MetricRejectionReason.InsufficientSamples, diagnostics)
        }

        val normalized = RppgDsp.zScore(RppgDsp.linearDetrend(signal.values))
            ?: return rejected(MetricRejectionReason.LowSignalEnergy, diagnostics)
        val cutoff = min(MAX_LOW_PASS_HZ, LOW_PASS_NYQUIST_FRACTION * signal.sampleRateHz)
        val filtered = RppgDsp.zeroPhaseButterworthLowPass(
            input = normalized,
            sampleRateHz = signal.sampleRateHz,
            cutoffHz = cutoff,
        ) ?: return rejected(MetricRejectionReason.FilterFailure, diagnostics)
        val spectrum = RppgDsp.rawPowerSpectrum(filtered, signal.sampleRateHz)
            ?: return rejected(MetricRejectionReason.NumericalFailure, diagnostics)

        val bandIndices = spectrum.frequenciesHz.indices.filter { index ->
            spectrum.frequenciesHz[index] + FREQUENCY_EPSILON >= MIN_RESPIRATION_HZ &&
                spectrum.frequenciesHz[index] - FREQUENCY_EPSILON <= MAX_RESPIRATION_HZ
        }
        if (bandIndices.isEmpty()) {
            return rejected(
                MetricRejectionReason.NoRespiratoryBandBin,
                diagnostics.copy(frequencyResolutionHz = spectrum.resolutionHz),
            )
        }
        val peakIndex = bandIndices.maxByOrNull { spectrum.power[it] }
            ?: return rejected(MetricRejectionReason.NoRespiratoryPeak, diagnostics)
        val peakPower = spectrum.power[peakIndex]
        val meanBandPower = bandIndices.map { spectrum.power[it] }.average()
        if (
            !peakPower.isFinite() || !meanBandPower.isFinite() ||
            peakPower <= POWER_EPSILON || meanBandPower <= POWER_EPSILON
        ) {
            return rejected(MetricRejectionReason.NoRespiratoryPeak, diagnostics)
        }
        val ratio = peakPower / meanBandPower
        val baseDiagnostics = diagnostics.copy(
            frequencyResolutionHz = spectrum.resolutionHz,
            peakFrequencyHz = spectrum.frequenciesHz[peakIndex],
            peakPower = peakPower,
            meanBandPower = meanBandPower,
            peakToMeanRatio = ratio,
        )
        if (ratio < MIN_PEAK_TO_MEAN_RATIO) {
            return rejected(MetricRejectionReason.WeakRespiratoryPeak, baseDiagnostics)
        }

        val peakFrequency = spectrum.frequenciesHz[peakIndex]
        // rFFT bin k represents exactly k cycles over N/fs. Using only the
        // timestamp span (N-1)/fs would make an exact three-cycle bin appear
        // infinitesimally below the hard physiological gate.
        val spectralDuration = signal.values.size / signal.sampleRateHz
        val cycles = spectralDuration * peakFrequency
        if (cycles < MIN_PHYSIOLOGICAL_CYCLES) {
            return rejected(
                MetricRejectionReason.InsufficientPhysiologicalCycles,
                baseDiagnostics.copy(physiologicalCycles = cycles),
            )
        }
        val rawValue = peakFrequency * SECONDS_PER_MINUTE
        if (!rawValue.isFinite()) {
            return rejected(MetricRejectionReason.NumericalFailure, baseDiagnostics)
        }

        val baselinePower = medianExcludingPeakNeighbors(bandIndices, peakIndex, spectrum.power)
        val prominence = ((peakPower - baselinePower) / max(peakPower, POWER_EPSILON))
            .coerceIn(0.0, 1.0)
        val concentrationRadius = max(spectrum.resolutionHz, CONCENTRATION_RADIUS_HZ)
        val bandPower = bandIndices.sumOf { spectrum.power[it] }
        val localPower = bandIndices
            .filter { abs(spectrum.frequenciesHz[it] - peakFrequency) <= concentrationRadius + FREQUENCY_EPSILON }
            .sumOf { spectrum.power[it] }
        val concentration = (localPower / max(bandPower, POWER_EPSILON)).coerceIn(0.0, 1.0)
        val historyQuality = history.historyQuality(segmentId, rawValue)
        val rawConfidence = (
            0.20 * ramp(prominence, 0.20, 0.80) +
                0.20 * ramp(ratio, 1.5, 4.0) +
                0.15 * ramp(concentration, 0.25, 0.65) +
                0.15 * ramp(cycles, 3.0, 6.0) +
                0.10 * ramp(duration, 12.0, 30.0) +
                0.10 * historyQuality +
                0.10 * (diagnostics.timeQuality ?: 0.0)
            ).coerceIn(0.0, 1.0)
        val estimate = MetricEstimate.available(
            type = TYPE,
            value = rawValue,
            confidence = rawConfidence,
            diagnostics = baseDiagnostics.copy(
                prominence = prominence,
                concentration = concentration,
                physiologicalCycles = cycles,
                historyQuality = historyQuality,
                rawConfidence = rawConfidence,
            ),
        )
        return history.stabilize(segmentId, estimate)
    }

    private fun medianExcludingPeakNeighbors(
        bandIndices: List<Int>,
        peakIndex: Int,
        power: DoubleArray,
    ): Double {
        val baseline = bandIndices
            .filter { abs(it - peakIndex) > 1 }
            .map { power[it] }
            .toDoubleArray()
        return if (baseline.isEmpty()) 0.0 else RppgSignalResampler.median(baseline)
    }

    private fun rejected(reason: MetricRejectionReason, diagnostics: MetricDiagnostics) =
        MetricEstimate.rejected(TYPE, reason, diagnostics)

    private companion object {
        val TYPE = RppgMetricType.RespirationRate
        const val MIN_DURATION_SECONDS = 12.0
        const val MIN_SAMPLE_RATE_HZ = 2.0
        const val MIN_UNIFORM_SAMPLES = 48
        const val MAX_LOW_PASS_HZ = 5.0
        const val LOW_PASS_NYQUIST_FRACTION = 0.45
        const val MIN_RESPIRATION_HZ = 0.15
        const val MAX_RESPIRATION_HZ = 0.40
        const val MIN_PEAK_TO_MEAN_RATIO = 1.5
        const val MIN_PHYSIOLOGICAL_CYCLES = 3.0
        const val CONCENTRATION_RADIUS_HZ = 0.03
        const val SECONDS_PER_MINUTE = 60.0
        const val POWER_EPSILON = 1e-12
        const val FREQUENCY_EPSILON = 1e-9
    }
}
