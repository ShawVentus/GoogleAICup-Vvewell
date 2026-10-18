package com.alloop.blue.test

import android.app.Activity
import android.content.Intent
import android.net.Uri
import com.rokid.cxr.link.CXRLink
import com.rokid.cxr.link.callbacks.ICXRLinkCbk
import com.rokid.cxr.link.utils.CxrDefs
import com.rokid.cxr.link.utils.GlassInfo
import com.rokid.sprite.aiapp.externalapp.auth.AuthResult
import com.rokid.sprite.aiapp.externalapp.auth.AuthorizationHelper
import com.rokid.sprite.aiapp.externalapp.auth.GlassPermission
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Owns the process-wide CXRLink session used by the Flutter device center. */
class RokidGlassesBridge(private val activity: Activity) {
    private var link: CXRLink? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingAuthorizationResult: MethodChannel.Result? = null
    private var token = ""
    private var cxrlConnected = false
    private var bluetoothConnected = false
    private var deviceInfo: Map<String, Any?> = emptyMap()

    private val callback = object : ICXRLinkCbk {
        override fun onCXRLConnected(connected: Boolean) {
            cxrlConnected = connected
            emitStatus()
        }

        override fun onGlassBtConnected(connected: Boolean) {
            bluetoothConnected = connected
            emitStatus()
        }

        override fun onGlassDeviceInfo(info: GlassInfo) {
            deviceInfo = mapOf(
                "deviceName" to info.deviceName,
                "serialNumber" to info.sn,
                "batteryLevel" to info.batteryLevel,
                "charging" to info.ischarging,
                "systemVersion" to info.systemVersion,
                "brightness" to info.brightness,
                "volume" to info.sound,
                "wearingStatus" to info.wearingStatus,
                "screenOn" to info.screenOn,
            )
            emitStatus()
        }

        override fun onGlassWearingStatus(wearing: Boolean) = Unit
        override fun onGlassAiAssistStart() = Unit
        override fun onGlassAiAssistStop() = Unit
        override fun onGlassAiInterrupt(interruptWake: Boolean) = Unit
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) emitStatus()
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(statusMap())
            "authorizeAndConnect" -> authorizeAndConnect(result)
            "requestDeviceInfo" -> {
                link?.getGlassDeviceInfo()
                result.success(null)
            }
            "disconnect" -> {
                disconnect()
                result.success(null)
            }
            "openCompanionMarket" -> {
                openCompanionMarket()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_AUTH) return false
        completeAuthorization(resultCode, data)
        return true
    }

    fun dispose() {
        pendingAuthorizationResult?.error(
            "ROKID_ACTIVITY_CLOSED",
            "The glasses authorization activity was closed",
            null,
        )
        pendingAuthorizationResult = null
        disconnect()
        eventSink = null
    }

    private fun authorizeAndConnect(result: MethodChannel.Result) {
        if (!isCompanionInstalled()) {
            result.error(
                "ROKID_COMPANION_MISSING",
                "Install and sign in to the Rokid AI or Hi Rokid companion app first",
                null,
            )
            return
        }
        if (pendingAuthorizationResult != null) {
            result.error("ROKID_AUTH_RUNNING", "Glasses authorization is in progress", null)
            return
        }
        pendingAuthorizationResult = result
        val immediate = AuthorizationHelper.requestAuthorization(
            activity,
            arrayOf(
                GlassPermission.MICROPHONE,
                GlassPermission.CAMERA,
                GlassPermission.MEDIA,
            ),
            REQUEST_CODE_AUTH,
        )
        if (immediate != null) {
            completeAuthorization(immediate.first, immediate.second)
        }
    }

    private fun completeAuthorization(resultCode: Int, data: Intent?) {
        val pending = pendingAuthorizationResult ?: return
        when (val auth = AuthorizationHelper.parseAuthorizationResult(resultCode, data)) {
            is AuthResult.AuthSuccess -> {
                token = auth.token
                try {
                    startSession(token)
                    pending.success(statusMap())
                } catch (error: Throwable) {
                    pending.error("ROKID_CONNECT_ERROR", error.message, null)
                }
            }
            is AuthResult.AuthCancel -> pending.error(
                "ROKID_AUTH_CANCELLED",
                "Glasses authorization was canceled",
                null,
            )
            is AuthResult.AuthFail -> pending.error(
                "ROKID_AUTH_FAILED",
                "Glasses authorization failed",
                null,
            )
        }
        pendingAuthorizationResult = null
        emitStatus()
    }

    private fun startSession(sessionToken: String) {
        require(sessionToken.isNotBlank()) { "Rokid authorization token is empty" }
        link?.disconnect()
        cxrlConnected = false
        bluetoothConnected = false
        val newLink = CXRLink(activity.applicationContext)
        check(
            newLink.configCXRSession(
                CxrDefs.CXRSession(CxrDefs.CXRSessionType.CUSTOMVIEW),
            ),
        ) { "Unable to configure the CXRLink custom-view session" }
        newLink.setCXRLinkCbk(callback)
        check(newLink.connect(sessionToken)) { "Unable to connect the CXRLink service" }
        link = newLink
    }

    private fun disconnect() {
        runCatching { link?.disconnect() }
        link = null
        token = ""
        cxrlConnected = false
        bluetoothConnected = false
        deviceInfo = emptyMap()
        emitStatus()
    }

    private fun statusMap(): Map<String, Any?> {
        val companionConnected = runCatching {
            AuthorizationHelper.isConnectHiRokid()
        }.getOrDefault(false)
        val btConnected = bluetoothConnected ||
            runCatching { link?.isGlassBtConnected() == true }.getOrDefault(false)
        return mapOf(
            "kind" to "status",
            "companionInstalled" to isCompanionInstalled(),
            "companionConnected" to companionConnected,
            "authorized" to token.isNotBlank(),
            "cxrlConnected" to cxrlConnected,
            "bluetoothConnected" to btConnected,
            "ready" to (cxrlConnected && btConnected),
            "deviceInfo" to deviceInfo,
        )
    }

    private fun isCompanionInstalled(): Boolean = runCatching {
        AuthorizationHelper.isRequiredRokidAppInstalled(activity) ||
            AuthorizationHelper.isRequiredHiRokidInstalled(activity)
    }.getOrDefault(false)

    private fun emitStatus() {
        val payload = statusMap()
        activity.runOnUiThread { eventSink?.success(payload) }
    }

    private fun openCompanionMarket() {
        val packageName = ROKID_AI_PACKAGE
        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val fallbackIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse(ROKID_DOWNLOAD_URL),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { activity.startActivity(marketIntent) }
            .getOrElse { activity.startActivity(fallbackIntent) }
    }

    companion object {
        const val REQUEST_CODE_AUTH = 5404
        private const val ROKID_AI_PACKAGE = "com.rokid.sprite.aiapp"
        private const val ROKID_DOWNLOAD_URL =
            "https://static.rokidcdn.com/web_assets/site/downloadAI.html"
    }
}
