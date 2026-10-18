# SQLite Local Database Implementation Plan

**Date:** 2026-04-01
**Scope:** Implement SQLite database for Vvewell iOS app based on design specs

---

## 1. Current State

**SQLite database implementation is COMPLETE.** All planned components have been created:

- Data models (6 files): `HealthMetricType`, `DeviceType`, `ReadingAccuracy`, `RawReading`, `FusedMetric`, `ReadingPayload`
- Storage layer (4 files): `SQLiteDatabase`, `SchemaMigrationManager`, `HealthMetricStore`, `DisplayCache`
- Profile management (3 files): `HealthProfile`, `ProfileManager`, `DeviceBinding`
- Fusion engine (2 files): `FusionPolicy`, `MetricFusionEngine`
- Sync engine (4 files): `SyncEngine`, `SyncPolicy`, `SyncStatus`, `BatchUploadRequest`

**Previous state:** The app used JSON file (`health_records.json`) for health records (max 50 records) and `UserDefaults` for user profile and auth state.

---

## 2. Database Schema

### 2.1 Table: `schema_version`

```sql
CREATE TABLE schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL,          -- ISO 8601
    description TEXT
);
```

### 2.2 Table: `raw_readings` (Core table, append-only)

```sql
CREATE TABLE raw_readings (
    id              TEXT PRIMARY KEY,   -- UUID
    schema_version  INTEGER NOT NULL DEFAULT 1,
    profile_id      TEXT NOT NULL,
    metric_type     TEXT NOT NULL,      -- "heartRate", "ecg"...
    source          TEXT NOT NULL,      -- "ring", "phone", "watch"
    source_name     TEXT NOT NULL,
    source_version  TEXT,
    timestamp       REAL NOT NULL,      -- Unix timestamp (device time)
    received_at     REAL NOT NULL,      -- Unix timestamp (phone time)
    value           REAL NOT NULL,
    unit            TEXT NOT NULL,
    accuracy        INTEGER NOT NULL,   -- 1=estimated, 2=consumer, 3=medical
    payload_type    TEXT,               -- "ecg", "sleep", "sport"... or NULL
    payload_json    TEXT,               -- JSON serialized payload
    created_at      REAL NOT NULL DEFAULT (strftime('%s','now')),
    -- Sync status columns (from transport design)
    sync_status     INTEGER NOT NULL DEFAULT 0,  -- 0=local, 1=pending, 2=uploading, 3=synced, 4=failed
    sync_id         TEXT,               -- Cloud returned ID
    synced_at       REAL,               -- Sync completion timestamp
    sync_retry_count INTEGER DEFAULT 0
);

-- Indexes
CREATE INDEX idx_readings_profile_metric_time
    ON raw_readings(profile_id, metric_type, timestamp DESC);

CREATE INDEX idx_readings_profile_time
    ON raw_readings(profile_id, timestamp DESC);

CREATE INDEX idx_readings_metric_source
    ON raw_readings(metric_type, source, timestamp DESC);

CREATE INDEX idx_readings_sync
    ON raw_readings(sync_status, received_at);
```

### 2.3 Table: `profiles`

```sql
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
```

### 2.4 Table: `device_bindings`

```sql
CREATE TABLE device_bindings (
    device_type         TEXT NOT NULL,
    device_name         TEXT NOT NULL,
    primary_profile_id  TEXT NOT NULL REFERENCES profiles(id),
    created_at          REAL NOT NULL DEFAULT (strftime('%s','now')),
    PRIMARY KEY (device_type)
);
```

### 2.5 Table: `fusion_policies`

```sql
CREATE TABLE fusion_policies (
    metric_type         TEXT PRIMARY KEY,
    strategy            TEXT NOT NULL DEFAULT 'highestAccuracy',
    preferred_source    TEXT,            -- NULL = auto
    updated_at          REAL NOT NULL DEFAULT (strftime('%s','now'))
);
```

---

## 3. Metric Types (16 unified)

| Category | Types |
|----------|-------|
| **Basic Physiological** | heartRate, spo2, bloodPressure, bodyTemperature, stress, hrv |
| **Specialized Tests** | ecg, bloodGlucose, bodyComposition, emotion, uv |
| **Activity & Sleep** | steps, calories, distance, sleep, sport |

---

## 4. Data Sources & Accuracy Levels

| Source | DeviceType | Accuracy | Notes |
|--------|------------|----------|-------|
| Ring | `.ring` | consumer (2) | Primary device, PPG sensors |
| iPhone Camera | `.phone` | estimated (1) | rPPG algorithm |
| Future Watch | `.watch` | consumer (2) | Planned support |
| Medical Device | `.medical` | medical (3) | External certified devices |

---

## 5. Fusion Strategies

| Strategy | Logic | Default For |
|----------|-------|-------------|
| `highestAccuracy` | Pick highest accuracy source; ties → most recent | heartRate, spo2, stress, ecg, bloodGlucose, sleep, steps |
| `mostRecent` | Pick newest timestamp | Real-time priority scenarios |
| `average` | Average values from multiple sources | Reference metrics |
| `userPreferred` | User-specified source override | Manual override |

---

## 6. Payload Types (JSON in `payload_json`)

| payload_type | Swift struct | Key fields |
|--------------|--------------|------------|
| ecg | ECGPayload | waveform: [Float], sampleRate, duration, minHeartRate, avgHeartRate, maxHeartRate, rhythmType, rhythmConfidence |
| sleep | SleepPayload | totalMinutes, deepMinutes, lightMinutes, remMinutes, awakeMinutes, stages |
| sport | SportPayload | sportType, duration, calories, steps, distance, avgHeartRate, maxHeartRate |
| bodyComposition | BodyCompositionPayload | bmi, bodyFatRate, muscleMass, hydration, boneMass, basalMetabolicRate |
| bloodGlucose | BloodGlucosePayload | glucoseValue, riskLevel, isFasting |
| emotion | EmotionPayload | emotionType, stressScore, fatigueLevel, valence |
| bloodPressure | BloodPressurePayload | systolic, diastolic |

---

## 7. Measurement Types Mapping (Ring SDK → HealthMetricType)

| SDK Code | SDK Name | HealthMetricType | Payload |
|----------|----------|------------------|---------|
| 0x01 | HR | heartRate | simple |
| 0x02 | SpO2 | spo2 | simple |
| 0x04 | ECG | ecg | ECGPayload |
| 0x06 | Temperature | bodyTemperature | simple |
| 0x07 | Body Composition | bodyComposition | BodyCompositionPayload |
| 0x08 | Glucose | bloodGlucose | BloodGlucosePayload |
| 0x09 | Stress | stress | simple |
| 0x0A | UV | uv | simple |

---

## 8. Sleep Stage Codes

| Code | Mode | Display |
|------|------|---------|
| 0x01 | Light Sleep | 浅睡 |
| 0x02 | Deep Sleep | 深睡 |
| 0x03 | Awake | 清醒 |
| 0x04 | Not Worn | 未佩戴 |
| 0x05 | REM | REM |
| 0x07 | Shutdown | 关机 |

---

## 9. Sport Types

| Code | Type |
|------|------|
| 0x05 | Indoor Walk |
| 0x07 | Indoor Bike |
| 0x08 | Indoor Run |
| 0x09 | Outdoor Walk |
| 0x0A | Outdoor Run |
| 0x0B | Outdoor Ride |

---

## 10. Emotion Types (11 categories)

| Code | Emotion | Category |
|------|---------|----------|
| 1 | Anxiety | negative |
| 2 | Sadness | negative |
| 3 | Unpleasant | negative |
| 4 | Tension | neutral |
| 5 | Challenge | neutral |
| 6 | Confusion | neutral |
| 7 | Calm | positive |
| 8 | Zen | positive |
| 9 | Pleasant | positive |
| 10 | Happy | positive |
| 11 | Excited | positive |

---

## 11. Data Sync Flow

```
Ring SDK callback
    │
    ▼
DeviceService (RingHealthService)
    │  Convert to RawReading
    ▼
HealthMetricStore.save(reading)
    │
    ├─ 1. Deduplication check (same id not written twice)
    ├─ 2. Schema version tag
    ├─ 3. SQLite INSERT (serial queue)
    ├─ 4. Mark sync_status = pending
    ├─ 5. Trigger MetricFusionEngine
    ├─ 6. Update DisplayCache (L4)
    └─ 7. Publish Combine notification
           UI receives update

Background Sync (batch mode, every 5 min):
    pending readings → gzip → POST /api/v1/health/readings/batch
    on success: sync_status = synced, sync_id = cloud_id
    on failure: sync_status = failed, retry with exponential backoff (2s, 4s, 8s)
```

---

## 12. Sync Status Values

| Status | Code | Description |
|--------|------|-------------|
| local | 0 | Local only, not synced |
| pending | 1 | Waiting for sync |
| uploading | 2 | Currently uploading |
| synced | 3 | Successfully synced to cloud |
| failed | 4 | Sync failed, awaiting retry |

---

## 13. BLE Data Constraints

| Constraint | Value |
|------------|-------|
| Max packet size | 144 bytes |
| ACK frequency | Every 5 packets |
| Packet timeout | 5 seconds |
| Retry count | 3 attempts |
| Queue model | Single serial queue (no concurrent requests) |

---

## 14. Data Retention Policy

| Tier | Age | Storage | Notes |
|------|-----|---------|-------|
| Hot | 0-7 days | Memory + SQLite | DisplayCache, instant access |
| Warm | 8-90 days | SQLite only | Normal queries |
| Cold | 91-365 days | SQLite | Slower queries acceptable |
| Archived | 365+ days | Export to JSON/CSV | Optional cleanup from SQLite |

---

## 15. Security & Privacy

| Data Sensitivity | Examples | Protection |
|------------------|----------|------------|
| **High** | ECG waveform, blood glucose, blood pressure | AES-256 encryption in transit, encrypted at rest in cloud |
| **Medium** | heartRate, spo2, sleep, emotion | TLS 1.3 in transit |
| **Low** | steps, calories, distance | Standard HTTPS |

**Privacy Rules:**
- profileId uses UUID (not phone number)
- MAC addresses stored as hash only
- Logs never print raw health values

---

## 16. File Structure to Create

```
Sources/
├── Metrics/
│   ├── Models/
│   │   ├── HealthMetricType.swift      # Enum of all metric types
│   │   ├── DeviceType.swift            # Device source enum
│   │   ├── ReadingAccuracy.swift       # Accuracy enum
│   │   ├── RawReading.swift            # Core reading model
│   │   ├── FusedMetric.swift           # Fused result model
│   │   └── ReadingPayload.swift        # All payload types
│   ├── Fusion/
│   │   ├── FusionPolicy.swift          # Fusion strategy enum
│   │   └── MetricFusionEngine.swift    # Fusion logic
│   ├── Storage/
│   │   ├── HealthMetricStore.swift     # Public API
│   │   ├── SQLiteDatabase.swift        # SQLite wrapper
│   │   ├── SchemaMigrationManager.swift # Version migrations
│   │   └── DisplayCache.swift          # L4 memory cache
│   └── Sync/
│       ├── SyncEngine.swift            # Sync engine
│       ├── SyncPolicy.swift            # Sync strategy config
│       ├── SyncStatus.swift            # Sync status enum
│       └── BatchUploadRequest.swift    # Batch upload model
├── Profile/
│   ├── HealthProfile.swift             # Profile model
│   ├── ProfileManager.swift            # Profile CRUD
│   └── DeviceBinding.swift             # Device binding model
└── Network/
    ├── APIClient.swift                 # HTTPS client (extend existing)
    ├── APIEndpoints.swift              # API routes
    └── NetworkMonitor.swift            # Network status
```

---

## 17. Implementation Phases

| Phase | Content | Status |
|-------|---------|--------|
| 1 | HealthMetricType + DeviceType + ReadingAccuracy enums | ✅ Complete |
| 2 | RawReading + FusedMetric + ReadingPayload models | ✅ Complete |
| 3 | SQLiteDatabase wrapper + SchemaMigrationManager | ✅ Complete |
| 4 | HealthMetricStore public API | ✅ Complete |
| 5 | ProfileManager + DeviceBinding | ✅ Complete |
| 6 | MetricFusionEngine with fusion policies | ✅ Complete |
| 7 | DisplayCache (L4 memory layer) | ✅ Complete |
| 8 | SyncEngine + SyncPolicy | ✅ Complete |
| 9 | Migrate existing health_records.json to SQLite | ⏳ Pending integration |

---

## 18. Storage Estimates

| Data Type | Single Record Size | Annual Volume |
|-----------|-------------------|---------------|
| Simple metrics (HR/SpO2/Temp...) | ~300 B | ~75 MB |
| Sleep data | ~2 KB | ~720 KB |
| Sport data | ~5 KB | ~1.8 MB |
| ECG waveform (30s, 250Hz) | ~30 KB | ~11 MB (daily) |
| **Total** | | **~90 MB/year** |

For 3 family members: ~90 MB/year total.

---

## 19. Notes

- **Implementation Date:** 2026-04-02 (completed)
- Database file: `Documents/vvewell_health.db`
- All writes on serial queue for thread safety
- Payload stored as JSON for schema flexibility
- Sync status integrated into raw_readings table
- BLE operations are single-queue (no concurrent requests to Ring)
- Feature flags from SDK are unreliable (Stress flag=0 but works)

## 20. Next Steps / Integration Points

| Component | Integration Task | Where |
|-----------|-----------------|-------|
| `HealthMetricStore` | Replace `health_records.json` writes | `RingHealthService`, device callbacks |
| `SyncEngine` | Wire to app lifecycle & background refresh | `AppDelegate`, `SceneDelegate` |
| `ProfileManager` | Connect to existing profile UI | `HealthProfileEditViewController` |
| `DisplayCache` | Replace in-memory metric storage | `MainViewController` home cards |
| Migration | JSON → SQLite one-time import | App launch / settings migration |

---

**Last Updated:** 2026-04-02
