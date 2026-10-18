package com.vvewell.health.core.rppg

import android.content.Context
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.time.OffsetDateTime
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

data class RppgEstimateSnapshot(
    val scheduledSecond: Int,
    val producedAtEpochMillis: Long,
    val heartRate: MetricEstimate,
    val respiration: MetricEstimate,
    val aggregateQuality: Double,
)

class RppgCameraController(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val previewView: PreviewView,
    private val onState: (RppgMeasurementState) -> Unit,
    private val onEstimate: (RppgEstimateSnapshot) -> Unit = {},
) : AutoCloseable {
    private val analyzerExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainExecutor = ContextCompat.getMainExecutor(context)
    private val lifecycleLock = Any()
    private val running = AtomicBoolean(false)
    private val closed = AtomicBoolean(false)
    private val generation = AtomicLong(0L)
    private val failureReported = AtomicBoolean(false)
    private val performanceSummaryLogged = AtomicBoolean(false)
    private val preparationSlowReported = AtomicBoolean(false)
    private val officialMeasurementSequence = AtomicLong(0L)
    private val signalProcessor = RppgSignalProcessor()
    private val metricAnalysisExecutor = RppgAnalysisExecutor()
    private val session = RppgMeasurementSession()
    private val bvpTimeline = RppgBvpTimeline()
    private val prerollTimeline = RppgBvpTimeline()
    private val readinessEvaluator = RppgPrerollReadinessEvaluator()
    private val officialMeasurementBoundary = RppgOfficialMeasurementBoundary(
        officialTimeline = bvpTimeline,
        prerollTimeline = prerollTimeline,
        readinessEvaluator = readinessEvaluator,
        signalProcessor = signalProcessor,
    )
    private val faceRoiTracker = RppgFaceRoiTracker()
    private val faceLossTracker = RppgFaceLossTracker()
    private val faceDetector: FaceDetector = FaceDetection.getClient(
        FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setMinFaceSize(RppgFaceRoiConfig.MIN_DETECTOR_FACE_SIZE)
            .enableTracking()
            .build(),
    )

    private var inferenceEngine: RppgInferenceEngine? = null
    private var provider: ProcessCameraProvider? = null
    @Volatile
    private var csvSession: RppgCsvSession? = null

    @Volatile
    private var startedAtNanos = 0L
    @Volatile
    private var preparationStartedAtNanos = 0L
    @Volatile
    private var effectiveElapsedMillis = 0L
    @Volatile
    private var officialMeasurementActive = false
    private var officialMeasurementId: String? = null
    private var lastPerformanceLogAtNanos = 0L
    private var receivedFrameCount = 0L
    private var analyzedFrameCount = 0L
    private var totalPreprocessNanos = 0L
    private var totalInferenceNanos = 0L
    private var totalFrameNanos = 0L
    private var slowestFrameNanos = 0L
    private var faceDetectedFrameCount = 0L
    private var skippedNoFaceFrameCount = 0L
    private var faceDetectionFailureCount = 0L
    private var totalFaceDetectionNanos = 0L
    private var lastFaceDiagnosticLogAtNanos = 0L
    private var lastFaceDetectionErrorLogAtNanos = 0L
    private var lastTimestampFallbackLogAtNanos = 0L
    private var lastCameraGapLogAtNanos = 0L
    private var lastDtClampLogAtNanos = 0L
    private var timestampRejectedFrameCount = 0L
    private var timestampFallbackFrameCount = 0L
    private var cameraGapFrameCount = 0L
    private var cameraStallResetCount = 0L
    private var modelDtClampCount = 0L
    private var continuousSegmentResetCount = 0L
    private var lastActualDtSeconds: Double? = null
    private var lastModelDtSeconds = RppgTimingConfig.MIN_MODEL_DT_SECONDS

    /** Starts preview and real-frame pre-roll without starting a measurement or CSV. */
    fun preparePreview() {
        val (token, previewState) = synchronized(lifecycleLock) {
            if (closed.get() || !running.compareAndSet(false, true)) return
            val nextToken = generation.incrementAndGet()
            failureReported.set(false)
            performanceSummaryLogged.set(false)
            preparationSlowReported.set(false)
            startedAtNanos = 0L
            preparationStartedAtNanos = SystemClock.elapsedRealtimeNanos()
            effectiveElapsedMillis = 0L
            officialMeasurementActive = false
            officialMeasurementId = null
            closeCsvSession("preview_started")
            nextToken to session.beginPreview()
        }
        postState(token, previewState)

        // Preview binding must not wait for the comparatively expensive ONNX
        // session creation. Analysis work is serialized behind initialization.
        mainExecutor.execute {
            if (isActive(token)) bindCamera(token)
        }

        analyzerExecutor.execute {
            if (!isActive(token)) return@execute
            try {
                resetPerformanceMetrics(preparationStartedAtNanos)
                prerollTimeline.resetMeasurement()
                readinessEvaluator.reset()
                bvpTimeline.resetMeasurement()
                metricAnalysisExecutor.invalidate()
                signalProcessor.clearMetricHistory()
                faceRoiTracker.reset()
                faceLossTracker.reset()
                val initializationStartedAt = System.nanoTime()
                val existingEngine = inferenceEngine
                val engine = existingEngine ?: MeRppgOnnxEngine(context).also { inferenceEngine = it }
                engine.reset()
                Log.i(
                    PERFORMANCE_TAG,
                    "engine_initialized reused=${existingEngine != null} " +
                        "durationMs=${nanosToMillis(System.nanoTime() - initializationStartedAt)}",
                )
            } catch (error: Throwable) {
                fail(error, token)
            }
        }
    }

    /** Retains one user start request while readiness is still pending. */
    fun requestMeasurement() {
        if (closed.get()) return
        if (!running.get()) preparePreview()
        val token = generation.get()
        if (!isActive(token)) return
        val transition = session.requestStart()
        Log.i(PERFORMANCE_TAG, "start_requested token=$token phase=${transition.state.phase}")
        if (transition.beginOfficialMeasurement) {
            analyzerExecutor.execute {
                if (isActive(token)) beginOfficialMeasurement(token, readinessEvaluator.snapshot())
            }
        } else {
            postState(token, transition.state)
            if (transition.state.phase == RppgPhase.StartPending) {
                Log.i(PERFORMANCE_TAG, "start_pending token=$token")
            }
        }
    }

    /** Compatibility alias for existing callers. */
    fun start() = requestMeasurement()

    /** Called by the Compose ticker; it only renders the latest effective BVP span. */
    fun tick(@Suppress("UNUSED_PARAMETER") nowNanos: Long = SystemClock.elapsedRealtimeNanos()) {
        if (!running.get()) return
        if (session.state.measuring) {
            onState(session.updateEffectiveElapsed(effectiveElapsedMillis))
        } else if (
            preparationStartedAtNanos > 0L &&
            nowNanos - preparationStartedAtNanos >=
            (RppgPrerollReadinessConfig.SLOW_PREPARATION_SECONDS * NANOS_PER_SECOND).toLong() &&
            preparationSlowReported.compareAndSet(false, true)
        ) {
            onState(session.markPreparationSlow())
        }
    }

    fun permissionDenied() {
        synchronized(lifecycleLock) {
            running.set(false)
            generation.incrementAndGet()
            metricAnalysisExecutor.invalidate()
            signalProcessor.clearMetricHistory()
            closeCsvSession("permission_denied")
        }
        mainExecutor.execute {
            try {
                provider?.unbindAll()
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to unbind CameraX after camera permission denial", error)
            }
            onState(session.permissionDenied())
        }
    }

    fun cancel() {
        val wasRunning = synchronized(lifecycleLock) {
            val active = running.getAndSet(false)
            generation.incrementAndGet()
            metricAnalysisExecutor.invalidate()
            signalProcessor.clearMetricHistory()
            closeCsvSession("cancelled")
            active
        }
        if (wasRunning && startedAtNanos != 0L) logPerformanceSummary("cancelled")
        mainExecutor.execute {
            try {
                provider?.unbindAll()
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to unbind CameraX while cancelling rPPG measurement", error)
            }
            onState(session.cancel())
        }
    }

    private fun bindCamera(token: Long) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener(
            {
                if (!isActive(token)) return@addListener
                runCatching {
                    provider = future.get()
                    val preview = Preview.Builder().build().also {
                        it.surfaceProvider = previewView.surfaceProvider
                    }
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                        .also { useCase ->
                            useCase.setAnalyzer(analyzerExecutor) { image -> analyzeFrame(image, token) }
                        }
                    // CameraX lifecycle operations must remain on the main thread.
                    provider?.unbindAll()
                    provider?.bindToLifecycle(
                        lifecycleOwner,
                        CameraSelector.DEFAULT_FRONT_CAMERA,
                        preview,
                        analysis,
                    )
                    Log.i(PERFORMANCE_TAG, "preview_camera_bound token=$token lens=front")
                }.onFailure { fail(it, token) }
            },
            mainExecutor,
        )
    }

    @ExperimentalGetImage
    private fun analyzeFrame(image: ImageProxy, token: Long) {
        receivedFrameCount += 1
        val frameStartedAtNanos = System.nanoTime()
        try {
            if (!isActive(token)) return
            val arrivalTimestampNanos = SystemClock.elapsedRealtimeNanos()
            val engine = checkNotNull(inferenceEngine) { "rPPG engine was not initialized" }

            val detectionStartedAtNanos = System.nanoTime()
            val detectedFaces = detectFaces(image, arrivalTimestampNanos)
            if (!isActive(token)) return
            val detectionNanos = System.nanoTime() - detectionStartedAtNanos
            val (uprightWidth, uprightHeight) = image.uprightDimensions()
            var faceBounds = detectedFaces?.let { faces ->
                faceRoiTracker.selectAndSmooth(
                    candidates = faces,
                    imageWidth = uprightWidth,
                    imageHeight = uprightHeight,
                )
            }
            if (faceBounds == null) {
                skippedNoFaceFrameCount += 1
                if (!officialMeasurementActive) markPrerollUnready(token)
                if (faceLossTracker.onMissingFace(arrivalTimestampNanos)) {
                    faceRoiTracker.reset()
                    if (officialMeasurementActive) {
                        resetContinuousSegment(engine, token, "face_lost")
                    } else {
                        resetPrerollSegment(engine, token, "face_lost")
                    }
                    Log.i(
                        FACE_TAG,
                        "face_lost stateReset=true missingSeconds=" +
                            "${RppgTimingConfig.FACE_LOSS_RESET_SECONDS} " +
                            "sourceDtSeconds=null arrivalDtSeconds=null resolvedDtSeconds=null " +
                            "modelDtSeconds=null segmentId=${activeTimeline().currentSegmentId()} " +
                            "resetReason=FaceLoss",
                    )
                }
                recordFaceDiagnostics(
                    nowNanos = arrivalTimestampNanos,
                    detectionNanos = detectionNanos,
                    faceBounds = null,
                )
                return
            }
            if (faceLossTracker.onReliableFace(arrivalTimestampNanos)) {
                faceRoiTracker.reset()
                if (officialMeasurementActive) {
                    resetContinuousSegment(engine, token, "face_recovered_after_loss")
                } else {
                    resetPrerollSegment(engine, token, "face_recovered_after_loss")
                }
                faceBounds = checkNotNull(detectedFaces).let { faces ->
                    faceRoiTracker.selectAndSmooth(
                        candidates = faces,
                        imageWidth = uprightWidth,
                        imageHeight = uprightHeight,
                    )
                }
                Log.i(
                    FACE_TAG,
                    "face_lost stateReset=true detectedOnRecovery=true missingSeconds=" +
                        "${RppgTimingConfig.FACE_LOSS_RESET_SECONDS} " +
                        "sourceDtSeconds=null arrivalDtSeconds=null resolvedDtSeconds=null " +
                        "modelDtSeconds=null segmentId=${activeTimeline().currentSegmentId()} " +
                        "resetReason=FaceLoss",
                )
            }
            val activeFaceBounds = checkNotNull(faceBounds) {
                "Reliable face disappeared while resetting rPPG tracking"
            }
            faceDetectedFrameCount += 1

            val timeline = activeTimeline()
            val frameTiming = when (
                val decision = timeline.prepareFrame(
                    sourceTimestampNanos = image.imageInfo.timestamp,
                    arrivalTimestampNanos = arrivalTimestampNanos,
                )
            ) {
                is RppgFrameTimingDecision.Accepted -> decision.timing
                is RppgFrameTimingDecision.Rejected -> {
                    timestampRejectedFrameCount += 1
                    if (!officialMeasurementActive) {
                        readinessEvaluator.recordInvalidInference()
                        postState(token, session.onPrerollUnready())
                    }
                    logTimestampRejection(arrivalTimestampNanos, decision)
                    recordFaceDiagnostics(
                        nowNanos = arrivalTimestampNanos,
                        detectionNanos = detectionNanos,
                        faceBounds = activeFaceBounds,
                    )
                    return
                }
            }
            if (frameTiming.segmentResetRequired) {
                engine.reset()
                cameraStallResetCount += 1
                continuousSegmentResetCount += 1
                if (officialMeasurementActive) {
                    signalProcessor.beginSegment(frameTiming.segmentId)
                    metricAnalysisExecutor.activate(token, frameTiming.segmentId)
                    effectiveElapsedMillis = 0L
                    postContinuousSegmentRestart(token)
                } else {
                    readinessEvaluator.recordStallReset()
                    markPrerollUnready(token)
                }
                Log.w(
                    TIMING_TAG,
                    "camera_stall_reset sourceDtSeconds=${frameTiming.sourceDtSeconds} " +
                        "arrivalDtSeconds=${frameTiming.arrivalDtSeconds} resolvedDtSeconds=null " +
                        "modelDtSeconds=${frameTiming.modelDtSeconds} " +
                        "segmentId=${frameTiming.segmentId} resetReason=${frameTiming.resetReason}",
                )
            }
            analyzedFrameCount += 1

            val preprocessStartedAtNanos = System.nanoTime()
            val uprightFrame = image.toUprightArgbFrame()
            val rgb = RppgImagePreprocessor.toModelInput(uprightFrame, activeFaceBounds)
            val preprocessNanos = System.nanoTime() - preprocessStartedAtNanos
            val inferenceStartedAtNanos = System.nanoTime()
            val sample = engine.processFrame(rgb, frameTiming.modelDtSeconds)
            val inferenceNanos = System.nanoTime() - inferenceStartedAtNanos
            if (!isActive(token)) return
            if (!officialMeasurementActive) {
                prerollTimeline.append(frameTiming, sample.toDouble())
                val wasReady = readinessEvaluator.snapshot().ready
                val readiness = readinessEvaluator.recordValidInference(
                    timestampSeconds = frameTiming.timestampSeconds,
                    timestampFallback = frameTiming.fallbackReason != null,
                    stallReset = frameTiming.segmentResetRequired,
                    facePresent = true,
                    roiValid = true,
                )
                Log.d(
                    PERFORMANCE_TAG,
                    "preroll_frame token=$token count=${readiness.frameCount} " +
                        "durationSeconds=${readiness.durationSeconds} " +
                        "sampleRateHz=${readiness.sampleRateHz} " +
                        "maxGapSeconds=${readiness.maximumGapSeconds} " +
                        "actualDtSeconds=${frameTiming.actualDtSeconds} " +
                        "timestampFallback=${readiness.hadTimestampFallback}",
                )
                recordFaceDiagnostics(
                    nowNanos = arrivalTimestampNanos,
                    detectionNanos = detectionNanos,
                    faceBounds = activeFaceBounds,
                )
                if (readiness.ready && !wasReady) {
                    Log.i(
                        PERFORMANCE_TAG,
                        "preroll_ready token=$token frames=${readiness.frameCount} " +
                            "durationSeconds=${readiness.durationSeconds} " +
                            "sampleRateHz=${readiness.sampleRateHz} " +
                            "maxGapSeconds=${readiness.maximumGapSeconds}",
                    )
                    val transition = session.onPrerollReady()
                    if (transition.beginOfficialMeasurement) {
                        beginOfficialMeasurement(token, readiness)
                    } else {
                        postState(token, transition.state)
                    }
                } else if (!readiness.ready && wasReady) {
                    postState(token, session.onPrerollUnready())
                }
                return
            }
            val appendResult = bvpTimeline.append(frameTiming, sample.toDouble())
            effectiveElapsedMillis = appendResult.elapsedMillis
            recordFrameTiming(frameTiming, arrivalTimestampNanos)
            if (appendResult.sampleCount == 1) {
                Log.i(
                    PERFORMANCE_TAG,
                    "first_official_sample measurementId=$officialMeasurementId " +
                        "timestampSeconds=${frameTiming.timestampSeconds} " +
                        "segmentId=${frameTiming.segmentId}",
                )
                mainExecutor.execute {
                    if (token == generation.get()) onState(session.onFirstSample())
                }
            }

            recordPerformance(
                preprocessNanos = preprocessNanos,
                inferenceNanos = inferenceNanos,
                frameNanos = System.nanoTime() - frameStartedAtNanos,
            )
            recordFaceDiagnostics(
                nowNanos = arrivalTimestampNanos,
                detectionNanos = detectionNanos,
                faceBounds = activeFaceBounds,
            )
            if (appendResult.analysisSecondsDue.isNotEmpty()) {
                val snapshot = bvpTimeline.snapshot()
                appendResult.analysisSecondsDue.forEach { scheduledSecond ->
                    val final = scheduledSecond == RppgTimingConfig.DEFAULT_DURATION_SECONDS &&
                        appendResult.complete
                    if (!final || running.compareAndSet(true, false)) {
                        requestAnalysis(
                            token = token,
                            segmentId = appendResult.segmentId,
                            scheduledSecond = scheduledSecond,
                            snapshot = snapshot,
                            final = final,
                        )
                    }
                }
            }
        } catch (error: Throwable) {
            fail(error, token)
        } finally {
            image.close()
        }
    }

    /**
     * The only transition into the official timeline. It runs on the analyzer
     * executor, after the triggering pre-roll inference has fully completed.
     */
    private fun beginOfficialMeasurement(
        token: Long,
        readiness: RppgPrerollReadiness,
    ) {
        synchronized(lifecycleLock) {
            if (!isActive(token) || officialMeasurementActive) return
            if (!readiness.ready) {
                postState(token, session.deferOfficialStartUntilReady())
                Log.i(PERFORMANCE_TAG, "start_pending token=$token reason=readiness_revoked")
                return
            }
            val engine = checkNotNull(inferenceEngine) { "rPPG engine was not initialized" }
            val measurementId = "$token-${officialMeasurementSequence.incrementAndGet()}"
            val prerollTotalFrames = analyzedFrameCount
            val prerollWallDurationSeconds = if (preparationStartedAtNanos > 0L) {
                (SystemClock.elapsedRealtimeNanos() - preparationStartedAtNanos) / NANOS_PER_SECOND
            } else {
                0.0
            }

            // Preserve the OrtSession while resetting every stateful measurement
            // boundary. No pre-roll sample can cross this serialized point.
            val segmentId = officialMeasurementBoundary.resetForOfficialMeasurement(engine)
            metricAnalysisExecutor.activate(token, segmentId)
            effectiveElapsedMillis = 0L
            officialMeasurementId = measurementId
            officialMeasurementActive = true
            preparationStartedAtNanos = 0L
            startedAtNanos = SystemClock.elapsedRealtimeNanos()
            resetPerformanceMetrics()
            startCsvSession()
            postState(token, session.markOfficialMeasurementStarted())
            Log.i(
                PERFORMANCE_TAG,
                "official_measurement_started measurementId=$measurementId " +
                    "prerollFrames=$prerollTotalFrames " +
                    "prerollWallDurationSeconds=$prerollWallDurationSeconds " +
                    "readinessWindowFrames=${readiness.frameCount} " +
                    "prerollDurationSeconds=${readiness.durationSeconds} " +
                    "prerollSampleRateHz=${readiness.sampleRateHz} " +
                    "prerollMaxGapSeconds=${readiness.maximumGapSeconds} " +
                    "engineReused=true segmentId=$segmentId officialSamples=0 " +
                    "officialMaxGapSeconds=0.0",
            )
        }
    }

    private fun activeTimeline(): RppgBvpTimeline =
        if (officialMeasurementActive) bvpTimeline else prerollTimeline

    private fun markPrerollUnready(token: Long) {
        readinessEvaluator.recordInvalidFace()
        postState(token, session.onPrerollUnready())
    }

    private fun resetPrerollSegment(
        engine: RppgInferenceEngine,
        token: Long,
        reason: String,
    ) {
        val reset = prerollTimeline.resetSegment()
        engine.reset()
        readinessEvaluator.reset()
        postState(token, session.onPrerollUnready())
        Log.i(
            TIMING_TAG,
            "preroll_segment_reset reason=$reason previousSegmentId=${reset.segmentId} " +
                "segmentId=${prerollTimeline.currentSegmentId()} " +
                "discardedSamples=${reset.discardedSampleCount} " +
                "discardedDurationSeconds=${reset.discardedDurationSeconds}",
        )
    }

    private fun requestAnalysis(
        token: Long,
        segmentId: Long,
        scheduledSecond: Int,
        snapshot: List<TimedRppgSample>,
        final: Boolean,
    ) {
        val key = RppgAnalysisKey(token, segmentId, scheduledSecond)
        val submitted = metricAnalysisExecutor.submit(key) analysis@{
            if (
                !metricAnalysisExecutor.isCurrent(key) || token != generation.get() ||
                segmentId != bvpTimeline.currentSegmentId()
            ) {
                return@analysis
            }
            try {
                val heartRate = signalProcessor.analyzeHeartRateMetric(snapshot, segmentId)
                val respiration = signalProcessor.analyzeRespirationMetric(snapshot, segmentId)
                val producedAt = OffsetDateTime.now()
                if (
                    !metricAnalysisExecutor.isCurrent(key) || token != generation.get() ||
                    segmentId != bvpTimeline.currentSegmentId()
                ) {
                    return@analysis
                }
                Log.d(
                    TIMING_TAG,
                    "analysis scheduledSecond=$scheduledSecond final=$final segmentId=$segmentId " +
                        "samples=${snapshot.size} durationSeconds=${heartRate.diagnostics.durationSeconds} " +
                        "sampleRateHz=${heartRate.diagnostics.targetSampleRateHz} " +
                        "maxGapSeconds=${heartRate.diagnostics.maximumGapSeconds} " +
                        "heartAvailable=${heartRate.available} heartConfidence=${heartRate.confidence} " +
                        "heartRejection=${heartRate.rejectionReason} " +
                        "respirationAvailable=${respiration.available} " +
                        "respirationConfidence=${respiration.confidence} " +
                        "respirationRejection=${respiration.rejectionReason}",
                )
                if (scheduledSecond == 10 || scheduledSecond == RppgTimingConfig.DEFAULT_DURATION_SECONDS) {
                    Log.i(
                        TIMING_TAG,
                        "heart_analysis scheduledSecond=$scheduledSecond segmentId=$segmentId " +
                            "durationMs=${heartRate.diagnostics.analysisDurationMillis} " +
                            "imfCount=${heartRate.diagnostics.imfCount} " +
                            "siftIterations=${heartRate.diagnostics.emdSiftIterations}",
                    )
                }
                mainExecutor.execute analysisResult@{
                    if (
                        token != generation.get() || !metricAnalysisExecutor.isCurrent(key) ||
                        segmentId != bvpTimeline.currentSegmentId()
                    ) {
                        return@analysisResult
                    }
                    csvSession?.enqueueSnapshot(
                        segmentId = segmentId,
                        scheduledSecond = scheduledSecond,
                        producedAt = producedAt,
                        heartRate = heartRate,
                        respiration = respiration,
                        isCurrent = {
                            token == generation.get() && metricAnalysisExecutor.isCurrent(key) &&
                                segmentId == bvpTimeline.currentSegmentId()
                        },
                    )
                    onEstimate(
                        RppgEstimateSnapshot(
                            scheduledSecond = scheduledSecond,
                            producedAtEpochMillis = producedAt.toInstant().toEpochMilli(),
                            heartRate = heartRate,
                            respiration = respiration,
                            aggregateQuality = RppgConfidencePolicy.conservativeAggregateQuality(
                                heartRate,
                                respiration,
                            ),
                        ),
                    )
                    if (final) {
                        completeOnMain(session.complete(heartRate, respiration))
                    } else if (running.get()) {
                        onState(session.updateEstimate(heartRate, respiration))
                    }
                }
            } catch (error: Throwable) {
                fail(error, token)
            }
        }
        if (!submitted) {
            Log.d(
                TIMING_TAG,
                "analysis_skipped scheduledSecond=$scheduledSecond segmentId=$segmentId " +
                    "reason=duplicate_or_stale",
            )
        }
    }

    private fun fail(error: Throwable, token: Long) {
        if (token != generation.get()) {
            Log.e(TAG, "Ignoring failure from stale rPPG measurement", error)
            return
        }
        running.set(false)
        metricAnalysisExecutor.invalidate()
        signalProcessor.clearMetricHistory()
        closeCsvSession("error")
        if (startedAtNanos != 0L) logPerformanceSummary("failed")
        mainExecutor.execute { reportFailureOnMain(error, token, shouldUnbind = true) }
    }

    private fun resetPerformanceMetrics(logAnchorNanos: Long = startedAtNanos) {
        lastPerformanceLogAtNanos = logAnchorNanos
        receivedFrameCount = 0L
        analyzedFrameCount = 0L
        totalPreprocessNanos = 0L
        totalInferenceNanos = 0L
        totalFrameNanos = 0L
        slowestFrameNanos = 0L
        faceDetectedFrameCount = 0L
        skippedNoFaceFrameCount = 0L
        faceDetectionFailureCount = 0L
        totalFaceDetectionNanos = 0L
        lastFaceDiagnosticLogAtNanos = logAnchorNanos
        lastFaceDetectionErrorLogAtNanos = 0L
        lastTimestampFallbackLogAtNanos = 0L
        lastCameraGapLogAtNanos = 0L
        lastDtClampLogAtNanos = 0L
        timestampRejectedFrameCount = 0L
        timestampFallbackFrameCount = 0L
        cameraGapFrameCount = 0L
        cameraStallResetCount = 0L
        modelDtClampCount = 0L
        continuousSegmentResetCount = 0L
        lastActualDtSeconds = null
        lastModelDtSeconds = RppgTimingConfig.MIN_MODEL_DT_SECONDS
    }

    private fun recordPerformance(
        preprocessNanos: Long,
        inferenceNanos: Long,
        frameNanos: Long,
    ) {
        totalPreprocessNanos += preprocessNanos
        totalInferenceNanos += inferenceNanos
        totalFrameNanos += frameNanos
        slowestFrameNanos = maxOf(slowestFrameNanos, frameNanos)

        val now = SystemClock.elapsedRealtimeNanos()
        if (now - lastPerformanceLogAtNanos < PERFORMANCE_LOG_INTERVAL_NANOS) return
        lastPerformanceLogAtNanos = now
        val sampleCount = bvpTimeline.snapshot().size
        val completedFrames = sampleCount.coerceAtLeast(1)
        Log.d(
            PERFORMANCE_TAG,
            "progress elapsedMs=${nanosToMillis(now - startedAtNanos)} " +
                "receivedFrames=$receivedFrameCount analyzedFrames=$analyzedFrameCount " +
                "samples=$sampleCount preprocessMs=${nanosToMillis(preprocessNanos)} " +
                "inferenceMs=${nanosToMillis(inferenceNanos)} frameMs=${nanosToMillis(frameNanos)} " +
                "actualDtSeconds=$lastActualDtSeconds modelDtSeconds=$lastModelDtSeconds " +
                "avgPreprocessMs=${nanosToMillis(totalPreprocessNanos / completedFrames)} " +
                "avgInferenceMs=${nanosToMillis(totalInferenceNanos / completedFrames)} " +
                "avgFrameMs=${nanosToMillis(totalFrameNanos / completedFrames)} " +
                "slowestFrameMs=${nanosToMillis(slowestFrameNanos)}",
        )
    }

    private fun recordFaceDiagnostics(
        nowNanos: Long,
        detectionNanos: Long,
        faceBounds: RppgRectF?,
    ) {
        totalFaceDetectionNanos += detectionNanos
        if (
            nowNanos - lastFaceDiagnosticLogAtNanos <
            RppgFaceRoiConfig.DIAGNOSTIC_LOG_INTERVAL_NANOS
        ) {
            return
        }
        lastFaceDiagnosticLogAtNanos = nowNanos
        val received = receivedFrameCount.coerceAtLeast(1L)
        val detectedRate = faceDetectedFrameCount.toDouble() / received
        Log.d(
            FACE_TAG,
            "progress receivedFrames=$receivedFrameCount faceFrames=$faceDetectedFrameCount " +
                "successRate=$detectedRate skippedFrames=$skippedNoFaceFrameCount " +
                "detectionFailures=$faceDetectionFailureCount " +
                "faceBounds=${faceBounds?.toLogString() ?: "none"} " +
                "detectionMs=${nanosToMillis(detectionNanos)} " +
                "avgDetectionMs=${nanosToMillis(totalFaceDetectionNanos / received)} " +
                "avgInferenceMs=${nanosToMillis(
                    totalInferenceNanos / analyzedFrameCount.coerceAtLeast(1L),
                )}",
        )
    }

    private fun logPerformanceSummary(outcome: String) {
        if (!performanceSummaryLogged.compareAndSet(false, true)) return
        val elapsedNanos = (SystemClock.elapsedRealtimeNanos() - startedAtNanos).coerceAtLeast(0L)
        val sampleSnapshot = bvpTimeline.snapshot()
        val completedFrames = sampleSnapshot.size
        val divisor = completedFrames.coerceAtLeast(1)
        val sampleSpanSeconds = if (sampleSnapshot.size >= 2) {
            sampleSnapshot.last().timestampSeconds - sampleSnapshot.first().timestampSeconds
        } else {
            0.0
        }
        val effectiveSampleRate = if (sampleSpanSeconds > 0.0) {
            (completedFrames - 1) / sampleSpanSeconds
        } else {
            0.0
        }
        Log.i(
            PERFORMANCE_TAG,
            "summary outcome=$outcome elapsedMs=${nanosToMillis(elapsedNanos)} " +
                "receivedFrames=$receivedFrameCount analyzedFrames=$analyzedFrameCount " +
                "processedFramesWithin20s=$analyzedFrameCount samples=$completedFrames " +
                "faceFrames=$faceDetectedFrameCount skippedFrames=$skippedNoFaceFrameCount " +
                "faceDetectionFailures=$faceDetectionFailureCount " +
                "timestampRejectedFrames=$timestampRejectedFrameCount " +
                "timestampFallbackFrames=$timestampFallbackFrameCount " +
                "cameraGapFrames=$cameraGapFrameCount cameraStallResets=$cameraStallResetCount " +
                "modelDtClamps=$modelDtClampCount segmentResets=$continuousSegmentResetCount " +
                "faceSuccessRate=${faceDetectedFrameCount.toDouble() / receivedFrameCount.coerceAtLeast(1L)} " +
                "avgFaceDetectionMs=${nanosToMillis(
                    totalFaceDetectionNanos / receivedFrameCount.coerceAtLeast(1L),
                )} " +
                "effectiveSampleRateHz=$effectiveSampleRate " +
                "avgPreprocessMs=${nanosToMillis(totalPreprocessNanos / divisor)} " +
                "avgInferenceMs=${nanosToMillis(totalInferenceNanos / divisor)} " +
                "avgFrameMs=${nanosToMillis(totalFrameNanos / divisor)} " +
                "slowestFrameMs=${nanosToMillis(slowestFrameNanos)}",
        )
    }

    private fun nanosToMillis(nanos: Long): Double = nanos / NANOS_PER_MILLISECOND

    private fun resetContinuousSegment(
        engine: RppgInferenceEngine,
        token: Long,
        reason: String,
    ) {
        val reset = bvpTimeline.resetSegment()
        engine.reset()
        signalProcessor.beginSegment(bvpTimeline.currentSegmentId())
        metricAnalysisExecutor.activate(token, bvpTimeline.currentSegmentId())
        continuousSegmentResetCount += 1
        effectiveElapsedMillis = 0L
        postContinuousSegmentRestart(token)
        Log.i(
            TIMING_TAG,
            "segment_reset reason=$reason previousSegmentId=${reset.segmentId} " +
                "segmentId=${bvpTimeline.currentSegmentId()} " +
                "discardedSamples=${reset.discardedSampleCount} " +
                "discardedDurationSeconds=${reset.discardedDurationSeconds}",
        )
    }

    private fun postContinuousSegmentRestart(token: Long) {
        mainExecutor.execute {
            if (token == generation.get() && running.get()) {
                onState(session.restartContinuousSegment())
            }
        }
    }

    private fun recordFrameTiming(timing: RppgFrameTiming, logNowNanos: Long) {
        lastActualDtSeconds = timing.actualDtSeconds
        lastModelDtSeconds = timing.modelDtSeconds
        if (timing.fallbackReason != null) timestampFallbackFrameCount += 1
        if (
            timing.fallbackReason != null &&
            logNowNanos - lastTimestampFallbackLogAtNanos >=
            RppgTimingConfig.TIMESTAMP_LOG_INTERVAL_NANOS
        ) {
            lastTimestampFallbackLogAtNanos = logNowNanos
            Log.w(
                TIMING_TAG,
                "timestamp_fallback sourceDtSeconds=${timing.sourceDtSeconds} " +
                    "arrivalDtSeconds=${timing.arrivalDtSeconds} " +
                    "resolvedDtSeconds=${timing.actualDtSeconds} " +
                    "modelDtSeconds=${timing.modelDtSeconds} segmentId=${timing.segmentId} " +
                    "fallbackReason=${timing.fallbackReason}",
            )
        }
        if (
            timing.fallbackReason == null &&
            timing.actualDtSeconds != null &&
            timing.actualDtSeconds > RppgTimingConfig.MAX_MODEL_DT_SECONDS &&
            logNowNanos - lastCameraGapLogAtNanos >= RppgTimingConfig.TIMESTAMP_LOG_INTERVAL_NANOS
        ) {
            lastCameraGapLogAtNanos = logNowNanos
            Log.d(
                TIMING_TAG,
                "camera_gap sourceDtSeconds=${timing.sourceDtSeconds} " +
                    "arrivalDtSeconds=${timing.arrivalDtSeconds} " +
                    "resolvedDtSeconds=${timing.actualDtSeconds} " +
                    "modelDtSeconds=${timing.modelDtSeconds} segmentId=${timing.segmentId} " +
                    "fallbackReason=none resetReason=none",
            )
        }
        if (
            timing.fallbackReason == null &&
            timing.actualDtSeconds != null &&
            timing.actualDtSeconds > RppgTimingConfig.MAX_MODEL_DT_SECONDS
        ) {
            cameraGapFrameCount += 1
        }
        if (timing.modelDtWasClamped) {
            modelDtClampCount += 1
            if (
                logNowNanos - lastDtClampLogAtNanos >=
                RppgTimingConfig.TIMESTAMP_LOG_INTERVAL_NANOS
            ) {
                lastDtClampLogAtNanos = logNowNanos
                Log.d(
                    TIMING_TAG,
                    "dt_clamped sourceDtSeconds=${timing.sourceDtSeconds} " +
                        "arrivalDtSeconds=${timing.arrivalDtSeconds} " +
                        "resolvedDtSeconds=${timing.actualDtSeconds} " +
                        "modelDtSeconds=${timing.modelDtSeconds} segmentId=${timing.segmentId} " +
                        "fallbackReason=${timing.fallbackReason} resetReason=${timing.resetReason} " +
                        "clampCount=$modelDtClampCount",
                )
            }
        }
    }

    private fun logTimestampRejection(
        logNowNanos: Long,
        rejection: RppgFrameTimingDecision.Rejected,
    ) {
        if (
            logNowNanos - lastTimestampFallbackLogAtNanos <
            RppgTimingConfig.TIMESTAMP_LOG_INTERVAL_NANOS
        ) {
            return
        }
        lastTimestampFallbackLogAtNanos = logNowNanos
        Log.w(
            TIMING_TAG,
            "timestamp_rejected reason=${rejection.reason} " +
                "sourceTimestampNanos=${rejection.sourceTimestampNanos} " +
                "arrivalTimestampNanos=${rejection.arrivalTimestampNanos} " +
                "sourceDtSeconds=${rejection.sourceDtSeconds} " +
                "arrivalDtSeconds=${rejection.arrivalDtSeconds} " +
                "rejectedCount=$timestampRejectedFrameCount",
        )
    }

    private fun completeOnMain(state: RppgMeasurementState) {
        try {
            provider?.unbindAll()
        } catch (error: Throwable) {
            reportFailureOnMain(error, generation.get(), shouldUnbind = false)
            return
        }
        metricAnalysisExecutor.invalidate()
        signalProcessor.clearMetricHistory()
        closeCsvSession("completed")
        logPerformanceSummary("completed")
        onState(state)
    }

    private fun reportFailureOnMain(error: Throwable, token: Long, shouldUnbind: Boolean) {
        if (token != generation.get()) return
        if (!failureReported.compareAndSet(false, true)) {
            Log.e(TAG, "Additional rPPG failure after failure was already reported", error)
            return
        }
        if (shouldUnbind) {
            try {
                provider?.unbindAll()
            } catch (unbindError: Throwable) {
                error.addSuppressed(unbindError)
                Log.e(TAG, "Failed to unbind CameraX after rPPG failure", unbindError)
            }
        }
        Log.e(TAG, "rPPG measurement failed", error)
        metricAnalysisExecutor.invalidate()
        signalProcessor.clearMetricHistory()
        closeCsvSession("error")
        onState(session.fail(error.message ?: "未知错误"))
    }

    private fun postState(token: Long, state: RppgMeasurementState) {
        mainExecutor.execute {
            if (token == generation.get()) onState(state)
        }
    }

    private fun isActive(token: Long): Boolean =
        token == generation.get() && running.get() && !closed.get()

    override fun close() {
        synchronized(lifecycleLock) {
            if (!closed.compareAndSet(false, true)) return
            running.set(false)
            generation.incrementAndGet()
            metricAnalysisExecutor.shutdown()
            signalProcessor.clearMetricHistory()
            closeCsvSession("controller_closed")
        }
        mainExecutor.execute {
            try {
                provider?.unbindAll()
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to unbind CameraX while closing rPPG controller", error)
            }
        }
        analyzerExecutor.execute {
            try {
                inferenceEngine?.close()
            } catch (error: Throwable) {
                Log.e(TAG, "Failed to close rPPG inference engine", error)
            } finally {
                inferenceEngine = null
                try {
                    faceDetector.close()
                } catch (error: Throwable) {
                    Log.e(TAG, "Failed to close ML Kit face detector", error)
                }
            }
        }
        analyzerExecutor.shutdown()
    }

    private fun startCsvSession() {
        closeCsvSession("restarted")
        csvSession = RppgCsvSession(
            outputDirectory = context.getExternalFilesDir("rppg_exports"),
            eventListener = ::logCsvEvent,
        )
    }

    private fun closeCsvSession(reason: String) {
        val activeSession = csvSession ?: return
        csvSession = null
        activeSession.close(reason)
    }

    private fun logCsvEvent(event: RppgCsvEvent) {
        when (event) {
            is RppgCsvEvent.SessionStarted -> Log.i(
                CSV_TAG,
                "csv_session_started path=${event.path} sessionId=${event.sessionId}",
            )
            is RppgCsvEvent.RowWritten -> Log.d(
                CSV_TAG,
                "csv_row_written path=${event.path} sessionId=${event.sessionId} rows=${event.rowCount}",
            )
            is RppgCsvEvent.SessionClosed -> Log.i(
                CSV_TAG,
                "csv_session_closed path=${event.path} sessionId=${event.sessionId} " +
                    "rows=${event.rowCount} reason=${event.reason}",
            )
            is RppgCsvEvent.WriteFailed -> Log.w(
                CSV_TAG,
                "csv_write_failed sessionId=${event.sessionId} operation=${event.operation}",
                event.error,
            )
        }
    }

    @ExperimentalGetImage
    private fun detectFaces(image: ImageProxy, nowNanos: Long): List<RppgFaceCandidate>? {
        val mediaImage = image.image
        if (mediaImage == null) {
            faceDetectionFailureCount += 1
            logFaceDetectionFailure(nowNanos, "CameraX image buffer was unavailable", null)
            return null
        }
        return try {
            val inputImage = InputImage.fromMediaImage(mediaImage, image.imageInfo.rotationDegrees)
            Tasks.await(faceDetector.process(inputImage)).map { face ->
                val box = face.boundingBox
                RppgFaceCandidate(
                    bounds = RppgRectF(
                        left = box.left.toFloat(),
                        top = box.top.toFloat(),
                        right = box.right.toFloat(),
                        bottom = box.bottom.toFloat(),
                    ),
                    trackingId = face.trackingId,
                )
            }
        } catch (error: Throwable) {
            faceDetectionFailureCount += 1
            logFaceDetectionFailure(nowNanos, "ML Kit face detection failed", error)
            null
        }
    }

    private fun logFaceDetectionFailure(nowNanos: Long, message: String, error: Throwable?) {
        if (
            nowNanos - lastFaceDetectionErrorLogAtNanos <
            RppgFaceRoiConfig.DIAGNOSTIC_LOG_INTERVAL_NANOS
        ) {
            return
        }
        lastFaceDetectionErrorLogAtNanos = nowNanos
        Log.w(FACE_TAG, message, error)
    }

    private fun ImageProxy.toUprightArgbFrame(): RppgArgbFrame {
        val bitmap = toBitmap()
        return try {
            val pixels = IntArray(bitmap.width * bitmap.height)
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            RppgImagePreprocessor.uprightFrame(
                argb = pixels,
                width = bitmap.width,
                height = bitmap.height,
                rotationDegrees = imageInfo.rotationDegrees,
            )
        } finally {
            bitmap.recycle()
        }
    }

    private fun ImageProxy.uprightDimensions(): Pair<Int, Int> =
        when (imageInfo.rotationDegrees) {
            0, 180 -> width to height
            90, 270 -> height to width
            else -> error("Unsupported CameraX rotation: ${imageInfo.rotationDegrees}")
        }

    private fun RppgRectF.toLogString(): String =
        "(${left.toInt()},${top.toInt()},${right.toInt()},${bottom.toInt()})"

    private companion object {
        const val TAG = "RppgCameraController"
        const val PERFORMANCE_TAG = "RppgPerformance"
        const val FACE_TAG = "RppgFaceRoi"
        const val TIMING_TAG = "RppgTiming"
        const val CSV_TAG = "RppgCsvExport"
        const val PERFORMANCE_LOG_INTERVAL_NANOS = 1_000_000_000L
        const val NANOS_PER_SECOND = 1_000_000_000.0
        const val NANOS_PER_MILLISECOND = 1_000_000.0
    }
}
