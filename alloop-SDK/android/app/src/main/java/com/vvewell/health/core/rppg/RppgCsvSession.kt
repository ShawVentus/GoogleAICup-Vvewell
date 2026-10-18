package com.vvewell.health.core.rppg

import java.io.BufferedWriter
import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.time.Clock
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

internal sealed interface RppgCsvEvent {
    data class SessionStarted(val path: String, val sessionId: String) : RppgCsvEvent
    data class RowWritten(val path: String, val sessionId: String, val rowCount: Int) : RppgCsvEvent
    data class SessionClosed(
        val path: String?,
        val sessionId: String,
        val rowCount: Int,
        val reason: String,
    ) : RppgCsvEvent

    data class WriteFailed(val sessionId: String, val operation: String, val error: Throwable) : RppgCsvEvent
}

/**
 * Ordered, measurement-scoped CSV writer. All file operations happen on its
 * own single-thread executor; callers only enqueue immutable analysis results.
 */
internal class RppgCsvSession(
    private val outputDirectory: File?,
    private val clock: Clock = Clock.systemDefaultZone(),
    private val sessionId: String = UUID.randomUUID().toString().take(8),
    private val eventListener: (RppgCsvEvent) -> Unit = {},
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor(),
) : AutoCloseable {
    private val lock = Any()
    private val startedAt = OffsetDateTime.now(clock)
    private val seenSnapshots = mutableSetOf<SnapshotKey>()
    private var acceptingRows = true
    private var closeRequested = false
    private var writer: BufferedWriter? = null
    private var outputFile: File? = null
    private var rowCount = 0

    init {
        ioExecutor.execute(::open)
    }

    fun enqueueSnapshot(
        segmentId: Long,
        scheduledSecond: Int,
        producedAt: OffsetDateTime,
        heartRate: MetricEstimate,
        respiration: MetricEstimate,
        isCurrent: () -> Boolean = { true },
    ): Boolean {
        val row = RppgCsvRow.from(producedAt, heartRate, respiration)
        synchronized(lock) {
            if (!acceptingRows || !isCurrent() || !seenSnapshots.add(SnapshotKey(segmentId, scheduledSecond))) {
                return false
            }
        }
        ioExecutor.execute { writeRow(row) }
        return true
    }

    fun close(reason: String) {
        val shouldQueueClose = synchronized(lock) {
            if (closeRequested) false else {
                closeRequested = true
                acceptingRows = false
                true
            }
        }
        if (!shouldQueueClose) return
        ioExecutor.execute { closeWriter(reason) }
        ioExecutor.shutdown()
    }

    override fun close() = close("closed")

    internal fun awaitClosedForTest(timeoutSeconds: Long = 5): Boolean =
        ioExecutor.awaitTermination(timeoutSeconds, TimeUnit.SECONDS)

    internal fun fileForTest(): File? = outputFile

    private fun open() {
        try {
            val directory = requireNotNull(outputDirectory) { "External rPPG export directory is unavailable" }
            if (!directory.exists() && !directory.mkdirs()) {
                throw IllegalStateException("Unable to create rPPG export directory: ${directory.absolutePath}")
            }
            if (!directory.isDirectory) throw IllegalStateException("rPPG export path is not a directory")
            val filename = "rppg_${FILE_TIME_FORMATTER.format(startedAt)}_$sessionId.csv"
            val file = File(directory, filename)
            val openedWriter = Files.newBufferedWriter(
                file.toPath(),
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE_NEW,
                StandardOpenOption.WRITE,
            )
            openedWriter.write(HEADER)
            openedWriter.newLine()
            openedWriter.flush()
            outputFile = file
            writer = openedWriter
            eventListener(RppgCsvEvent.SessionStarted(file.absolutePath, sessionId))
        } catch (error: Throwable) {
            eventListener(RppgCsvEvent.WriteFailed(sessionId, "open", error))
        }
    }

    private fun writeRow(row: RppgCsvRow) {
        val activeWriter = writer ?: return
        try {
            activeWriter.write(row.format())
            activeWriter.newLine()
            activeWriter.flush()
            rowCount += 1
            eventListener(
                RppgCsvEvent.RowWritten(
                    path = requireNotNull(outputFile).absolutePath,
                    sessionId = sessionId,
                    rowCount = rowCount,
                ),
            )
        } catch (error: Throwable) {
            eventListener(RppgCsvEvent.WriteFailed(sessionId, "write", error))
            runCatching { activeWriter.close() }
            writer = null
        }
    }

    private fun closeWriter(reason: String) {
        try {
            writer?.flush()
            writer?.close()
        } catch (error: Throwable) {
            eventListener(RppgCsvEvent.WriteFailed(sessionId, "close", error))
        } finally {
            writer = null
            eventListener(
                RppgCsvEvent.SessionClosed(
                    path = outputFile?.absolutePath,
                    sessionId = sessionId,
                    rowCount = rowCount,
                    reason = reason,
                ),
            )
        }
    }

    private data class SnapshotKey(val segmentId: Long, val scheduledSecond: Int)

    private data class RppgCsvRow(
        val timestamp: OffsetDateTime,
        val heartRate: Double?,
        val heartRateConfidence: Double,
        val respiration: Double?,
        val respirationConfidence: Double,
        val signalQuality: Double,
    ) {
        fun format(): String = listOf(
            ISO_TIMESTAMP_FORMATTER.format(timestamp),
            heartRate?.let(::formatNumber).orEmpty(),
            formatNumber(heartRateConfidence),
            respiration?.let(::formatNumber).orEmpty(),
            formatNumber(respirationConfidence),
            formatNumber(signalQuality),
        ).joinToString(",")

        companion object {
            fun from(
                timestamp: OffsetDateTime,
                heartRate: MetricEstimate,
                respiration: MetricEstimate,
            ): RppgCsvRow = RppgCsvRow(
                timestamp = timestamp,
                heartRate = heartRate.availableValueOrNull(),
                heartRateConfidence = heartRate.csvConfidence(),
                respiration = respiration.availableValueOrNull(),
                respirationConfidence = respiration.csvConfidence(),
                signalQuality = RppgConfidencePolicy.conservativeAggregateQuality(heartRate, respiration),
            )

            private fun MetricEstimate.availableValueOrNull(): Double? =
                value?.takeIf { available && it.isFinite() }

            private fun MetricEstimate.csvConfidence(): Double =
                confidence.takeIf { available && it.isFinite() }?.coerceIn(0.0, 1.0) ?: 0.0

            private fun formatNumber(value: Double): String {
                val fixed = String.format(Locale.US, "%.6f", value)
                return fixed.trimEnd('0').trimEnd('.').ifEmpty { "0" }
            }
        }
    }

    private companion object {
        const val HEADER = "时间戳,心率,心率置信度,呼吸率,呼吸率置信度,信号质量"
        val FILE_TIME_FORMATTER: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss", Locale.US)
        val ISO_TIMESTAMP_FORMATTER: DateTimeFormatter = DateTimeFormatter.ISO_OFFSET_DATE_TIME
    }
}
