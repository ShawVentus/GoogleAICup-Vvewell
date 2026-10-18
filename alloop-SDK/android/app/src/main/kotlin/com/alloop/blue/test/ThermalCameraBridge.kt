package com.alloop.blue.test

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.view.View
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** USB/UVC infrared camera preview backed by the Android external-camera provider. */
class ThermalCameraBridge(private val activity: Activity) : LifecycleOwner {
    private val lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    private val mainExecutor = ContextCompat.getMainExecutor(activity)
    private var eventSink: EventChannel.EventSink? = null
    private var provider: ProcessCameraProvider? = null
    private var previewUseCase: Preview? = null
    private var previewView: PreviewView? = null
    private var state = STATE_DISCONNECTED
    private var lastError: String? = null
    private var connectionRequested = false
    private var binding = false

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) emitState()
    }

    fun handle(call: MethodCall): Any? = when (call.method) {
        "getState" -> stateMap()
        "connect" -> connect()
        "disconnect" -> {
            disconnect()
            stateMap()
        }
        else -> NOT_IMPLEMENTED
    }

    fun attachPreviewView(view: PreviewView) {
        previewView = view
        if (connectionRequested) bindPreviewIfReady()
    }

    fun detachPreviewView(view: PreviewView) {
        if (previewView !== view) return
        disconnect()
        previewView = null
    }

    fun dispose() {
        disconnect()
        eventSink = null
    }

    fun onHostCreate() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)

    fun onHostStart() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)

    fun onHostResume() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)

    fun onHostPause() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)

    fun onHostStop() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)

    fun onHostDestroy() = lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)

    private fun connect(): Map<String, Any?> {
        connectionRequested = true
        lastError = null
        if (!hasCameraPermission()) {
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(Manifest.permission.CAMERA),
                CAMERA_PERMISSION_REQUEST_CODE,
            )
            state = STATE_ERROR
            lastError = "Grant camera permission, then reconnect the USB thermal camera"
            emitState()
            return stateMap()
        }
        state = STATE_CONNECTING
        emitState()
        bindPreviewIfReady()
        return stateMap()
    }

    private fun disconnect() {
        connectionRequested = false
        binding = false
        previewUseCase?.let { useCase ->
            runCatching { provider?.unbind(useCase) }
        }
        previewUseCase = null
        state = STATE_DISCONNECTED
        lastError = null
        emitState()
    }

    private fun bindPreviewIfReady() {
        if (!connectionRequested || binding) return
        val view = previewView ?: return
        binding = true
        val future = ProcessCameraProvider.getInstance(activity)
        future.addListener(
            {
                try {
                    if (!connectionRequested) return@addListener
                    val cameraProvider = future.get()
                    previewUseCase?.let { activeUseCase ->
                        runCatching { provider?.unbind(activeUseCase) }
                    }
                    val preview = Preview.Builder().build().also {
                        it.surfaceProvider = view.surfaceProvider
                    }
                    cameraProvider.bindToLifecycle(
                        this,
                        externalCameraSelector(),
                        preview,
                    )
                    provider = cameraProvider
                    previewUseCase = preview
                    state = STATE_PREVIEWING
                    lastError = null
                } catch (error: Throwable) {
                    state = STATE_ERROR
                    lastError = previewFailureMessage(error)
                } finally {
                    binding = false
                    emitState()
                }
            },
            mainExecutor,
        )
    }

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED

    private fun externalCameraSelector(): CameraSelector = CameraSelector.Builder()
        .addCameraFilter { cameraInfos ->
            cameraInfos.filter { cameraInfo ->
                Camera2CameraInfo.from(cameraInfo).getCameraCharacteristic(
                    CameraCharacteristics.LENS_FACING,
                ) == CameraCharacteristics.LENS_FACING_EXTERNAL
            }
        }
        .build()

    private fun hasExternalCamera(): Boolean = runCatching {
        val manager = activity.getSystemService(CameraManager::class.java)
        manager.cameraIdList.any { cameraId ->
            manager.getCameraCharacteristics(cameraId)
                .get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_EXTERNAL
        }
    }.getOrDefault(false)

    private fun previewFailureMessage(error: Throwable): String =
        if (!hasExternalCamera()) {
            "No compatible USB/UVC thermal camera found. Check the OTG connection and device compatibility"
        } else {
            "Could not start the USB thermal camera preview: ${error.message ?: "Unknown error"}"
        }

    private fun stateMap(): Map<String, Any?> = mapOf(
        "kind" to "state",
        "state" to state,
        "usbCameraAvailable" to hasExternalCamera(),
        "error" to lastError,
    )

    private fun emitState() {
        eventSink?.success(stateMap())
    }

    companion object {
        val NOT_IMPLEMENTED = Any()
        private const val CAMERA_PERMISSION_REQUEST_CODE = 6_208
        private const val STATE_DISCONNECTED = "disconnected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_PREVIEWING = "previewing"
        private const val STATE_ERROR = "error"
    }
}

class ThermalCameraViewFactory(
    private val bridge: ThermalCameraBridge,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: android.content.Context, viewId: Int, args: Any?): PlatformView =
        ThermalCameraPlatformView(context, bridge)
}

private class ThermalCameraPlatformView(
    context: android.content.Context,
    private val bridge: ThermalCameraBridge,
) : PlatformView {
    private val previewView = PreviewView(context).apply {
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    init {
        bridge.attachPreviewView(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        bridge.detachPreviewView(previewView)
    }
}
