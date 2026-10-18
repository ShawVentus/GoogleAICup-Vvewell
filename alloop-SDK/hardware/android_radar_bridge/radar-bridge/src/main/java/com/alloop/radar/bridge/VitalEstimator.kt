package com.alloop.radar.bridge

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Optional, non-medical frequency estimator for the 0xE0 I/Q stream.
 * It deliberately returns null until a stable window is available.
 */
class VitalEstimator(
    private val windowSeconds: Double = 20.0,
    private val minSamples: Int = 80,
    private val emitIntervalSeconds: Double = 1.0
) {
    private data class Sample(val time: Double, val phase: Double, val distance: Double)
    private val samples = ArrayDeque<Sample>()
    private var lastPhase: Double? = null
    private var lastEmit = Double.NEGATIVE_INFINITY

    fun reset() {
        samples.clear()
        lastPhase = null
        lastEmit = Double.NEGATIVE_INFINITY
    }

    @Synchronized
    fun add(sample: VitalSample): VitalMetrics? {
        val now = if (samples.isEmpty()) 0.0 else samples.last().time + sample.samplePeriodMs / 1000.0
        val wrapped = sample.phaseRadians
        val previous = lastPhase
        val unwrapped = if (previous == null) wrapped else {
            var delta = wrapped - previous
            while (delta > Math.PI) delta -= 2.0 * Math.PI
            while (delta < -Math.PI) delta += 2.0 * Math.PI
            previous + delta
        }
        lastPhase = unwrapped
        samples.addLast(Sample(now, unwrapped, sample.distanceMeters))
        while (samples.isNotEmpty() && now - samples.first().time > windowSeconds) samples.removeFirst()
        if (samples.size < minSamples || now - lastEmit < emitIntervalSeconds) return null
        lastEmit = now

        val values = samples.map { it.phase }
        val mean = values.average()
        val detrended = values.mapIndexed { index, value -> value - mean - (values.last() - values.first()) * index / (values.size - 1).coerceAtLeast(1) }
        val sampleRate = if (samples.size > 1) (samples.size - 1) / (samples.last().time - samples.first().time).coerceAtLeast(1e-6) else 0.0
        val breathing = peak(detrended, sampleRate, 0.10, 0.60)
        val heart = peak(detrended, sampleRate, 0.80, 2.00)
        return VitalMetrics(
            breathingBpm = breathing?.frequencyHz?.times(60.0),
            heartBpm = heart?.frequencyHz?.times(60.0),
            breathingConfidence = breathing?.confidence ?: 0.0,
            heartConfidence = heart?.confidence ?: 0.0,
            windowSeconds = samples.last().time - samples.first().time,
            distanceMeters = samples.map { it.distance }.average()
        )
    }

    private data class Peak(val frequencyHz: Double, val confidence: Double)

    private fun peak(values: List<Double>, sampleRate: Double, low: Double, high: Double): Peak? {
        if (sampleRate <= 0.0 || values.size < minSamples) return null
        var bestFrequency = 0.0
        var bestPower = 0.0
        var totalPower = 0.0
        var frequency = low
        while (frequency <= high + 1e-9) {
            var real = 0.0
            var imag = 0.0
            values.forEachIndexed { index, value ->
                val angle = 2.0 * Math.PI * frequency * index / sampleRate
                real += value * cos(angle)
                imag -= value * sin(angle)
            }
            val power = hypot(real, imag) * hypot(real, imag)
            totalPower += power
            if (power > bestPower) { bestPower = power; bestFrequency = frequency }
            frequency += 0.02
        }
        if (bestFrequency == 0.0) return null
        return Peak(bestFrequency, (bestPower / totalPower.coerceAtLeast(1e-9)).coerceIn(0.0, 1.0))
    }
}
