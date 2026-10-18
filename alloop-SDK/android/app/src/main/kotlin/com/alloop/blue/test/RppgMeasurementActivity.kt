package com.alloop.blue.test

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import com.vvewell.health.core.rppg.RppgEstimateSnapshot
import com.vvewell.health.core.rppg.RppgMeasurementState
import com.vvewell.health.core.rppg.RppgPhase
import com.vvewell.health.ui.screens.RppgScreen
import java.util.UUID
import java.util.concurrent.atomic.AtomicReference

class RppgMeasurementActivity : ComponentActivity() {
    private val sessionId = UUID.randomUUID().toString()
    private val estimates = linkedMapOf<Int, Map<String, Any?>>()
    private var startedAtEpochMillis: Long? = null
    private var terminal = false
    private var lastState: RppgMeasurementState? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeActivity.set(this)
        setContent {
            MaterialTheme {
                RppgScreen(
                    onBack = ::finishCancelled,
                    onStateChanged = ::recordState,
                    onEstimate = ::recordEstimate,
                    onTerminalState = ::finishTerminal,
                )
            }
        }
    }

    override fun onDestroy() {
        if (activeActivity.get() === this) activeActivity.set(null)
        super.onDestroy()
    }

    private fun recordState(state: RppgMeasurementState) {
        lastState = state
        if (startedAtEpochMillis == null && state.measuring) {
            startedAtEpochMillis = System.currentTimeMillis()
        }
    }

    private fun recordEstimate(snapshot: RppgEstimateSnapshot) {
        if (startedAtEpochMillis == null) {
            startedAtEpochMillis = snapshot.producedAtEpochMillis - snapshot.scheduledSecond * 1_000L
        }
        estimates[snapshot.scheduledSecond] = estimateSampleMap(snapshot)
    }

    private fun finishTerminal(state: RppgMeasurementState) {
        if (terminal) return
        terminal = true
        val reason = when (state.phase) {
            RppgPhase.Completed -> "completed"
            RppgPhase.LowQuality -> "low_quality"
            RppgPhase.Error -> "error"
            else -> state.phase.name.lowercase()
        }
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra(EXTRA_RESULT, HashMap(sessionMap(reason, state))),
        )
        finish()
    }

    private fun finishCancelled() {
        if (terminal) return
        terminal = true
        setResult(
            Activity.RESULT_CANCELED,
            Intent().putExtra(EXTRA_RESULT, HashMap(sessionMap("cancelled", lastState))),
        )
        finish()
    }

    private fun sessionMap(reason: String, state: RppgMeasurementState?): Map<String, Any?> {
        val completedAt = System.currentTimeMillis()
        val startedAt = startedAtEpochMillis ?: completedAt
        return linkedMapOf(
            "sessionId" to sessionId,
            "startedAt" to startedAt,
            "completedAt" to completedAt,
            "source" to SOURCE,
            "deviceId" to DEVICE_ID,
            "schemaVersion" to SCHEMA_VERSION,
            "completionReason" to reason,
            "demoOnly" to false,
            "estimateSamples" to ArrayList(estimates.values),
            "summary" to summaryMap(state),
            "message" to state?.message,
        )
    }

    private fun estimateSampleMap(snapshot: RppgEstimateSnapshot): Map<String, Any?> = linkedMapOf(
        "timestamp" to snapshot.producedAtEpochMillis,
        "heartRate" to snapshot.heartRate.value,
        "heartRateConfidence" to snapshot.heartRate.confidence,
        "respiratoryRate" to snapshot.respiration.value,
        "respiratoryRateConfidence" to snapshot.respiration.confidence,
        "aggregateQuality" to snapshot.aggregateQuality,
        "scheduledSecond" to snapshot.scheduledSecond,
    )

    private fun summaryMap(state: RppgMeasurementState?): Map<String, Any?> {
        val heartRate = state?.heartRateEstimate
        val respiration = state?.respirationEstimate
        val aggregateQuality = estimates.values.lastOrNull()?.get("aggregateQuality") as? Double ?: 0.0
        return linkedMapOf(
            "heartRate" to heartRate?.value,
            "heartRateConfidence" to (heartRate?.confidence ?: 0.0),
            "respiratoryRate" to respiration?.value,
            "respiratoryRateConfidence" to (respiration?.confidence ?: 0.0),
            "aggregateQuality" to aggregateQuality,
        )
    }

    companion object {
        const val EXTRA_RESULT = "com.alloop.blue.test.RPPG_RESULT"
        const val SOURCE = "rppg_phone"
        const val DEVICE_ID = "phone_camera"
        const val SCHEMA_VERSION = 1
        private val activeActivity = AtomicReference<RppgMeasurementActivity?>()

        fun cancelActiveMeasurement(): Boolean {
            val activity = activeActivity.get() ?: return false
            activity.runOnUiThread { activity.finishCancelled() }
            return true
        }
    }
}
