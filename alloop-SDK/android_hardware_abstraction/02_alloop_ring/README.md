# Alloop 戒指适配器

本目录把 `com.alloop.core.api.AlloopCore` 包装为与 AIZO 戒指完全一致的 `RingHardware`。对上层而言，扫描、连接、`vitalReadings`、测量和历史同步的入口不因戒指品牌而变化。

## 厂商 SDK 映射

| 抽象操作 | Alloop Core 调用 / 回调 |
| --- | --- |
| 初始化 | `AlloopCore.init(context)` |
| 扫描 | `startScan(nameFilter, timeoutMs)`；通过 `setScanCallback(ScanCallback)` 收设备 |
| 连接 | `connect(deviceId)`；通过 `setConnectionCallback(ConnectionCallback)` 得状态 |
| 断开 | `disconnect(deviceId)` |
| 设备状态 | `queryDeviceStatus(deviceId)` 与 `setDeviceStatusCallback(DeviceStatusCallback)` |
| 血氧验证 | `startSpo2Verification(deviceId)`；`RealtimeCallback.onSpo2Result/onVerifySpo2` 映射至 `VitalReading.spo2Percent` |
| PPG / 加速度 | `RealtimeCallback.onPpg/onAcc`；原始波形写到 `VitalReading.raw`，不应直接显示为 BPM |
| 停止测量 | `stopMeasurement(deviceId)` |
| 历史数据 | `syncHistory(deviceId)`；`HistoryCallback` 映射为 `HardwareEvent.History` |

## Port 实现要点

1. `AlloopCore` 同一时刻只保存一组全局回调，因此应由一个应用级单例 Port 统一注册、再使用 `SharedFlow` 分发。
2. `startMeasurement`：当请求包含 `SPO2` 时调用 `startSpo2Verification`；当前 SDK 未暴露通用“开始心率/呼吸”命令，不能伪造该功能。PPG 可作为上层算法输入，但算法输出必须标明来源和置信度。
3. 以 `onSpo2Result` 的 map 中实际存在的键填充 `VitalReading`；键缺失时设为 `null`，不使用 0 代替未测得。
4. `syncHistory` 是异步过程，Port 必须将 `onTypeStarted/onRecord/onTypeCompleted/onAllCompleted/onError` 全部映射，确保 UI 能显示进度或失败。

## 两个宿主 SDK 的接入

- Flutter 1 Android：可在 `packages/alloop_blue_lite` 的 Android plugin 中实现 Port，并继续使用其现有 EventChannel；业务模型应转换为统一 `VitalReading`。
- 纯 Android：将 `core-1.0.0.aar` 或相同 Maven 坐标加入纯 Android 工程后，在 data/device 层实现 Port；不要从 Compose 页面直接调 `AlloopCore`。

权限同 Android BLE 标准：Android 12+ 为 `BLUETOOTH_SCAN` 和 `BLUETOOTH_CONNECT`；连接前确认权限和蓝牙已开启。
