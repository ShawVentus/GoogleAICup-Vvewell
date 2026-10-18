# 本地健康指标存储层评测报告

- 评测时间：2026-04-20
- 评测范围：`Sources/Metrics/` 全栈 + `Sources/Devices/Ring/` 与存储层对接部分 + `HealthViewController` / `RingCheckViewController` 的数据消费侧
- 主要文件：
  - `Sources/Metrics/Storage/{SQLiteDatabase, HealthMetricStore, SchemaMigrationManager, DisplayCache}.swift`
  - `Sources/Metrics/Models/{RawReading, ReadingPayload, FusedMetric, HealthMetricType}.swift`
  - `Sources/Metrics/Fusion/{MetricFusionEngine, FusionPolicy}.swift`
  - `Sources/Metrics/Sync/SyncEngine.swift`
  - `Sources/Devices/Ring/*.swift`
  - `Sources/Features/Health/Views/HealthViewController.swift`
  - `Sources/Views/RingCheckViewController.swift`

## 1. 架构摘要

单表 append-only 设计：所有指标（16 种 `HealthMetricType`）统一写入 `raw_readings`，标量指标直接占用 `value + unit`，复杂指标（ECG、睡眠、运动、体成分等）通过 `payload_type + payload_json` 扩展。上层通过 `HealthMetricStore`（Combine Publisher）→ `MetricFusionEngine`（按策略合并）→ `DisplayCache`（5 min TTL 内存热缓存）提供读路径。写路径**理论上**由 `RingDevice` / 其他设备适配层构造 `RawReading` 落库，**实际上**当前仓库中没有任何 Ring 适配代码在写入（见 L7 §16）。

---

## 2. 分层总览

### 2.1 各层 bug 数量与严重度分布

| 层 | 组件 | 🔴 blocker | 🟡 重要 | 🟢 次要 | 合计 | 核心关注点 |
|---|---|---:|---:|---:|---:|---|
| **L0** | SQLite 底层封装 (`SQLiteDatabase`) | **2** | 0 | 2 | 4 | 并发 / 内存安全 / API 缺失 |
| **L1** | Schema 与迁移 (`SchemaMigrationManager` + 表定义) | 0 | **3** | 3 | 6 | 表设计 / 约束 / 聚合缺位 |
| **L2** | 数据模型 (`RawReading` / `ReadingPayload`) | **1** | 2 | 4 | 7 | id 稳定性 / 错误降级 / payload 结构 |
| **L3** | 存储对外 API (`HealthMetricStore`) | **1** | 2 | 2 | 5 | 参数绑定失效 / 清理不全 |
| **L4** | 融合引擎 (`MetricFusionEngine`) | 0 | 2 | 2 | 4 | 策略通知链断 / 融合不持久 |
| **L5** | 显示缓存 (`DisplayCache`) | 0 | **3** | 0 | 3 | 线程 / 内存上限 / 生命周期 |
| **L6** | 同步引擎 (`SyncEngine`) | 0 | **3** | 2 | 5 | 线程 / 退避 / 与 L3 联动 |
| **L7** | 设备适配 (`Sources/Devices/Ring/*`) | **1🔴🔴** | 0 | 0 | 1 | **整层断路：本地测量不入库** |
| **L8** | UI 消费 (ViewControllers) | 0 | 0 | 2 | 2 | 生命周期 hook 缺失 |
| — | **合计** | **5** | **15** | **17** | **37** | — |

### 2.2 全栈拓扑

```
L8 UI 消费 ─────────────────────── 🟢🟢
  ↑ Combine
L5 DisplayCache ───────────────── 🟡🟡🟡
  ↑
L4 融合引擎 ───────────────────── 🟡🟡 🟢🟢
  ↑
L3 存储 API ───────────────────── 🔴 🟡🟡 🟢🟢
  ↑
L2 数据模型 ───────────────────── 🔴 🟡🟡 🟢🟢🟢🟢
  ↑
L1 Schema ─────────────────────── 🟡🟡🟡 🟢🟢🟢
  ↑
L0 SQLite 封装 ────────────────── 🔴🔴 🟢🟢
  ↑
L6 SyncEngine ─────────────────── 🟡🟡🟡 🟢🟢
  ↖── 读取 raw_readings

L7 设备适配 ──────────────────── 🔴🔴 ← 当前最贵的问题（整层未接线）
```

### 2.3 决策观察

- L7 断路意味着 L0–L6 的修复都属于"未来投资"——先把 Ring 入库通路打通，其他层的 bug 才会真正体现在本地设备数据上。
- L3 #1（sync 状态写不回）与 L6 #18 联动放大：sync 状态机半瘫 + 线程不稳 → 数据同步链路实际处于不可观测的病态。
- L0 的 #2/#3 影响所有调用者，属于"基础设施级别"bug，任何并发路径都可能踩。

---

## 3. 分层详细问题清单

每层按"编号 / 严重度 / 位置 / 摘要"列出。`#N` 是首轮已编号项，「新」是首轮未归类、本次按层补齐的项。

### L0 · SQLite 底层封装 — `SQLiteDatabase.swift`
**职责**：sqlite3 C API 的 Swift 包装；事务；参数绑定；线程调度

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #2 | 🔴 | 全文 | 串行 `queue` 声明了但 public API 未使用，直接并发操作 `db` 指针 |
| #3 | 🔴 | `SQLiteDatabase.swift:300-313` | `bind` 对 text/blob 传 `nil` destructor（SQLITE_STATIC）绑定瞬时桥接指针 |
| #12 | 🟢 | `SQLiteDatabase.swift:47-50` | DB 文件未设 `NSFileProtectionComplete`，锁屏后仍可读 |
| 新 | 🟢 | `SQLiteDatabase.swift:88-105` | `execute()` 只有无参版本，缺 `execute(_:params:)` → 直接诱发 L3 #1 |

### L1 · Schema 与迁移 — `SchemaMigrationManager.swift` + 表定义
**职责**：DDL 版本管理；forward 迁移；索引与约束

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #6 | 🟡 | `raw_readings.sync_status/sync_id/synced_at` | sync 字段直接挂在"append-only"表上 UPDATE，破坏语义 |
| #8 | 🟡 | 所有趋势/聚合查询 | 无 rollup / daily / hourly 表，全打 raw |
| #10 | 🟡 | `raw_readings` 无 FK | profile 删除留孤儿行；无 `ON DELETE CASCADE` |
| #11 | 🟢 | schema 定义 | `metric_type / source / unit / source_name` 每行字符串冗余 |
| #15 | 🟢 | `SchemaMigrationManager.swift:175-184` | 靠 `localizedDescription` 子串匹配判断"重复列" |
| 新 | 🟢 | `SchemaMigrationManager.swift` 整体 | 无 down migration；硬编码 `switch` 无 registry |

### L2 · 数据模型 — `RawReading.swift` / `ReadingPayload.swift` / `HealthMetricType.swift`
**职责**：指标领域对象；SDK→领域映射；序列化约定

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #4 | 🔴 | `RawReading.swift:110` | `init(from sdkResult:)` 在无 id 时 fallback `UUID()` → 破坏去重 |
| #5 | 🟡 | `RawReading.swift:121, 144` | 未知类型 → `.heartRate`；解析失败 → `value=0`，静默降级 |
| #7 | 🟡 | `ReadingPayload.swift:41-67` | ECG `[Float]` 波形 JSON 化（~75KB），应 BLOB + 压缩 |
| #13 | 🟢 | `RawReading.timestamp` | Unix 秒无时区；跨时区/DST 下 sleep/sport 区间易错 |
| #14 | 🟢 | `ReadingPayload.swift` | Payload 无独立 `version`，加必填项会破坏老数据解码 |
| 新 | 🟢 | `HealthMetricType.defaultUnit` | 一对一映射，血糖等双单位（mg/dL vs mmol/L）无兼容策略 |
| 新 | 🟢 | `RawReading.swift:12` | `schemaVersion` 每行存 Int，与表级 `schema_version` 语义重叠 |

### L3 · 存储对外 API — `HealthMetricStore.swift`
**职责**：应用层读写入口；Combine publisher；FusionPolicy 存取

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #1 | 🔴 | `HealthMetricStore.swift:253-263, 336-343` | `updateSyncStatus` / `saveFusionPolicy` 用 `db.execute()` 发带 `?` SQL，参数绑定失效 |
| #9 | 🟡 | `HealthMetricStore.swift:62-68` | `save(readings:)` 逐条 SELECT+INSERT，N 行 = 2N 语句 |
| 新 | 🟡 | `HealthMetricStore.swift:298-304` | `deleteReadings(olderThan:)` 只清 synced；pending/failed/local 永不清理 |
| 新 | 🟢 | `HealthMetricStore.swift:152-170` 等 | 多个查询默认无 limit / 无分页，大区间一次性加载内存风险 |
| 新 | 🟢 | 全文 | 存储层出错全靠 `throws`，无统一埋点 / Crashlytics 接入 |

### L4 · 融合引擎 — `MetricFusionEngine.swift` / `FusionPolicy.swift`
**职责**：多源读数按策略合成 `FusedMetric`；策略持久化

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #21 | 🟢 | `MetricFusionEngine.swift:21` | `fusedMetricUpdated` 声明但零发射零订阅（死代码） |
| 新 | 🟡 | 读路径全部 | 融合只在读路径热算，不持久化；冷启每次从 raw 重算 |
| 新 | 🟡 | FusionPolicy 写入无通知链路 | L5 DisplayCache 感知不到策略改动（叠加 L3 #1 时 policy 还存不下） |
| 新 | 🟢 | `fuseByUserPreferred` | 首选源当前无数据时 fallback 语义未明确 |

### L5 · 显示缓存 — `DisplayCache.swift`
**职责**：内存级热缓存；订阅 `readingSaved` 自动失效并重算

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #17 | 🟡 | `DisplayCache.swift:173` | `latestMetricUpdated.send` 在 `readingSaved.sink` 回调线程发射，未 hop main |
| #19 | 🟡 | `DisplayCache.swift:15-27` | 四个字典无 LRU / 内存压力回收 |
| 新 | 🟡 | 全文 | profile 切换时无自动 `invalidate(profileId:)`，需调用侧显式清 |

### L6 · 同步引擎 — `SyncEngine.swift`
**职责**：批量上云；重试；网络监听；增量调度

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #18 | 🟡 | `SyncEngine.swift:28-34` + 所有 send | `syncCompleted/syncError/syncStatusChanged` 在 `syncQueue` 后台 send，未 hop main |
| #20 | 🟢 | `SyncEngine.swift:237` 等 | `syncError.send(error)` 无上下文（batch id / 失败 id 列表） |
| #22 | 🟢 | `SyncEngine.swift:44` | `networkSnapshot = .unknown` 初始态被视作"可达"，冷启窗口误判 |
| 新 | 🟡 | 重试路径 | 未见指数退避 / jitter，连环失败下重试风暴 |
| 新 | 🟡 | 与 L3 #1 联动 | sync 状态写不回 → SyncEngine 下一轮仍扫同一批，形成无效重传循环 |

### L7 · 设备适配 — `Sources/Devices/Ring/*` + `RingCheckViewController`
**职责**：SDK 回调 → `RawReading` 构造 → 落盘 → 通知上层

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| #16 | 🔴🔴 critical | `Sources/Devices/Ring/*` 全部；`Sources/Views/RingCheckViewController.swift` | **整层断路**：`Sources/Devices/` 下零 `HealthMetricStore` 引用；Ring 测量走纯 UI 结构 `CheckResult/lastResult`，从不 `store.save` |

### L8 · UI 消费 — `HealthViewController` / `RingCheckViewController`
**职责**：订阅 publisher 驱动 UI；触发主动同步；lifecycle 管理

| 编号 | 严重 | 位置 | 问题 |
|---|---|---|---|
| 新 | 🟢 | `HealthViewController.swift:364-369` | 订阅 `readingSaved` 只用于 `refreshSyncStatus()`，不驱动数据卡片 |
| 新 | 🟢 | profile 切换 / 前后台恢复路径 | 未见主动 `DisplayCache.invalidate` / 强制拉新同步 hook |

### 2.x 已排除的误报（防回归）

首轮审计曾 flag 但实地验证排除的项，避免后续修复误伤：

- ❌ DisplayCache "double-checked locking"：所有判断都在 `queue.sync` 内，无双检
- ❌ HealthViewController 在 `readingSaved` 时未 invalidate 缓存：`DisplayCache.init` 已订阅并在 `handleNewReading` 中调 `invalidate`
- ❌ `fuseByAverage` 的 "Double overflow"：`reduce(0, +)` 对 `[Double]` 类型推断为 Double，无溢出风险

---

## 4. Bug 详情与修复建议

以下按严重度递减、辅以跨层依赖顺序展开。仅对 🔴 与首批 🟡 展开细节；剩余 🟡 / 🟢 在 §4.x 以建议要点集中列出。

### 4.1 🔴🔴 L7 #16 — Ring 原生测量从不入库（系统性通路缺失）

**证据**
```bash
$ grep -rn "HealthMetricStore\|store\.save\|RawReading(" Sources/Devices/
# no matches
$ grep -rn "HealthMetricStore.shared.save" Sources/
Sources/Features/Health/Views/HealthViewController.swift:493: try? HealthMetricStore.shared.save(readings: imported)
# 唯一一处写入，且数据来自云端 API 响应：
# line 491: let imported = response.readings.compactMap { $0.toRawReading() }
```
- `RingCheckViewController` 把测量结果写入 `CheckResult / lastResult` 等纯 UI 结构，测完后不调用任何 Store API
- 各 Ring Service（`RingHealthService / RingSleepService / RingSportService / RingECGService`）不持有 `HealthMetricStore`
- `RawReading.init(from sdkResult:)` 定义了 SDK→RawReading 映射，但无任何代码路径使用它

**影响**
- 戒指本地测的每一条心率 / SpO2 / ECG / 睡眠 / 运动数据在退出页面或杀进程后即丢失
- 融合引擎看不到本地测量，只能融合云端返回的数据 → 融合策略实际不起作用
- `DisplayCache` 订阅 `readingSaved`，但事件源只有云端 → 离线"测完-看结果"链路缓存不更新
- `SyncEngine` 扫 `sync_status = 0` 想上传本地数据，但本地从没存 → 同步空转
- Ring 单设备场景下整个 Metrics 架构等同未接线

**修复**
1. 在各 Ring Service 回调处构造 `RawReading` + 调 `HealthMetricStore.shared.save`
2. 或在 `RingCheckViewController.completeMeasurement` 处统一 batch 落盘
3. 优先级高于 P0 存储底层修复
4. 补集成测试：一条假 SDK 回调 → 期望出现在 `store.readings(for:)` 查询结果
5. 数据审计：生产日志提取平均每用户戒指测量次数 + 当前 DB 行数，估算丢失量

---

### 4.2 🔴 L3 #1 — sync / policy 更新语句参数绑定失效

**证据**
```swift
// HealthMetricStore.swift:253-263
let sql = """
    UPDATE raw_readings
    SET \(setClauses.joined(separator: ", "))
    WHERE id IN (\(placeholders))
"""
params.append(contentsOf: ids)
// Use execute with manual parameter binding
try db.execute(sql)       // ← 没传 params，且 execute() 不支持 ?
```
`SQLiteDatabase.execute` 内部调用 `sqlite3_exec`，后者不支持占位符；带 `?` 的 SQL 在此路径会解析失败或丢 bind。`saveFusionPolicy`（336-343）同病。

**影响**
- 所有 sync 状态推进（`local → pending → uploading → synced`）实际失败 → 数据永远卡初始状态
- 用户配置的融合策略无法落库
- 错误只在日志，UI 无感知
- **与 L6 联动**：SyncEngine 下一轮仍扫同一批未推进的记录，产生无效重传

**修复**
1. 在 `SQLiteDatabase` 增加 `execute(_ sql: String, params: [Any])`，`sqlite3_prepare_v2` + bind + step 实现
2. `updateSyncStatus` / `saveFusionPolicy` 改用该接口
3. 补回归：写入一行 → 调 `updateSyncStatus` → SELECT 验证

---

### 4.3 🔴 L0 #2 — 串行队列声明了但没用

**证据**
```swift
// SQLiteDatabase.swift:20
private let queue = DispatchQueue(label: "com.vvewell.health.sqlite", qos: .userInitiated)
```
`open/close/execute/query/insert/update/delete/inTransaction` 均未经过 `queue.sync`，直接操作 `self.db`。只有 `run(_:)` / `runAsync(_:)` 走队列，但 `HealthMetricStore` 不使用。

**影响**
- BLE 回调线程 + SyncEngine 后台队列并发写 = `sqlite3_step` 在同一连接上并发 = 未定义行为
- WAL 只允许一个 writer，偶发 `SQLITE_BUSY` 或 db 损坏
- 目前不崩只是因为触发路径少（见 L7 #16，Ring 路径根本不在写）

**修复**
- 把 `query/insert/update/delete/execute/inTransaction` 统一包进 `queue.sync { ... }`
- 调用侧无需感知

---

### 4.4 🔴 L0 #3 — bind 使用瞬时指针配 SQLITE_STATIC

**证据**
```swift
// SQLiteDatabase.swift:300-313
case let v as String:
    sqlite3_bind_text(stmt, index, (v as NSString).utf8String, -1, nil)
case let v as Data:
    sqlite3_bind_blob(stmt, index, (v as NSData).bytes, Int32(v.count), nil)
```
第 5 参数 `nil` = SQLITE_STATIC，承诺指针在 statement finalize 前有效。而 `NSString.utf8String` / `NSData.bytes` 桥接产物生命周期只到当行语句结束 → 函数返回后 `sqlite3_step` 才读，可能读脏内存。

**影响**
- 偶发字符串/blob 列乱码、nil、或崩溃
- 并发/内存压力大时更易触发
- 难复现、沉默出错

**修复**
```swift
private let SQLITE_TRANSIENT = unsafeBitCast(
    OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

case let v as String:
    v.withCString { cstr in
        sqlite3_bind_text(stmt, index, cstr, -1, SQLITE_TRANSIENT)
    }
case let v as Data:
    v.withUnsafeBytes { buf in
        sqlite3_bind_blob(stmt, index, buf.baseAddress,
                          Int32(v.count), SQLITE_TRANSIENT)
    }
```

---

### 4.5 🔴 L2 #4 — 去重键不稳定

**证据**
```swift
// RawReading.swift:110
self.id = (sdkResult["id"] as? String) ?? UUID().uuidString
// HealthMetricStore.swift:38-49
let existing = try db.query("SELECT id FROM raw_readings WHERE id = ?", ...)
guard existing.isEmpty else { return }
```
Ring SDK 多数测量回调不带稳定 id，每次重新投递就生成新 UUID，"去重"形同虚设。

**影响**
- 戒指断连后批量补传、app 冷启重读、下拉刷新 → 同一测量入库 N 次
- 趋势/均值被稀释或放大
- 云端同步把重复数据一并推上

**修复**
1. 为 `raw_readings` 增加 `UNIQUE(profile_id, metric_type, source, timestamp, value)` 或 `(source, source_record_id)`
2. 写入改 `INSERT OR IGNORE`；结合 `sqlite3_changes()` 判断是否真写入
3. SDK 适配层用 `(timestamp, type, value)` hash 作稳定 id 兜底，而非随机 UUID
4. 上线前跑 `GROUP BY ... HAVING COUNT(*)>1` 清理历史重复

---

### 4.6 🟡 L5 #17 — DisplayCache 发射不在主线程

**证据**
```swift
// DisplayCache.swift:162-174
private func handleNewReading(_ reading: RawReading) {
    invalidate(profileId: reading.profileId, metric: reading.metricType)
    if let fused = fusionEngine.fuseLatest(...) {
        let key = ...
        queue.sync {
            latestMetrics[key] = fused
            lastUpdated[key] = Date()
        }
        latestMetricUpdated.send(fused)   // ← caller thread，不保证 main
    }
}
```
触发链：`HealthMetricStore.save(reading:) → readingSaved.send → sink → handleNewReading → latestMetricUpdated.send`；首环 `save` 在哪个线程，最终 `send` 就在那。

**修复**：`DispatchQueue.main.async { self.latestMetricUpdated.send(fused) }`；或对外暴露 `.receive(on: RunLoop.main).eraseToAnyPublisher()` 作为 API。

---

### 4.7 🟡 L6 #18 — SyncEngine 所有 subject 在后台 emit

**证据**：`syncCompleted / syncError / syncStatusChanged` 在 `syncQueue`（utility qos）内 `.send`。当前 `HealthViewController:334-355` 手动 `.receive(on: .main)` 兜住，属约定式防护，新订阅者易漏。

**修复**：在 SyncEngine 内 send 前 hop 到 main，或约定"发布者自己保证线程"。

---

### 4.8 🟡 L5 #19 — DisplayCache 无 LRU / 上限

`latestMetrics / dailyMetrics / trendData / lastUpdated` 四字典只有 `invalidate(profileId:)` / `invalidate(profileId:, metric:)` / `clearAll()` 三个清理入口，无总量上限、无过期清除。多 profile × 多 metric × 多 days 查询下单会话轻易上千。

**修复**：`NSCache`（自带内存压力回收）或简单 LRU；最差也加一个 `purgeExpired()` 由后台 timer 驱动。

---

### 4.9 其余 🟡 / 🟢 建议要点（按层聚合）

| 项 | 所属层 | 建议 |
|---|---|---|
| #5 静默降级 | L2 | 未知类型/缺失值直接抛错 + 埋点；不要伪造 `.heartRate` / `value=0` |
| #6 sync 回写 | L1 | 新增 `reading_sync` 副表（1:1 外键 + status/retry/synced_at），`raw_readings` 真·不可变 |
| #7 ECG 波形 | L2 | `payload_blob BLOB` 存 Int16 PCM + zstd；`payload_meta_json` 仅元数据（sampleRate、心率、心律分类） |
| #8 rollup | L1 | 新增 `metric_daily` / `metric_hourly`（min/max/avg/count）；趋势查询走汇总表 |
| #9 批量写 | L3 | `INSERT OR IGNORE ... VALUES (?,...),(?,...)` 多值 insert；一个 prepared stmt + rebind 循环 |
| #10 FK | L1 | `raw_readings.profile_id REFERENCES profiles(id) ON DELETE CASCADE`；`PRAGMA foreign_keys=ON` |
| #11 字符串冗余 | L1 | `metric_types / sources / units` 字典表；`raw_readings` 存 INT FK；可省 60-70% 字符串列空间 |
| #12 文件保护 | L0 | `FileProtectionType.completeUntilFirstUserAuthentication`（注意后台 BLE 写入兼容性，别上来就 complete） |
| #13 时区 | L2 | 每条记录保存 `timezone`（例如 "Asia/Shanghai"）；sleep/sport 按 local day 聚合时必需 |
| #14 payload version | L2 | 协议新增 `version: Int`；解码失败走 fallback decoder |
| #15 迁移脆弱 | L1 | `PRAGMA table_info(profiles)` 显式判断列，而非字符串异常匹配 |
| #20 syncError | L6 | `struct SyncFailure { error; batchId; failedIds }` 包裹 |
| #21 死代码 | L4 | 删除 `fusedMetricUpdated` 或真正 emit（与 `latestMetricUpdated` 二选一） |
| #22 network 初始态 | L6 | `.unknown → .initializing`；首次 sync 等 pathMonitor 第一次回调再跑 |
| L2 新·单位 | L2 | `unit` 列 + `unitGroup` 枚举；或存毫摩尔/毫克/毫升三套规则化值 |
| L2 新·schemaVersion | L2 | 从行级 `RawReading.schemaVersion` 撤出，统一由表级 `schema_version` 承载 |
| L3 新·清理不全 | L3 | `deleteReadings(olderThan:)` 支持按多状态清，或把"过老数据"定义为 `received_at < X` 无视 sync 状态 |
| L3 新·无分页 | L3 | 加 `limit/offset` 默认；或新增 `readingsPaged(...)` API |
| L3 新·无埋点 | L3 | Crashlytics / 自建 telemetry 接入关键 catch 点 |
| L4 新·无持久融合 | L4 | `fused_metrics` 表 + 写路径触发重算；或 L5 落盘 |
| L4 新·policy 通知 | L4 | `FusionPolicy` 写入触发 `Notification` / 专用 publisher，L5 订阅失效 |
| L4 新·userPreferred fallback | L4 | 首选源空数据时按 policy.fallbackStrategy 退到 `highestAccuracy` |
| L5 新·profile 切换 | L5 | `ProfileManager.activeProfile` 变更时统一调 `DisplayCache.invalidate(profileId:)` |
| L6 新·退避 | L6 | 指数退避 + jitter；`sync_retry_count` 超阈值进入死信队列 |
| L6 新·与 #1 联动 | L6 | 修了 #1 后这条自然缓解；加"同批已上传过"指纹避免幂等写入风暴 |
| L8 新·UI 数据驱动 | L8 | `HealthViewController` 直接订阅 `DisplayCache.latestMetricUpdated` 驱动卡片；`readingSaved` 只做 sync 徽章 |
| L8 新·生命周期 | L8 | profile 切换 / app 前后台回归时统一调 `DisplayCache.invalidate` + `SyncEngine.performSyncIfNeeded` |

---

## 5. 修复顺序与迭代计划

### P-1（最优先，链路打通）
- **L7 #16** 把 Ring 原生测量接到 `HealthMetricStore.save`，否则下面一切修复无数据可跑

### P0（本周内，阻塞正确性）
1. **L3 #1** 参数绑定（`updateSyncStatus` / `saveFusionPolicy`）
2. **L0 #2** 全量 SQL 调用包串行队列
3. **L0 #3** bind 改 SQLITE_TRANSIENT
4. **L2 #4** UNIQUE 约束 + `INSERT OR IGNORE` + SDK id 稳定化
5. **L5 #17 + L6 #18** 发布者统一 main-queue hop

**交付**：schema → V3；新增单元/集成测试：并发写、sync 状态流转、重复入库幂等、Ring 回调→DB 可查

### P1（本迭代，1-2 周）
6. L2 #5 错误不降级 + 埋点
7. L1 #6 拆 `reading_sync` 副表（schema V4）
8. L3 #9 批量写多值 insert
9. L1 #10 FK ON DELETE CASCADE
10. L5 #19 DisplayCache 上限/LRU
11. L6 #20 SyncError 包上下文

### P2（下迭代，中长期）
12. L2 #7 ECG BLOB + zstd 迁移
13. L1 #8 rollup 表 + 触发器
14. L1 #11 字典表
15. L0 #12 文件保护
16. L2 #13 时区列
17. L2 #14 payload version
18. L4 #新·持久融合
19. L4 #新·policy 通知链

### P3（锦上添花）
- L1 #15 迁移逻辑健壮化
- L4 #21 清理死代码
- L6 #22 网络状态初始化收紧
- L6 #新·指数退避
- L8 #新·生命周期 hook
- `PRAGMA wal_autocheckpoint` 调优
- 大 payload 分片存储
- 备份/恢复与导出格式

---

## 6. 迁移与风险

- **加 UNIQUE 前**：先跑去重脚本（group by 自然键保留 min(id)）再 `CREATE UNIQUE INDEX`；可在 `migrateToV3` 内做
- **拆 reading_sync**：老字段保留一版本用于回滚；新数据双写，观察 1 版本后删旧列
- **文件保护切 Complete**：若存在后台（锁屏态）BLE 写入会失败；先走 `completeUntilFirstUserAuthentication`
- **BLOB 化 ECG**：老 JSON 行后台任务渐进迁移，不阻塞启动
- 所有 schema 变更走 `SchemaMigrationManager.migrate(to:)`

---

## 7. 附录：核心修复代码骨架

### 7.1 `execute` 带参版本

```swift
@discardableResult
func execute(_ sql: String, params: [Any]) throws -> Int {
    try queue.sync {
        guard isOpen, let db = db else { throw SQLiteError.notOpen }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed
        }
        defer { sqlite3_finalize(stmt) }
        guard let stmt else { throw SQLiteError.prepareFailed }
        for (i, p) in params.enumerated() {
            bind(p, to: stmt, at: Int32(i + 1))
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.executeFailed(sqlite3_errcode(db),
                String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_changes(db))
    }
}
```

### 7.2 bind 修正（TRANSIENT + withCString）

```swift
private let SQLITE_TRANSIENT = unsafeBitCast(
    OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)

private func bind(_ value: Any, to stmt: OpaquePointer, at index: Int32) {
    switch value {
    case let v as String:
        v.withCString { sqlite3_bind_text(stmt, index, $0, -1, SQLITE_TRANSIENT) }
    case let v as Data:
        v.withUnsafeBytes { buf in
            sqlite3_bind_blob(stmt, index, buf.baseAddress,
                              Int32(v.count), SQLITE_TRANSIENT)
        }
    // ... 数值类型不变
    }
}
```

### 7.3 幂等 INSERT

```sql
-- migrateToV3
CREATE UNIQUE INDEX IF NOT EXISTS uq_reading_natural
ON raw_readings(profile_id, metric_type, source, timestamp, value);
```

```swift
// save(reading:)
let sql = "INSERT OR IGNORE INTO raw_readings (...) VALUES (...)"
let rowsChanged = try db.execute(sql, params: [...])
if rowsChanged == 0 { return }   // 已存在，跳过通知
readingSaved.send(reading)
```

### 7.4 Ring 落盘骨架（L7 #16 修复方向）

```swift
// RingHealthService.swift
final class RingHealthService {
    private let store = HealthMetricStore.shared
    private let profileProvider: () -> String

    func handleMeasurement(_ sdkResult: [String: Any]) {
        let profileId = profileProvider()
        let reading = RawReading(from: sdkResult, profileId: profileId,
                                 sourceName: "Vvewell Ring")
        do {
            try store.save(reading: reading)
        } catch {
            // 埋点，不吞
            Telemetry.record(.ringSaveFailed, error: error)
        }
    }
}
```
