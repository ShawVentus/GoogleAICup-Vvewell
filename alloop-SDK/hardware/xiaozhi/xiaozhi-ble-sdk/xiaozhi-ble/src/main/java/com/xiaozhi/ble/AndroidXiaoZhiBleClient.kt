@file:Suppress("DEPRECATION")

package com.xiaozhi.ble

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.ParcelUuid
import android.util.Log
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.nio.charset.StandardCharsets
import java.util.UUID
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Android framework implementation. All GATT reads, writes, descriptors, and MTU requests
 * are processed one at a time, which is required by Android's BluetoothGatt implementation.
 */
class AndroidXiaoZhiBleClient(context: Context) : XiaoZhiBleClient {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val adapter: BluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        ?: error("This device does not support Bluetooth")
    private val scanner: BluetoothLeScanner
        get() = adapter.bluetoothLeScanner ?: error("Bluetooth is disabled")

    private val _connection = MutableStateFlow<XiaoZhiConnectionState>(XiaoZhiConnectionState.Disconnected)
    override val connection: StateFlow<XiaoZhiConnectionState> = _connection.asStateFlow()
    private val _events = MutableSharedFlow<XiaoZhiBleEvent>(extraBufferCapacity = 32)
    override val events: SharedFlow<XiaoZhiBleEvent> = _events.asSharedFlow()

    private val operations = Channel<GattOperation>(Channel.UNLIMITED)
    private val mcpAssembler = McpFrameAssembler()
    private var gatt: BluetoothGatt? = null
    private var connected = CompletableDeferred<Unit>()
    private var servicesReady = CompletableDeferred<Unit>()
    private var activeOperation: GattOperation? = null
    private var currentDevice: XiaoZhiDevice? = null
    private var currentMtu = 23
    private var activeScanCallback: ScanCallback? = null
    private var activeScanContinuation: CancellableContinuation<List<XiaoZhiDevice>>? = null
    private var activeScanDevices: LinkedHashMap<String, XiaoZhiDevice>? = null

    init {
        scope.launch {
            for (operation in operations) {
                activeOperation = operation
                val started = startOperation(operation)
                if (!started) {
                    operation.result.completeExceptionally(IllegalStateException("BluetoothGatt rejected ${operation.kind}"))
                }
                try {
                    operation.result.await()
                } finally {
                    activeOperation = null
                }
            }
        }
    }

    override suspend fun scan(timeoutMillis: Long): List<XiaoZhiDevice> = suspendCancellableCoroutine { continuation ->
        assertScanPermission()
        // Android only supports a limited number of concurrent scan clients.
        // Finish the prior one before a new host scan starts.
        stopActiveScan()
        val discovered = linkedMapOf<String, XiaoZhiDevice>()
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val name = result.scanRecord?.deviceName ?: result.device.name
                val isNew = discovered.put(result.device.address, XiaoZhiDevice(result.device.address, name, result.rssi)) == null
                if (isNew && name?.startsWith("XIAOZHI", ignoreCase = true) == true) {
                    Log.i(TAG, "Discovered XiaoZhi: name=$name, address=${result.device.address}, rssi=${result.rssi}")
                }
            }

            override fun onScanFailed(errorCode: Int) {
                finishActiveScan(IllegalStateException("BLE scan failed: $errorCode"))
            }
        }
        activeScanCallback = callback
        activeScanContinuation = continuation
        activeScanDevices = discovered
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        scanner.startScan(null, settings, callback)
        scope.launch {
            delay(timeoutMillis)
            finishScan(callback, continuation, discovered)
        }
        continuation.invokeOnCancellation { finishScan(callback, continuation, discovered) }
    }

    override suspend fun stopScan() {
        stopActiveScan()
    }

    private fun stopActiveScan() {
        finishActiveScan()
    }

    private fun finishActiveScan(error: Throwable? = null) {
        val callback = activeScanCallback ?: return
        val continuation = activeScanContinuation ?: return
        val devices = activeScanDevices ?: linkedMapOf()
        finishScan(callback, continuation, devices, error)
    }

    private fun finishScan(
        callback: ScanCallback,
        continuation: CancellableContinuation<List<XiaoZhiDevice>>,
        devices: LinkedHashMap<String, XiaoZhiDevice>,
        error: Throwable? = null,
    ) {
        if (activeScanCallback !== callback) return
        activeScanCallback = null
        activeScanContinuation = null
        activeScanDevices = null
        runCatching { scanner.stopScan(callback) }
        if (!continuation.isActive) return
        if (error == null) {
            Log.i(TAG, "XiaoZhi scan completed: ${devices.size} devices")
            continuation.resume(devices.values.sortedByDescending { it.rssi })
        } else {
            continuation.resumeWithException(error)
        }
    }

    override suspend fun connect(device: XiaoZhiDevice) {
        assertConnectPermission()
        disconnect()
        currentDevice = device
        currentMtu = 23
        connected = CompletableDeferred()
        servicesReady = CompletableDeferred()
        val remote = adapter.getRemoteDevice(device.address)
        try {
            // XiaoZhi's control characteristics are encrypted. Match the
            // working desktop test client: establish the Just Works bond
            // before creating the GATT connection, avoiding an
            // unauthenticated service-discovery/CCCD race on Android.
            _connection.value = XiaoZhiConnectionState.Pairing(device.address)
            Log.i(TAG, "Pairing XiaoZhi before GATT connect: ${device.address}")
            withTimeout(CONNECT_TIMEOUT_MS) { ensureBond(remote) }
            _connection.value = XiaoZhiConnectionState.Connecting(device.address)
            Log.i(TAG, "Connecting XiaoZhi GATT: ${device.address}")
            gatt = remote.connectGatt(appContext, false, callback, BluetoothDevice.TRANSPORT_LE)
                ?: error("Unable to create BluetoothGatt")
            withTimeout(CONNECT_TIMEOUT_MS) { connected.await() }
            withTimeout(CONNECT_TIMEOUT_MS) { servicesReady.await() }
            requestMtu(247)
            subscribe(XiaoZhiBleProtocol.DEVICE_STATUS_UUID)
            subscribe(XiaoZhiBleProtocol.COMMAND_RESPONSE_UUID)
            subscribe(XiaoZhiBleProtocol.MCP_RESPONSE_UUID)
            _connection.value = XiaoZhiConnectionState.Ready(device, currentMtu)
            Log.i(TAG, "XiaoZhi ready: ${device.address}, mtu=$currentMtu")
        } catch (error: Throwable) {
            Log.e(TAG, "XiaoZhi connect failed: ${device.address}", error)
            _connection.value = XiaoZhiConnectionState.Failed(error.message ?: "BLE connection failed")
            disconnect()
            throw error
        }
    }

    override suspend fun disconnect() {
        val oldGatt = gatt
        gatt = null
        mcpAssembler.clear()
        activeOperation?.result?.completeExceptionally(IllegalStateException("Bluetooth disconnected"))
        while (true) operations.tryReceive().getOrNull()?.result?.completeExceptionally(IllegalStateException("Bluetooth disconnected")) ?: break
        oldGatt?.disconnect()
        oldGatt?.close()
        currentDevice = null
        _connection.value = XiaoZhiConnectionState.Disconnected
    }

    override suspend fun readDeviceStatus(): XiaoZhiJsonPayload = readJson(XiaoZhiBleProtocol.DEVICE_STATUS_UUID)
    override suspend fun readSystemInfo(): XiaoZhiJsonPayload = readJson(XiaoZhiBleProtocol.SYSTEM_INFO_UUID)
    override suspend fun readWifiStatus(): XiaoZhiJsonPayload = readJson(XiaoZhiBleProtocol.WIFI_CONFIG_UUID)

    override suspend fun configureWifi(ssid: String, password: String) {
        require(ssid.isNotBlank()) { "SSID must not be empty" }
        val json = JSONObject().put("ssid", ssid).put("password", password).toString()
        write(XiaoZhiBleProtocol.WIFI_CONFIG_UUID, json.toByteArray(StandardCharsets.UTF_8))
    }

    override suspend fun sendCommand(command: String, paramsJson: String) {
        val params = JSONObject(paramsJson)
        val packet = JSONObject().put("command", command).put("params", params).toString()
        write(XiaoZhiBleProtocol.COMMAND_UUID, packet.toByteArray(StandardCharsets.UTF_8))
    }

    override suspend fun initializeMcp(requestId: Int) =
        sendMcpRequest(JSONObject().put("jsonrpc", "2.0").put("id", requestId).put("method", "initialize").put("params", JSONObject().put("capabilities", JSONObject())).toString())

    override suspend fun listMcpTools(requestId: Int, withUserTools: Boolean) =
        sendMcpRequest(JSONObject().put("jsonrpc", "2.0").put("id", requestId).put("method", "tools/list").put("params", JSONObject().put("withUserTools", withUserTools)).toString())

    override suspend fun callMcpTool(name: String, argumentsJson: String, requestId: Int) =
        sendMcpRequest(JSONObject().put("jsonrpc", "2.0").put("id", requestId).put("method", "tools/call").put("params", JSONObject().put("name", name).put("arguments", JSONObject(argumentsJson))).toString())

    override suspend fun sendMcpRequest(requestJson: String) {
        val request = JSONObject(requestJson) // Validate before writing to the peripheral.
        sendCommand("mcp", JSONObject().put("request", request).toString())
    }

    private suspend fun readJson(uuid: String): XiaoZhiJsonPayload =
        XiaoZhiBleProtocol.utf8(enqueue(GattOperation.read(uuid)))

    private suspend fun write(uuid: String, value: ByteArray) {
        enqueue(GattOperation.write(uuid, value))
    }

    private suspend fun subscribe(uuid: String) {
        enqueue(GattOperation.subscribe(uuid))
    }

    private suspend fun requestMtu(mtu: Int) {
        runCatching { enqueue(GattOperation.mtu(mtu)) }
    }

    private suspend fun enqueue(operation: GattOperation): ByteArray {
        operations.send(operation)
        return operation.result.await()
    }

    private fun startOperation(operation: GattOperation): Boolean {
        val activeGatt = gatt ?: return false
        val service = activeGatt.getService(UUID.fromString(XiaoZhiBleProtocol.SERVICE_UUID)) ?: return false
        return when (operation.kind) {
            GattOperation.Kind.READ -> service.characteristic(operation.uuid)?.let(activeGatt::readCharacteristic) ?: false
            GattOperation.Kind.WRITE -> service.characteristic(operation.uuid)?.let { characteristic ->
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                characteristic.value = operation.value
                activeGatt.writeCharacteristic(characteristic)
            } ?: false
            GattOperation.Kind.SUBSCRIBE -> service.characteristic(operation.uuid)?.let { characteristic ->
                if (!activeGatt.setCharacteristicNotification(characteristic, true)) return false
                val descriptor = characteristic.getDescriptor(UUID.fromString(XiaoZhiBleProtocol.CCCD_UUID)) ?: return false
                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                activeGatt.writeDescriptor(descriptor)
            } ?: false
            GattOperation.Kind.MTU -> activeGatt.requestMtu(operation.mtu)
        }
    }

    private suspend fun ensureBond(device: BluetoothDevice) = suspendCancellableCoroutine { continuation ->
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            continuation.resume(Unit)
            return@suspendCancellableCoroutine
        }
        var registered = true
        var pollJob: Job? = null
        lateinit var receiver: BroadcastReceiver
        fun unregister() {
            if (registered) {
                registered = false
                runCatching { appContext.unregisterReceiver(receiver) }
            }
        }
        fun finish(error: Throwable? = null) {
            unregister()
            pollJob?.cancel()
            if (!continuation.isActive) return
            if (error == null) {
                Log.i(TAG, "XiaoZhi bond completed: ${device.address}")
                continuation.resume(Unit)
            } else {
                continuation.resumeWithException(error)
            }
        }
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED || intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)?.address != device.address) return
                val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
                Log.i(TAG, "XiaoZhi bond broadcast: ${device.address}, state=$state")
                when (state) {
                    BluetoothDevice.BOND_BONDED -> finish()
                    BluetoothDevice.BOND_NONE -> finish(IllegalStateException("BLE pairing was cancelled or failed"))
                }
            }
        }
        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) appContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED) else appContext.registerReceiver(receiver, filter)
        continuation.invokeOnCancellation { unregister() }
        if (device.bondState == BluetoothDevice.BOND_NONE && !device.createBond() && device.bondState == BluetoothDevice.BOND_NONE) {
            finish(IllegalStateException("Android refused to start BLE pairing"))
            return@suspendCancellableCoroutine
        }
        // Some Vivo Bluetooth stacks update BluetoothDevice.bondState but do
        // not deliver ACTION_BOND_STATE_CHANGED to dynamically registered
        // non-exported receivers. Polling is a safe fallback for that case.
        pollJob = scope.launch {
            while (continuation.isActive) {
                when (device.bondState) {
                    BluetoothDevice.BOND_BONDED -> {
                        Log.i(TAG, "XiaoZhi bond detected by state poll: ${device.address}")
                        finish()
                        return@launch
                    }
                }
                delay(BOND_POLL_INTERVAL_MS)
            }
        }
    }

    private fun completeActive(kind: GattOperation.Kind, data: ByteArray = ByteArray(0), status: Int) {
        val operation = activeOperation ?: return
        if (operation.kind != kind) return
        if (status == BluetoothGatt.GATT_SUCCESS) operation.result.complete(data)
        else operation.result.completeExceptionally(IllegalStateException("GATT ${kind.name.lowercase()} failed: 0x${status.toString(16)}"))
    }

    private fun handleNotification(characteristic: BluetoothGattCharacteristic, value: ByteArray) {
        when (characteristic.uuid.toString()) {
            XiaoZhiBleProtocol.DEVICE_STATUS_UUID -> _events.tryEmit(XiaoZhiBleEvent.DeviceStatus(XiaoZhiBleProtocol.utf8(value)))
            XiaoZhiBleProtocol.COMMAND_RESPONSE_UUID -> _events.tryEmit(XiaoZhiBleEvent.CommandResponse(XiaoZhiBleProtocol.utf8(value)))
            XiaoZhiBleProtocol.MCP_RESPONSE_UUID -> mcpAssembler.accept(value)?.let { _events.tryEmit(XiaoZhiBleEvent.McpResponse(it)) }
        }
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (gatt !== this@AndroidXiaoZhiBleClient.gatt) {
                gatt.close()
                return
            }
            if (status == BluetoothGatt.GATT_SUCCESS && newState == BluetoothProfile.STATE_CONNECTED) {
                connected.complete(Unit)
                if (!gatt.discoverServices()) servicesReady.completeExceptionally(IllegalStateException("Service discovery could not start"))
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                val reason = "GATT disconnected: status=0x${status.toString(16)}"
                connected.completeExceptionally(IllegalStateException(reason))
                servicesReady.completeExceptionally(IllegalStateException(reason))
                activeOperation?.result?.completeExceptionally(IllegalStateException(reason))
                _events.tryEmit(XiaoZhiBleEvent.ConnectionLost(reason))
                _connection.value = XiaoZhiConnectionState.Disconnected
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (gatt !== this@AndroidXiaoZhiBleClient.gatt) return
            if (status == BluetoothGatt.GATT_SUCCESS && gatt.getService(UUID.fromString(XiaoZhiBleProtocol.SERVICE_UUID)) != null) servicesReady.complete(Unit)
            else servicesReady.completeExceptionally(IllegalStateException("XiaoZhi GATT service was not found"))
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) =
            completeActive(GattOperation.Kind.READ, characteristic.value ?: ByteArray(0), status)

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray, status: Int) =
            completeActive(GattOperation.Kind.READ, value, status)

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) =
            completeActive(GattOperation.Kind.WRITE, status = status)

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) =
            completeActive(GattOperation.Kind.SUBSCRIBE, status = status)

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) currentMtu = mtu
            completeActive(GattOperation.Kind.MTU, status = status)
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) =
            handleNotification(characteristic, characteristic.value ?: ByteArray(0))

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) =
            handleNotification(characteristic, value)
    }

    private fun BluetoothGattService.characteristic(uuid: String): BluetoothGattCharacteristic? =
        getCharacteristic(UUID.fromString(uuid))

    private fun assertScanPermission() {
        if (Build.VERSION.SDK_INT >= 31 && appContext.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("BLUETOOTH_SCAN permission is required")
        }
    }

    private fun assertConnectPermission() {
        if (Build.VERSION.SDK_INT >= 31 && appContext.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            throw SecurityException("BLUETOOTH_CONNECT permission is required")
        }
    }

    private companion object {
        const val TAG = "XiaoZhiBle"
        const val CONNECT_TIMEOUT_MS = 40_000L
        const val BOND_POLL_INTERVAL_MS = 200L
    }

    private class GattOperation private constructor(
        val kind: Kind,
        val uuid: String = "",
        val value: ByteArray = ByteArray(0),
        val mtu: Int = 0,
        val result: CompletableDeferred<ByteArray> = CompletableDeferred(),
    ) {
        enum class Kind { READ, WRITE, SUBSCRIBE, MTU }
        companion object {
            fun read(uuid: String) = GattOperation(Kind.READ, uuid)
            fun write(uuid: String, value: ByteArray) = GattOperation(Kind.WRITE, uuid, value)
            fun subscribe(uuid: String) = GattOperation(Kind.SUBSCRIBE, uuid)
            fun mtu(value: Int) = GattOperation(Kind.MTU, mtu = value)
        }
    }
}
