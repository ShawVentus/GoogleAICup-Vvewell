# 数据传输规范设计

**Date:** 2026-03-31
**Scope:** 健康数据从设备端 → APP 端 → 云端的全链路传输规范

---

## 1. 全链路数据流

```
设备端                    APP端                          云端
(Ring/Watch/Band)        (iPhone)                      (Vvewell Cloud)

┌──────────┐    BLE     ┌──────────────┐    HTTPS    ┌──────────────┐
│ 传感器采集 │ ────────→ │ L1 设备通信层  │ ─────────→ │ API Gateway   │
│          │  单队列    │              │  批量同步   │              │
│ 本地缓存  │ ←──ACK── │ L2 原始数据层  │ ←─响应──── │ 数据处理服务   │
│          │          │ (SQLite)     │            │              │
│ 自动监测  │          │ L3 融合层     │  WebSocket │ 实时推送服务   │
│ 手动测量  │          │ L4 展示缓存   │ ←─推送──── │ (家庭共享)    │
└──────────┘          └──────────────┘            └──────────────┘
     │                      │                          │
     │                      │                          │
 rPPG 摄像头               本地存储                    云端存储
 (无 BLE)                  SQLite                   时序数据库
```

---

## 2. 第一段：设备 → APP（BLE 传输）

### 2.1 传输协议

| 参数 | 值 |
|------|------|
| 协议 | Bluetooth Low Energy (BLE) 4.2+ |
| MTU | 默认 23 字节，协商后可达 512 字节 |
| 传输模式 | 单队列串行（SDK 限制） |
| 连接管理 | BTService 自动重连 |
| 鉴权 | Keychain 存储的 UniqueAppID |

### 2.2 两种数据采集模式

#### 实时测量（APP 主动触发）

```
APP                          Ring
 │                            │
 │── startMeasurement(HR) ──→│
 │                            │ 传感器采集中...
 │←── ACK (已收到命令) ───────│
 │                            │ 计算中...
 │←── Result (HR=72) ────────│
 │                            │
 │── stopMeasurement ────────→│
 │←── ACK ───────────────────│
```

**超时机制：**

| 测量类型 | 超时时间 | 超时处理 |
|---------|---------|---------|
| HR/SpO2/Temp/Stress/UV | 30 秒 | 停止测量，返回超时错误 |
| ECG | 90 秒 | 关闭 Booster 模式，返回错误 |
| 血糖 | 20 秒（硬件阶段）| 停止采集 |
| 情绪/PPI | 用户设定时长 | 正常结束 |
| 体成分 | 30 秒 | 停止测量 |

#### 历史数据同步（APP 请求回传）

设备自动监测积累的数据，通过多包 BLE 传输回 APP。

```
APP                              Ring
 │                                │
 │── fetchHealthData(date) ─────→│
 │                                │ 查询本地存储
 │←── Packet 1/N ────────────────│
 │── ACK ────────────────────────→│
 │←── Packet 2/N ────────────────│
 │── ACK ────────────────────────→│
 │      ...                       │
 │←── Packet N/N (END) ─────────│
 │── ACK ────────────────────────→│
```

**分包传输规则：**
- 每包最大 144 字节（BTOriginalDataPacket）
- ACK 频率可配（默认每 5 包一次 ACK）
- 超时 5 秒未收到下一包，视为传输失败
- 支持断点续传（记录 packetIndex）

### 2.3 数据完整性保证

```swift
struct TransportGuarantee {
    // BLE 层
    let bleRetryCount: Int = 3              // 发送失败重试次数
    let bleAckTimeout: TimeInterval = 5.0   // ACK 超时
    let blePacketChecksum: Bool = true      // 校验和验证

    // APP 层
    let deduplication: Bool = true          // 按 id + timestamp 去重
    let orderGuarantee: Bool = true         // 按 timestamp 排序写入
    let writeConfirm: Bool = true           // SQLite 写入成功后才 ACK 设备
}
```

### 2.4 rPPG 摄像头数据（无 BLE）

摄像头检测不经过 BLE，直接在 APP 内处理：

```
摄像头 → 视频帧采集 → rPPG 算法（本地） → 结果
                                         ↓
                              RawReading(source: .phone,
                                         accuracy: .estimated)
                                         ↓
                              L2 SQLite 写入
```

无传输层问题，但需要标记 `accuracy: .estimated`。

---

## 3. 第二段：APP 本地处理

### 3.1 数据接收与转换

```
BLE 回调 (ObjC 对象)
    │
    ▼
DeviceService 转换层
    │  BTMeasureResult → RawReading
    │  BTHealthModel → RawReading
    │  BTSleepDetailModel → RawReading(payload: SleepPayload)
    │  BTECGPacket → RawReading(payload: ECGPayload)
    ▼
HealthMetricStore.save()
    │
    ├─ 去重检查（同一 id 不重复写入）
    ├─ Schema version 标记
    ├─ SQLite INSERT（串行队列）
    ├─ 触发融合计算
    ├─ 更新 DisplayCache
    └─ 标记为"待同步"（syncStatus = .pending）
```

### 3.2 本地数据状态机

每条 RawReading 有一个同步状态：

```swift
enum SyncStatus: Int {
    case local = 0          // 仅本地，未同步
    case pending = 1        // 等待同步
    case uploading = 2      // 正在上传
    case synced = 3         // 已同步到云端
    case failed = 4         // 同步失败（等待重试）
}
```

SQLite 表添加字段：

```sql
ALTER TABLE raw_readings ADD COLUMN sync_status INTEGER NOT NULL DEFAULT 0;
ALTER TABLE raw_readings ADD COLUMN sync_id TEXT;           -- 云端返回的 ID
ALTER TABLE raw_readings ADD COLUMN synced_at REAL;         -- 同步完成时间
ALTER TABLE raw_readings ADD COLUMN sync_retry_count INTEGER DEFAULT 0;

CREATE INDEX idx_readings_sync ON raw_readings(sync_status, received_at);
```

---

## 4. 第三段：APP → 云端（HTTPS 传输）

### 4.1 传输协议

| 参数 | 值 |
|------|------|
| 协议 | HTTPS (TLS 1.3) |
| 认证 | Bearer Token (JWT) |
| 格式 | JSON (Content-Type: application/json) |
| 压缩 | gzip (Content-Encoding: gzip) |
| 超时 | 30 秒 |
| 重试 | 3 次，指数退避（2s, 4s, 8s） |

### 4.2 同步策略

```swift
struct SyncPolicy {
    let mode: SyncMode
    let batchSize: Int = 50             // 每批最多 50 条
    let maxPayloadSize: Int = 512_000   // 每批最大 500 KB
    let syncInterval: TimeInterval = 300 // 定时同步间隔（5 分钟）
    let wifiOnly: Bool = false          // 是否仅 WiFi 同步
    let retryLimit: Int = 3
    let retryBackoff: [TimeInterval] = [2, 4, 8]
}

enum SyncMode {
    case realtime       // 实时：数据写入后立即同步（WiFi 下）
    case batch          // 批量：定时批量同步（默认）
    case manual         // 手动：用户主动触发
    case wifiOnly       // 仅 WiFi：蜂窝网络下暂缓
}
```

### 4.3 上传 API

#### 批量上传读数

```
POST /api/v1/health/readings/batch
Authorization: Bearer <jwt_token>
Content-Type: application/json
Content-Encoding: gzip

{
    "device_id": "iPhone-UUID",
    "app_version": "1.0.0",
    "batch_id": "uuid-batch-001",
    "readings": [
        {
            "id": "uuid-reading-001",
            "schema_version": 1,
            "profile_id": "uuid-profile-lichao",
            "metric_type": "heartRate",
            "source": "ring",
            "source_name": "Vvewell Ring",
            "source_version": "V2.0.35",
            "timestamp": 1711872000.0,
            "received_at": 1711872001.5,
            "value": 72.0,
            "unit": "bpm",
            "accuracy": 2,
            "payload_type": null,
            "payload": null
        },
        {
            "id": "uuid-reading-002",
            "schema_version": 1,
            "profile_id": "uuid-profile-lichao",
            "metric_type": "ecg",
            "source": "ring",
            "source_name": "Vvewell Ring",
            "source_version": "V2.0.35",
            "timestamp": 1711872060.0,
            "received_at": 1711872095.0,
            "value": 72.0,
            "unit": "bpm",
            "accuracy": 2,
            "payload_type": "ecg",
            "payload": {
                "sampleRate": 250,
                "waveform": [0.12, 0.15, ...],
                "duration": 30.0,
                "minHeartRate": 58,
                "avgHeartRate": 72,
                "maxHeartRate": 85,
                "rhythmType": 0,
                "rhythmConfidence": 0.95
            }
        }
    ]
}
```

#### 响应

```json
// 成功
{
    "status": "ok",
    "batch_id": "uuid-batch-001",
    "accepted": 2,
    "rejected": 0,
    "results": [
        {"id": "uuid-reading-001", "sync_id": "cloud-001", "status": "accepted"},
        {"id": "uuid-reading-002", "sync_id": "cloud-002", "status": "accepted"}
    ]
}

// 部分失败
{
    "status": "partial",
    "batch_id": "uuid-batch-001",
    "accepted": 1,
    "rejected": 1,
    "results": [
        {"id": "uuid-reading-001", "sync_id": "cloud-001", "status": "accepted"},
        {"id": "uuid-reading-002", "status": "rejected", "reason": "invalid_payload"}
    ]
}
```

#### 同步家庭成员

```
POST /api/v1/profiles/sync
Authorization: Bearer <jwt_token>

{
    "profiles": [
        {
            "id": "uuid-profile-lichao",
            "name": "李超",
            "relationship": "owner",
            "birth_year": 1990,
            "gender": "male",
            "updated_at": 1711872000.0
        },
        {
            "id": "uuid-profile-mom",
            "name": "妈妈",
            "relationship": "parent",
            "birth_year": 1965,
            "gender": "female",
            "updated_at": 1711872000.0
        }
    ]
}
```

#### 拉取云端数据（多设备同步）

```
GET /api/v1/health/readings?profile_id=xxx&since=1711872000&limit=100
Authorization: Bearer <jwt_token>
```

用于：另一台手机登录同一账号后，拉取历史数据。

### 4.4 同步引擎

```swift
class SyncEngine {

    private let policy: SyncPolicy
    private let store: HealthMetricStore
    private let apiClient: APIClient
    private var syncTimer: Timer?

    /// 启动定时同步
    func start()

    /// 停止同步
    func stop()

    /// 手动触发同步
    func syncNow() -> AnyPublisher<SyncResult, Error>

    /// 单次同步流程
    private func performSync() {
        // 1. 查询 pending 状态的读数
        let pending = store.readings(syncStatus: .pending, limit: policy.batchSize)
        guard !pending.isEmpty else { return }

        // 2. 标记为 uploading
        store.updateSyncStatus(ids: pending.map(\.id), status: .uploading)

        // 3. 构建 batch request
        let batch = BatchUploadRequest(readings: pending)

        // 4. 上传
        apiClient.upload(batch)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        // 回退为 failed，增加重试计数
                        self?.store.updateSyncStatus(
                            ids: pending.map(\.id),
                            status: .failed,
                            incrementRetry: true
                        )
                    }
                },
                receiveValue: { [weak self] response in
                    for result in response.results {
                        if result.status == "accepted" {
                            self?.store.updateSyncStatus(
                                ids: [result.id],
                                status: .synced,
                                syncId: result.syncId
                            )
                        } else {
                            self?.store.updateSyncStatus(
                                ids: [result.id],
                                status: .failed
                            )
                        }
                    }
                }
            )
    }
}

struct SyncResult {
    let uploaded: Int
    let failed: Int
    let pendingRemaining: Int
}
```

### 4.5 冲突解决

多设备（如两台 iPhone）同时上传同一成员的数据：

| 场景 | 策略 |
|------|------|
| 相同 reading.id | 去重，以先到为准（幂等） |
| 同一时间段不同值 | 全部保留，云端也做融合 |
| 成员信息冲突 | 以 updated_at 最新的为准（Last Write Wins） |

### 4.6 离线处理

```
网络不可用时：
  ├─ 数据正常写入 L2 (SQLite)
  ├─ sync_status = .pending（积压）
  ├─ UI 正常显示本地数据
  └─ 网络恢复后自动批量同步积压数据

积压数据处理：
  ├─ 按 received_at 顺序上传
  ├─ 超过 1000 条时分批（每批 50 条）
  └─ 超过 7 天未同步的标记为 stale，降低优先级
```

---

## 5. 数据安全

### 5.1 传输安全

| 链路 | 加密 | 认证 |
|------|------|------|
| 设备 → APP (BLE) | BLE 配对加密 | UniqueAppID 鉴权 |
| APP → 云端 (HTTPS) | TLS 1.3 | JWT Bearer Token |
| APP 本地存储 | SQLite 不加密（依赖 iOS 沙盒） | — |

### 5.2 敏感数据处理

```swift
struct DataSensitivity {
    // 高敏感：ECG 波形、血糖值 → 传输时额外加密 payload
    static let highSensitivity: Set<HealthMetricType> = [.ecg, .bloodGlucose, .bloodPressure]

    // 中敏感：一般健康指标 → 标准 HTTPS 传输
    static let mediumSensitivity: Set<HealthMetricType> = [.heartRate, .spo2, .sleep, .emotion]

    // 低敏感：活动数据 → 标准传输
    static let lowSensitivity: Set<HealthMetricType> = [.steps, .calories, .distance]
}
```

### 5.3 数据脱敏（云端存储）

- profileId 不直接使用手机号，用 UUID
- 云端不存储设备 MAC 地址明文（哈希存储）
- ECG 波形云端加密存储（AES-256）
- 日志中不打印原始健康数据值

---

## 6. 监控与可观测性

### 6.1 传输指标

```swift
struct TransportMetrics {
    // BLE 段
    var blePacketsReceived: Int = 0
    var blePacketsDropped: Int = 0
    var bleReconnectCount: Int = 0
    var bleAvgLatencyMs: Double = 0

    // 云端段
    var syncBatchCount: Int = 0
    var syncSuccessCount: Int = 0
    var syncFailCount: Int = 0
    var syncAvgLatencyMs: Double = 0
    var pendingReadingsCount: Int = 0
    var oldestPendingAge: TimeInterval = 0
}
```

### 6.2 健康度检查

APP 内可查看的同步状态：

```
同步状态
├── 最后同步时间：2 分钟前
├── 待同步数据：3 条
├── 同步失败：0 条
├── 今日上传：245 条
└── 网络状态：WiFi
```

---

## 7. 新增文件结构

```
Sources/
├── Metrics/
│   ├── Storage/
│   │   ├── HealthMetricStore.swift      # 添加 syncStatus 字段
│   │   └── ...
│   └── Sync/
│       ├── SyncEngine.swift             # 同步引擎
│       ├── SyncPolicy.swift             # 同步策略配置
│       ├── BatchUploadRequest.swift     # 批量上传请求
│       ├── SyncStatus.swift             # 同步状态枚举
│       └── TransportMetrics.swift       # 传输指标
├── Network/
│   ├── APIClient.swift                  # HTTPS 客户端
│   ├── APIEndpoints.swift               # API 路由定义
│   ├── AuthTokenManager.swift           # JWT 管理
│   └── NetworkMonitor.swift             # 网络状态监听
```
