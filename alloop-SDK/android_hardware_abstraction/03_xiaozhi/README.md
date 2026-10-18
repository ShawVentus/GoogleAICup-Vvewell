# 小智 BLE 适配器

`XiaoZhiAdapter` 将小智的 Wi-Fi 配网、普通命令与 MCP 工具调用纳入统一设备门面，同时保留小智特有的 `messages` 流。小智并非健康传感器，仍提供统一 `vitalReadings` 属性以便调用方使用同一订阅模型；默认不发出任何健康数据，不能伪造心率、血氧或呼吸率。

## 厂商 SDK 映射

| 抽象操作 | `XiaoZhiBleClient` 调用 / 事件 |
| --- | --- |
| 扫描/停止 | `scan(timeoutMillis)` / `stopScan()` |
| 连接 | `connect(XiaoZhiDevice)`，内部执行配对、服务发现和通知订阅 |
| 断开 | `disconnect()` |
| 状态 | `connection: StateFlow<XiaoZhiConnectionState>`；`readDeviceStatus()` / `readSystemInfo()` |
| Wi-Fi | `configureWifi(ssid, password)`、`readWifiStatus()` |
| 普通命令 | `sendCommand(command, paramsJson)` |
| MCP | `initializeMcp`、`listMcpTools`、`callMcpTool`、`sendMcpRequest` |
| 设备消息 | `events: SharedFlow<XiaoZhiBleEvent>`，转换为 `XiaoZhiMessage` |

## Port 实现要点

1. 仅在 `XiaoZhiConnectionState.Ready` 后允许命令/MCP 调用；其余状态必须返回统一错误事件。
2. 首次连接可能触发 Just Works 配对。若收到 ATT `0x05`，断开、删除系统旧配对后重新连接；不要绕过固件加密。
3. 先 `initializeMcp()`，再 `listMcpTools()`，只调用列表中真实存在的工具。板级能力（摄像头、扬声器、电量等）不能假定每台设备具备。
4. 若某个 MCP 工具明确返回健康 JSON，Port 可转换为 `VitalReading`，并在 `raw` 保存原始 JSON 和工具名；没有厂商字段约定前不要猜测字段语义。

## 两个宿主 SDK 的接入

- Flutter 1 Android：在 Android 原生层调用现有 `xiaozhi-ble` module，再以 Method/EventChannel 向 Dart 传递统一状态和 JSON。
- 纯 Android：直接注入 `AndroidXiaoZhiBleClient(applicationContext)`，以 Flow 收集并实现 `XiaoZhiSdkPort`。

运行时权限请使用 `XiaoZhiBlePermissions.requiredForFullUse()`：Android 12+ 需要附近设备权限，旧系统扫描通常还需要定位权限与已打开的位置服务。
