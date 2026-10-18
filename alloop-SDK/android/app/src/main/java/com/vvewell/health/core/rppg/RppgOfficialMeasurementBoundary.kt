package com.vvewell.health.core.rppg

/** Stateful data reset performed at the serialized pre-roll/official boundary. */
internal class RppgOfficialMeasurementBoundary(
    private val officialTimeline: RppgBvpTimeline,
    private val prerollTimeline: RppgBvpTimeline,
    private val readinessEvaluator: RppgPrerollReadinessEvaluator,
    private val signalProcessor: RppgSignalProcessor,
) {
    fun resetForOfficialMeasurement(engine: RppgInferenceEngine): Long {
        engine.reset()
        prerollTimeline.resetMeasurement()
        readinessEvaluator.reset()
        officialTimeline.resetMeasurement()
        signalProcessor.clearMetricHistory()
        signalProcessor.beginSegment(officialTimeline.currentSegmentId())
        return officialTimeline.currentSegmentId()
    }
}
