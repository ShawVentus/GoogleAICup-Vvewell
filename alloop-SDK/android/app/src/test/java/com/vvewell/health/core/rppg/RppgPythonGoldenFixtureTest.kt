package com.vvewell.health.core.rppg

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgPythonGoldenFixtureTest {
    @Test
    fun parserPreservesPythonIntermediateColumns() {
        val fixture = RppgPythonGoldenFixtureParser.parse(
            """
            # sample_rate_hz=30.0
            # expected_hr_bpm=72.0
            timestamp,bvp,resampled,filtered,imf_0,hilbert_real,hilbert_imag,phase,instantaneous_hz
            0.0,0.1,0.1,0.2,0.3,0.3,0.0,0.0,1.2
            0.033333,0.2,0.2,0.3,0.4,0.3,0.1,0.321,1.2
            """.trimIndent(),
        )

        assertEquals("72.0", fixture.metadata["expected_hr_bpm"])
        assertTrue(fixture.columns.contains("instantaneous_hz"))
        assertEquals(2, fixture.timedSamples().size)
    }
}
