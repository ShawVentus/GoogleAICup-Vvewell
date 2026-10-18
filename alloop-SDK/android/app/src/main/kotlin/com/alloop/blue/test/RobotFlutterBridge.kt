package com.alloop.blue.test

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodCall
import java.nio.charset.StandardCharsets
import java.util.UUID

/** Native GATT transport for the vvewell-robot JSON-line BLE protocol. */
class RobotFlutterBridge(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val adapter: BluetoothAdapter?
        get() = context.getSystemService(BluetoothManager::class.java)?.adapter
    private var scanCallback: ScanCallback? = null
    private var gatt: BluetoothGatt? = null
    private var rx: BluetoothGattCharacteristic? = null

    @SuppressLint("MissingPermission")
    fun handle(call: MethodCall): Any? = when (call.method) {
        "scan" -> scan()
        "stopScan" -> { stopScan(); null }
        "connect" -> {
            val address = call.argument<String>("address") ?: error("Missing robot address")
            connect(address)
            null
        }
        "disconnect" -> { disconnect(); null }
        "sendCommand" -> {
            val payload = call.argument<String>("payload") ?: error("Missing command payload")
            send(payload)
            null
        }
        else -> NOT_IMPLEMENTED
    }

    @SuppressLint("MissingPermission")
    private fun scan(): List<Map<String, Any?>> {
        val bluetoothAdapter = adapter ?: error("Bluetooth unavailable")
        if (!bluetoothAdapter.isEnabled) error("Bluetooth is disabled")
        val results = LinkedHashMap<String, Map<String, Any?>>()
        stopScan()
        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val scanRecord = result.scanRecord
                val advertisedName = scanRecord?.deviceName
                    ?: runCatching { result.device.name }.getOrNull()
                val hasRobotService = scanRecord?.serviceUuids
                    ?.any { it.uuid == SERVICE_UUID } == true
                if (!hasRobotService &&
                    (advertisedName == null || !advertisedName.startsWith(DEVICE_PREFIX, ignoreCase = true))
                ) return
                // Android may hide the local name for an unpaired BLE device.
                // The firmware service UUID remains a stable way to identify it.
                val name = advertisedName ?: DEFAULT_DEVICE_NAME
                results[result.device.address] = mapOf(
                    "address" to result.device.address,
                    "name" to name,
                    "rssi" to result.rssi,
                )
                emit(
                    mapOf(
                        "kind" to "discovery",
                        "address" to result.device.address,
                        "name" to name,
                        "rssi" to result.rssi,
                    ),
                )
            }

            override fun onScanFailed(errorCode: Int) {
                emit(mapOf("kind" to "scanError", "payload" to "Scan failed: $errorCode"))
            }
        }
        bluetoothAdapter.bluetoothLeScanner.startScan(scanCallback)
        // The Flutter unified scan is already timed; this bridge returns the
        // immediate matches and keeps its callback active for that interval.
        return results.values.toList()
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        scanCallback?.let { adapter?.bluetoothLeScanner?.stopScan(it) }
        scanCallback = null
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String) {
        disconnect()
        val device = adapter?.getRemoteDevice(address) ?: error("Bluetooth unavailable")
        emit(mapOf("kind" to "connection", "state" to "connecting"))
        gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
    }

    @SuppressLint("MissingPermission")
    private fun disconnect() {
        rx = null
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        emit(mapOf("kind" to "connection", "state" to "disconnected"))
    }

    @SuppressLint("MissingPermission")
    private fun send(payload: String) {
        val characteristic = rx ?: error("Robot is not ready")
        val value = (payload.trimEnd() + "\n").toByteArray(StandardCharsets.UTF_8)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val status = gatt?.writeCharacteristic(characteristic, value, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE)
            if (status != BluetoothGatt.GATT_SUCCESS) error("Write failed: $status")
        } else {
            characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            characteristic.value = value
            if (gatt?.writeCharacteristic(characteristic) != true) error("Write failed")
        }
    }

    private val callback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                rx = null
                emit(mapOf("kind" to "connection", "state" to "disconnected"))
                gatt.close()
                return
            }
            if (status != BluetoothGatt.GATT_SUCCESS || newState != BluetoothProfile.STATE_CONNECTED) {
                emit(mapOf("kind" to "connection", "state" to "failed", "payload" to "GATT status: $status"))
                gatt.close()
                return
            }
            gatt.discoverServices()
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val service = gatt.getService(SERVICE_UUID)
            val write = service?.getCharacteristic(RX_UUID)
            val notify = service?.getCharacteristic(TX_UUID)
            if (status != BluetoothGatt.GATT_SUCCESS || write == null || notify == null) {
                emit(mapOf("kind" to "connection", "state" to "failed", "payload" to "Robot GATT profile unavailable"))
                gatt.disconnect()
                return
            }
            rx = write
            gatt.setCharacteristicNotification(notify, true)
            val descriptor = notify.getDescriptor(CCCD_UUID)
            if (descriptor == null) {
                emit(mapOf("kind" to "connection", "state" to "connected"))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            } else {
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                gatt.writeDescriptor(descriptor)
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            emit(mapOf("kind" to "connection", "state" to "connected"))
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            emit(mapOf("kind" to "response", "payload" to String(value, StandardCharsets.UTF_8).trim()))
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            emit(mapOf("kind" to "response", "payload" to String(characteristic.value, StandardCharsets.UTF_8).trim()))
        }
    }

    companion object {
        val NOT_IMPLEMENTED = Any()
        private const val DEVICE_PREFIX = "vvewell"
        private const val DEFAULT_DEVICE_NAME = "vvewell-robot"
        private val SERVICE_UUID = UUID.fromString("d6f00001-9a1a-4f8d-a7fd-2e3b2e819001")
        private val RX_UUID = UUID.fromString("d6f00002-9a1a-4f8d-a7fd-2e3b2e819001")
        private val TX_UUID = UUID.fromString("d6f00003-9a1a-4f8d-a7fd-2e3b2e819001")
        private val CCCD_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
