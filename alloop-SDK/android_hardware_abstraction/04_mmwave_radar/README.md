# 毫米波雷达适配器

本适配器以 `RadarHardware` 给应用提供连接、启停、配置、点云流和生命体征流；底层仍由现有 `RadarBridge` 处理 HIF 分帧、CRC、`0xC3` 点云与 `0xE0` VitalSample。雷达没有血氧传感器，因此 `VitalReading.spo2Percent` 必须为 `null`。

## 厂商 SDK 映射

| 抽象操作 | `RadarBridge` / 传输层调用 |
| --- | --- |
| 扫描 | 宿主使用 Android BLE 或自己的 BLE SDK 扫描；扫描结果装为 `HardwareDevice`，`transportData` 保存 `BluetoothDevice` |
| 连接 | `attach(RadarTransport)` 后 `connect(BluetoothDevice)` |
| 配置 | `configureVital(VitalConfig)`；`RadarConfig` 的 `includeVitalPhase/includePointCloud` 对应 `RadarOutputFlags`，自动/手动 bin 对应 `VitalBinMode` |
| 启停 | `start()` / `stop()`；仅在 `READY` 后发送 |
| 点云 | `RadarListener.onPointCloud(PointCloudFrame)` 转换为统一 `PointCloudFrame` |
| 呼吸/心率 | `RadarListener.onVitalMetrics(VitalMetrics)` 转换为 `VitalReading.breathingRateBpm/heartRateBpm/confidence` |
| 原始 Vital | `onVitalSample(VitalSample)` 可保存在 `raw`，包括距离、I/Q、帧号；不得当作血氧 |
| 故障 | `onProtocolError/onTransportError` 映射为 `HardwareEvent.Error` |

## Port 实现要点

1. `RadarBridge` 不扫描设备；`MmWaveRadarSdkPort.scan` 由宿主 BLE 框架实现，并把选中的 `BluetoothDevice` 放入 `HardwareDevice.transportData`。
2. 雷达使用的 UART service、write characteristic、notify characteristic UUID 不应硬编码。根据 JDY-23 实物或厂商资料构造 `RadarGattProfile`。
3. 低 MTU 时 `AndroidGattTransport` 会自动按 `maxWriteBytes` 分片；第三方 BLE SDK 则实现 `RadarTransport.write`。通知数据必须直接交给 `RadarBridge`，不可按 BLE 包边界解析 HIF。
4. `VitalMetrics` 是手机端频谱估计结果，受距离、姿态、运动和环境噪声影响；仅作交互/研究用途，不能用于诊断、监护、报警或治疗决策。
5. `stopRadar()` 后仍可能有少量在 GATT 队列中的迟到数据；Port 应在收到停止应答后丢弃这些数据。

## 两个宿主 SDK 的接入

- Flutter 1 Android：可复用已有 `RadarFlutterBridge` 与 `hardware/android_radar_bridge`，在其 Kotlin 侧实现 Port，再向 Flutter 发统一数据模型。
- 纯 Android：直接依赖/复制 `radar-bridge` library module；使用 `AndroidGattTransport` 或将当前 BLE SDK 包装为 `RadarTransport`。

Android 12+ 需要 `BLUETOOTH_SCAN` 和 `BLUETOOTH_CONNECT`；停止页面或前台服务时应依次调用 `stopRadar()`、`disconnect()`。
