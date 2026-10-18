package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgHilbertTest {
    @Test
    fun hilbertInstantaneousFrequencyMatchesKnownSine() {
        val sampleRate = 30.0
        val frequency = 1.2
        val signal = DoubleArray(600) { index -> sin(2.0 * PI * frequency * index / sampleRate) }

        val instantaneous = requireNotNull(RppgHilbert.instantaneousFrequency(signal, sampleRate))
        val center = instantaneous.copyOfRange(30, instantaneous.size - 30)

        assertEquals(frequency, center.average(), 1e-3)
    }

    @Test
    fun phaseUnwrapContinuesAcrossPlusMinusPi() {
        val sourcePhase = doubleArrayOf(2.8, 3.1, 3.4, 3.7, 4.0)
        val analytic = RppgAnalyticSignal(
            real = DoubleArray(sourcePhase.size) { cos(sourcePhase[it]) },
            imaginary = DoubleArray(sourcePhase.size) { sin(sourcePhase[it]) },
        )

        val unwrapped = RppgHilbert.unwrappedPhase(analytic)

        assertNotNull(unwrapped)
        requireNotNull(unwrapped).forEachIndexed { index, value ->
            assertEquals(sourcePhase[index], value, 1e-9)
        }
    }

    @Test
    fun threePopulationSigmaRoundsFollowFrozenPseudocode() {
        val cleaned = RppgOutlierCleaner.populationSigma(
            doubleArrayOf(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 10.0, 100.0),
            rounds = 3,
        )

        assertEquals(8, cleaned.size)
        assertTrue(cleaned.all { it == 1.0 })
    }
}
