package com.alloop.blue.test

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.alloop.radar.bridge.AndroidGattTransport
import com.alloop.radar.bridge.HifResponse
import com.alloop.radar.bridge.PointCloudFrame
import com.alloop.radar.bridge.RadarBridge
import com.alloop.radar.bridge.RadarConnectionState
import com.alloop.radar.bridge.RadarGattProfile
import com.alloop.radar.bridge.RadarListener
import com.alloop.radar.bridge.VitalBinMode
import com.alloop.radar.bridge.VitalConfig
import com.alloop.radar.bridge.VitalMetrics
import com.alloop.radar.bridge.VitalSample
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import io.flutter.plugin.common.MethodCall
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.util.UUID
import java.nio.charset.StandardCharsets
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Isolated JDY-23/MRS6130 bridge for Flutter.  Ring and XiaoZhi BLE flows do
 * not call this class.  JDY-23 commonly exposes one FFE1 characteristic for
 * both notifications and writes, which is the profile used here.
 */
class RadarFlutterBridge(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val adapter: BluetoothAdapter? get() = BluetoothAdapter.getDefaultAdapter()
    private var scanCallback: ScanCallback? = null
    private var scanTimeoutJob: Job? = null
    private var radar: RadarBridge? = null
    private var connectedDeviceAddress: String? = null
    private var streaming = false
    private var lastPointCloudEmitAt = 0L
    private val pointCloudCaptureLock = Any()
    private var pointCloudWriter: BufferedWriter? = null
    private var pointCloudCaptureFile: File? = null
    private var pointCloudCaptureStartedAt: Long? = null
    private var capturedPointCloudFrames = 0L
    private var capturedPointCloudPoints = 0L
    private var pointsSinceLastFlush = 0
    private val vitalMetricsCaptureLock = Any()
    private var vitalMetricsWriter: BufferedWriter? = null
    private var vitalMetricsCaptureFile: File? = null
    private var vitalMetricsCaptureStartedAt: Long? = null
    private var capturedVitalMetricRows = 0L
    private var vitalMetricsSinceLastFlush = 0
    private var latestVitalSample: VitalSample? = null
    private var activeVitalOutputFlags = VITAL_PHASE_OUTPUT_FLAG or POINT_CLOUD_OUTPUT_FLAG
    private var activeVitalBinMode = "auto_strongest"
    private var activeVitalSelectedBin = 25
    private var activeVitalMinBin = 10
    private var activeVitalMaxBin = 100

    suspend fun handle(call: MethodCall): Any? = when (call.method) {
        "scan" -> scan()
        "stopScan" -> { stopScan(); null }
        "connect" -> {
            val args = call.arguments<Map<String, Any?>>() ?: error("Missing radar device")
            connect(args.string("address"))
            null
        }
        "disconnect" -> { disconnect(); null }
        "wakeup" -> { requireRadar().wakeup().requireAccepted("Wakeup"); null }
        "start" -> { startRadar(); null }
        "stop" -> { stopRadar(); null }
        "exportPointCloudCsv" -> exportPointCloudCsv()
        "exportVitalMetricsCsv" -> exportVitalMetricsCsv()
        "queryVitalConfig" -> { requireRadar().queryVitalConfig().requireAccepted("Query vital config"); null }
        "selectVitalBinAutomatically" -> { requireRadar().selectVitalBinAutomatically().requireAccepted("Auto select bin"); null }
        "configureVital" -> {
            val args = call.arguments<Map<String, Any?>>() ?: error("Missing vital configuration")
            val flags = (if (args.bool("phaseEnabled")) 1 else 0) or (if (args.bool("pointCloudEnabled")) 2 else 0)
            val config = VitalConfig(
                outputFlags = flags,
                binMode = if (args.bool("manualBin")) VitalBinMode.MANUAL else VitalBinMode.AUTO_STRONGEST,
                selectedBin = args.int("selectedBin", 25),
                minBin = args.int("minBin", 10),
                maxBin = args.int("maxBin", 100),
            )
            requireRadar().configureVital(config).requireAccepted("Configure vital output")
            activeVitalOutputFlags = config.outputFlags
            activeVitalBinMode = config.binMode.name.lowercase()
            activeVitalSelectedBin = config.selectedBin
            activeVitalMinBin = config.minBin
            activeVitalMaxBin = config.maxBin
            null
        }
        "sendHif" -> {
            val args = call.arguments<Map<String, Any?>>() ?: error("Missing HIF message")
            requireRadar().sendHif(args.int("messageId", -1), parseHex(args["payloadHex"] as? String ?: ""))
                .requireAccepted("Send HIF")
            null
        }
        else -> throw UnsupportedOperationException("Unsupported radar call: ${call.method}")
    }

    @SuppressLint("MissingPermission")
    private suspend fun scan(): List<Map<String, Any?>> = suspendCancellableCoroutine { continuation ->
        stopScan()
        val scanner = adapter?.bluetoothLeScanner ?: run {
            continuation.resumeWithException(IllegalStateException("Bluetooth LE is unavailable"))
            return@suspendCancellableCoroutine
        }
        val found = linkedMapOf<String, Map<String, Any?>>()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val name = result.device.name ?: result.scanRecord?.deviceName ?: return
                if (!name.equals(JDY23_NAME, ignoreCase = true)) return
                found[result.device.address] = mapOf(
                    "address" to result.device.address,
                    "name" to name,
                    "rssi" to result.rssi,
                )
            }

            override fun onScanFailed(errorCode: Int) {
                stopScan()
                if (continuation.isActive) continuation.resumeWithException(
                    IllegalStateException("JDY-23 scan failed: $errorCode"),
                )
            }
        }
        scanCallback = callback
        scanner.startScan(callback)
        scanTimeoutJob = scope.launch {
            delay(SCAN_DURATION_MS)
            scanTimeoutJob = null
            scanCallback = null
            try { scanner.stopScan(callback) } catch (_: Throwable) { }
            if (continuation.isActive) continuation.resume(found.values.sortedByDescending { (it["rssi"] as Number).toInt() })
        }
        continuation.invokeOnCancellation { stopScan() }
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        scanTimeoutJob?.cancel()
        scanTimeoutJob = null
        val callback = scanCallback ?: return
        try { adapter?.bluetoothLeScanner?.stopScan(callback) } catch (_: Throwable) { }
        scanCallback = null
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String) {
        disconnect()
        val device = adapter?.getRemoteDevice(address)
            ?: error("Bluetooth adapter is unavailable")
        val profile = RadarGattProfile(
            serviceUuid = FFE0_SERVICE,
            writeCharacteristicUuid = FFE1_CHARACTERISTIC,
            notifyCharacteristicUuid = FFE1_CHARACTERISTIC,
            writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
            maxWriteBytes = 20,
            allowReadyWithoutCccdCallback = true,
        )
        radar = RadarBridge(estimateVitalMetrics = true).also { bridge ->
            bridge.addListener(listener)
            bridge.attach(AndroidGattTransport(context, profile))
            bridge.connect(device)
        }
        connectedDeviceAddress = address
    }

    private fun disconnect() {
        streaming = false
        finishPointCloudCapture("interrupted")
        finishVitalMetricsCapture("interrupted")
        radar?.disconnect()
        radar = null
        connectedDeviceAddress = null
        emit(mapOf("kind" to "connection", "state" to "disconnected"))
    }

    private fun requireRadar(): RadarBridge = radar ?: error("Radar is not connected")

    private fun startRadar() {
        requireRadar().start().requireAccepted("Start radar")
        try {
            beginMeasurementCaptures()
            streaming = true
            lastPointCloudEmitAt = 0L
        } catch (error: Throwable) {
            radar?.stop()
            throw error
        }
    }

    private fun stopRadar() {
        // Gate events first: a BLE queue may still contain a few reports after
        // the stop write is accepted.
        streaming = false
        try {
            requireRadar().stop().requireAccepted("Stop radar")
        } finally {
            finishPointCloudCapture("completed")
            finishVitalMetricsCapture("completed")
        }
    }

    private val listener = object : RadarListener {
        override fun onStateChanged(state: RadarConnectionState) {
            if (state == RadarConnectionState.READY) {
                // VitalBridge firmware is documented to stay idle after power
                // on.  Some deployed boards retain their previous run state,
                // so explicitly return them to standby before the user presses
                // the Start button.
                streaming = false
                radar?.stop()
            }
            if (state == RadarConnectionState.DISCONNECTED || state == RadarConnectionState.ERROR) {
                streaming = false
                finishPointCloudCapture("interrupted")
                finishVitalMetricsCapture("interrupted")
            }
            emit(mapOf("kind" to "connection", "state" to state.name.lowercase()))
        }

        override fun onHifResponse(response: HifResponse) {
            emit(mapOf(
                "kind" to "response",
                "message" to "HIF 0x${response.messageId.toString(16).padStart(2, '0')} status=${response.status}",
                "messageId" to response.messageId,
                "status" to response.status,
            ))
        }

        override fun onPointCloud(frame: PointCloudFrame) = emitPointCloud(frame)
        override fun onVitalSample(sample: VitalSample) = emitVitalSample(sample)
        override fun onVitalMetrics(metrics: VitalMetrics) = emitVitalMetrics(metrics)
        override fun onProtocolError(message: String) = emit(mapOf("kind" to "error", "message" to message))
        override fun onTransportError(error: Throwable) = emit(mapOf("kind" to "error", "message" to (error.message ?: error.toString())))
    }

    private fun emitPointCloud(frame: PointCloudFrame) {
        if (!streaming) return
        capturePointCloud(frame)
        val now = SystemClock.elapsedRealtime()
        // Rendering every UART frame causes repeated full Flutter layouts.
        // Ten frames/second remains smooth while keeping the UI responsive.
        if (now - lastPointCloudEmitAt < POINT_CLOUD_INTERVAL_MS) return
        lastPointCloudEmitAt = now
        emit(mapOf(
            "kind" to "pointCloud",
            "frameIndex" to frame.frameIndex,
            "pointCount" to frame.points.size,
            "points" to frame.points.take(MAX_RENDER_POINTS).map { point -> mapOf(
            "x" to point.xMeters,
            "y" to point.yMeters,
            "z" to point.zMeters,
            "velocity" to point.velocityMetersPerSecond,
            "snr" to point.snrDb,
            "trackId" to point.trackId,
            "static" to point.isStatic,
            ) },
        ))
    }

    /**
     * Captures every native point-cloud frame before the Flutter display is
     * throttled and truncated. The CSV therefore preserves the full session.
     */
    private fun capturePointCloud(frame: PointCloudFrame) {
        val recordedAt = System.currentTimeMillis()
        synchronized(pointCloudCaptureLock) {
            val writer = pointCloudWriter ?: return
            capturedPointCloudFrames++
            frame.points.forEachIndexed { pointIndex, point ->
                writer.append(recordedAt.toString()).append(',')
                    .append(frame.frameIndex.toString()).append(',')
                    .append(pointIndex.toString()).append(',')
                    .append(point.xMeters.toString()).append(',')
                    .append(point.yMeters.toString()).append(',')
                    .append(point.zMeters.toString()).append(',')
                    .append(point.velocityMetersPerSecond.toString()).append(',')
                    .append(point.snrDb.toString()).append(',')
                    .append(point.trackId.toString()).append(',')
                    .append(point.isStatic.toString())
                writer.newLine()
                capturedPointCloudPoints++
                pointsSinceLastFlush++
            }
            if (pointsSinceLastFlush >= POINT_CLOUD_FLUSH_INTERVAL) {
                writer.flush()
                pointsSinceLastFlush = 0
            }
        }
    }

    private fun beginPointCloudCapture() {
        finishPointCloudCapture("replaced")
        val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
        val exportDir = File(baseDir, POINT_CLOUD_EXPORT_DIRECTORY)
        check(exportDir.exists() || exportDir.mkdirs()) {
            "Unable to create point-cloud export directory: ${exportDir.absolutePath}"
        }
        val startedAt = System.currentTimeMillis()
        val file = File(exportDir, "radar_point_cloud_$startedAt.csv")
        val writer = BufferedWriter(
            OutputStreamWriter(FileOutputStream(file), StandardCharsets.UTF_8),
            POINT_CLOUD_WRITE_BUFFER_BYTES,
        )
        writer.write("recorded_at_epoch_ms,frame_index,point_index,x_m,y_m,z_m,velocity_mps,snr_db,track_id,is_static")
        writer.newLine()
        synchronized(pointCloudCaptureLock) {
            pointCloudWriter = writer
            pointCloudCaptureFile = file
            pointCloudCaptureStartedAt = startedAt
            capturedPointCloudFrames = 0
            capturedPointCloudPoints = 0
            pointsSinceLastFlush = 0
        }
        Log.i(TAG, "Point-cloud capture started: ${file.absolutePath}")
        emitPointCloudCaptureStatus("capturing")
    }

    private fun beginMeasurementCaptures() {
        try {
            beginPointCloudCapture()
            beginVitalMetricsCapture()
        } catch (error: Throwable) {
            finishPointCloudCapture("interrupted")
            finishVitalMetricsCapture("interrupted")
            throw error
        }
    }

    private fun finishPointCloudCapture(status: String) {
        val hadCapture = synchronized(pointCloudCaptureLock) {
            val writer = pointCloudWriter ?: return@synchronized false
            try {
                writer.flush()
            } finally {
                try {
                    writer.close()
                } finally {
                    pointCloudWriter = null
                    pointsSinceLastFlush = 0
                }
            }
            true
        }
        if (hadCapture) {
            Log.i(TAG, "Point-cloud capture $status: ${pointCloudCaptureFile?.absolutePath}, frames=$capturedPointCloudFrames, points=$capturedPointCloudPoints")
            emitPointCloudCaptureStatus(status)
        }
    }

    private fun exportPointCloudCsv(): Map<String, Any?> {
        synchronized(pointCloudCaptureLock) {
            val file = pointCloudCaptureFile
                ?: error("No point-cloud capture is available for export")
            pointCloudWriter?.flush()
            val result = pointCloudCaptureStatus(
                if (pointCloudWriter == null) "completed" else "capturing",
            )
            Log.i(TAG, "Point-cloud CSV requested: ${file.absolutePath}, frames=$capturedPointCloudFrames, points=$capturedPointCloudPoints")
            return result
        }
    }

    private fun emitPointCloudCaptureStatus(status: String) =
        emit(pointCloudCaptureStatus(status) + mapOf("kind" to "pointCloudCapture"))

    private fun pointCloudCaptureStatus(status: String): Map<String, Any?> = mapOf(
        "path" to pointCloudCaptureFile?.absolutePath,
        "state" to status,
        "frameCount" to capturedPointCloudFrames,
        "pointCount" to capturedPointCloudPoints,
        "startedAt" to pointCloudCaptureStartedAt,
    )

    /**
     * Records one row per VitalMetrics callback, with the most recent I/Q
     * sample and VitalBridge configuration attached for engineering analysis.
     */
    private fun captureVitalMetrics(metrics: VitalMetrics) {
        val recordedAt = System.currentTimeMillis()
        synchronized(vitalMetricsCaptureLock) {
            val writer = vitalMetricsWriter ?: return
            val sample = latestVitalSample
            val startedAt = vitalMetricsCaptureStartedAt ?: recordedAt
            val averageConfidence = (metrics.breathingConfidence + metrics.heartConfidence) / 2.0
            val row = listOf(
                recordedAt.toString(),
                formatUtcTimestamp(recordedAt),
                startedAt.toString(),
                (recordedAt - startedAt).coerceAtLeast(0).toString(),
                connectedDeviceAddress.orEmpty(),
                JDY23_NAME,
                metrics.breathingBpm.csvNumber(),
                metrics.heartBpm.csvNumber(),
                metrics.breathingConfidence.csvNumber(),
                metrics.heartConfidence.csvNumber(),
                averageConfidence.csvNumber(),
                metrics.windowSeconds.csvNumber(),
                metrics.distanceMeters.csvNumber(),
                sample?.frameIndex?.toString().orEmpty(),
                sample?.protocolVersion?.toString().orEmpty(),
                sample?.flags?.toString().orEmpty(),
                sample?.rangeBin?.toString().orEmpty(),
                sample?.distanceMeters.csvNumber(),
                sample?.rangeResolutionMm?.toString().orEmpty(),
                sample?.samplePeriodMs?.toString().orEmpty(),
                sample?.imag?.toInt()?.toString().orEmpty(),
                sample?.real?.toInt()?.toString().orEmpty(),
                sample?.magnitudeSquared?.toString().orEmpty(),
                sample?.phaseRadians.csvNumber(),
                ((activeVitalOutputFlags and VITAL_PHASE_OUTPUT_FLAG) != 0).toString(),
                ((activeVitalOutputFlags and POINT_CLOUD_OUTPUT_FLAG) != 0).toString(),
                activeVitalBinMode,
                activeVitalSelectedBin.toString(),
                activeVitalMinBin.toString(),
                activeVitalMaxBin.toString(),
            )
            writer.write(row.joinToString(","))
            writer.newLine()
            capturedVitalMetricRows++
            vitalMetricsSinceLastFlush++
            if (vitalMetricsSinceLastFlush >= VITAL_METRICS_FLUSH_INTERVAL) {
                writer.flush()
                vitalMetricsSinceLastFlush = 0
            }
        }
    }

    private fun beginVitalMetricsCapture() {
        finishVitalMetricsCapture("replaced")
        val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
        val exportDir = File(baseDir, POINT_CLOUD_EXPORT_DIRECTORY)
        check(exportDir.exists() || exportDir.mkdirs()) {
            "Unable to create radar export directory: ${exportDir.absolutePath}"
        }
        val startedAt = System.currentTimeMillis()
        val file = File(exportDir, "radar_vital_metrics_$startedAt.csv")
        val writer = BufferedWriter(
            OutputStreamWriter(FileOutputStream(file), StandardCharsets.UTF_8),
            POINT_CLOUD_WRITE_BUFFER_BYTES,
        )
        writer.write(
            "recorded_at_epoch_ms,recorded_at_utc,measurement_started_at_epoch_ms,elapsed_ms,"
                + "radar_device_address,radar_model,breathing_bpm,heart_bpm,"
                + "breathing_confidence,heart_confidence,mean_confidence,"
                + "window_seconds,metrics_distance_m,sample_frame_index,sample_protocol_version,"
                + "sample_flags,sample_range_bin,sample_distance_m,sample_range_resolution_mm,"
                + "sample_period_ms,sample_imag,sample_real,sample_magnitude_squared,sample_phase_radians,"
                + "phase_output_enabled,point_cloud_output_enabled,bin_mode,selected_bin,min_bin,max_bin",
        )
        writer.newLine()
        synchronized(vitalMetricsCaptureLock) {
            vitalMetricsWriter = writer
            vitalMetricsCaptureFile = file
            vitalMetricsCaptureStartedAt = startedAt
            capturedVitalMetricRows = 0
            vitalMetricsSinceLastFlush = 0
            latestVitalSample = null
        }
        Log.i(TAG, "Vital-metrics capture started: ${file.absolutePath}")
        emitVitalMetricsCaptureStatus("capturing")
    }

    private fun finishVitalMetricsCapture(status: String) {
        val hadCapture = synchronized(vitalMetricsCaptureLock) {
            val writer = vitalMetricsWriter ?: return@synchronized false
            try {
                writer.flush()
            } finally {
                try {
                    writer.close()
                } finally {
                    vitalMetricsWriter = null
                    vitalMetricsSinceLastFlush = 0
                }
            }
            true
        }
        if (hadCapture) {
            Log.i(
                TAG,
                "Vital-metrics capture $status: ${vitalMetricsCaptureFile?.absolutePath}, "
                    + "records=$capturedVitalMetricRows",
            )
            emitVitalMetricsCaptureStatus(status)
        }
    }

    private fun exportVitalMetricsCsv(): Map<String, Any?> {
        synchronized(vitalMetricsCaptureLock) {
            val file = vitalMetricsCaptureFile
                ?: error("No vital-metrics capture is available for export")
            vitalMetricsWriter?.flush()
            val result = vitalMetricsCaptureStatus(
                if (vitalMetricsWriter == null) "completed" else "capturing",
            )
            Log.i(TAG, "Vital-metrics CSV requested: ${file.absolutePath}, records=$capturedVitalMetricRows")
            return result
        }
    }

    private fun emitVitalMetricsCaptureStatus(status: String) =
        emit(vitalMetricsCaptureStatus(status) + mapOf("kind" to "vitalMetricsCapture"))

    private fun vitalMetricsCaptureStatus(status: String): Map<String, Any?> = mapOf(
        "path" to vitalMetricsCaptureFile?.absolutePath,
        "state" to status,
        "recordCount" to capturedVitalMetricRows,
        "startedAt" to vitalMetricsCaptureStartedAt,
    )

    private fun emitVitalSample(sample: VitalSample) {
        if (!streaming) return
        synchronized(vitalMetricsCaptureLock) {
            latestVitalSample = sample
        }
        emit(mapOf(
        "kind" to "vitalSample",
        "rangeBin" to sample.rangeBin,
        "frameIndex" to sample.frameIndex,
        "imag" to sample.imag.toInt(),
        "real" to sample.real.toInt(),
        "phaseRadians" to sample.phaseRadians,
        "distanceMeters" to sample.distanceMeters,
        "rangeResolutionMm" to sample.rangeResolutionMm,
        "samplePeriodMs" to sample.samplePeriodMs,
        ))
    }

    private fun emitVitalMetrics(metrics: VitalMetrics) {
        if (!streaming) return
        captureVitalMetrics(metrics)
        emit(mapOf(
        "kind" to "vitalMetrics",
        "breathingBpm" to metrics.breathingBpm,
        "heartBpm" to metrics.heartBpm,
        "breathingConfidence" to metrics.breathingConfidence,
        "heartConfidence" to metrics.heartConfidence,
        "windowSeconds" to metrics.windowSeconds,
        "distanceMeters" to metrics.distanceMeters,
        ))
    }

    private fun Boolean.requireAccepted(operation: String) {
        check(this) { "$operation was rejected; wait until the connection state is ready" }
    }

    private fun parseHex(value: String): ByteArray {
        val normalized = value.replace(Regex("[^0-9a-fA-F]"), "")
        require(normalized.length % 2 == 0) { "Payload hex must contain complete bytes" }
        return ByteArray(normalized.length / 2) { index ->
            normalized.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
    }

    private fun Map<String, Any?>.string(name: String) = this[name] as? String ?: error("Missing $name")
    private fun Map<String, Any?>.bool(name: String) = this[name] as? Boolean ?: false
    private fun Map<String, Any?>.int(name: String, fallback: Int) = (this[name] as? Number)?.toInt() ?: fallback
    private fun Double?.csvNumber(): String = this?.takeIf { it.isFinite() }?.toString().orEmpty()

    private fun formatUtcTimestamp(epochMs: Long): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(epochMs))

    companion object {
        private const val JDY23_NAME = "JDY-23"
        private const val SCAN_DURATION_MS = 5_000L
        private const val POINT_CLOUD_INTERVAL_MS = 100L
        private const val MAX_RENDER_POINTS = 256
        private const val POINT_CLOUD_EXPORT_DIRECTORY = "radar_exports"
        private const val POINT_CLOUD_WRITE_BUFFER_BYTES = 64 * 1024
        private const val POINT_CLOUD_FLUSH_INTERVAL = 500
        private const val VITAL_METRICS_FLUSH_INTERVAL = 20
        private const val VITAL_PHASE_OUTPUT_FLAG = 0x01
        private const val POINT_CLOUD_OUTPUT_FLAG = 0x02
        private const val TAG = "RadarCsvExport"
        private val FFE0_SERVICE: UUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
        private val FFE1_CHARACTERISTIC: UUID = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
    }
}
