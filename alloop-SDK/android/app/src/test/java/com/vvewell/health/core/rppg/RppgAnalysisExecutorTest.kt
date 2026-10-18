package com.vvewell.health.core.rppg

import java.util.ArrayDeque
import java.util.concurrent.Executor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgAnalysisExecutorTest {
    @Test
    fun duplicateScheduledSecondRunsOnlyOnce() {
        val manual = ManualExecutor()
        val executor = RppgAnalysisExecutor(manual)
        val key = RppgAnalysisKey(1L, 2L, 10)
        var runs = 0
        executor.activate(1L, 2L)

        assertTrue(executor.submit(key) { runs += 1 })
        assertFalse(executor.submit(key) { runs += 1 })
        manual.runAll()

        assertEquals(1, runs)
    }

    @Test
    fun oldSegmentWorkIsDiscardedBeforeExecution() {
        val manual = ManualExecutor()
        val executor = RppgAnalysisExecutor(manual)
        var runs = 0
        executor.activate(1L, 1L)
        executor.submit(RppgAnalysisKey(1L, 1L, 10)) { runs += 1 }

        executor.activate(1L, 2L)
        manual.runAll()

        assertEquals(0, runs)
    }

    @Test
    fun staleGenerationWorkIsDiscardedBeforeExecution() {
        val manual = ManualExecutor()
        val executor = RppgAnalysisExecutor(manual)
        var runs = 0
        executor.activate(1L, 1L)
        executor.submit(RppgAnalysisKey(1L, 1L, 10)) { runs += 1 }

        executor.activate(2L, 0L)
        manual.runAll()

        assertEquals(0, runs)
    }

    @Test
    fun pendingQueueKeepsOnlyLatestAnalysis() {
        val manual = ManualExecutor()
        val executor = RppgAnalysisExecutor(manual)
        val completed = mutableListOf<Int>()
        executor.activate(3L, 4L)

        executor.submit(RppgAnalysisKey(3L, 4L, 10)) { completed += 10 }
        executor.submit(RppgAnalysisKey(3L, 4L, 12)) { completed += 12 }
        executor.submit(RppgAnalysisKey(3L, 4L, 14)) { completed += 14 }
        manual.runAll()

        assertEquals(listOf(10, 14), completed)
    }

    private class ManualExecutor : Executor {
        private val tasks = ArrayDeque<Runnable>()

        override fun execute(command: Runnable) {
            tasks.addLast(command)
        }

        fun runAll() {
            while (tasks.isNotEmpty()) tasks.removeFirst().run()
        }
    }
}
