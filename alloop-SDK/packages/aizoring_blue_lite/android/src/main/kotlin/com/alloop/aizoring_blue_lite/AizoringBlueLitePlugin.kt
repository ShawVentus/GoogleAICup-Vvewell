package com.alloop.aizoring_blue_lite

import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.alibaba.fastjson.JSON
import com.eiot.aizo.sdk.callback.AizoDeviceConnectCallback
import com.eiot.ringsdk.ServiceSdkCommandV2
import com.eiot.ringsdk.bean.*
import com.eiot.ringsdk.callback.*
import com.eiot.ringsdk.ecg.ECGCallback
import com.eiot.ringsdk.measure.ContinuousMeasureData
import com.tencent.mmkv.MMKV
import kotlinx.coroutines.*
import com.eiot.ringsdk.measure.ContinuousMeasureListener
import com.eiot.ringsdk.measure.MeasureResult
import com.eiot.ringsdk.measure.MeasureResultCallback
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin bridge to the AIZORING [ServiceSdkCommandV2] SDK.
 */
class AizoringBlueLitePlugin :
    FlutterPlugin,
    MethodCallHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val initScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var application: Application? = null
    private var isSdkInitialized = false

    companion object {
        private const val TAG = "AizoringPlugin"
        private val NOOP_SINK = object : EventChannel.EventSink {
            override fun success(event: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun endOfStream() {}
        }
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var scanChannel: EventChannel
    private lateinit var connectionChannel: EventChannel
    private lateinit var deviceStatusChannel: EventChannel
    private lateinit var measurementChannel: EventChannel
    private lateinit var continuousDataChannel: EventChannel
    private lateinit var healthDataChannel: EventChannel
    private lateinit var sleepDataChannel: EventChannel
    private lateinit var ecgChannel: EventChannel

    private var scanSink: EventChannel.EventSink? = null
    private var connectionSink: EventChannel.EventSink? = null
    private var deviceStatusSink: EventChannel.EventSink? = null
    private var measurementSink: EventChannel.EventSink? = null
    private var continuousDataSink: EventChannel.EventSink? = null
    private var healthDataSink: EventChannel.EventSink? = null
    private var sleepDataSink: EventChannel.EventSink? = null
    private var ecgSink: EventChannel.EventSink? = null

    private var isScanning = false

    // ── Plugin lifecycle ────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        application = binding.applicationContext as Application

        methodChannel = MethodChannel(messenger, "aizoring_blue_lite/methods")
        methodChannel.setMethodCallHandler(this)

        scanChannel = EventChannel(messenger, "aizoring_blue_lite/events/scan")
        scanChannel.setStreamHandler(simpleHandler { scanSink = it })

        connectionChannel = EventChannel(messenger, "aizoring_blue_lite/events/connection")
        connectionChannel.setStreamHandler(simpleHandler { connectionSink = it })

        deviceStatusChannel = EventChannel(messenger, "aizoring_blue_lite/events/device_status")
        deviceStatusChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                deviceStatusSink = events
                try {
                    ServiceSdkCommandV2.registerPowerStateListener { bean ->
                        bean?.let { power ->
                            postToSink(deviceStatusSink, mapOf(
                                "batteryPercent" to power.electricity,
                                "isCharging" to (if (power.workingMode == 1) 1 else 0),
                            ))
                        }
                    }
                } catch (_: Exception) {}
            }
            override fun onCancel(arguments: Any?) { deviceStatusSink = null }
        })

        measurementChannel = EventChannel(messenger, "aizoring_blue_lite/events/measurement")
        measurementChannel.setStreamHandler(simpleHandler { measurementSink = it })

        continuousDataChannel = EventChannel(messenger, "aizoring_blue_lite/events/continuous_data")
        continuousDataChannel.setStreamHandler(simpleHandler { continuousDataSink = it })

        healthDataChannel = EventChannel(messenger, "aizoring_blue_lite/events/health_data")
        healthDataChannel.setStreamHandler(simpleHandler { healthDataSink = it })

        sleepDataChannel = EventChannel(messenger, "aizoring_blue_lite/events/sleep_data")
        sleepDataChannel.setStreamHandler(simpleHandler { sleepDataSink = it })

        ecgChannel = EventChannel(messenger, "aizoring_blue_lite/events/ecg")
        ecgChannel.setStreamHandler(simpleHandler { ecgSink = it })

        // Eagerly register connection + config callbacks
        try {
            ServiceSdkCommandV2.addCallback(object : AizoDeviceConnectCallback {
                override fun connect() {
                    postToSink(connectionSink, mapOf("state" to "connected"))
                    // Actively query battery level on connect — the listener only
                    // fires on change, so the initial value must be polled.
                    try { ServiceSdkCommandV2.getInstantPowerState() } catch (_: Exception) {}
                }
                override fun disconnect() = postToSink(connectionSink, mapOf("state" to "disconnected"))
                override fun connectError(throwable: Throwable, state: Int) {
                    postToSink(connectionSink, mapOf(
                        "state" to "disconnected",
                        "errorCode" to (throwable.message ?: "UNKNOWN"),
                        "errorState" to state,
                    ))
                }
            })
        } catch (_: Exception) {}

        try {
            ServiceSdkCommandV2.addDeviceConfigCallback { bean ->
                bean?.let {
                    postToSink(deviceStatusSink, mapOf(
                        "kind" to "deviceConfig",
                        "heartRateMonitoring" to it.heartRateMonitoring,
                        "bloodOxygenMonitoring" to it.bloodOxygenMonitoring,
                        "temperatureMonitoring" to it.temperatureMonitoring,
                        "bloodPressureMonitoring" to it.bloodPressureMonitoring,
                        "bloodSugarMonitoring" to it.bloodSugarMonitoring,
                        "ecgMonitoring" to it.ecgMonitoring,
                        "pressureMonitoring" to it.pressureMonitoring,
                        "moodMonitoring" to it.moodMonitoring,
                        "sleepMonitoring" to it.sleepMonitoring,
                        "breatheMonitoring" to it.breatheMonitoring,
                        "isHeartRateSupport" to it.isHeartRateSupport,
                        "isTouchSet" to it.isTouchSet,
                        "supportWakeupByGesture" to it.supportWakeupByGesture,
                        "supportSos" to it.supportSos,
                        "sosTriggerMode" to it.sosTriggerMode,
                        "vibrate" to it.vibrate,
                        "msgNotify" to it.msgNotify,
                        "sportVersion" to it.sportVersion,
                        "careReminder" to it.careReminder,
                        "supportUltraviolet" to it.supportUltraviolet,
                        "supportVoiceRecord" to it.supportVoiceRecord,
                        "supportBmi" to it.supportBmi,
                    ))
                }
            }
        } catch (_: Exception) {}
    }

    // ── Method dispatch ─────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "initialize" -> handleInit(call, result)
                "startScan" -> handleStartScan(call, result)
                "stopScan" -> handleStopScan(call, result)
                "connect" -> handleConnect(call, result)
                "disconnect" -> handleDisconnect(result)
                "getDeviceInfo" -> handleGetDeviceInfo(result)
                "instantMeasurement" -> handleInstantMeasurement(call, result)
                "startContinuousMeasure" -> handleStartContinuous(call, result)
                "stopContinuousMeasure" -> handleStopContinuous(call, result)
                "getHealthData" -> handleGetHealthData(call, result)
                "getSleepData" -> handleGetSleepData(call, result)
                "startEcgMeasure" -> handleStartEcg(call, result)
                "stopEcgMeasure" -> handleStopEcg(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("PLUGIN_ERROR", e.message, null)
        }
    }

    // ── Init ────────────────────────────────────────────────────────

    private fun handleInit(call: MethodCall, result: Result) {
        val app = application ?: run {
            result.error("NOT_INITIALIZED", "plugin not attached", null)
            return
        }
        if (!isSdkInitialized) {
            try {
                Log.i(TAG, "Starting AIZORING SDK init on main thread...")
                // MMKV must be initialized on the main thread first
                MMKV.initialize(app)
                // ServiceSdkCommandV2.init uses BLE — must run on main thread
                ServiceSdkCommandV2.init(
                    app,
                    region = call.argument<Int>("region") ?: 1,
                    version = call.argument<String>("appVersion") ?: "1.0.0",
                    name = call.argument<String>("appName") ?: "AlloopKit",
                    id = call.argument<String>("appId") ?: "com.alloop.blue.test",
                    country = call.argument<String>("country") ?: "CN",
                    language = call.argument<String>("language") ?: "ZH",
                    debugging = call.argument<Boolean>("debugging") ?: true,
                )
                val btConnectId = call.argument<String>("btConnectId")
                if (!btConnectId.isNullOrEmpty()) {
                    ServiceSdkCommandV2.setBtParm(btConnectId)
                }
                isSdkInitialized = true
                Log.i(TAG, "AIZORING SDK initialized successfully")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "AIZORING SDK init failed: ${e.message}", e)
                result.error("INIT_ERROR", e.message, null)
            }
        } else {
            result.success(null)
        }
    }

    // ── Scan ────────────────────────────────────────────────────────

    private fun handleStartScan(call: MethodCall, result: Result) {
        // Guard: check Bluetooth state before attempting scan
        val btManager = application?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val btAdapter = btManager?.adapter
        if (btAdapter == null || !btAdapter.isEnabled) {
            Log.w(TAG, "Bluetooth is off — cannot start AIZORING scan")
            result.error("BT_OFF", "Bluetooth is turned off. Please enable Bluetooth first.", null)
            return
        }
        if (isScanning) ServiceSdkCommandV2.stopSearchBtDevice()
        isScanning = true
        ServiceSdkCommandV2.searchBtDevice(
            lis = object : OnBluetoothSearchListener {
                override fun start() {
                    Log.i(TAG, "AIZORING BLE scan started")
                    postToSink(scanSink, mapOf("kind" to "scanStart"))
                }
                override fun end() {
                    isScanning = false
                    Log.i(TAG, "AIZORING BLE scan ended")
                    postToSink(scanSink, mapOf("kind" to "scanEnd"))
                }
                override fun search(bluetoothDevice: ExBluetoothDevice) {
                    Log.i(TAG, "AIZORING device found: name=${bluetoothDevice.name}, addr=${bluetoothDevice.address}, rssi=${bluetoothDevice.scanResult?.rssi}")
                    postToSink(scanSink, mapOf(
                        "kind" to "device",
                        "id" to (bluetoothDevice.address ?: ""),
                        "name" to (bluetoothDevice.name ?: ""),
                        "rssi" to (bluetoothDevice.scanResult?.rssi ?: -100),
                    ))
                }
            }
        )
        result.success(null)
    }

    private fun handleStopScan(call: MethodCall, result: Result) {
        isScanning = false
        ServiceSdkCommandV2.stopSearchBtDevice()
        result.success(null)
    }

    // ── Connection ─────────────────────────────────────────────────

    private fun handleConnect(call: MethodCall, result: Result) {
        val btManager = application?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        if (btManager?.adapter?.isEnabled != true) {
            result.error("BT_OFF", "Bluetooth is turned off.", null)
            return
        }
        val mac = call.argument<String>("deviceId") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'deviceId'", null)
            return
        }
        postToSink(connectionSink, mapOf("state" to "connecting"))
        ServiceSdkCommandV2.connect(mac)
        result.success(null)
    }

    private fun handleDisconnect(result: Result) {
        ServiceSdkCommandV2.disconnect { _ -> }
        result.success(null)
    }

    // ── Device info ─────────────────────────────────────────────────

    private fun handleGetDeviceInfo(result: Result) {
        val params = ServiceSdkCommandV2.getFirmwareParams()
        result.success(mapOf(
            "firmwareVersion" to (params?.fwmVersion ?: ""),
            "modelName" to (params?.modelName ?: ""),
            // Power is asynchronous SDK state and arrives through
            // registerPowerStateListener. Do not fabricate zero values here:
            // they would overwrite a previously reported real battery level.
            "brandName" to (params?.brandName ?: ""),
            "productSn" to (params?.productSn ?: "")
        ))
    }

    // ── Instant measurement ─────────────────────────────────────────

    private fun handleInstantMeasurement(call: MethodCall, result: Result) {
        val type = call.argument<Int>("type") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'type'", null)
            return
        }
        val operation = call.argument<Int>("operation") ?: 1
        ServiceSdkCommandV2.instantMeasurement(
            type,
            operation = operation,
            object : MeasureResultCallback {
                override fun measureResult(bean: MeasureResult) {
                    mainHandler.post {
                        postToSink(measurementSink, mapOf(
                            "kind" to "result",
                            "type" to bean.type,
                            "result" to bean.result,
                            "timestamp" to bean.time,
                            "heartRate" to bean.heartrate,
                            "bloodOxygen" to bean.bloodoxygen,
                            "bodyTemp" to (bean.bodytemp ?: 0.0),
                            "envTemp" to (bean.envtemp ?: 0.0),
                            "stress" to (bean.stress ?: 0),
                            "uvi" to (bean.uvi ?: 0),
                        ))
                    }
                }
            }
        )
        // Return immediately — results arrive via EventChannel
        result.success(null)
    }

    // ── Continuous measurement ─────────────────────────────────────

    private fun handleStartContinuous(call: MethodCall, result: Result) {
        val measureType = call.argument<Int>("measureType") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'measureType'", null)
            return
        }
        val measureMode = call.argument<Int>("measureMode") ?: 1
        val timeout = call.argument<Int>("timeout") ?: 0
        ServiceSdkCommandV2.startContinuousMeasure(
            listener = object : ContinuousMeasureListener {
                override fun onStart(resultCode: Int) {
                    postToSink(continuousDataSink, mapOf("kind" to "continuousStart", "result" to resultCode))
                }
                override fun onEnd(resultCode: Int) {
                    postToSink(continuousDataSink, mapOf("kind" to "continuousEnd", "result" to resultCode))
                }
                override fun onReceiveData(data: ContinuousMeasureData) {
                    val map = mutableMapOf<String, Any?>()
                    if (data is ContinuousMeasureData.PpiRawData) {
                        map["kind"] = "ppi"
                        map["samples"] = data.sampleDatas?.map { sample ->
                            mapOf("time" to (sample?.time ?: 0L), "ppi" to (sample?.ppi ?: 0))
                        } ?: emptyList<Map<String, Any?>>()
                    } else if (data is ContinuousMeasureData.LovingRawData) {
                        map["kind"] = "loving"
                        map["startTime"] = data.startTime ?: 0L
                        map["frequency"] = data.frequency ?: 0.0
                        map["samples"] = data.sampleDatas?.map { sample ->
                            mapOf(
                                "time" to (sample?.time ?: 0L),
                                "hr" to (sample?.hr ?: 0),
                                "temp" to (sample?.temp ?: 0.0),
                                "axisX" to (sample?.axis_x ?: 0.0),
                                "axisY" to (sample?.axis_y ?: 0.0),
                                "axisZ" to (sample?.axis_z ?: 0.0),
                            )
                        } ?: emptyList<Map<String, Any?>>()
                    }
                    if (map.isNotEmpty()) postToSink(continuousDataSink, map)
                }
            },
            measureType = measureType,
            measureMode = measureMode,
            timeout = timeout,
        )
        result.success(null)
    }

    private fun handleStopContinuous(call: MethodCall, result: Result) {
        val measureType = call.argument<Int>("measureType") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'measureType'", null)
            return
        }
        ServiceSdkCommandV2.stopContinuousMeasure(measureType)
        result.success(null)
    }

    // ── Health data ─────────────────────────────────────────────────

    private fun handleGetHealthData(call: MethodCall, result: Result) {
        val time = call.argument<Long>("time") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'time'", null)
            return
        }
        ServiceSdkCommandV2.getHealthData(
            time,
            object : HealthDataCallback {
                override fun onFinish(time: Long) {
                    postToSink(healthDataSink, mapOf("kind" to "healthDataComplete", "time" to time))
                }
                override fun onReceive(data: MutableList<HealthDataBean>) {
                    // Pass through as JSON — field names vary by SDK version
                    val json = JSON.toJSONString(data)
                    postToSink(healthDataSink, mapOf("kind" to "healthData", "json" to json))
                }
            }
        )
        result.success(null)
    }

    // ── Sleep data ─────────────────────────────────────────────────

    private fun handleGetSleepData(call: MethodCall, result: Result) {
        val time = call.argument<Long>("time") ?: run {
            result.error("INVALID_ARGUMENT", "missing 'time'", null)
            return
        }
        ServiceSdkCommandV2.getSleepData(
            time,
            object : SleepDataCallback {
                override fun sleepData(bean: MutableList<SleepRecord>) {
                    val json = JSON.toJSONString(bean)
                    postToSink(sleepDataSink, mapOf("kind" to "sleepData", "json" to json))
                }
            }
        )
        result.success(null)
    }

    // ── ECG ─────────────────────────────────────────────────────────

    private fun handleStartEcg(call: MethodCall, result: Result) {
        val wearType = call.argument<Int>("wearType") ?: 0x01
        ServiceSdkCommandV2.startEcgMeasure(
            wearType,
            object : ECGCallback {
                override fun onStart() = postToSink(ecgSink, mapOf("kind" to "ecgStart"))
                override fun onError(errorType: Int) {
                    postToSink(ecgSink, mapOf("kind" to "ecgError", "errorType" to errorType))
                }
                override fun onReceive(data: Pair<DoubleArray, Int>) {
                    postToSink(ecgSink, mapOf(
                        "kind" to "ecgData",
                        "samples" to (data.first?.toList() ?: emptyList<Double>()),
                        "metadata" to data.second,
                    ))
                }
                override fun onFinish(ecgTotal: EcgTotal, list: MutableList<EcgDetail>) {
                    postToSink(ecgSink, mapOf(
                        "kind" to "ecgFinish",
                        "address" to (ecgTotal.address ?: ""),
                        "ecgId" to (ecgTotal.ecgId ?: ""),
                        "startTime" to (ecgTotal.startTime ?: 0L),
                        "duration" to (ecgTotal.duration ?: 0),
                        "frequency" to (ecgTotal.frequency ?: 0),
                        "leads" to (ecgTotal.leads ?: 0),
                        "ecgResult" to (ecgTotal.ecgResult ?: -1),
                        "avgHr" to (ecgTotal.avgHr ?: 0),
                    ))
                }
            }
        )
        result.success(null)
    }

    private fun handleStopEcg(result: Result) {
        ServiceSdkCommandV2.stopEcgMeasure { _ -> }
        result.success(null)
    }

    // ── Teardown ────────────────────────────────────────────────────

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        listOf(scanChannel, connectionChannel, deviceStatusChannel,
               measurementChannel, continuousDataChannel, healthDataChannel,
               sleepDataChannel, ecgChannel).forEach { it.setStreamHandler(null) }

        scanSink = null; connectionSink = null; deviceStatusSink = null
        measurementSink = null; continuousDataSink = null; healthDataSink = null
        sleepDataSink = null; ecgSink = null

        initScope.cancel()
        if (isSdkInitialized) {
            try { ServiceSdkCommandV2.onDestory() } catch (_: Exception) {}
            isSdkInitialized = false
        }
        application = null
    }

    // ── Helpers ─────────────────────────────────────────────────────

    private fun postToSink(sink: EventChannel.EventSink?, map: Map<String, Any?>) {
        sink ?: return
        mainHandler.post { sink.success(map) }
    }

    private fun simpleHandler(onListen: (EventChannel.EventSink) -> Unit) =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) = onListen(events)
            override fun onCancel(arguments: Any?) = onListen(NOOP_SINK)
        }
}
