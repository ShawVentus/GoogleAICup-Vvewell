package com.vvewell.health.core.rppg

import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgButterworthTest {
    @Test
    fun fourthOrderBandPassPreservesHeartBandAndSuppressesOutOfBandEnergy() {
        val sampleRate = 30.0
        val heart = DoubleArray(600) { index -> sin(2.0 * PI * 1.2 * index / sampleRate) }
        val low = DoubleArray(600) { index -> sin(2.0 * PI * 0.2 * index / sampleRate) }
        val high = DoubleArray(600) { index -> sin(2.0 * PI * 4.0 * index / sampleRate) }

        val filteredHeart = RppgButterworth.zeroPhaseBandPass(heart, sampleRate, 0.6, 2.5)
        val filteredLow = RppgButterworth.zeroPhaseBandPass(low, sampleRate, 0.6, 2.5)
        val filteredHigh = RppgButterworth.zeroPhaseBandPass(high, sampleRate, 0.6, 2.5)

        assertNotNull(filteredHeart)
        assertNotNull(filteredLow)
        assertNotNull(filteredHigh)
        val heartRms = rms(requireNotNull(filteredHeart).copyOfRange(60, 540))
        val lowRms = rms(requireNotNull(filteredLow).copyOfRange(60, 540))
        val highRms = rms(requireNotNull(filteredHigh).copyOfRange(60, 540))
        assertTrue("heart=$heartRms low=$lowRms", heartRms > lowRms * 5.0)
        assertTrue("heart=$heartRms high=$highRms", heartRms > highRms * 5.0)
    }

    private fun rms(values: DoubleArray): Double = sqrt(values.sumOf { it * it } / values.size)
}
