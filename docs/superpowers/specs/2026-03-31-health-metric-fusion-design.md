# Health Metric Fusion Design Spec

**Date:** 2026-03-31
**Scope:** 多来源健康指标的统一存储、融合策略和展示方案

---

## 1. 问题定义

多种设备（Ring、rPPG 摄像头、未来手表/手环）采集健康数据，存在：
- **独有指标**：ECG 仅 Ring 能测，GPS 仅手表能测
- **重复指标**：心率、血氧、压力等多设备可测，值可能不同
- **精度差异**：Ring 光电传感器 > rPPG 摄像头估算
- **时间差异**：Ring 持续监测 vs rPPG 单次测量

需要一个方案：全部保留、智能融合、灵活展示。

---

## 2. 统一指标枚举

与设备解耦，按健康指标维度定义：

```swift
enum HealthMetricType: String, CaseIterable {
    // 基础生理
    case heartRate          // 心率 (bpm)
    case spo2               // 血氧 (%)
    case bloodPressure      // 血压 (mmHg)
    case bodyTemperature    // 体温 (°C)
    case stress             // 压力 (1-100)
    case hrv                // 心率变异性 (ms)

    // 专项检测
    case ecg                // 心电图 (波形数据)
    case bloodGlucose       // 血糖
    case bodyComposition    // 体成分
    case emotion            // 情绪/PPI
    case uv                 // 紫外线

    // 活动
    case steps              // 步数
    case calories           // 卡路里
    case distance           // 距离

    // 睡眠
    case sleep              // 睡眠数据

    // 运动
    case sport              // 运动记录
}
```

每种设备声明自己能提供哪些指标：

```swift
protocol HealthDeviceProtocol {
    // 现有...
    var supportedMetrics: [HealthMetricType] { get }
}
```

---

## 3. 家庭成员模型

家庭场景下，同一设备可能被不同成员使用（如共用一台血压计），同一成员也可能有多个设备。数据必须标记归属。

```swift
struct HealthProfile {
    let id: String                  // 唯一标识（UUID 或后端用户 ID）
    let name: String                // "李超" / "妈妈" / "爸爸"
    let avatar: String?             // 头像（emoji 或图片路径）
    let relationship: Relationship  // 与主账号的关系
    let birthYear: Int?
    let gender: Gender?
}

enum Relationship: String {
    case owner          // 本人（主账号）
    case spouse         // 配偶
    case parent         // 父母
    case child          // 子女
    case other          // 其他
}

enum Gender: String {
    case male, female, other
}
```

**设备绑定关系：** 一个设备可以绑定一个主要佩戴者（如 Ring → 李超），但测量时可以临时切换成员（如用 Ring 给妈妈测一次心率）。

```swift
struct DeviceBinding {
    let deviceType: DeviceType
    let deviceName: String
    let primaryProfileId: String    // 默认归属的成员
}
```

**数据流向：**
```
设备测量 → 确定当前成员（默认=设备绑定者，可临时切换）→ RawReading.profileId
```

---

## 4. 三层数据模型

### 4.1 原始层 — RawReading

所有设备的每次测量结果，全部保留，不丢弃。

```swift
struct RawReading {
    let id: UUID
    let profileId: String           // 归属哪个家庭成员
    let metricType: HealthMetricType
    let source: DeviceType          // .ring / .phone / .watch / .band
    let sourceName: String          // "Vvewell Ring" / "iPhone 15 Camera"
    let timestamp: Date
    let value: Double               // 主值（心率=72, 血氧=98）
    let unit: String                // "bpm", "%", "°C"
    let accuracy: ReadingAccuracy   // 精度等级
    let metadata: [String: Any]?    // 附加数据（ECG波形、体成分详情等）
}

enum ReadingAccuracy: Int, Comparable {
    case estimated = 1      // 算法估算（rPPG）
    case consumer = 2       // 消费级传感器（手环）
    case medical = 3        // 医疗级传感器（认证设备）

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

### 3.2 融合层 — FusionPolicy

决定同一指标多个来源时，展示哪个值。

```swift
struct FusionPolicy {
    let metricType: HealthMetricType
    let strategy: FusionStrategy
    let preferredSource: DeviceType?    // 用户手动指定的首选设备（可选）
}

enum FusionStrategy {
    case highestAccuracy    // 取精度最高的来源（默认）
    case mostRecent         // 取最近的读数
    case average            // 取多来源平均值
    case userPreferred      // 用户指定的设备优先
}
```

默认策略：

| 指标 | 默认融合策略 | 原因 |
|------|------------|------|
| heartRate | highestAccuracy | Ring 传感器比 rPPG 准 |
| spo2 | highestAccuracy | 同上 |
| stress | highestAccuracy | 同上 |
| ecg | highestAccuracy | 通常只有一个来源 |
| sleep | highestAccuracy | Ring 持续监测最准 |
| steps | highestAccuracy | 手表/手环计步更准 |

用户可在设置中覆盖：「心率数据来源：自动（推荐）/ Ring / iPhone / Watch」

### 3.3 展示层 — FusedMetric

UI 层消费的最终数据，每个指标一个融合后的值。

```swift
struct FusedMetric {
    let profileId: String           // 归属成员
    let metricType: HealthMetricType
    let value: Double
    let unit: String
    let timestamp: Date             // 最新读数的时间
    let source: DeviceType          // 被选中的来源
    let sourceName: String
    let accuracy: ReadingAccuracy
    let allReadings: [RawReading]   // 所有来源的原始读数（可展开查看）
}
```

---

## 4. 融合引擎 — MetricFusionEngine

```swift
class MetricFusionEngine {

    private var policies: [HealthMetricType: FusionPolicy] = [:]

    /// 从多个 RawReading 中融合出一个 FusedMetric
    func fuse(readings: [RawReading], for metric: HealthMetricType) -> FusedMetric?

    /// 设置某个指标的融合策略
    func setPolicy(_ policy: FusionPolicy, for metric: HealthMetricType)

    /// 获取当前策略
    func policy(for metric: HealthMetricType) -> FusionPolicy
}
```

融合逻辑：

```
输入: [RawReading] (同一指标，不同来源)
  │
  ├─ 只有 1 个来源 → 直接返回
  │
  ├─ 用户指定了 preferredSource?
  │   ├─ 有该来源的读数 → 用它
  │   └─ 没有 → fallback 到 highestAccuracy
  │
  ├─ strategy == .highestAccuracy
  │   → 按 accuracy 降序，取最高；同精度取最近的
  │
  ├─ strategy == .mostRecent
  │   → 按 timestamp 降序，取最新的
  │
  └─ strategy == .average
      → 计算数值平均，source 标记为 "mixed"
```

---

## 5. 数据存储 — HealthMetricStore

```swift
class HealthMetricStore {

    /// 写入一条原始读数
    func save(reading: RawReading)

    /// 查询某成员某指标某时间段的原始数据
    func readings(for metric: HealthMetricType,
                  profileId: String,
                  from: Date, to: Date,
                  source: DeviceType? = nil) -> [RawReading]

    /// 查询某成员某指标的最新融合值
    func latestFused(for metric: HealthMetricType,
                     profileId: String) -> FusedMetric?

    /// 查询某成员某天的所有融合指标（首页用）
    func dailyFused(date: Date, profileId: String) -> [FusedMetric]

    /// 查询某成员某指标的趋势数据（支持按来源筛选）
    func trend(for metric: HealthMetricType,
               profileId: String,
               days: Int,
               source: DeviceType? = nil) -> [FusedMetric]

    /// 查询某成员的所有原始数据（导出用）
    func allReadings(profileId: String,
                     from: Date, to: Date) -> [RawReading]
}
```

存储方案：
- **短期（7天）**：内存缓存 + UserDefaults（JSON 序列化）
- **长期**：Core Data 或 SQLite（后续迭代）
- **RawReading 表**：id, metricType, source, timestamp, value, unit, accuracy, metadata_json
- **索引**：(metricType, timestamp), (source, timestamp)

---

## 6. 数据写入流程

每个设备服务测量完成后，统一写入 HealthMetricStore：

```
Ring.healthService.startMeasurement(.heartRate)
  → 回调: BTMeasureResult(value: 72)
    → 确定当前成员: activeProfileId（默认=设备绑定者）
    → 转换: RawReading(
          profileId: activeProfileId,
          metricType: .heartRate,
          source: .ring,
          sourceName: "Vvewell Ring",
          value: 72,
          unit: "bpm",
          accuracy: .consumer,
          timestamp: now
        )
    → HealthMetricStore.save(reading)
    → MetricFusionEngine.fuse(profileId:) → FusedMetric
    → 通知 UI 更新
```

```
rPPG.cameraMeasurement()
  → 回调: heartRate = 75
    → 转换: RawReading(
          metricType: .heartRate,
          source: .phone,
          sourceName: "iPhone Camera",
          value: 75,
          unit: "bpm",
          accuracy: .estimated,
          timestamp: now
        )
    → HealthMetricStore.save(reading)
    → MetricFusionEngine.fuse() → 仍选 Ring 的 72（accuracy 更高）
    → UI 不变（或更新"2 个来源"标记）
```

---

## 7. 家庭成员管理 — ProfileManager

```swift
class ProfileManager {
    static let shared = ProfileManager()

    /// 当前活跃成员（首页展示谁的数据）
    var activeProfileId: String

    /// 所有家庭成员
    func allProfiles() -> [HealthProfile]

    /// 添加/编辑/删除成员
    func addProfile(_ profile: HealthProfile)
    func updateProfile(_ profile: HealthProfile)
    func removeProfile(id: String)

    /// 主账号（owner），不可删除
    func ownerProfile() -> HealthProfile
}
```

**测量时切换成员的流程：**
1. 默认使用设备绑定的成员（Ring → 李超）
2. 测量前 UI 提供"为谁测量"选择器（头像列表）
3. 选择后临时设置 `activeProfileId`，本次测量数据归属该成员
4. 测量完成后恢复为默认成员

---

## 8. UI 展示规则

### 7.1 首页/健康页
- 显示 FusedMetric 的值，不区分来源
- 如果有多个来源，值旁边显示小图标提示（如 "2 sources"）
- 点击进入详情可切换查看不同来源

### 7.2 指标详情页
- 默认显示融合后的趋势线
- 提供筛选器：「全部来源 / Ring / iPhone / Watch」
- 多来源时可叠加显示（不同颜色的趋势线）
- 每个数据点标注来源设备图标

### 8.3 健康检查页
- 测量前显示"为谁测量"成员选择器（默认=设备绑定者）
- 测量结果标注来源设备 + 归属成员
- 测量完成后写入 HealthMetricStore
- 如果同一指标已有其他来源的近期数据，可显示对比

### 8.4 首页成员切换
- 顶部可切换当前查看的成员（头像横滑）
- 切换后所有数据刷新为该成员的 FusedMetric
- 默认显示 owner（本人）

---

## 8. 设备能力注册

每个设备声明支持的指标和精度：

```swift
// RingDevice
var supportedMetrics: [HealthMetricType] {
    [.heartRate, .spo2, .bodyTemperature, .stress, .ecg,
     .bloodGlucose, .bodyComposition, .emotion, .uv,
     .steps, .calories, .distance, .sleep, .sport, .hrv]
}

var accuracyMap: [HealthMetricType: ReadingAccuracy] {
    [.heartRate: .consumer, .spo2: .consumer, .ecg: .consumer,
     .bodyTemperature: .consumer, .stress: .consumer, ...]
}

// PhoneCameraDevice (rPPG)
var supportedMetrics: [HealthMetricType] {
    [.heartRate, .spo2, .stress]
}

var accuracyMap: [HealthMetricType: ReadingAccuracy] {
    [.heartRate: .estimated, .spo2: .estimated, .stress: .estimated]
}
```

---

## 9. 新增文件结构

```
Sources/
├── Metrics/
│   ├── HealthMetricType.swift          # 统一指标枚举
│   ├── RawReading.swift                # 原始读数模型
│   ├── FusedMetric.swift               # 融合后指标模型
│   ├── FusionPolicy.swift              # 融合策略定义
│   ├── MetricFusionEngine.swift        # 融合引擎
│   └── HealthMetricStore.swift         # 数据存储
├── Profile/
│   ├── HealthProfile.swift             # 家庭成员模型
│   ├── ProfileManager.swift            # 成员管理器
│   └── DeviceBinding.swift             # 设备-成员绑定关系
```

不修改现有 Devices/ 层代码，Metrics/ 层消费 Devices/ 层的输出。

---

## 10. 阶段计划

| 阶段 | 内容 | 依赖 |
|------|------|------|
| Phase 1 | HealthMetricType + RawReading + FusedMetric 模型 | 无 |
| Phase 2 | HealthMetricStore (内存 + UserDefaults) | Phase 1 |
| Phase 3 | MetricFusionEngine (highestAccuracy 策略) | Phase 1-2 |
| Phase 4 | Ring 服务写入 HealthMetricStore | Phase 2-3 |
| Phase 5 | UI 消费 FusedMetric 替代 mock 数据 | Phase 3-4 |
| Phase 6 | 详情页多来源切换 | Phase 5 |
| Phase 7 | 用户自定义融合策略设置页 | Phase 3 |
| Phase 8 | Core Data 持久化 | Phase 2 |
