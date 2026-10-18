# 数据层级、存储与版本管理设计

**Date:** 2026-03-31
**Scope:** Health Metric Fusion 的数据存储细节、分层策略、Schema 版本管理

---

## 1. 数据分层架构

```
┌──────────────────────────────────────────────────────────────┐
│ L4  展示缓存层  DisplayCache                                  │
│     热数据缓存，UI 直接消费，内存驻留                           │
│     当前成员的最新 FusedMetric 快照                             │
├──────────────────────────────────────────────────────────────┤
│ L3  融合层  FusionLayer                                       │
│     MetricFusionEngine 实时计算                                │
│     输入: L2 的 RawReading → 输出: FusedMetric → 写入 L4      │
├──────────────────────────────────────────────────────────────┤
│ L2  原始数据层  RawDataLayer                                   │
│     所有设备的每次读数，持久化到 SQLite                          │
│     不可变（写入后不修改），只追加                               │
├──────────────────────────────────────────────────────────────┤
│ L1  设备通信层  DeviceLayer                                    │
│     BTService / rPPG / 其他 SDK 的原始回调                     │
│     瞬态数据，不持久化                                         │
└──────────────────────────────────────────────────────────────┘
```

### L1 设备通信层（瞬态）

SDK 回调的原始数据，格式各异（ObjC 对象、回调 block、二进制包等）。

- 不持久化，用完即丢
- 由各 Device Service（RingHealthService 等）接收
- 转换为统一的 `RawReading` 后交给 L2

### L2 原始数据层（持久化）

所有测量结果的永久存储。**只追加，不修改，不删除**（除非用户主动清除）。

每条 RawReading 是一个不可变记录：

```swift
struct RawReading: Codable {
    let id: UUID
    let schemaVersion: Int              // 数据格式版本号
    let profileId: String
    let metricType: HealthMetricType
    let source: DeviceType
    let sourceName: String
    let sourceVersion: String?          // 设备固件版本（如 "V2.0.35"）
    let timestamp: Date                 // 测量时间（设备端时间）
    let receivedAt: Date                // 接收时间（手机端时间）
    let value: Double
    let unit: String
    let accuracy: ReadingAccuracy
    let payload: ReadingPayload?        // 结构化附加数据
}
```

### L3 融合层（计算层，不持久化）

MetricFusionEngine 是一个纯计算层：

- 输入：L2 中同一 profileId + 同一 metricType 的最近 N 条 RawReading
- 输出：一个 FusedMetric
- **不持久化**融合结果（因为策略可能变，随时可重算）
- 每次查询时实时计算

### L4 展示缓存层（内存）

UI 消费的热数据：

- 当前活跃成员的所有最新 FusedMetric，内存字典
- APP 启动时从 L2 读取 + L3 计算，填充到 L4
- 新数据写入 L2 后，L3 重算，更新 L4，通知 UI
- APP 进入后台时释放

```swift
class DisplayCache {
    // 当前成员的最新融合指标 [metricType: FusedMetric]
    private var currentMetrics: [HealthMetricType: FusedMetric] = [:]

    // Combine 发布者，UI 订阅
    let metricsUpdated = PassthroughSubject<HealthMetricType, Never>()
}
```

---

## 2. 数据类型与 Payload

不同指标的数据复杂度差异很大。简单指标（心率=72）用 `value: Double` 够了，复杂指标（ECG 波形、睡眠阶段、体成分 15 项）需要结构化 payload。

### ReadingPayload

```swift
enum ReadingPayload: Codable {
    case simple                                     // 仅 value 字段即可
    case ecg(ECGPayload)                           // ECG 波形 + 诊断
    case sleep(SleepPayload)                       // 睡眠阶段数据
    case sport(SportPayload)                       // 运动详情
    case bodyComposition(BodyCompositionPayload)   // 体成分 15 项
    case bloodGlucose(BloodGlucosePayload)         // 血糖报告
    case emotion(EmotionPayload)                   // 情绪分析
    case bloodPressure(BloodPressurePayload)       // 收缩压/舒张压
}
```

### 各 Payload 定义

```swift
struct ECGPayload: Codable {
    let sampleRate: Int                 // 250 Hz
    let waveform: [Float]              // mV 值数组
    let duration: TimeInterval          // 秒
    let minHeartRate: Int
    let avgHeartRate: Int
    let maxHeartRate: Int
    let rhythmType: Int                 // 0=窦性, 1=房颤...
    let rhythmConfidence: Float         // 0.0-1.0
}

struct SleepPayload: Codable {
    let startTime: Date
    let endTime: Date
    let totalMinutes: Int
    let deepMinutes: Int
    let lightMinutes: Int
    let remMinutes: Int
    let awakeMinutes: Int
    let awakeCount: Int
    let stages: [SleepStage]            // 时间轴

    struct SleepStage: Codable {
        let mode: Int                   // 1=light, 2=deep, 3=awake, 5=rem
        let startTimestamp: TimeInterval
        let durationMinutes: Int
    }
}

struct SportPayload: Codable {
    let sportType: Int                  // BTSportType raw value
    let duration: Int                   // 秒
    let calories: Int
    let steps: Int
    let distance: Int                   // 米
    let avgHeartRate: Int
    let maxHeartRate: Int
    let avgPace: Int                    // 秒/公里
    let details: [SportDetail]?         // 分段详情

    struct SportDetail: Codable {
        let timeOffset: Int             // 秒
        let heartRate: Int
        let pace: Int
        let cadence: Int
    }
}

struct BodyCompositionPayload: Codable {
    let bmi: Float
    let bodyFatRate: Float
    let muscleMass: Float
    let skeletalMuscleMass: Float
    let hydration: Float
    let proteinRate: Float
    let boneMass: Float
    let basalMetabolicRate: Float
    let standardWeight: Float
}

struct BloodGlucosePayload: Codable {
    let glucoseValue: Float
    let riskLevel: Int
    let isFasting: Bool?
    let isPostMeal: Bool?
    let serverReportId: String?         // 云端分析报告 ID
}

struct EmotionPayload: Codable {
    let emotionType: Int                // 1-11
    let emotionLabel: String            // "calm", "happy"...
    let emotionCategory: String         // positive/neutral/negative
    let valence: Float
    let stressScore: Int                // 1-99
    let fatigueLevel: Int               // 1-5
    let ppiData: [Int]?                 // 原始 PPI 值
}

struct BloodPressurePayload: Codable {
    let systolic: Int                   // 收缩压
    let diastolic: Int                  // 舒张压
}
```

### value 字段的约定

对于有 payload 的指标，`value` 字段存储最具代表性的单一数值，方便排序/趋势/融合：

| metricType | value 含义 | payload |
|-----------|-----------|---------|
| heartRate | 72 (bpm) | simple |
| spo2 | 98 (%) | simple |
| bodyTemperature | 36.5 (°C) | simple |
| stress | 32 (1-100) | simple |
| hrv | 45 (ms) | simple |
| uv | 3.5 (UV index) | simple |
| ecg | avgHeartRate | ECGPayload |
| sleep | totalMinutes | SleepPayload |
| sport | duration (秒) | SportPayload |
| bodyComposition | bmi | BodyCompositionPayload |
| bloodGlucose | glucoseValue | BloodGlucosePayload |
| emotion | stressScore | EmotionPayload |
| bloodPressure | systolic | BloodPressurePayload |
| steps | 6842 (步) | simple |
| calories | 324 (千卡) | simple |
| distance | 3200 (米) | simple |

---

## 3. SQLite 存储方案

选择 SQLite（通过 Swift 原生 `sqlite3` 或轻量封装），不用 Core Data（过重）。

### 数据库文件

```
Documents/
└── vvewell_health.db          # 单一数据库文件
```

按 profileId 分区查询，不按成员分库（方便家庭数据导出和迁移）。

### Schema

```sql
-- 版本管理表
CREATE TABLE schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL,          -- ISO 8601
    description TEXT
);

-- 原始读数表（核心表，只追加）
CREATE TABLE raw_readings (
    id              TEXT PRIMARY KEY,   -- UUID
    schema_version  INTEGER NOT NULL DEFAULT 1,
    profile_id      TEXT NOT NULL,
    metric_type     TEXT NOT NULL,      -- "heartRate", "ecg"...
    source          TEXT NOT NULL,      -- "ring", "phone", "watch"
    source_name     TEXT NOT NULL,
    source_version  TEXT,
    timestamp       REAL NOT NULL,      -- Unix timestamp (设备端)
    received_at     REAL NOT NULL,      -- Unix timestamp (手机端)
    value           REAL NOT NULL,
    unit            TEXT NOT NULL,
    accuracy        INTEGER NOT NULL,   -- 1=estimated, 2=consumer, 3=medical
    payload_type    TEXT,               -- "ecg", "sleep", "sport"... 或 NULL
    payload_json    TEXT,               -- JSON 序列化的 payload
    created_at      REAL NOT NULL DEFAULT (strftime('%s','now'))
);

-- 索引（查询优化）
CREATE INDEX idx_readings_profile_metric_time
    ON raw_readings(profile_id, metric_type, timestamp DESC);

CREATE INDEX idx_readings_profile_time
    ON raw_readings(profile_id, timestamp DESC);

CREATE INDEX idx_readings_metric_source
    ON raw_readings(metric_type, source, timestamp DESC);

-- 家庭成员表
CREATE TABLE profiles (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    avatar          TEXT,
    relationship    TEXT NOT NULL,      -- "owner", "spouse", "parent", "child"
    birth_year      INTEGER,
    gender          TEXT,               -- "male", "female", "other"
    created_at      REAL NOT NULL DEFAULT (strftime('%s','now')),
    updated_at      REAL NOT NULL DEFAULT (strftime('%s','now'))
);

-- 设备绑定表
CREATE TABLE device_bindings (
    device_type         TEXT NOT NULL,
    device_name         TEXT NOT NULL,
    primary_profile_id  TEXT NOT NULL REFERENCES profiles(id),
    created_at          REAL NOT NULL DEFAULT (strftime('%s','now')),
    PRIMARY KEY (device_type)
);

-- 融合策略表（用户自定义覆盖）
CREATE TABLE fusion_policies (
    metric_type         TEXT PRIMARY KEY,
    strategy            TEXT NOT NULL DEFAULT 'highestAccuracy',
    preferred_source    TEXT,            -- NULL = 自动
    updated_at          REAL NOT NULL DEFAULT (strftime('%s','now'))
);
```

### 数据量估算

| 场景 | 频率 | 每天行数 | 每月行数 |
|------|------|---------|---------|
| Ring 自动监测（30 分钟间隔）| 48 次/天 × 5 指标 | ~240 | ~7,200 |
| 手动测量 | ~3 次/天 | ~3 | ~90 |
| 睡眠 | 1 次/天 | 1 | 30 |
| 运动 | 0-2 次/天 | ~1 | ~30 |
| **合计（单成员）** | | **~245** | **~7,350** |
| **3 个家庭成员** | | **~735** | **~22,050** |

一年约 26 万行，每行约 200-500 字节（简单指标）或 2-50 KB（ECG 波形）。

### 存储空间估算

| 数据类型 | 单条大小 | 一年总量 |
|---------|---------|---------|
| 简单指标（HR/SpO2/Temp...） | ~300 B | ~75 MB |
| 睡眠数据 | ~2 KB | ~720 KB |
| 运动数据 | ~5 KB | ~1.8 MB |
| ECG 波形（30 秒，250Hz） | ~30 KB | ~11 MB（每天 1 次）|
| **总计** | | **~90 MB/年** |

结论：SQLite 完全能胜任，不需要分库分表。

---

## 4. 数据生命周期

```
写入 → 热缓存（7天）→ 温存储（90天）→ 冷存储（1年+）→ 归档/导出
```

### 分层存储策略

```swift
enum DataTier {
    case hot       // 最近 7 天，内存缓存 + SQLite
    case warm      // 8-90 天，仅 SQLite
    case cold      // 91-365 天，仅 SQLite（查询时延可接受）
    case archived  // 365 天+，可选导出为 JSON/CSV 后清理 SQLite
}
```

### 热缓存（L4 DisplayCache）

```swift
class DisplayCache {
    // 最近 7 天的融合结果缓存
    // key = "\(profileId)_\(metricType)_\(dateString)"
    private var cache: [String: FusedMetric] = [:]

    // 最新值快照（每个成员每个指标一个）
    private var latest: [String: [HealthMetricType: FusedMetric]] = [:]

    // 缓存失效
    func invalidate(profileId: String, metric: HealthMetricType)
    func invalidateAll(profileId: String)

    // APP 启动时预热
    func warmUp(profileId: String)
}
```

### 数据清理策略

```swift
struct DataRetentionPolicy {
    let maxAgeDays: Int = 365           // 超过 1 年的数据可归档
    let maxDatabaseSizeMB: Int = 200    // 数据库最大 200MB
    let cleanupInterval: TimeInterval = 86400 * 7  // 每 7 天检查一次

    // ECG 波形特殊处理：原始波形 90 天后压缩存储（只保留摘要）
    let ecgWaveformRetentionDays: Int = 90
}
```

---

## 5. Schema 版本管理

### 版本号体系

```
schemaVersion = 1    初始版本
schemaVersion = 2    添加新字段
schemaVersion = 3    修改 payload 结构
...
```

每条 `RawReading` 记录自身的 `schemaVersion`，这样不同版本的数据可以共存。

### Migration Manager

```swift
class SchemaMigrationManager {

    static let currentVersion = 1

    func migrateIfNeeded(db: Database) {
        let currentDBVersion = getCurrentVersion(db)

        if currentDBVersion < Self.currentVersion {
            for version in (currentDBVersion + 1)...Self.currentVersion {
                applyMigration(db: db, toVersion: version)
                recordMigration(db: db, version: version)
            }
        }
    }

    private func applyMigration(db: Database, toVersion: Int) {
        switch toVersion {
        case 2:
            migration_v2(db)
        case 3:
            migration_v3(db)
        default:
            break
        }
    }
}
```

### 迁移示例

```swift
// V1 → V2：给 raw_readings 添加 source_version 字段
private func migration_v2(_ db: Database) {
    db.execute("""
        ALTER TABLE raw_readings
        ADD COLUMN source_version TEXT;
    """)
}

// V2 → V3：payload 结构变更（ECG 添加 rhythmConfidence）
// 不需要改表结构，因为 payload 是 JSON
// 只需要读取时兼容：
private func migration_v3(_ db: Database) {
    // payload_json 是 JSON，向后兼容
    // 读取时缺失的字段使用默认值
    // 不需要修改已有数据
}
```

### Payload 版本兼容

payload 用 JSON 存储，天然支持向后兼容：

```swift
struct ECGPayload: Codable {
    let sampleRate: Int
    let waveform: [Float]
    let duration: TimeInterval
    let minHeartRate: Int
    let avgHeartRate: Int
    let maxHeartRate: Int
    let rhythmType: Int
    let rhythmConfidence: Float

    // V3 新增字段，旧数据解码时使用默认值
    let filterVersion: String?         // V3 新增
    let signalQuality: Float?          // V3 新增

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sampleRate = try c.decode(Int.self, forKey: .sampleRate)
        waveform = try c.decode([Float].self, forKey: .waveform)
        duration = try c.decode(TimeInterval.self, forKey: .duration)
        minHeartRate = try c.decode(Int.self, forKey: .minHeartRate)
        avgHeartRate = try c.decode(Int.self, forKey: .avgHeartRate)
        maxHeartRate = try c.decode(Int.self, forKey: .maxHeartRate)
        rhythmType = try c.decode(Int.self, forKey: .rhythmType)
        rhythmConfidence = try c.decodeIfPresent(Float.self, forKey: .rhythmConfidence) ?? 0
        filterVersion = try c.decodeIfPresent(String.self, forKey: .filterVersion)
        signalQuality = try c.decodeIfPresent(Float.self, forKey: .signalQuality)
    }
}
```

**规则：**
- 新增字段用 `Optional` 类型 + `decodeIfPresent` + 默认值
- 永远不删除已有字段
- 永远不修改字段类型
- 如果必须破坏性变更，创建新的 payload 类型（如 `ECGPayloadV2`）

### 数据导出格式

```swift
struct ExportBundle: Codable {
    let exportVersion: Int = 1
    let exportDate: Date
    let appVersion: String
    let schemaVersion: Int
    let profile: HealthProfile
    let readings: [RawReading]
    let metadata: ExportMetadata

    struct ExportMetadata: Codable {
        let dateRange: ClosedRange<Date>
        let totalReadings: Int
        let metricTypes: [String]
        let sources: [String]
    }
}
```

导出为 JSON 文件：`vvewell_export_{profileName}_{date}.json`

---

## 6. 数据写入管道

```
Device SDK callback
    │
    ▼
DeviceService (Ring/rPPG/Watch)
    │  转换为 RawReading
    ▼
HealthMetricStore.save(reading)
    │
    ├─ 1. 写入 SQLite (L2)
    │
    ├─ 2. 触发 MetricFusionEngine (L3)
    │      查询同一 profileId + metricType 最近 N 条
    │      按 FusionPolicy 融合
    │      生成 FusedMetric
    │
    ├─ 3. 更新 DisplayCache (L4)
    │
    └─ 4. 发布 Combine 通知
           metricsUpdated.send(metricType)
           UI 收到通知后从 DisplayCache 读取
```

### 写入保证

```swift
class HealthMetricStore {

    private let dbQueue: DispatchQueue  // 串行队列，保证写入顺序

    func save(reading: RawReading) {
        dbQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. 写 SQLite
            self.database.insert(reading)

            // 2. 融合
            let readings = self.database.recentReadings(
                profileId: reading.profileId,
                metric: reading.metricType,
                limit: 10
            )
            let fused = self.fusionEngine.fuse(
                readings: readings,
                for: reading.metricType
            )

            // 3. 更新缓存
            if let fused = fused {
                self.displayCache.update(fused)
            }

            // 4. 通知 UI（主线程）
            DispatchQueue.main.async {
                self.displayCache.metricsUpdated.send(reading.metricType)
            }
        }
    }
}
```

---

## 7. 查询接口

```swift
class HealthMetricStore {

    // === 写入 ===
    func save(reading: RawReading)
    func saveBatch(readings: [RawReading])      // 批量写入（历史同步用）

    // === 最新值 ===
    func latest(metric: HealthMetricType,
                profileId: String) -> FusedMetric?

    func latestAll(profileId: String) -> [HealthMetricType: FusedMetric]

    // === 历史查询 ===
    func readings(metric: HealthMetricType,
                  profileId: String,
                  from: Date, to: Date,
                  source: DeviceType? = nil,
                  limit: Int? = nil) -> [RawReading]

    // === 趋势（按天聚合）===
    func dailyTrend(metric: HealthMetricType,
                    profileId: String,
                    days: Int) -> [DailyAggregate]

    // === 统计 ===
    func stats(metric: HealthMetricType,
               profileId: String,
               from: Date, to: Date) -> MetricStats?

    // === 导出 ===
    func export(profileId: String,
                from: Date, to: Date) -> ExportBundle

    // === 清理 ===
    func cleanup(policy: DataRetentionPolicy)
    func deleteAll(profileId: String)           // 删除某成员所有数据
}

struct DailyAggregate {
    let date: Date
    let min: Double
    let max: Double
    let avg: Double
    let count: Int
    let primarySource: DeviceType
}

struct MetricStats {
    let min: Double
    let max: Double
    let avg: Double
    let count: Int
    let latestValue: Double
    let latestTimestamp: Date
    let sources: [DeviceType]
}
```

---

## 8. 新增文件结构（更新）

```
Sources/
├── Metrics/
│   ├── Models/
│   │   ├── HealthMetricType.swift
│   │   ├── RawReading.swift
│   │   ├── FusedMetric.swift
│   │   ├── ReadingPayload.swift        # 所有 payload 类型定义
│   │   └── ReadingAccuracy.swift
│   ├── Fusion/
│   │   ├── FusionPolicy.swift
│   │   └── MetricFusionEngine.swift
│   ├── Storage/
│   │   ├── HealthMetricStore.swift     # 对外接口
│   │   ├── SQLiteDatabase.swift        # SQLite 封装
│   │   ├── SchemaMigrationManager.swift
│   │   ├── DisplayCache.swift          # L4 热缓存
│   │   └── DataRetentionPolicy.swift
│   └── Export/
│       └── ExportBundle.swift
├── Profile/
│   ├── HealthProfile.swift
│   ├── ProfileManager.swift
│   └── DeviceBinding.swift
```
