package com.xiaozhi.ble

import java.nio.charset.StandardCharsets

internal object XiaoZhiBleProtocol {
    const val SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
    const val WIFI_CONFIG_UUID = "4fafc202-1fb5-459e-8fcc-c5c9c331914b"
    const val DEVICE_STATUS_UUID = "4fafc203-1fb5-459e-8fcc-c5c9c331914b"
    const val COMMAND_UUID = "4fafc204-1fb5-459e-8fcc-c5c9c331914b"
    const val COMMAND_RESPONSE_UUID = "4fafc205-1fb5-459e-8fcc-c5c9c331914b"
    const val SYSTEM_INFO_UUID = "4fafc206-1fb5-459e-8fcc-c5c9c331914b"
    const val MCP_RESPONSE_UUID = "4fafc207-1fb5-459e-8fcc-c5c9c331914b"
    const val CCCD_UUID = "00002902-0000-1000-8000-00805f9b34fb"

    fun utf8(bytes: ByteArray): XiaoZhiJsonPayload = XiaoZhiJsonPayload(bytes.toString(StandardCharsets.UTF_8))
}

/** Reassembles the XiaoZhi `XZ` version-1 MCP notification frames. */
internal class McpFrameAssembler {
    private data class Pending(val total: Int, val chunks: MutableMap<Int, ByteArray>)
    private val pending = mutableMapOf<Int, Pending>()

    fun clear() = pending.clear()

    fun accept(value: ByteArray): XiaoZhiMcpResponse? {
        if (value.size < 9 || value[0] != 'X'.code.toByte() || value[1] != 'Z'.code.toByte() || value[2] != 1.toByte()) {
            return XiaoZhiMcpResponse(0, value.toString(StandardCharsets.UTF_8))
        }
        val id = u16(value, 3)
        val total = u16(value, 5)
        val index = u16(value, 7)
        if (total == 0 || index >= total) return null
        val message = pending[id]
        val current = if (message == null || message.total != total) Pending(total, mutableMapOf()) else message
        current.chunks[index] = value.copyOfRange(9, value.size)
        pending[id] = current
        if (current.chunks.size != total) return null
        val result = ByteArrayOutputStreamCompat()
        for (position in 0 until total) {
            result.write(current.chunks[position] ?: return null)
        }
        pending.remove(id)
        return XiaoZhiMcpResponse(id, result.toByteArray().toString(StandardCharsets.UTF_8))
    }

    private fun u16(data: ByteArray, offset: Int): Int =
        ((data[offset].toInt() and 0xff) shl 8) or (data[offset + 1].toInt() and 0xff)
}

/** Avoids exposing java.io types from the protocol implementation. */
private class ByteArrayOutputStreamCompat {
    private val values = ArrayList<Byte>()
    fun write(chunk: ByteArray) = chunk.forEach(values::add)
    fun toByteArray(): ByteArray = values.toByteArray()
}
