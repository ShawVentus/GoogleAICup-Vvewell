package com.vvewell.health.core.rppg

import java.util.concurrent.Executor
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal data class RppgAnalysisKey(
    val measurementToken: Long,
    val segmentId: Long,
    val scheduledSecond: Int,
)

/**
 * Single-thread analysis lane with a one-item latest-wins pending queue.
 * CameraX inference never waits for RR/HR post-processing.
 */
internal class RppgAnalysisExecutor(
    private val executor: Executor = Executors.newSingleThreadExecutor(),
    private val shutdownAction: () -> Unit = {},
) {

    private val lock = Any()
    private var activeMeasurementToken: Long? = null
    private var activeSegmentId: Long? = null
    private var running = false
    private var pending: Work? = null
    private var closed = false
    private val submittedKeys = mutableSetOf<RppgAnalysisKey>()

    fun activate(measurementToken: Long, segmentId: Long) {
        synchronized(lock) {
            if (closed) return
            activeMeasurementToken = measurementToken
            activeSegmentId = segmentId
            pending = null
            submittedKeys.clear()
        }
    }

    fun submit(key: RppgAnalysisKey, task: () -> Unit): Boolean {
        val work = Work(key, task)
        synchronized(lock) {
            if (closed || !isCurrentLocked(key) || !submittedKeys.add(key)) return false
            if (running) {
                pending = work
                return true
            }
            running = true
        }
        launch(work)
        return true
    }

    fun isCurrent(key: RppgAnalysisKey): Boolean = synchronized(lock) {
        !closed && isCurrentLocked(key)
    }

    fun invalidate() {
        synchronized(lock) {
            activeMeasurementToken = null
            activeSegmentId = null
            pending = null
            submittedKeys.clear()
        }
    }

    fun shutdown() {
        val executorService = executor as? ExecutorService
        synchronized(lock) {
            if (closed) return
            closed = true
            pending = null
            submittedKeys.clear()
        }
        executorService?.shutdown()
        shutdownAction()
    }

    private fun launch(work: Work) {
        executor.execute {
            try {
                if (isCurrent(work.key)) work.task()
            } finally {
                val next = synchronized(lock) {
                    val candidate = pending
                    pending = null
                    if (candidate == null || closed) running = false
                    candidate?.takeUnless { closed }
                }
                if (next != null) launch(next)
            }
        }
    }

    private fun isCurrentLocked(key: RppgAnalysisKey): Boolean =
        key.measurementToken == activeMeasurementToken && key.segmentId == activeSegmentId

    private data class Work(
        val key: RppgAnalysisKey,
        val task: () -> Unit,
    )
}
