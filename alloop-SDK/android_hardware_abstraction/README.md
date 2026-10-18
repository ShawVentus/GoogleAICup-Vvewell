# Android 四硬件统一抽象层

本目录是**新增、独立、可复用**的 Android 接口层，不改动当前 Flutter 1 Android 工程、其 Dart 代码，也不修改 `D:\Project\vvewell-physical-ai-2026\android_app`。目录只引用两个工程现有的 SDK 能力：

```text
android_hardware_abstraction/
├── HardwareContracts.kt       # 所有应用侧统一模型与接口
├── 01_aizo_ring/              # AIZO 戒指：ServiceSdkCommandV2
├── 02_alloop_ring/            # Alloop 戒指：AlloopCore
├── 03_xiaozhi/                # 小智：XiaoZhiBleClient / MCP
└── 04_mmwave_radar/           # 毫米波：RadarBridge / HIF
```

每个硬件目录均包含一个 Kotlin 适配器和一份接口说明；根目录 `HardwareContracts.kt` 是唯一共享依赖。四个适配器对应用暴露同样的 `UnifiedHardware`，并按能力细分为：戒指 `RingHardware`、小智 `XiaoZhiHardware`、雷达 `RadarHardware`。

## 应用层使用方式

```kotlin
val hardware: UnifiedHardware = aizoRingAdapter // 也可以替换为另一个戒指、小智或雷达

lifecycleScope.launch {
    hardware.vitalReadings.collect { reading ->
        renderHeartRate(reading.heartRateBpm)
        renderSpO2(reading.spo2Percent)          // 雷达/小智没有时为 null
        renderBreathing(reading.breathingRateBpm)
    }
}

val devices = hardware.scan()
hardware.connect(devices.first())
```

调用者先用 `descriptor.supportedMetrics` 决定能否展示某项测量，再处理 `VitalReading` 中可能为 `null` 的实际值。这样同一界面不会把雷达推导的心率伪装成血氧，也不会把小智控制设备伪装成医疗传感器。

## 统一层与厂商 SDK 的边界

```text
应用 / ViewModel / Flutter Channel
              │  UnifiedHardware、VitalReading、HardwareEvent
              ▼
对应硬件 Adapter（本目录）
              │  XxxSdkPort：每个品牌各自实现
              ▼
AIZO ServiceSdkCommandV2 | AlloopCore | XiaoZhiBleClient | RadarBridge
```

`XxxSdkPort` 是刻意保留的设备通信边界：统一 API 不会抹平厂家协议，而是把品牌专有的扫描、配对、GATT、指令与回调留在各自 Port 内。各目录 README 给出了每项抽象操作到现有 SDK 方法的映射和实现约束。

## 在两个 Android SDK 中复用

### 1. 当前 Flutter 1 Android 工程

将本目录作为 Android library 源码加入 `android/`（或由现有 Android plugin 依赖），分别在下列已有桥接层实现相应 `XxxSdkPort`：

- AIZO：`packages/aizoring_blue_lite`；
- Alloop：`packages/alloop_blue_lite`；
- 小智：`hardware/xiaozhi/xiaozhi-ble-sdk`；
- 雷达：`hardware/android_radar_bridge` 与 `RadarFlutterBridge`。

Port 内再把统一模型映射到 MethodChannel/EventChannel；不要让 Dart 直接接触厂商 SDK 或协议字节。

### 2. 纯 Android 工程

将根目录 `HardwareContracts.kt` 与所需硬件子目录作为一个 Android library module 源码引入。在 data/device 层用 Hilt 提供对应 `XxxSdkPort` 及 Adapter，ViewModel 仅注入 `UnifiedHardware` 或更具体的能力接口。纯 Android 工程现有 `BleRingManager` 仅有扫描边界，正好可以替换为或复用在各 Port 的扫描实现中。

## 接入前提与校验

1. Android 12+ 请求 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`；旧版本按厂商要求处理定位/旧蓝牙权限。
2. 一个厂商 SDK 的全局回调只能由对应 Port 注册一次，然后以 `StateFlow` / `Flow` 分发。
3. 只在连接状态为 `READY` 时下发设备命令；断线后清空当前会话数据并重新扫描。
4. 全部生命体征字段均为非医疗用途数据接口。雷达的心率/呼吸尤其是算法估计，必须在产品层清晰标记其限制。

本目录不携带或复制厂商 AAR、密钥、UUID 或固件，也不替换现有实现；导入时由宿主工程按各硬件 README 中列出的现有 SDK 依赖提供实现。
