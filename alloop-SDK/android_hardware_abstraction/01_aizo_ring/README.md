# AIZO 戒指适配器

`AizoRingAdapter` 是应用唯一需要依赖的戒指接口；具体的 `ServiceSdkCommandV2` 调用收敛在 `AizoRingSdkPort` 实现中。Flutter 工程和纯 Android 工程各实现一次该 Port，界面、业务和数据层都只接触 `RingHardware` / `VitalReading`。

## 厂商 SDK 映射

| 抽象操作 | AIZO SDK 调用 / 回调 |
| --- | --- |
| 初始化 | `MMKV.initialize(application)`，再 `ServiceSdkCommandV2.init(...)` |
| 扫描 | `searchBtDevice(OnBluetoothSearchListener)` / `stopSearchBtDevice()` |
| 连接与断开 | `connect(mac)` / `disconnect {}`；连接状态用 `addCallback(AizoDeviceConnectCallback)` |
| 即时测量 | `instantMeasurement(...)`，结果映射为 `VitalReading` |
| 连续测量 | `startContinuousMeasure(...)` / `stopContinuousMeasure(measureType)`，PPG/连续原始数据写入 `raw` |
| 血氧、心率、呼吸等 | 依据 `MeasureResult`、`ContinuousMeasureData`、设备能力回调填充；不支持的字段保持 `null` |
| 历史健康/睡眠 | `getHealthData(...)` / `getSleepData(...)`，经 `HardwareEvent.History` 返回 |
| ECG | `startEcgMeasure(...)` / `stopEcgMeasure {}`；波形使用 `raw`，不可把原始波形误当心率 |
| 电量/配置 | `registerPowerStateListener`、`addDeviceConfigCallback`，映射为 `HardwareEvent.Status` |

## Port 实现要点

1. 在主线程执行 `MMKV.initialize` 与 `ServiceSdkCommandV2.init`；应用启动期间只初始化一次。
2. `connect` 的 `HardwareDevice.id` 必须是 AIZO 扫描回调中返回的 MAC 地址。
3. 厂商回调可能不带时间戳，适配器以收到回调的系统时间作为 `timestampEpochMillis`；若 SDK 提供记录时间，应优先使用记录时间。
4. 读取 `AizoDeviceConfigBean` 后再声明可用能力。`descriptor` 是默认能力集合，最终 UI 必须同时以设备配置为准。
5. `ServiceSdkCommandV2` 是全局单例，同一进程只能由一个 `AizoRingSdkPort` 持有回调注册权；销毁时调用 `onDestory()`。

## 两个宿主 SDK 的接入

- Flutter 1 Android：在 `packages/aizoring_blue_lite` 的 Android bridge 同一侧实现 Port，再通过 Platform Channel 把 `VitalReading` 序列化到 Dart；不要在 Dart 端解析厂商原始包。
- 纯 Android：将本目录和根目录的 `HardwareContracts.kt` 复制/作为 library module 引入；在 Hilt Module 中提供 `AizoRingSdkPort` 和 `AizoRingAdapter`。

Android 12+ 需申请 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`；Android 11 及以下按厂商 SDK 要求申请定位与旧蓝牙权限。
