package com.vvewell.health.core.rppg

import java.nio.file.Files
import java.time.Clock
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.Collections
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgCsvSessionTest {
    @Test
    fun writesRequiredHeaderOrderedRowsAndConservativeQuality() {
        val directory = Files.createTempDirectory("rppg-csv-test").toFile()
        val events = Collections.synchronizedList(mutableListOf<RppgCsvEvent>())
        val session = RppgCsvSession(
            outputDirectory = directory,
            clock = fixedClock(),
            sessionId = "session01",
            eventListener = events::add,
        )
        val heartRate = available(RppgMetricType.HeartRate, 66.3, 0.757)
        val unavailableRespiration = rejected(RppgMetricType.RespirationRate)
        val respiration = available(RppgMetricType.RespirationRate, 22.5, 0.855)

        assertTrue(session.enqueueSnapshot(0L, 10, timestamp("2026-08-01T16:34:10.124+08:00"), heartRate, unavailableRespiration))
        assertTrue(session.enqueueSnapshot(0L, 12, timestamp("2026-08-01T16:34:12.017+08:00"), heartRate, respiration))
        assertFalse(session.enqueueSnapshot(0L, 12, timestamp("2026-08-01T16:34:12.017+08:00"), heartRate, respiration))
        assertTrue(session.enqueueSnapshot(0L, 14, timestamp("2026-08-01T16:34:14.000+08:00"), heartRate, respiration))
        assertTrue(session.enqueueSnapshot(1L, 10, timestamp("2026-08-01T16:34:14.000+08:00"), heartRate, respiration))
        session.close("completed")

        assertTrue(session.awaitClosedForTest())
        val file = requireNotNull(session.fileForTest())
        val lines = file.readLines(Charsets.UTF_8)
        assertEquals("时间戳,心率,心率置信度,呼吸率,呼吸率置信度,信号质量", lines[0])
        assertEquals(5, lines.size)
        assertEquals("2026-08-01T16:34:10.124+08:00,66.3,0.757,,0,0.757", lines[1])
        assertEquals("2026-08-01T16:34:12.017+08:00,66.3,0.757,22.5,0.855,0.757", lines[2])
        assertEquals("2026-08-01T16:34:14+08:00,66.3,0.757,22.5,0.855,0.757", lines[3])
        assertEquals("2026-08-01T16:34:14+08:00,66.3,0.757,22.5,0.855,0.757", lines[4])
        assertTrue(events.any { it is RppgCsvEvent.SessionStarted })
        assertEquals(4, events.count { it is RppgCsvEvent.RowWritten })
        assertTrue(events.any { it is RppgCsvEvent.SessionClosed && it.reason == "completed" })
    }

    @Test
    fun formatsNumbersWithUsDecimalSeparatorEvenWhenDeviceLocaleDiffers() {
        val previousLocale = Locale.getDefault()
        Locale.setDefault(Locale.GERMANY)
        try {
            val directory = Files.createTempDirectory("rppg-csv-locale").toFile()
            val session = RppgCsvSession(directory, fixedClock(), "locale01")
            session.enqueueSnapshot(
                0L,
                10,
                timestamp("2026-08-01T16:34:10+08:00"),
                available(RppgMetricType.HeartRate, 66.25, 0.75),
                rejected(RppgMetricType.RespirationRate),
            )
            session.close("completed")

            assertTrue(session.awaitClosedForTest())
            val line = requireNotNull(session.fileForTest()).readLines(Charsets.UTF_8)[1]
            assertTrue(line.contains(",66.25,0.75,,0,0.75"))
            assertFalse(line.contains("66,25"))
        } finally {
            Locale.setDefault(previousLocale)
        }
    }

    @Test
    fun writeFailureDoesNotThrowAndSessionCloses() {
        val outputPathThatIsAFile = Files.createTempFile("rppg-csv-not-directory", ".tmp").toFile()
        val events = Collections.synchronizedList(mutableListOf<RppgCsvEvent>())
        val session = RppgCsvSession(outputPathThatIsAFile, fixedClock(), "failure01", events::add)

        assertTrue(
            session.enqueueSnapshot(
                0L,
                10,
                timestamp("2026-08-01T16:34:10+08:00"),
                available(RppgMetricType.HeartRate, 66.0, 0.8),
                rejected(RppgMetricType.RespirationRate),
            ),
        )
        session.close("error")

        assertTrue(session.awaitClosedForTest())
        assertNotNull(events.filterIsInstance<RppgCsvEvent.WriteFailed>().singleOrNull())
        assertTrue(events.any { it is RppgCsvEvent.SessionClosed && it.reason == "error" })
    }

    @Test
    fun staleSnapshotIsNotQueuedForWriting() {
        val directory = Files.createTempDirectory("rppg-csv-stale").toFile()
        val session = RppgCsvSession(directory, fixedClock(), "stale001")

        assertFalse(
            session.enqueueSnapshot(
                segmentId = 5L,
                scheduledSecond = 10,
                producedAt = timestamp("2026-08-01T16:34:10+08:00"),
                heartRate = available(RppgMetricType.HeartRate, 66.0, 0.8),
                respiration = rejected(RppgMetricType.RespirationRate),
                isCurrent = { false },
            ),
        )
        session.close("cancelled")

        assertTrue(session.awaitClosedForTest())
        val lines = requireNotNull(session.fileForTest()).readLines(Charsets.UTF_8)
        assertEquals(1, lines.size)
    }

    @Test
    fun nonFiniteMetricIsExportedAsUnavailableWithoutNonFiniteCsvCells() {
        val directory = Files.createTempDirectory("rppg-csv-nonfinite").toFile()
        val session = RppgCsvSession(directory, fixedClock(), "finite001")
        val invalidHeartRate = MetricEstimate.available(
            type = RppgMetricType.HeartRate,
            value = 66.0,
            confidence = Double.NaN,
            diagnostics = MetricDiagnostics(),
        )

        assertTrue(
            session.enqueueSnapshot(
                0L,
                10,
                timestamp("2026-08-01T16:34:10+08:00"),
                invalidHeartRate,
                rejected(RppgMetricType.RespirationRate),
            ),
        )
        session.close("completed")

        assertTrue(session.awaitClosedForTest())
        val row = requireNotNull(session.fileForTest()).readLines(Charsets.UTF_8)[1]
        assertEquals("2026-08-01T16:34:10+08:00,,0,,0,0", row)
        assertFalse(row.contains("NaN"))
        assertFalse(row.contains("Infinity"))
    }

    @Test
    fun completedCancelledAndErrorSessionsAllClose() {
        listOf("completed", "cancelled", "error").forEachIndexed { index, reason ->
            val directory = Files.createTempDirectory("rppg-csv-close").toFile()
            val events = Collections.synchronizedList(mutableListOf<RppgCsvEvent>())
            val session = RppgCsvSession(directory, fixedClock(), "close00$index", events::add)
            session.close(reason)

            assertTrue(session.awaitClosedForTest())
            assertTrue(events.any { it is RppgCsvEvent.SessionClosed && it.reason == reason })
        }
    }

    private fun fixedClock(): Clock = Clock.fixed(
        Instant.parse("2026-08-01T08:34:00Z"),
        ZoneId.of("Asia/Shanghai"),
    )

    private fun timestamp(value: String): OffsetDateTime = OffsetDateTime.parse(value)

    private fun available(type: RppgMetricType, value: Double, confidence: Double): MetricEstimate =
        MetricEstimate.available(type, value, confidence = confidence, diagnostics = MetricDiagnostics())

    private fun rejected(type: RppgMetricType): MetricEstimate = MetricEstimate.rejected(
        type = type,
        reason = MetricRejectionReason.InsufficientDuration,
    )
}
