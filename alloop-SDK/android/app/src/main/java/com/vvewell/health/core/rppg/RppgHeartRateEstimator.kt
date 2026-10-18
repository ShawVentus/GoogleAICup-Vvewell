package com.vvewell.health.core.rppg

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.sqrt

internal class RppgHeartRateEstimator(
    private val emd: RppgEmd = RppgEmd(),
    private val history: RppgMetricHistory = RppgMetricHistory(
        stableRelativeChange = 0.05,
        unstableRelativeChange = 0.20,
    ),
) {
    fun beginSegment(segmentId: Long) = history.beginSegment(segmentId)

    fun clearHistory() = history.clear()

    fun estimate(samples: List<TimedRppgSample>, segmentId: Long): MetricEstimate {
        val startedAt = System.nanoTime()
        val prepared = RppgSignalResampler.resample(samples)
        val estimate = if (prepared is RppgResampleOutcome.Rejected) {
            MetricEstimate.rejected(TYPE, prepared.reason, prepared.diagnostics)
        } else {
            estimateUniform((prepared as RppgResampleOutcome.Success).signal, segmentId)
        }
        val elapsedMillis = (System.nanoTime() - startedAt) / NANOS_PER_MILLISECOND
        return estimate.copy(
            diagnostics = estimate.diagnostics.copy(analysisDurationMillis = elapsedMillis),
        )
    }

    private fun estimateUniform(signal: UniformRppgSignal, segmentId: Long): MetricEstimate {
        val commonDiagnostics = signal.diagnostics.copy(
            filterLowHz = BAND_PASS_LOW_HZ,
            filterHighHz = BAND_PASS_HIGH_HZ,
            physiologicalLowHz = PHYSIOLOGICAL_LOW_HZ,
            physiologicalHighHz = PHYSIOLOGICAL_HIGH_HZ,
        )
        val duration = commonDiagnostics.durationSeconds ?: 0.0
        if (duration < MIN_DURATION_SECONDS) {
            return rejected(MetricRejectionReason.InsufficientDuration, commonDiagnostics)
        }
        if (signal.sampleRateHz < MIN_SAMPLE_RATE_HZ) {
            return rejected(MetricRejectionReason.SampleRateTooLow, commonDiagnostics)
        }
        if (signal.values.size < MIN_UNIFORM_SAMPLES) {
            return rejected(MetricRejectionReason.InsufficientSamples, commonDiagnostics)
        }

        val normalized = RppgDsp.zScore(RppgDsp.linearDetrend(signal.values))
            ?: return rejected(MetricRejectionReason.LowSignalEnergy, commonDiagnostics)
        val filtered = RppgButterworth.zeroPhaseBandPass(
            input = normalized,
            sampleRateHz = signal.sampleRateHz,
            lowHz = BAND_PASS_LOW_HZ,
            highHz = BAND_PASS_HIGH_HZ,
        ) ?: return rejected(MetricRejectionReason.FilterFailure, commonDiagnostics)

        val decomposition = emd.decompose(filtered)
        if (decomposition is RppgEmdOutcome.Failure) {
            val reason = if (decomposition.reason == RppgEmdFailure.DidNotConverge) {
                MetricRejectionReason.EmdDidNotConverge
            } else {
                MetricRejectionReason.EmdFailure
            }
            return rejected(
                reason,
                commonDiagnostics.copy(
                    imfCount = decomposition.completedImfs,
                    emdSiftIterations = decomposition.siftIterations.sum(),
                ),
            )
        }
        val emdResult = decomposition as RppgEmdOutcome.Success
        if (emdResult.imfs.isEmpty()) {
            return rejected(MetricRejectionReason.EmdFailure, commonDiagnostics)
        }
        val energies = DoubleArray(emdResult.imfs.size) { index ->
            emdResult.imfs[index].sumOf { value -> value * value } / emdResult.imfs[index].size
        }
        val totalEnergy = energies.sum()
        if (!totalEnergy.isFinite() || totalEnergy <= ENERGY_EPSILON) {
            return rejected(MetricRejectionReason.EmdFailure, commonDiagnostics)
        }

        var selectedIndex: Int? = null
        var validFrequencies = DoubleArray(0)
        for (index in energies.indices.sortedByDescending { energies[it] }) {
            val instantaneous = RppgHilbert.instantaneousFrequency(
                emdResult.imfs[index],
                signal.sampleRateHz,
            ) ?: continue
            val physiological = instantaneous.filter { frequency ->
                frequency.isFinite() &&
                    frequency >= PHYSIOLOGICAL_LOW_HZ && frequency <= PHYSIOLOGICAL_HIGH_HZ
            }.toDoubleArray()
            if (physiological.isNotEmpty()) {
                selectedIndex = index
                validFrequencies = physiological
                break
            }
        }
        val selected = selectedIndex ?: return rejected(
            MetricRejectionReason.NoPhysiologicalImf,
            commonDiagnostics.copy(
                imfCount = emdResult.imfs.size,
                totalImfEnergy = totalEnergy,
                emdSiftIterations = emdResult.siftIterations.sum(),
            ),
        )

        val cleaned = RppgOutlierCleaner.populationSigma(validFrequencies, rounds = OUTLIER_ROUNDS)
        val minimumCleaned = max(
            MIN_CLEANED_FREQUENCIES,
            ceil(MIN_CLEANED_FRACTION * (signal.values.size - 1)).toInt(),
        )
        val selectedDiagnostics = commonDiagnostics.copy(
            imfCount = emdResult.imfs.size,
            selectedImfIndex = selected,
            selectedImfEnergy = energies[selected],
            totalImfEnergy = totalEnergy,
            validInstantaneousFrequencyCount = validFrequencies.size,
            cleanedInstantaneousFrequencyCount = cleaned.size,
            minimumCleanedFrequencyCount = minimumCleaned,
            emdSiftIterations = emdResult.siftIterations.sum(),
        )
        if (cleaned.size < minimumCleaned) {
            return rejected(
                MetricRejectionReason.InsufficientInstantaneousFrequency,
                selectedDiagnostics,
            )
        }
        val meanFrequency = cleaned.average()
        if (!meanFrequency.isFinite()) {
            return rejected(MetricRejectionReason.NumericalFailure, selectedDiagnostics)
        }
        val physiologicalCycles = duration * meanFrequency
        if (physiologicalCycles < MIN_HEART_CYCLES) {
            return rejected(
                MetricRejectionReason.InsufficientPhysiologicalCycles,
                selectedDiagnostics.copy(physiologicalCycles = physiologicalCycles),
            )
        }
        val rawHeartRate = meanFrequency * SECONDS_PER_MINUTE
        if (!rawHeartRate.isFinite()) {
            return rejected(MetricRejectionReason.NumericalFailure, selectedDiagnostics)
        }

        val autocorrelation = autocorrelationSqi(filtered, signal.sampleRateHz)
        val validRatio = validFrequencies.size.toDouble() / (signal.values.size - 1)
        val energyConcentration = energies[selected] / totalEnergy
        val cleanRetention = cleaned.size.toDouble() / validFrequencies.size
        val cleanAmount = ramp(
            cleaned.size.toDouble(),
            minimumCleaned.toDouble(),
            0.5 * (signal.values.size - 1),
        )
        val cleanQuality = sqrt(
            ramp(cleanRetention, 0.60, 0.95) * cleanAmount,
        )
        val historyQuality = history.historyQuality(segmentId, rawHeartRate)
        val rawConfidence = (
            0.25 * autocorrelation.quality +
                0.15 * ramp(validRatio, 0.15, 0.60) +
                0.10 * ramp(energyConcentration, 0.15, 0.60) +
                0.10 * cleanQuality +
                0.15 * ramp(physiologicalCycles, 6.0, 12.0) +
                0.10 * historyQuality +
                0.15 * (commonDiagnostics.timeQuality ?: 0.0)
            ).coerceIn(0.0, 1.0)
        val estimate = MetricEstimate.available(
            type = TYPE,
            value = rawHeartRate,
            confidence = rawConfidence,
            diagnostics = selectedDiagnostics.copy(
                physiologicalCycles = physiologicalCycles,
                historyQuality = historyQuality,
                rawConfidence = rawConfidence,
                signalQuality = autocorrelation.quality,
                autocorrelationPeakLag = autocorrelation.peakLag,
                autocorrelationPeakBpm = autocorrelation.peakBpm,
            ),
        )
        return history.stabilize(segmentId, estimate)
    }

    internal fun autocorrelationSqi(signal: DoubleArray, sampleRateHz: Double): AutocorrelationResult {
        if (signal.size < 2 || sampleRateHz <= 0.0 || signal.any { !it.isFinite() }) {
            return AutocorrelationResult(0.0, null, null)
        }
        val zeroLagEnergy = signal.sumOf { it * it }
        if (zeroLagEnergy <= ENERGY_EPSILON) return AutocorrelationResult(0.0, null, null)
        val minimumLag = max(1, (sampleRateHz / PHYSIOLOGICAL_HIGH_HZ).toInt())
        val maximumLag = (sampleRateHz / PHYSIOLOGICAL_LOW_HZ).toInt()
            .coerceAtMost(signal.lastIndex)
        if (maximumLag < minimumLag) return AutocorrelationResult(0.0, null, null)
        var bestQuality = 0.0
        var bestLag: Int? = null
        for (lag in minimumLag..maximumLag) {
            var correlation = 0.0
            for (index in lag until signal.size) correlation += signal[index] * signal[index - lag]
            val normalized = (correlation / zeroLagEnergy).coerceIn(0.0, 1.0)
            if (normalized > bestQuality) {
                bestQuality = normalized
                bestLag = lag
            }
        }
        return AutocorrelationResult(
            quality = bestQuality,
            peakLag = bestLag,
            peakBpm = bestLag?.let { SECONDS_PER_MINUTE * sampleRateHz / it },
        )
    }

    private fun rejected(reason: MetricRejectionReason, diagnostics: MetricDiagnostics) =
        MetricEstimate.rejected(TYPE, reason, diagnostics)

    internal data class AutocorrelationResult(
        val quality: Double,
        val peakLag: Int?,
        val peakBpm: Double?,
    )

    private companion object {
        val TYPE = RppgMetricType.HeartRate
        const val MIN_DURATION_SECONDS = 10.0
        const val MIN_SAMPLE_RATE_HZ = 6.0
        const val MIN_UNIFORM_SAMPLES = 64
        const val BAND_PASS_LOW_HZ = 0.6
        const val BAND_PASS_HIGH_HZ = 2.5
        const val PHYSIOLOGICAL_LOW_HZ = 2.0 / 3.0
        const val PHYSIOLOGICAL_HIGH_HZ = 3.0
        const val MIN_CLEANED_FREQUENCIES = 8
        const val MIN_CLEANED_FRACTION = 0.05
        const val MIN_HEART_CYCLES = 6.0
        const val OUTLIER_ROUNDS = 3
        const val SECONDS_PER_MINUTE = 60.0
        const val ENERGY_EPSILON = 1e-12
        const val NANOS_PER_MILLISECOND = 1_000_000.0
    }
}
