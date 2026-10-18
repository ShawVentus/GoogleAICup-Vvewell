package com.alloop.radar.bridge

import java.util.concurrent.CopyOnWriteArrayList

/**
 * Stable application-facing API. The caller owns scanning and selects a
 * transport; this class owns HIF framing, report decoding, and radar commands.
 */
class RadarBridge(
    private val estimateVitalMetrics: Boolean = true,
    private val vitalEstimator: VitalEstimator = VitalEstimator()
) {
    private val listeners = CopyOnWriteArrayList<RadarListener>()
    private val parser = HifStreamParser()
    private var transport: RadarTransport? = null

    private val transportListener = object : RadarTransport.Listener {
        override fun onStateChanged(state: RadarConnectionState) {
            if (state == RadarConnectionState.CONNECTING || state == RadarConnectionState.DISCONNECTED || state == RadarConnectionState.ERROR) {
                parser.reset()
                vitalEstimator.reset()
            }
            listeners.forEach { it.onStateChanged(state) }
        }

        override fun onBytesReceived(bytes: ByteArray) {
            val badBefore = parser.badFrames
            parser.feed(bytes).forEach(::handleFrame)
            if (parser.badFrames > badBefore) {
                listeners.forEach { it.onProtocolError("Dropped ${parser.badFrames - badBefore} invalid HIF frame(s)") }
            }
        }

        override fun onError(error: Throwable) {
            listeners.forEach { it.onTransportError(error) }
        }
    }

    fun addListener(listener: RadarListener) { listeners += listener }
    fun removeListener(listener: RadarListener) { listeners -= listener }

    fun attach(transport: RadarTransport) {
        this.transport?.setListener(null)
        this.transport = transport
        transport.setListener(transportListener)
    }

    fun connect(device: android.bluetooth.BluetoothDevice) {
        requireNotNull(transport) { "Attach a RadarTransport before connect" }.connect(device)
    }

    fun disconnect() { transport?.disconnect() }

    fun wakeup(): Boolean = write(HifProtocol.wakeup())
    fun start(): Boolean = write(HifProtocol.startRadar())
    fun stop(): Boolean = write(HifProtocol.stopRadar())
    fun configureVital(config: VitalConfig): Boolean = write(HifProtocol.setOutput(config))
    fun queryVitalConfig(): Boolean = write(HifProtocol.getOutput())
    fun selectVitalBinAutomatically(): Boolean = write(HifProtocol.autoSelectOutput())

    /** Escape hatch for future firmware commands while retaining HIF framing. */
    fun sendHif(messageId: Int, payload: ByteArray): Boolean = write(HifProtocol.packet(messageId, payload))

    private fun write(bytes: ByteArray): Boolean = transport?.write(bytes) == true

    private fun handleFrame(frame: HifFrame) {
        listeners.forEach { it.onRawHifFrame(frame) }
        if (frame.type == HifProtocol.TYPE_RESPONSE && frame.payload.isNotEmpty()) {
            listeners.forEach { it.onHifResponse(HifResponse(frame.messageId, frame.payload[0].toInt() and 0xFF, frame.payload.copyOfRange(1, frame.payload.size))) }
        }
        when (frame.messageId) {
            HifProtocol.MSG_ID_POINT_CLOUD -> HifProtocol.decodePointCloud(frame.payload)?.let { cloud -> listeners.forEach { it.onPointCloud(cloud) } }
            HifProtocol.MSG_ID_VITAL_SAMPLE -> HifProtocol.decodeVitalSample(frame.payload)?.let { sample ->
                listeners.forEach { it.onVitalSample(sample) }
                if (estimateVitalMetrics) vitalEstimator.add(sample)?.let { metrics -> listeners.forEach { it.onVitalMetrics(metrics) } }
            }
        }
    }
}
