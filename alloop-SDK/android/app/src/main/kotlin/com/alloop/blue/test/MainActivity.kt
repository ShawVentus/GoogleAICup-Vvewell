package com.alloop.blue.test

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import com.xiaozhi.ble.AndroidXiaoZhiBleClient
import com.xiaozhi.ble.XiaoZhiBleEvent
import com.xiaozhi.ble.XiaoZhiConnectionState
import com.xiaozhi.ble.XiaoZhiDevice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch

/** Flutter host for the XiaoZhi SDK. Ring plugins are not routed through here. */
class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val xiaoZhi by lazy { AndroidXiaoZhiBleClient(applicationContext) }
    private var eventSink: EventChannel.EventSink? = null
    private var connectionJob: Job? = null
    private var eventJob: Job? = null
    private var radarEventSink: EventChannel.EventSink? = null
    private var robotEventSink: EventChannel.EventSink? = null
    private var pendingRppgResult: MethodChannel.Result? = null
    private var rppgActivityInFlight = false
    private var lastRppgResult: Map<String, Any?>? = null
    private val localHealthDatabase by lazy { LocalHealthDatabaseBridge(applicationContext) }
    private val rokidGlasses by lazy { RokidGlassesBridge(this) }
    private val thermalCamera by lazy { ThermalCameraBridge(this) }
    private val radar by lazy {
        RadarFlutterBridge(applicationContext) { event ->
            runOnUiThread { radarEventSink?.success(event) }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler(::handleMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    observeEvents()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    connectionJob?.cancel()
                    eventJob?.cancel()
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RADAR_METHOD_CHANNEL)
            .setMethodCallHandler(::handleRadarMethodCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCAL_DATABASE_METHOD_CHANNEL)
            .setMethodCallHandler(::handleLocalDatabaseMethodCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RPPG_METHOD_CHANNEL)
            .setMethodCallHandler(::handleRppgMethodCall)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROKID_GLASSES_METHOD_CHANNEL)
            .setMethodCallHandler(::handleRokidGlassesMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ROKID_GLASSES_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    rokidGlasses.setEventSink(sink)
                }

                override fun onCancel(arguments: Any?) {
                    rokidGlasses.setEventSink(null)
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THERMAL_CAMERA_METHOD_CHANNEL)
            .setMethodCallHandler(::handleThermalCameraMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, THERMAL_CAMERA_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    thermalCamera.setEventSink(sink)
                }

                override fun onCancel(arguments: Any?) {
                    thermalCamera.setEventSink(null)
                }
            })
        flutterEngine.platformViewsController.registry.registerViewFactory(
            THERMAL_CAMERA_VIEW_TYPE,
            ThermalCameraViewFactory(thermalCamera),
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RADAR_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    radarEventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    radarEventSink = null
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROBOT_METHOD_CHANNEL)
            .setMethodCallHandler(::handleRobotMethodCall)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ROBOT_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    robotEventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    robotEventSink = null
                }
            })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                when (call.method) {
                    "scan" -> result.success(xiaoZhi.scan().filter { it.name?.startsWith("XIAOZHI", true) == true }.map(::deviceMap))
                    "stopScan" -> { xiaoZhi.stopScan(); result.success(null) }
                    "connect" -> {
                        val args = call.arguments<Map<String, Any?>>() ?: error("Missing XiaoZhi device")
                        val device = XiaoZhiDevice(args.string("address"), args["name"] as String?, args.int("rssi"))
                        Log.i(TAG, "Flutter requested XiaoZhi connect: name=${device.name}, address=${device.address}")
                        xiaoZhi.connect(device)
                        result.success(null)
                    }
                    "disconnect" -> { xiaoZhi.disconnect(); result.success(null) }
                    "readDeviceStatus" -> result.success(xiaoZhi.readDeviceStatus().raw)
                    "readSystemInfo" -> result.success(xiaoZhi.readSystemInfo().raw)
                    "readWifiStatus" -> result.success(xiaoZhi.readWifiStatus().raw)
                    "configureWifi" -> {
                        val args = call.arguments<Map<String, Any?>>() ?: error("Missing Wi-Fi parameters")
                        xiaoZhi.configureWifi(args.string("ssid"), args["password"] as String? ?: "")
                        result.success(null)
                    }
                    "sendCommand" -> {
                        val args = call.arguments<Map<String, Any?>>() ?: error("Missing command")
                        xiaoZhi.sendCommand(args.string("command"), args["paramsJson"] as String? ?: "{}")
                        result.success(null)
                    }
                    "initializeMcp" -> { xiaoZhi.initializeMcp(call.intArgument("requestId", 1)); result.success(null) }
                    "listMcpTools" -> { xiaoZhi.listMcpTools(call.intArgument("requestId", 2)); result.success(null) }
                    "callMcpTool" -> {
                        val args = call.arguments<Map<String, Any?>>() ?: error("Missing MCP tool")
                        xiaoZhi.callMcpTool(
                            args.string("name"),
                            args["argumentsJson"] as String? ?: "{}",
                            (args["requestId"] as? Number)?.toInt() ?: 3,
                        )
                        result.success(null)
                    }
                    "sendMcpRequest" -> {
                        val args = call.arguments<Map<String, Any?>>() ?: error("Missing MCP request")
                        xiaoZhi.sendMcpRequest(args.string("requestJson"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                Log.e(TAG, "XiaoZhi platform call failed: ${call.method}", error)
                result.error("XIAOZHI_BLE_ERROR", error.message, null)
            }
        }
    }

    private fun handleRadarMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(radar.handle(call))
            } catch (error: Throwable) {
                Log.e(TAG, "Radar platform call failed: ${call.method}", error)
                result.error("RADAR_BLE_ERROR", error.message, null)
            }
        }
    }

    private fun handleRobotMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val value = robot.handle(call)
            if (value === RobotFlutterBridge.NOT_IMPLEMENTED) {
                result.notImplemented()
            } else {
                result.success(value)
            }
        } catch (error: Throwable) {
            Log.e(TAG, "Robot platform call failed: ${call.method}", error)
            result.error("ROBOT_BLE_ERROR", error.message, null)
        }
    }
    private val robot by lazy {
        RobotFlutterBridge(applicationContext) { event ->
            runOnUiThread { robotEventSink?.success(event) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        thermalCamera.onHostCreate()
    }

    override fun onStart() {
        super.onStart()
        thermalCamera.onHostStart()
    }

    override fun onResume() {
        super.onResume()
        thermalCamera.onHostResume()
    }

    override fun onPause() {
        thermalCamera.onHostPause()
        super.onPause()
    }

    override fun onStop() {
        thermalCamera.onHostStop()
        super.onStop()
    }

    private fun handleRokidGlassesMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        try {
            rokidGlasses.handle(call, result)
        } catch (error: Throwable) {
            Log.e(TAG, "Rokid glasses platform call failed: ${call.method}", error)
            result.error("ROKID_GLASSES_ERROR", error.message, null)
        }
    }

    private fun handleThermalCameraMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        scope.launch {
            try {
                val value = thermalCamera.handle(call)
                if (value === ThermalCameraBridge.NOT_IMPLEMENTED) {
                    result.notImplemented()
                } else {
                    result.success(value)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Thermal camera platform call failed: ${call.method}", error)
                result.error("THERMAL_CAMERA_ERROR", error.message, null)
            }
        }
    }


    private fun handleRppgMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isAvailable" -> result.success(isRppgAvailable())
                "startMeasurement" -> startRppgMeasurement(result)
                "cancelMeasurement" -> result.success(RppgMeasurementActivity.cancelActiveMeasurement())
                "getLastResult" -> result.success(lastRppgResult)
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            Log.e(TAG, "rPPG platform call failed: ${call.method}", error)
            result.error("RPPG_PHONE_ERROR", error.message, null)
        }
    }

    private fun isRppgAvailable(): Boolean {
        val hasFrontCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
        val hasModel = runCatching {
            assets.open("rppg/model.onnx").use { }
            assets.open("rppg/state.json").use { }
            true
        }.getOrDefault(false)
        return hasFrontCamera && hasModel
    }

    @Suppress("DEPRECATION")
    private fun startRppgMeasurement(result: MethodChannel.Result) {
        if (pendingRppgResult != null || rppgActivityInFlight) {
            result.error("RPPG_ALREADY_RUNNING", "An rPPG measurement is already running", null)
            return
        }
        pendingRppgResult = result
        rppgActivityInFlight = true
        try {
            startActivityForResult(
                Intent(this, RppgMeasurementActivity::class.java),
                RPPG_REQUEST_CODE,
            )
        } catch (error: Throwable) {
            rppgActivityInFlight = false
            pendingRppgResult = null
            throw error
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (rokidGlasses.onActivityResult(requestCode, resultCode, data)) return
        if (requestCode != RPPG_REQUEST_CODE) return
        val payload = data?.rppgResultExtra() ?: mapOf(
            "sessionId" to "",
            "startedAt" to System.currentTimeMillis(),
            "completedAt" to System.currentTimeMillis(),
            "source" to RppgMeasurementActivity.SOURCE,
            "deviceId" to RppgMeasurementActivity.DEVICE_ID,
            "schemaVersion" to RppgMeasurementActivity.SCHEMA_VERSION,
            "completionReason" to "cancelled",
            "demoOnly" to false,
            "estimateSamples" to emptyList<Map<String, Any?>>(),
            "summary" to mapOf(
                "heartRate" to null,
                "heartRateConfidence" to 0.0,
                "respiratoryRate" to null,
                "respiratoryRateConfidence" to 0.0,
                "aggregateQuality" to 0.0,
            ),
        )
        lastRppgResult = payload
        val pendingResult = pendingRppgResult
        pendingRppgResult = null
        rppgActivityInFlight = false
        pendingResult?.success(payload)
    }

    override fun onDestroy() {
        rokidGlasses.dispose()
        thermalCamera.dispose()
        thermalCamera.onHostDestroy()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun Intent.rppgResultExtra(): Map<String, Any?>? =
        (getSerializableExtra(RppgMeasurementActivity.EXTRA_RESULT) as? Map<*, *>)
            ?.mapKeys { it.key.toString() }

    private fun handleLocalDatabaseMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                result.success(localHealthDatabase.handle(call))
            } catch (error: Throwable) {
                Log.e(TAG, "Local database call failed: ${call.method}", error)
                result.error("LOCAL_DATABASE_ERROR", error.message, null)
            }
        }
    }

    private fun observeEvents() {
        connectionJob?.cancel()
        eventJob?.cancel()
        connectionJob = scope.launch {
            xiaoZhi.connection.collect { state -> emit(mapOf("kind" to "connection", "state" to stateName(state), "detail" to state.toString())) }
        }
        eventJob = scope.launch {
            xiaoZhi.events.collect { event ->
                when (event) {
                    is XiaoZhiBleEvent.DeviceStatus -> emit(mapOf("kind" to "deviceStatus", "payload" to event.payload.raw))
                    is XiaoZhiBleEvent.CommandResponse -> emit(mapOf("kind" to "commandResponse", "payload" to event.payload.raw))
                    is XiaoZhiBleEvent.McpResponse -> emit(mapOf("kind" to "mcpResponse", "payload" to event.response.rawJson, "requestId" to event.response.messageId))
                    is XiaoZhiBleEvent.ConnectionLost -> emit(mapOf("kind" to "connectionLost", "payload" to event.reason))
                }
            }
        }
    }

    private fun emit(value: Map<String, Any?>) = eventSink?.success(value)
    private fun deviceMap(device: XiaoZhiDevice) = mapOf("address" to device.address, "name" to device.name, "rssi" to device.rssi)
    private fun stateName(state: XiaoZhiConnectionState) = when (state) {
        XiaoZhiConnectionState.Disconnected -> "disconnected"
        is XiaoZhiConnectionState.Connecting -> "connecting"
        is XiaoZhiConnectionState.Pairing -> "pairing"
        is XiaoZhiConnectionState.Ready -> "ready"
        is XiaoZhiConnectionState.Failed -> "failed"
    }
    private fun Map<String, Any?>.string(name: String) = this[name] as? String ?: error("Missing $name")
    private fun Map<String, Any?>.int(name: String) = (this[name] as? Number)?.toInt() ?: -127
    private fun MethodCall.intArgument(name: String, fallback: Int) = (argument<Number>(name))?.toInt() ?: fallback

    companion object {
        private const val METHOD_CHANNEL = "alloop/xiaozhi_ble"
        private const val EVENT_CHANNEL = "alloop/xiaozhi_ble/events"
        private const val RADAR_METHOD_CHANNEL = "alloop/radar_ble"
        private const val RADAR_EVENT_CHANNEL = "alloop/radar_ble/events"
        private const val ROBOT_METHOD_CHANNEL = "alloop/robot_ble"
        private const val ROBOT_EVENT_CHANNEL = "alloop/robot_ble/events"
        private const val LOCAL_DATABASE_METHOD_CHANNEL = "alloop/local_health_database"
        private const val RPPG_METHOD_CHANNEL = "alloop/rppg_phone"
        private const val ROKID_GLASSES_METHOD_CHANNEL = "alloop/rokid_glasses"
        private const val ROKID_GLASSES_EVENT_CHANNEL = "alloop/rokid_glasses/events"
        private const val THERMAL_CAMERA_METHOD_CHANNEL = "alloop/thermal_camera"
        private const val THERMAL_CAMERA_EVENT_CHANNEL = "alloop/thermal_camera/events"
        private const val THERMAL_CAMERA_VIEW_TYPE = "alloop/thermal_camera_view"
        private const val RPPG_REQUEST_CODE = 4203
        private const val TAG = "XiaoZhiBridge"
    }
}
