package com.alloop.radar.bridge

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.ArrayDeque
import java.util.UUID

data class RadarGattProfile(
    val serviceUuid: UUID,
    val writeCharacteristicUuid: UUID,
    val notifyCharacteristicUuid: UUID,
    val writeType: Int = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
    val maxWriteBytes: Int = 20,
    /** Some JDY-23 firmware omits CCCD or never sends its write callback. */
    val allowReadyWithoutCccdCallback: Boolean = false
)

/**
 * Android framework GATT implementation. UUIDs are intentionally injected,
 * because JDY-23 carrier boards and vendor BLE UART SDKs use different UUIDs.
 */
class AndroidGattTransport(
    private val context: Context,
    private var profile: RadarGattProfile,
    private val mainHandler: Handler = Handler(Looper.getMainLooper())
) : RadarTransport {
    private var callback: RadarTransport.Listener? = null
    private var gatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null
    private val pendingWrites = ArrayDeque<ByteArray>()
    private var activeWrite: ByteArray? = null
    private var activeOffset = 0
    private var writeInFlight = false
    private var notificationDescriptor: BluetoothGattDescriptor? = null
    private val notificationReadyFallback = Runnable {
        if (state == RadarConnectionState.ENABLING_NOTIFICATIONS &&
            profile.allowReadyWithoutCccdCallback
        ) {
            changeState(RadarConnectionState.READY)
        }
    }

    override var state: RadarConnectionState = RadarConnectionState.DISCONNECTED
        private set

    override fun setListener(listener: RadarTransport.Listener?) { callback = listener }

    @SuppressLint("MissingPermission")
    override fun connect(device: BluetoothDevice) {
        closeGatt()
        changeState(RadarConnectionState.CONNECTING)
        try {
            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context, false, gattCallback)
            }
        } catch (error: Throwable) {
            fail(error)
        }
    }

    @SuppressLint("MissingPermission")
    override fun disconnect() {
        changeState(RadarConnectionState.DISCONNECTING)
        try { gatt?.disconnect() } catch (error: Throwable) { fail(error) }
    }

    override fun write(bytes: ByteArray): Boolean {
        if (bytes.isEmpty() || state != RadarConnectionState.READY) return false
        synchronized(pendingWrites) {
            pendingWrites.addLast(bytes.copyOf())
            pumpWrite()
        }
        return true
    }

    @SuppressLint("MissingPermission")
    private fun enableNotifications() {
        val localGatt = gatt ?: return fail(IllegalStateException("GATT is null"))
        var service = localGatt.getService(profile.serviceUuid)
        if (service == null ||
            service.getCharacteristic(profile.writeCharacteristicUuid) == null ||
            service.getCharacteristic(profile.notifyCharacteristicUuid) == null
        ) {
            profile = discoverUartProfile(localGatt)
                ?: return fail(IllegalStateException("Radar UART service not found: ${profile.serviceUuid}"))
            service = localGatt.getService(profile.serviceUuid)
        }
        writeCharacteristic = service.getCharacteristic(profile.writeCharacteristicUuid)
            ?: return fail(IllegalStateException("Radar write characteristic not found"))
        notifyCharacteristic = service.getCharacteristic(profile.notifyCharacteristicUuid)
            ?: return fail(IllegalStateException("Radar notify characteristic not found"))
        if (!localGatt.setCharacteristicNotification(notifyCharacteristic, true)) {
            return fail(IllegalStateException("setCharacteristicNotification returned false"))
        }
        notificationDescriptor = notifyCharacteristic?.getDescriptor(CLIENT_CHARACTERISTIC_CONFIG)
        if (notificationDescriptor == null) {
            if (profile.allowReadyWithoutCccdCallback) {
                // Transparent-UART JDY firmware can expose notifications without
                // a readable CCCD descriptor. The local subscription above is
                // still required; do not tear down an otherwise valid link.
                changeState(RadarConnectionState.READY)
                return
            }
            return fail(IllegalStateException("CCCD descriptor not found"))
        }
        changeState(RadarConnectionState.ENABLING_NOTIFICATIONS)
        notificationDescriptor?.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        if (!localGatt.writeDescriptor(notificationDescriptor)) {
            if (profile.allowReadyWithoutCccdCallback) changeState(RadarConnectionState.READY)
            else fail(IllegalStateException("CCCD write returned false"))
        } else if (profile.allowReadyWithoutCccdCallback) {
            mainHandler.postDelayed(notificationReadyFallback, NOTIFICATION_FALLBACK_DELAY_MS)
        }
    }

    /**
     * JDY-23 carrier boards are commonly FFE0/FFE1, but some batches use
     * Nordic UART UUIDs or a vendor UUID.  Fall back to a non-GATT-standard
     * service which exposes both a notify/indicate and writable characteristic.
     */
    private fun discoverUartProfile(localGatt: BluetoothGatt): RadarGattProfile? {
        val genericServices = setOf(
            UUID.fromString("00001800-0000-1000-8000-00805f9b34fb"),
            UUID.fromString("00001801-0000-1000-8000-00805f9b34fb")
        )
        for (service in localGatt.services) {
            if (service.uuid in genericServices) continue
            val notify = service.characteristics.firstOrNull { characteristic ->
                characteristic.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0
            } ?: continue
            val write = service.characteristics.firstOrNull { characteristic ->
                characteristic.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
            } ?: continue
            val writeType = if (write.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
                BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            } else {
                BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            }
            return RadarGattProfile(
                serviceUuid = service.uuid,
                writeCharacteristicUuid = write.uuid,
                notifyCharacteristicUuid = notify.uuid,
                writeType = writeType,
                maxWriteBytes = 20,
                allowReadyWithoutCccdCallback = profile.allowReadyWithoutCccdCallback
            )
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun pumpWrite() {
        if (writeInFlight || state != RadarConnectionState.READY) return
        if (activeWrite == null) {
            if (pendingWrites.isEmpty()) return
            activeWrite = pendingWrites.removeFirst()
            activeOffset = 0
        }
        val data = activeWrite ?: return
        val end = (activeOffset + profile.maxWriteBytes.coerceAtLeast(1)).coerceAtMost(data.size)
        val chunk = data.copyOfRange(activeOffset, end)
        val characteristic = writeCharacteristic ?: return fail(IllegalStateException("Write characteristic is null"))
        writeInFlight = true
        try {
            val accepted = if (Build.VERSION.SDK_INT >= 33) {
                gatt?.writeCharacteristic(characteristic, chunk, profile.writeType) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.setValue(chunk)
                @Suppress("DEPRECATION")
                gatt?.writeCharacteristic(characteristic) == true
            }
            if (!accepted) {
                writeInFlight = false
                fail(IllegalStateException("GATT characteristic write rejected"))
            }
        } catch (error: Throwable) {
            writeInFlight = false
            fail(error)
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            mainHandler.post {
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail(IllegalStateException("GATT connection status=$status"))
                } else if (newState == BluetoothGatt.STATE_CONNECTED) {
                    changeState(RadarConnectionState.DISCOVERING)
                    try { gatt.discoverServices() } catch (error: Throwable) { fail(error) }
                } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                    closeGatt()
                    changeState(RadarConnectionState.DISCONNECTED)
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            mainHandler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) enableNotifications()
                else fail(IllegalStateException("GATT service discovery status=$status"))
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            mainHandler.post {
                if (status == BluetoothGatt.GATT_SUCCESS && descriptor == notificationDescriptor) changeState(RadarConnectionState.READY)
                else if (profile.allowReadyWithoutCccdCallback) changeState(RadarConnectionState.READY)
                else fail(IllegalStateException("CCCD write status=$status"))
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            if (characteristic.uuid == profile.notifyCharacteristicUuid) callback?.onBytesReceived(characteristic.value ?: ByteArray(0))
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
            if (characteristic.uuid == profile.notifyCharacteristicUuid) callback?.onBytesReceived(value.copyOf())
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            mainHandler.post {
                writeInFlight = false
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    fail(IllegalStateException("GATT write status=$status"))
                    return@post
                }
                activeOffset += (profile.maxWriteBytes.coerceAtLeast(1)).coerceAtMost((activeWrite?.size ?: 0) - activeOffset)
                if (activeWrite != null && activeOffset >= activeWrite!!.size) {
                    activeWrite = null
                    activeOffset = 0
                }
                synchronized(pendingWrites) { pumpWrite() }
            }
        }
    }

    private fun changeState(newState: RadarConnectionState) {
        state = newState
        if (newState != RadarConnectionState.ENABLING_NOTIFICATIONS) mainHandler.removeCallbacks(notificationReadyFallback)
        callback?.onStateChanged(newState)
    }

    private fun fail(error: Throwable) {
        closeGatt()
        changeState(RadarConnectionState.ERROR)
        callback?.onError(error)
    }

    @SuppressLint("MissingPermission")
    private fun closeGatt() {
        synchronized(pendingWrites) {
            pendingWrites.clear()
            activeWrite = null
            activeOffset = 0
            writeInFlight = false
        }
        try { gatt?.close() } catch (_: Throwable) { }
        gatt = null
        writeCharacteristic = null
        notifyCharacteristic = null
        notificationDescriptor = null
    }

    companion object {
        private const val NOTIFICATION_FALLBACK_DELAY_MS = 400L
        val CLIENT_CHARACTERISTIC_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }
}
