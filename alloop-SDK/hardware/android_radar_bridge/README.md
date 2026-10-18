# Android Radar Bridge

这是面向 Android 应用的 MRS6130-P1812 + JDY-23 蓝牙毫米波雷达抽象层。它把 BLE SDK、BLE GATT 细节和 Possumic HIF/VitalBridge 协议隔离开，上层业务只需要使用统一的 `RadarBridge` 接口。

## 解决的问题

- 不同项目可以替换 Android 原生 GATT、Nordic、RxAndroidBle、Kable 或自研 BLE SDK，而不改雷达业务代码。
- BLE notification 可能按任意长度分包，抽象层会自动重组 HIF 帧并校验 Check8/Check32。
- 提供统一的启动、停止、输出配置和生命体征 bin 选择接口。
- 将 `0xC3` 点云、`0xE0` VitalSample、HIF 应答和原始厂商帧转换为稳定的数据模型。
- 可选地在手机端计算呼吸率、心率频谱估计；算法是非医疗级的，应用不得把结果作为诊断或监护结论。

## 目录结构

```text
android_radar_bridge/
├─ settings.gradle.kts
├─ build.gradle.kts
├─ README.md
└─ radar-bridge/
   ├─ build.gradle.kts
   └─ src/main/
      ├─ AndroidManifest.xml
      └─ java/com/alloop/radar/bridge/
         ├─ RadarModels.kt          # 状态、点云、VitalSample、回调模型
         ├─ RadarTransport.kt       # 与具体 BLE SDK 解耦的最小传输接口
         ├─ AndroidGattTransport.kt # Android BluetoothGatt 适配器
         ├─ HifProtocol.kt           # HIF 编解码、流式解析、点云/Vital 解码
         ├─ RadarBridge.kt            # 业务门面
         └─ VitalEstimator.kt         # 可选的非医疗级频谱估计
```

## 接入方式

把 `android_radar_bridge` 作为独立 Gradle 工程，或把 `radar-bridge` 目录复制为现有工程的 library module：

```kotlin
dependencies {
    implementation(project(":radar-bridge"))
}
```

若作为 Maven/AAR 发布，发布坐标由宿主项目决定；该模块本身不依赖第三方 BLE 库和 Kotlin Coroutines。

用 Android Studio 打开本目录即可导入。命令行构建需要 Gradle 8.11+、Android SDK 35 和 Kotlin/Android Gradle Plugin 8.9+：

```powershell
gradle :radar-bridge:assembleRelease
```

如果宿主项目已经有 Gradle Wrapper，直接用宿主项目的 wrapper 执行同一个 task 即可。

本次已验证并生成可直接导入的 release AAR：`radar-bridge-release.aar`。源码接入更适合长期维护；AAR 接入时把该文件放入宿主的 `libs/`，再添加 `implementation(files("libs/radar-bridge-release.aar"))`。

本次验证结果：`radar-bridge:compileDebugKotlin` 和 `radar-bridge:assembleRelease` 均成功。Android GATT API 仅产生 Java SDK 的弃用警告，不影响构建；宿主应用可以逐步迁移到新版 descriptor 写入 API。

## Android 原生 GATT 用法

扫描仍由应用负责，因为扫描过滤、权限和设备选择属于产品逻辑。拿到 `BluetoothDevice` 后，传入实际设备的 UART Service、写特征和通知特征 UUID：

```kotlin
val profile = RadarGattProfile(
    serviceUuid = UUID.fromString("<UART_SERVICE_UUID>"),
    writeCharacteristicUuid = UUID.fromString("<UART_WRITE_UUID>"),
    notifyCharacteristicUuid = UUID.fromString("<UART_NOTIFY_UUID>"),
    writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
    maxWriteBytes = 20
)

val transport = AndroidGattTransport(applicationContext, profile)
val radar = RadarBridge(estimateVitalMetrics = true)
radar.addListener(object : RadarListener {
    override fun onStateChanged(state: RadarConnectionState) {
        // READY 后才能发送命令
    }

    override fun onPointCloud(frame: PointCloudFrame) {
        // frame.points: 米、米/秒、dB 等统一单位
    }

    override fun onVitalSample(sample: VitalSample) {
        // 原始 I/Q、距离 bin、帧序号
    }

    override fun onVitalMetrics(metrics: VitalMetrics) {
        // 可选估计结果；仅供交互/研究
    }
})
radar.attach(transport)
radar.connect(device)
```

`AndroidGattTransport` 会自动完成：连接、服务发现、CCCD 通知订阅、GATT 写入串行化和 20 字节分片。不要在应用中直接并发调用 `BluetoothGatt.writeCharacteristic`，统一通过 `RadarBridge` 发送。

### 权限与生命周期

Android 12 及以上在 manifest 和运行时申请 `BLUETOOTH_SCAN`、`BLUETOOTH_CONNECT`；Android 11 及以下按系统版本申请 `BLUETOOTH`、`BLUETOOTH_ADMIN`，扫描通常还需要位置权限。权限申请、蓝牙开关和前台服务策略由宿主应用负责。

页面销毁或前台服务停止时调用：

```kotlin
radar.stop()
radar.disconnect()
```

## 接入任意第三方 BLE SDK

第三方 SDK 只需实现 `RadarTransport`，不用重新实现 HIF 解析：

```kotlin
class MySdkTransport : RadarTransport {
    override var state = RadarConnectionState.DISCONNECTED
        private set
    private var listener: RadarTransport.Listener? = null

    override fun setListener(listener: RadarTransport.Listener?) {
        this.listener = listener
    }

    override fun connect(device: BluetoothDevice) {
        // 调用第三方 SDK；连接并订阅通知成功后：
        state = RadarConnectionState.READY
        listener?.onStateChanged(state)
    }

    override fun disconnect() {
        // 调用第三方 SDK 断开
    }

    override fun write(bytes: ByteArray): Boolean {
        // 写入 UART 写特征；成功入队返回 true
        return true
    }

    private fun onNotify(data: ByteArray) {
        listener?.onBytesReceived(data)
    }

    private fun onSdkError(error: Throwable) {
        listener?.onError(error)
    }
}
```

第三方 SDK 的通知回调可以是 20、40 或任意长度；直接把每段 byte 数组传给 `onBytesReceived` 即可。不要按通知边界自行解析。

## 统一业务接口

当传输状态为 `READY` 后，应用可以调用：

| API | HIF 行为 |
|---|---|
| `wakeup()` | 发送 `55 FF 55 FF` 唤醒序列 |
| `start()` | `0x07`，payload `01`，启动完整雷达框架 |
| `stop()` | `0x07`，payload `00`，停止雷达并清理上报队列 |
| `configureVital(config)` | `0x90` 写点云/相位、自动/手动 bin 配置 |
| `queryVitalConfig()` | `0x90` 读取当前配置 |
| `selectVitalBinAutomatically()` | `0x90` 切回自动选 bin |
| `sendHif(messageId, payload)` | 保留对未来固件命令的扩展能力 |

示例：

```kotlin
radar.configureVital(
    VitalConfig(
        outputFlags = RadarOutputFlags.VITAL_PHASE,
        binMode = VitalBinMode.MANUAL,
        selectedBin = 30, // 约 1.2 m，实际以固件返回的分辨率为准
        minBin = 10,
        maxBin = 100
    )
)
radar.start()
// ...接收数据...
radar.stop()
```

`outputFlags = 0` 可以静音 `0xC3/0xE0` 上报但保持雷达运行；需要真正停止雷达时必须调用 `stop()`。

## 事件和数据单位

- `onHifResponse`：包含消息 ID、状态字节和去除状态字节后的 payload。
- `onPointCloud`：`x/y/z` 单位米，速度单位米/秒，SNR 单位 dB；未知 TLV 会被跳过。
- `onVitalSample`：包含原始 I/Q、距离 bin、帧号、幅度平方、距离分辨率和采样周期。`phaseRadians` 是包裹相位，连续相位由 `VitalEstimator` 处理。
- `onVitalMetrics`：频谱估计的呼吸率/心率 BPM、置信度、窗口长度和平均距离。
- `onRawHifFrame`：保留所有已校验 HIF 帧，便于调试或扩展新的消息 ID。
- `onProtocolError`：预留给宿主对异常帧进行统计；传输错误通过 `onTransportError` 通知。

## UUID、MTU 和吞吐量

JDY-23 不同批次或载板可能使用不同的 UART Service/Characteristic UUID，本库不硬编码 UUID。建议用 nRF Connect 或设备厂商工具确认：一个可写特征、一个支持 Notify 的通知特征，以及通知特征上的 CCCD `00002902-0000-1000-8000-00805F9B34FB`。

默认按 20 字节写入，兼容未协商扩展 MTU 的 BLE 链路。若宿主已确认目标模块和 SDK 支持更大 MTU，可以把 `maxWriteBytes` 调大；HIF 接收端仍然必须保留流式解析。

完整 FFT/数据立方体的带宽会超过 JDY-23 115200 UART 和普通 BLE 透传能力。此抽象层面向当前固件的 `0xC3` 点云和低带宽 `0xE0` I/Q；如需更高带宽，应更换传输模块和固件报告格式。

## 建议的应用状态机

```text
DISCONNECTED
   │ scan/connect
CONNECTING → DISCOVERING → ENABLING_NOTIFICATIONS → READY
                                                   │
                         configureVital() → start()
                                                   │
                                            点云/Vital 事件
                                                   │
                                           stop() → READY
                                                   │
                                              disconnect()
```

只有 `READY` 状态才发送命令；断线后清空页面缓存并等待重新连接。收到 `stop()` 的成功应答后，应用仍应忽略迟到的通知，因为 BLE/GATT 队列中可能残留少量已发送数据。

## 与当前 P1812 固件的对应关系

本目录对应仓库中的 VitalBridge P1812 固件和协议说明：

- `HIF 0x07`：完整启停，解决连接后自动输出和无法停止问题。
- `HIF 0x90`：输出模式、bin 和搜索范围配置。
- `HIF 0xC3`：标准点云报告。
- `HIF 0xE0`：每帧 20 字节的 VitalSampleV1。
- 上电默认待机，连接后必须显式调用 `start()`。

硬件接线、PA11/PWRC、PA2/STAT、PB0/PB1 UART0 和 JDY-23 115200 配置请参考仓库根目录的 `VITALBRIDGE_P1812_PROTOCOL.md` 与 `MMWAVE_TO_BLE_WIRING.md`。

## 验证清单

1. 设备权限和蓝牙开关正常。
2. GATT 连接后状态进入 `READY`，并且通知特征已订阅。
3. 连接后没有点云或 Vital 数据自动涌入。
4. `start()` 收到 `messageId=0x07, status=0` 的应答后才出现数据。
5. `stop()` 成功后不再出现持续数据；允许有极少量迟到通知。
6. `configureVital(VitalConfig(outputFlags = 0))` 能静音数据，随后恢复 flags 能继续输出。
7. 使用错误 CRC 或截断数据测试时，`HifStreamParser.badFrames` 会增加，后续合法帧仍能恢复解析。

## 限制声明

生命体征频谱估计用于工程验证、交互和研究，不是医疗器械，不可用于诊断、监护、报警或治疗决策。实际精度会受距离、姿态、多径、目标运动、模块安装角度和环境噪声影响。
