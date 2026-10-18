package com.alloop.radar.bridge

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Possumic HIF packet builder, streaming parser, and VitalBridge codecs. */
object HifProtocol {
    const val MAGIC = 0xA5
    const val TYPE_TO_DEVICE = 1
    const val TYPE_RESPONSE = 2
    const val FLAG_NEED_ACK = 1 shl 0
    const val FLAG_CHECK32 = 1 shl 2

    const val MSG_ID_POWER = 0x05
    const val MSG_ID_START_CTRL = 0x07
    const val MSG_ID_RADAR_GET = 0x40
    const val MSG_ID_RADAR_CONFIG = 0x41
    const val MSG_ID_VITAL_CONFIG = 0x90
    const val MSG_ID_POINT_CLOUD = 0xC3
    const val MSG_ID_VITAL_SAMPLE = 0xE0

    fun wakeup(): ByteArray = byteArrayOf(0x55, 0xFF.toByte(), 0x55, 0xFF.toByte())

    fun startRadar(): ByteArray = packet(MSG_ID_START_CTRL, byteArrayOf(1))
    fun stopRadar(): ByteArray = packet(MSG_ID_START_CTRL, byteArrayOf(0))
    fun setOutput(config: VitalConfig): ByteArray = packet(MSG_ID_VITAL_CONFIG, vitalConfigPayload(config))
    fun getOutput(): ByteArray = packet(MSG_ID_VITAL_CONFIG, byteArrayOf(0x02))
    fun autoSelectOutput(): ByteArray = packet(MSG_ID_VITAL_CONFIG, byteArrayOf(0x03))

    fun packet(messageId: Int, payload: ByteArray, sequence: Int = 0, needAck: Boolean = true): ByteArray {
        require(messageId in 0..0xFF)
        require(payload.size <= 0xFFF)
        require(sequence in 0..7)
        var header = TYPE_TO_DEVICE
        var flag = if (needAck) FLAG_NEED_ACK else 0
        flag = flag or FLAG_CHECK32
        header = header or ((flag and 0x3F) shl 2)
        header = header or ((messageId and 0xFF) shl 8)
        header = header or ((payload.size and 0xFFF) shl 16)
        header = header or ((sequence and 0x7) shl 28)
        val headerBytes = leInt(header)
        val check8 = ((0xFF - ((MAGIC + headerBytes.sumOf { it.toInt() and 0xFF }) and 0xFF)) and 0xFF)
        val body = headerBytes + payload
        val check32 = leInt(checksum32(body).inv())
        return byteArrayOf(MAGIC.toByte(), check8.toByte()) + body + check32
    }

    fun vitalConfigPayload(config: VitalConfig): ByteArray {
        val mode = if (config.binMode == VitalBinMode.MANUAL) 1 else 0
        return ByteBuffer.allocate(9).order(ByteOrder.LITTLE_ENDIAN)
            .put(0x01.toByte())
            .put(config.outputFlags.toByte())
            .put(mode.toByte())
            .putShort(config.selectedBin.toShort())
            .putShort(config.minBin.toShort())
            .putShort(config.maxBin.toShort())
            .array()
    }

    fun decodeVitalSample(payload: ByteArray): VitalSample? {
        if (payload.size != 20) return null
        val b = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN)
        val version = b.get().toInt() and 0xFF
        val flags = b.get().toInt() and 0xFF
        val rangeBin = b.short.toInt() and 0xFFFF
        val frameIndex = b.int.toLong() and 0xFFFFFFFFL
        val imag = b.short
        val real = b.short
        val magnitude = b.int.toLong() and 0xFFFFFFFFL
        val resolution = b.short.toInt() and 0xFFFF
        val period = b.short.toInt() and 0xFFFF
        if (version != 1 || period <= 0 || resolution <= 0) return null
        return VitalSample(version, flags, rangeBin, frameIndex, imag, real, magnitude, resolution, period)
    }

    fun decodePointCloud(payload: ByteArray): PointCloudFrame? {
        if (payload.size < 12) return null
        val b = ByteBuffer.wrap(payload).order(ByteOrder.LITTLE_ENDIAN)
        val frameIndex = b.int.toLong() and 0xFFFFFFFFL
        val frameWords = b.int.toLong() and 0xFFFFFFFFL
        val offset = b.int.toLong() and 0xFFFFFFFFL
        val points = mutableListOf<PointCloudPoint>()
        while (b.remaining() >= 4) {
            val type = b.get().toInt() and 0xFF
            val tlvFlags = b.get().toInt() and 0xFF
            val length = b.short.toInt() and 0xFFFF
            if (length > b.remaining()) return null
            if (type == 4 && (tlvFlags and 1) != 0 && length % 12 == 0) {
                val end = b.position() + length
                while (b.position() < end) {
                    val x = b.short.toInt()
                    val y = b.short.toInt()
                    val z = b.short.toInt()
                    val velocity = b.short.toInt()
                    val snr = b.short.toInt()
                    val trackId = b.short.toInt()
                    points += PointCloudPoint(
                        x / 100.0, y / 100.0, z / 100.0,
                        velocity / 100.0, snr / 100.0, trackId,
                        (tlvFlags and 2) != 0
                    )
                }
            } else {
                b.position(b.position() + length)
            }
        }
        return PointCloudFrame(frameIndex, frameWords, offset, points)
    }

    private fun leInt(value: Int): ByteArray = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(value).array()

    private fun checksum32(data: ByteArray): Int {
        var result = 0L
        var offset = 0
        while (offset + 4 <= data.size) {
            result = (result + (ByteBuffer.wrap(data, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong() and 0xFFFFFFFFL)) and 0xFFFFFFFFL
            offset += 4
        }
        if (offset < data.size) {
            var tail = 0L
            var shift = 0
            while (offset < data.size) {
                tail = tail or ((data[offset].toInt() and 0xFF).toLong() shl shift)
                offset++
                shift += 8
            }
            result = (result + tail) and 0xFFFFFFFFL
        }
        return result.toInt()
    }
}

class HifStreamParser(private val maxPayload: Int = 4095) {
    private val buffer = ArrayDeque<Byte>()
    var badFrames: Int = 0
        private set

    fun reset() {
        buffer.clear()
        badFrames = 0
    }

    fun feed(bytes: ByteArray): List<HifFrame> {
        bytes.forEach(buffer::addLast)
        val frames = mutableListOf<HifFrame>()
        while (true) {
            while (buffer.isNotEmpty() && (buffer.first().toInt() and 0xFF) != HifProtocol.MAGIC) buffer.removeFirst()
            if (buffer.size < 6) break
            val headerBytes = buffer.toList().toByteArray().copyOfRange(2, 6)
            val expectedCheck8 = ((0xFF - ((HifProtocol.MAGIC + headerBytes.sumOf { it.toInt() and 0xFF }) and 0xFF)) and 0xFF)
            if ((buffer.elementAt(1).toInt() and 0xFF) != expectedCheck8) {
                buffer.removeFirst(); badFrames++; continue
            }
            val header = ByteBuffer.wrap(headerBytes).order(ByteOrder.LITTLE_ENDIAN).int
            val flags = (header ushr 2) and 0x3F
            val payloadLength = (header ushr 16) and 0xFFF
            if (payloadLength > maxPayload) { buffer.removeFirst(); badFrames++; continue }
            val hasCheck32 = (flags and HifProtocol.FLAG_CHECK32) != 0
            val totalLength = 6 + payloadLength + if (hasCheck32) 4 else 0
            if (buffer.size < totalLength) break
            val raw = buffer.toList().toByteArray().copyOfRange(0, totalLength)
            repeat(totalLength) { buffer.removeFirst() }
            val payload = raw.copyOfRange(6, 6 + payloadLength)
            if (hasCheck32) {
                val expected = ByteBuffer.wrap(raw, totalLength - 4, 4).order(ByteOrder.LITTLE_ENDIAN).int
                val actual = HifProtocol.packetChecksumForParser(headerBytes + payload).inv()
                if (expected != actual) { badFrames++; continue }
            }
            frames += HifFrame(header and 0x3, flags, (header ushr 8) and 0xFF, (header ushr 28) and 0x7, payload, raw)
        }
        return frames
    }
}

private fun HifProtocol.packetChecksumForParser(data: ByteArray): Int {
    var result = 0L
    var offset = 0
    while (offset + 4 <= data.size) {
        result = (result + ByteBuffer.wrap(data, offset, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong()) and 0xFFFFFFFFL
        offset += 4
    }
    if (offset < data.size) {
        var tail = 0L
        var shift = 0
        while (offset < data.size) {
            tail = tail or ((data[offset].toInt() and 0xFF).toLong() shl shift)
            offset++; shift += 8
        }
        result = (result + tail) and 0xFFFFFFFFL
    }
    return result.toInt()
}
