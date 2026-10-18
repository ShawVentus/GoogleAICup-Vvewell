# 小智 Android BLE SDK

这是一个独立的 Kotlin Android library，用于让 Android 6.0（API 23）及以上应用，以统一接口连接、配对和控制小智 BLE 固件。它实现了项目的 `XIAOZHI-*` 广告、GATT 特征、加密要求、兼容命令与 MCP 分帧协议。

## 能力

- 统一处理 Android 6–11 定位权限与 Android 12+ `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` 权限差异。
- 扫描 `XIAOZHI-*`，按 RSSI 返回稳定的 `XiaoZhiDevice`。
- 连接时主动发起 Just Works 配对，随后才读写受保护特征。
- 所有 GATT 操作通过单一串行队列执行，避免 Android `BluetoothGatt` 并发读写导致的随机失败。
- 自动订阅设备状态、兼容命令响应和 MCP 响应流；自动重组 `XZ` MCP 分帧。
- 提供配网、设备状态、系统信息、音量/亮度等兼容命令，以及 MCP 初始化、工具列举和工具调用接口。

## 引入

将整个 `xiaozhi-ble-sdk` 文件夹放入 Android 工程，或把其中的 `xiaozhi-ble` 模块作为子模块引入：

```kotlin
// app/build.gradle.kts
dependencies {
    implementation(project(":xiaozhi-ble"))
}
```

库以 `compileSdk = 35` 构建，`minSdk = 23`；宿主可以使用更高的 `targetSdk`。依赖仅为 `kotlinx-coroutines-android`。

## Manifest 与运行时权限

Library Manifest 会自动合并下列权限声明；运行时权限请求仍必须由宿主 Activity/Fragment 执行：

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

运行时请求统一由 `XiaoZhiBlePermissions.requiredForFullUse()` 提供：

```kotlin
requestPermissions(XiaoZhiBlePermissions.requiredForFullUse(), 1001)
```

Android 12+ 必须授予附近设备权限；Android 6–11 扫描通常需要定位权限和已打开的位置服务。

## 最小连接示例

```kotlin
class DeviceViewModel(application: Application) : AndroidViewModel(application) {
    private val ble = AndroidXiaoZhiBleClient(application)

    fun connect() = viewModelScope.launch {
        val device = ble.scan().firstOrNull { it.name?.startsWith("XIAOZHI") == true }
            ?: error("No XiaoZhi device found")
        ble.connect(device) // 自动执行配对、服务发现与三类通知订阅
        val info = ble.readSystemInfo()
        Log.i("XiaoZhi", info.raw)
    }
}
```

`connection` 是 `StateFlow<XiaoZhiConnectionState>`，可直接绑定 Compose 或在 Fragment 中收集。`events` 是 `SharedFlow<XiaoZhiBleEvent>`：其中包括状态通知、命令响应、MCP 响应和断开原因。

```kotlin
lifecycleScope.launch {
    repeatOnLifecycle(Lifecycle.State.STARTED) {
        ble.events.collect { event ->
            when (event) {
                is XiaoZhiBleEvent.DeviceStatus -> renderStatus(event.payload.raw)
                is XiaoZhiBleEvent.CommandResponse -> showResult(event.payload.raw)
                is XiaoZhiBleEvent.McpResponse -> handleJsonRpc(event.response.rawJson)
                is XiaoZhiBleEvent.ConnectionLost -> showReconnectHint(event.reason)
            }
        }
    }
}
```

## 控制接口

```kotlin
ble.configureWifi("OfficeWiFi", "secret")
ble.sendCommand("set_volume", """{"volume":70}""")
ble.sendCommand("start_listening")
ble.sendCommand("get_wifi_scan")

ble.initializeMcp()
ble.listMcpTools()
ble.callMcpTool("self.audio_speaker.set_volume", """{"volume":70}""")
```

MCP 是首选控制面：先调用 `initializeMcp()`，然后调用 `listMcpTools()`，只调用返回列表中存在的工具。显示、摄像头、电池等属于板级可选能力，不能假设每台设备都支持。

## 安全与配对故障处理

小智的 Wi-Fi、状态和控制特征要求加密。`connect()` 会调用 Android 的 `createBond()` 并等待 `BOND_BONDED`；只有随后才会执行 GATT 读取、写入和 CCCD 订阅。

首次升级到启用绑定密钥持久化的固件后，用户需要在系统蓝牙设置中删除旧的 `XIAOZHI-xxxx` 记录并重新连接一次。若看到 ATT `0x05` / `Insufficient Authentication`：

1. 调用 `disconnect()`。
2. 删除系统中的旧配对记录。
3. 重新扫描并调用 `connect()`，接受 Just Works 提示。
4. 等待 `XiaoZhiConnectionState.Ready` 后再发送命令。

不要为绕过配对而关闭固件端加密；BLE 接口可修改设备 Wi-Fi、调用管理工具和重启设备。

## 生命周期

- 在 `onStop()` 或 ViewModel `onCleared()` 调用 `disconnect()`，避免占用 GATT 连接。
- 断开后重新调用 `scan()` 和 `connect()`，不要复用已经关闭的 `BluetoothGatt`。
- 不要绕过 SDK 对 `BluetoothGatt` 直接写特征；其内部队列是保证命令可靠性的前提。

## 与固件协议的对应关系

| SDK 方法/事件 | GATT 特征 |
| --- | --- |
| `configureWifi` / `readWifiStatus` | `4fafc202-...` |
| `readDeviceStatus` / `DeviceStatus` | `4fafc203-...` |
| `sendCommand` | `4fafc204-...` |
| `CommandResponse` | `4fafc205-...` |
| `readSystemInfo` | `4fafc206-...` |
| `McpResponse` | `4fafc207-...`，`XZ` 分帧自动重组 |

完整固件协议见项目的 [BLE 接口文档](../../../docs/ble_android_integration.md)。
