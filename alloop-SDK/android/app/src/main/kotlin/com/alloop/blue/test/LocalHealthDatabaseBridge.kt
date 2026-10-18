package com.alloop.blue.test

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.DatabaseUtils
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import io.flutter.plugin.common.MethodCall
import java.nio.charset.StandardCharsets
import java.util.UUID

/** Native SQLite implementation for the Flutter local health database channel. */
class LocalHealthDatabaseBridge(
    context: Context,
    databaseName: String = DATABASE_NAME,
) : SQLiteOpenHelper(context, databaseName, null, DATABASE_VERSION) {

    fun handle(call: MethodCall): Any? = when (call.method) {
        "initialize" -> {
            ensureUser(writableDatabase, DEFAULT_USER_ID)
            null
        }
        "upsertDevice" -> upsertDevice(call.localArguments())
        "saveVitalReading" -> saveVitalReading(call.localArguments())
        "saveRingMeasurementResult" -> saveRingMeasurementResult(call.localArguments())
        "saveRingDailyLog" -> saveRingDailyLog(call.localArguments())
        "loadVitalReadings" -> loadVitalReadings(call.localArguments())
        "countPendingRealVitalReadings" -> countPendingRealVitalReadings(call.localArguments())
        "loadRingDailyLogs" -> loadRingDailyLogs(call.localArguments())
        "manageAlloopDeviceData" -> manageAlloopDeviceData(call.localArguments())
        "markVitalReadingSynced" -> complete {
            markVitalReadingSynced(call.localArguments())
        }
        "saveAnalysisBundle" -> analysisStore.saveAnalysisBundle(call.localArguments())
        "loadAnalysisInputs" -> analysisStore.loadAnalysisInputs(call.localArguments())
        "loadLatestRecommendation" -> analysisStore.loadLatestRecommendation(call.localArguments())
        "loadActiveHealthTags" -> analysisStore.loadActiveHealthTags(call.localArguments())
        "updateLocalTask" -> analysisStore.updateLocalTask(call.localArguments())
        "appendLocalFeedback" -> analysisStore.appendLocalFeedback(call.localArguments())
        "loadPendingSyncBundle" -> analysisStore.loadPendingSyncBundle(call.localArguments())
        "acknowledgeSyncBundle" -> analysisStore.acknowledgeSyncBundle(call.localArguments())
        "saveRecommendationContext" -> complete {
            analysisStore.saveRecommendationContext(call.localArguments())
        }
        "debugAnalysisStatus" -> analysisStore.debugStatus()
        "loadLatestRingTemperature" -> loadLatestRingTemperature(call.localArguments())
        "deleteVitalReadings" -> deleteVitalReadings(call.localArguments())
        "saveHealthIntervention" -> complete {
            saveHealthIntervention(call.localArguments())
        }
        "loadHealthInterventions" -> loadHealthInterventions(call.localArguments())
        "saveWomenHealthRecord" -> saveWomenHealthRecord(call.localArguments())
        "loadWomenHealthRecords" -> loadWomenHealthRecords(call.localArguments())
        "saveMealRecord" -> saveMealRecord(call.localArguments())
        "loadMealRecords" -> loadMealRecords(call.localArguments())
        "cleanupExpiredMealRecords" -> cleanupExpiredMealRecords(call.localArguments())
        "debugStatus" -> debugStatus()
        else -> throw UnsupportedOperationException("Unsupported local database call: ${call.method}")
    }

    override fun onConfigure(database: SQLiteDatabase) {
        super.onConfigure(database)
        database.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(database: SQLiteDatabase) {
        Log.i(TAG, "Creating local health database schema v$DATABASE_VERSION")
        database.execSQL(
            """
            CREATE TABLE users (
              id TEXT PRIMARY KEY,
              auth_uid TEXT UNIQUE,
              username TEXT NOT NULL UNIQUE,
              display_name TEXT,
              created_at INTEGER NOT NULL
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE devices (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              device_id TEXT NOT NULL,
              name TEXT NOT NULL,
              type TEXT NOT NULL CHECK (type IN ('aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar')),
              firmware_version TEXT,
              battery_percent INTEGER CHECK (battery_percent BETWEEN 0 AND 100),
              connected INTEGER NOT NULL DEFAULT 0 CHECK (connected IN (0, 1)),
              last_sync_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              UNIQUE (user_id, device_id),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE vital_readings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              device_id TEXT,
              source TEXT NOT NULL CHECK (source IN ('aizo_ring', 'alloop_ring', 'rppg_phone', 'mmwave_radar')),
              recorded_at INTEGER NOT NULL,
              heart_rate REAL,
              spo2 REAL,
              hrv REAL,
              respiratory_rate REAL,
              temperature REAL,
              stress REAL,
              steps INTEGER,
              signal_quality REAL CHECK (signal_quality IS NULL OR signal_quality BETWEEN 0 AND 1),
              confidence REAL CHECK (confidence IS NULL OR confidence BETWEEN 0 AND 1),
              coverage_ratio REAL CHECK (coverage_ratio IS NULL OR coverage_ratio BETWEEN 0 AND 1),
              quality_flag TEXT CHECK (quality_flag IS NULL OR quality_flag IN ('good', 'degraded', 'poor', 'unknown')),
              wear_state TEXT CHECK (wear_state IS NULL OR wear_state IN ('WORN_GOOD', 'WORN_POOR', 'CHARGING', 'OFF')),
              clock_offset_ms REAL,
              packet_loss_ratio REAL CHECK (packet_loss_ratio IS NULL OR packet_loss_ratio BETWEEN 0 AND 1),
              client_event_id TEXT NOT NULL,
              data_origin TEXT NOT NULL DEFAULT 'REAL' CHECK (data_origin IN ('REAL', 'DEBUG_MOCK')),
              is_valid INTEGER NOT NULL DEFAULT 1 CHECK (is_valid IN (0, 1)),
              is_abnormal INTEGER NOT NULL DEFAULT 0 CHECK (is_abnormal IN (0, 1)),
              raw_data TEXT NOT NULL DEFAULT '{}',
              cloud_synced_at INTEGER,
              cloud_reading_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, device_id, source, recorded_at, raw_data),
              UNIQUE (user_id, client_event_id),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE ring_measurement_results (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              device_id TEXT NOT NULL,
              recorded_at INTEGER NOT NULL,
              sdk_heart_rate INTEGER,
              sdk_spo2 INTEGER,
              algorithm_heart_rate REAL,
              algorithm_spo2 REAL,
              algorithm_hrv_rmssd REAL,
              signal_quality REAL NOT NULL CHECK (signal_quality BETWEEN 0 AND 1),
              valid INTEGER NOT NULL CHECK (valid IN (0, 1)),
              raw_data TEXT NOT NULL DEFAULT '{}',
              created_at INTEGER NOT NULL,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE ring_daily_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              device_id TEXT NOT NULL,
              recorded_at INTEGER NOT NULL,
              log_type TEXT NOT NULL CHECK (log_type IN ('sport', 'activity')),
              heart_rate INTEGER,
              steps INTEGER,
              activity_count INTEGER,
              battery_percent INTEGER CHECK (battery_percent BETWEEN 0 AND 100),
              active_seconds INTEGER,
              temperatures_c TEXT,
              raw_data TEXT NOT NULL DEFAULT '{}',
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, device_id, recorded_at, log_type),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            "CREATE INDEX idx_vital_readings_user_recorded_at " +
                "ON vital_readings(user_id, recorded_at DESC)",
        )
        database.execSQL(
            "CREATE INDEX idx_vital_readings_user_source_recorded_at " +
                "ON vital_readings(user_id, source, recorded_at DESC)",
        )
        database.execSQL(
            "CREATE INDEX idx_vital_readings_device_recorded_at " +
                "ON vital_readings(device_id, recorded_at DESC)",
        )
        database.execSQL(
            "CREATE INDEX idx_vital_readings_pending " +
                "ON vital_readings(user_id, cloud_synced_at, recorded_at)",
        )
        database.execSQL(
            "CREATE INDEX idx_vital_readings_pending_real " +
                "ON vital_readings(user_id, data_origin, cloud_synced_at, recorded_at)",
        )
        database.execSQL(
            "CREATE INDEX idx_ring_measurement_results_user_device_recorded_at " +
                "ON ring_measurement_results(user_id, device_id, recorded_at DESC)",
        )
        database.execSQL(
            "CREATE INDEX idx_ring_daily_log_user_device_recorded_at " +
                "ON ring_daily_log(user_id, device_id, recorded_at DESC)",
        )
        LocalAnalysisSchema.create(database)
        createWellnessDemoTables(database)
        createHealthScoreTables(database)
    }

    override fun onUpgrade(database: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            database.execSQL("ALTER TABLE vital_readings ADD COLUMN cloud_synced_at INTEGER")
            database.execSQL("ALTER TABLE vital_readings ADD COLUMN cloud_reading_id TEXT")
            database.execSQL(
                "CREATE INDEX IF NOT EXISTS idx_vital_readings_pending " +
                    "ON vital_readings(user_id, cloud_synced_at, recorded_at)",
            )
        }
        if (oldVersion < 3) {
            LocalAnalysisSchema.create(database)
            createWellnessDemoTables(database)
        }
        if (oldVersion < 4) createHealthScoreTables(database)
        if (oldVersion < 5) {
            createWellnessDemoTables(database)
            createHealthScoreTables(database)
        }
        if (oldVersion < 6 && tableExists(database, "vital_readings")) {
            addVitalSyncColumns(database)
        }
    }

    private fun createWellnessDemoTables(database: SQLiteDatabase) {
        database.execSQL("""CREATE TABLE IF NOT EXISTS women_health_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, record_type TEXT NOT NULL,
          recorded_at INTEGER NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE)""".trimIndent())
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_women_health_user_time ON women_health_records(user_id, recorded_at DESC)")
        database.execSQL("""CREATE TABLE IF NOT EXISTS meal_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, recorded_at INTEGER NOT NULL,
          photo_path TEXT NOT NULL, payload TEXT NOT NULL, is_demo INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE)""".trimIndent())
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_meal_records_user_time ON meal_records(user_id, recorded_at DESC)")
    }

    private fun createHealthScoreTables(database: SQLiteDatabase) {
        database.execSQL("""CREATE TABLE IF NOT EXISTS health_interventions (
          user_id TEXT NOT NULL, action_id TEXT NOT NULL, day INTEGER NOT NULL,
          completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
          updated_at INTEGER NOT NULL, PRIMARY KEY (user_id, action_id, day),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE)""".trimIndent())
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_health_interventions_user_day ON health_interventions(user_id, day DESC)")
    }

    private inline fun complete(operation: () -> Unit): Any? {
        operation()
        return null
    }

    private fun upsertDevice(args: Map<String, Any?>): Any? {
        val database = writableDatabase
        val userId = args.requiredString("userId")
        ensureUser(database, userId)
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("name", args.requiredString("name"))
            put("type", args.requiredString("type"))
            put("connected", if (args.boolean("connected")) 1 else 0)
            put("updated_at", now)
            args.string("firmwareVersion")?.let { put("firmware_version", it) }
            boundedPercent(args["batteryPercent"])?.let { put("battery_percent", it) }
            args.long("lastSyncAt")?.let { put("last_sync_at", it) }
        }
        val deviceId = args.requiredString("deviceId")
        val updated = database.update(
            "devices",
            values,
            "user_id = ? AND device_id = ?",
            arrayOf(userId, deviceId),
        )
        if (updated == 0) {
            values.put("user_id", userId)
            values.put("device_id", deviceId)
            values.put("created_at", now)
            database.insertOrThrow("devices", null, values)
        }
        Log.d(TAG, "Device upserted: type=${args.requiredString("type")}, device=$deviceId, updated=$updated")
        return null
    }

    private fun saveVitalReading(args: Map<String, Any?>): Long {
        val database = writableDatabase
        val userId = args.requiredString("userId")
        ensureUser(database, userId)
        val source = args.requiredString("source")
        val recordedAt = args.requiredLong("recordedAt")
        val deviceId = args.string("deviceId")
        val rawData = args.string("rawData") ?: "{}"
        val clientEventId = args.string("clientEventId") ?: stableVitalEventId(
            userId = userId,
            source = source,
            deviceId = deviceId,
            recordedAt = recordedAt,
            rawData = rawData,
        )
        val values = ContentValues().apply {
            put("user_id", userId)
            putNullableText("device_id", deviceId)
            put("source", source)
            put("recorded_at", recordedAt)
            putNullableDouble("heart_rate", args.double("heartRate"))
            putNullableDouble("spo2", args.double("spo2"))
            putNullableDouble("hrv", args.double("hrv"))
            putNullableDouble("respiratory_rate", args.double("respiratoryRate"))
            putNullableDouble("temperature", args.double("temperature"))
            putNullableDouble("stress", args.double("stress"))
            putNullableLong("steps", args.long("steps"))
            putNullableDouble("signal_quality", normalizedRatio(args.double("signalQuality")))
            putNullableDouble("confidence", normalizedRatio(args.double("confidence")))
            putNullableDouble("coverage_ratio", normalizedRatio(args.double("coverageRatio")))
            putNullableText("quality_flag", args.string("qualityFlag"))
            putNullableText("wear_state", args.string("wearState"))
            putNullableDouble("clock_offset_ms", args.double("clockOffsetMs"))
            putNullableDouble("packet_loss_ratio", normalizedRatio(args.double("packetLossRatio")))
            put("client_event_id", clientEventId)
            put("data_origin", args.string("dataOrigin") ?: "REAL")
            put("is_valid", if (args.boolean("isValid", true)) 1 else 0)
            put("is_abnormal", if (args.boolean("isAbnormal")) 1 else 0)
            put("raw_data", rawData)
            put("created_at", System.currentTimeMillis())
        }
        val rowId = database.insertWithOnConflict(
            "vital_readings",
            null,
            values,
            SQLiteDatabase.CONFLICT_IGNORE,
        )
        Log.d(TAG, "Vital reading write: source=$source, device=${deviceId ?: "none"}, rowId=$rowId")
        return rowId
    }

    private fun saveRingMeasurementResult(args: Map<String, Any?>): Long {
        val database = writableDatabase
        val userId = args.requiredString("userId")
        ensureUser(database, userId)
        val values = ContentValues().apply {
            put("user_id", userId)
            put("device_id", args.requiredString("deviceId"))
            put("recorded_at", args.requiredLong("recordedAt"))
            putNullableLong("sdk_heart_rate", args.long("sdkHeartRate"))
            putNullableLong("sdk_spo2", args.long("sdkSpo2"))
            putNullableDouble("algorithm_heart_rate", args.double("algorithmHeartRate"))
            putNullableDouble("algorithm_spo2", args.double("algorithmSpo2"))
            putNullableDouble("algorithm_hrv_rmssd", args.double("algorithmHrvRmssd"))
            put("signal_quality", normalizedRatio(args.double("signalQuality")) ?: 0.0)
            put("valid", if (args.boolean("valid")) 1 else 0)
            put("raw_data", args.string("rawData") ?: "{}")
            put("created_at", System.currentTimeMillis())
        }
        val rowId = database.insertOrThrow("ring_measurement_results", null, values)
        Log.d(TAG, "Ring comparison write: device=${args.requiredString("deviceId")}, rowId=$rowId")
        return rowId
    }

    private fun saveRingDailyLog(args: Map<String, Any?>): Long {
        val database = writableDatabase
        val userId = args.requiredString("userId")
        ensureUser(database, userId)
        val values = ContentValues().apply {
            put("user_id", userId)
            put("device_id", args.requiredString("deviceId"))
            put("recorded_at", args.requiredLong("recordedAt"))
            put("log_type", args.requiredString("logType"))
            putNullableLong("heart_rate", args.long("heartRate"))
            putNullableLong("steps", args.long("steps"))
            putNullableLong("activity_count", args.long("activityCount"))
            putNullableLong("battery_percent", boundedPercent(args["batteryPercent"])?.toLong())
            putNullableLong("active_seconds", args.long("activeSeconds"))
            putNullableText("temperatures_c", args.string("temperaturesC"))
            put("raw_data", args.string("rawData") ?: "{}")
            put("created_at", System.currentTimeMillis())
        }
        val rowId = database.insertWithOnConflict(
            "ring_daily_log",
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE,
        )
        Log.d(TAG, "Ring daily log write: type=${args.requiredString("logType")}, device=${args.requiredString("deviceId")}, rowId=$rowId")
        return rowId
    }

    private fun loadVitalReadings(args: Map<String, Any?>): List<Map<String, Any?>> {
        val where = mutableListOf("user_id = ?")
        val whereArgs = mutableListOf(args.requiredString("userId"))
        args.string("source")?.let {
            where += "source = ?"
            whereArgs += it
        }
        args.string("deviceId")?.let {
            where += "device_id = ?"
            whereArgs += it
        }
        args.long("start")?.let {
            where += "recorded_at >= ?"
            whereArgs += it.toString()
        }
        args.long("end")?.let {
            where += "recorded_at < ?"
            whereArgs += it.toString()
        }
        if (args.boolean("onlyUnsynced")) {
            where += "cloud_synced_at IS NULL"
        }
        if (args.boolean("onlyReal")) {
            where += "data_origin = 'REAL'"
        }
        args.long("beforeLocalId")?.let {
            where += "id < ?"
            whereArgs += it.toString()
        }
        val limit = args.long("limit")?.takeIf { it > 0 }?.toString()
        val result = readableDatabase.query(
            "vital_readings",
            null,
            where.joinToString(" AND "),
            whereArgs.toTypedArray(),
            null,
            null,
            if (args.long("beforeLocalId") != null) "id DESC" else "recorded_at DESC",
            limit,
        ).use(::rows)
        Log.d(TAG, "Vital reading query: source=${args.string("source") ?: "all"}, device=${args.string("deviceId") ?: "all"}, count=${result.size}")
        return result
    }

    private fun countPendingRealVitalReadings(args: Map<String, Any?>): Long =
        DatabaseUtils.longForQuery(
            readableDatabase,
            "SELECT count(*) FROM vital_readings " +
                "WHERE user_id = ? AND data_origin = 'REAL' AND cloud_synced_at IS NULL",
            arrayOf(args.requiredString("userId")),
        )

    private fun loadRingDailyLogs(args: Map<String, Any?>): List<Map<String, Any?>> {
        val where = mutableListOf("user_id = ?", "device_id = ?")
        val whereArgs = mutableListOf(
            args.requiredString("userId"),
            args.requiredString("deviceId"),
        )
        args.long("start")?.let {
            where += "recorded_at >= ?"
            whereArgs += it.toString()
        }
        args.long("end")?.let {
            where += "recorded_at < ?"
            whereArgs += it.toString()
        }
        val limit = args.long("limit")?.takeIf { it > 0 }?.toString()
        return readableDatabase.query(
            "ring_daily_log",
            null,
            where.joinToString(" AND "),
            whereArgs.toTypedArray(),
            null,
            null,
            "recorded_at DESC",
            limit,
        ).use(::rows)
    }

    private fun manageAlloopDeviceData(args: Map<String, Any?>): Map<String, Int> {
        val database = writableDatabase
        val userId = args.requiredString("userId")
        val deviceId = args.requiredString("deviceId")
        val deleteHealthData = args.boolean("deleteHealthData")
        val removeDevice = args.boolean("removeDevice")
        val counts = linkedMapOf(
            "vitalReadings" to 0,
            "measurementResults" to 0,
            "dailyLogs" to 0,
            "devices" to 0,
        )
        database.beginTransaction()
        try {
            val where = "user_id = ? AND device_id = ?"
            val whereArgs = arrayOf(userId, deviceId)
            if (deleteHealthData) {
                counts["vitalReadings"] = database.delete(
                    "vital_readings",
                    "$where AND source = ?",
                    arrayOf(userId, deviceId, "alloop_ring"),
                )
                counts["measurementResults"] = database.delete(
                    "ring_measurement_results",
                    where,
                    whereArgs,
                )
                counts["dailyLogs"] = database.delete(
                    "ring_daily_log",
                    where,
                    whereArgs,
                )
            }
            if (removeDevice) {
                counts["devices"] = database.delete("devices", where, whereArgs)
            }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
        Log.i(
            TAG,
            "Alloop device data managed: device=$deviceId, clear=$deleteHealthData, " +
                "remove=$removeDevice, counts=$counts",
        )
        return counts
    }

    private fun markVitalReadingSynced(args: Map<String, Any?>) {
        val values = ContentValues().apply {
            put("cloud_synced_at", args.requiredLong("syncedAt"))
            put("cloud_reading_id", args.requiredString("cloudReadingId"))
        }
        val updated = writableDatabase.update(
            "vital_readings",
            values,
            "id = ? AND user_id = ?",
            arrayOf(args.requiredLong("localId").toString(), args.requiredString("userId")),
        )
        if (updated != 1) error("Local vital row not found: ${args.requiredLong("localId")}")
    }

    private fun loadLatestRingTemperature(args: Map<String, Any?>): Map<String, Any?>? {
        val userId = args.requiredString("userId")
        val deviceId = args.requiredString("deviceId")
        val cursor = readableDatabase.query(
            "ring_daily_log",
            arrayOf("recorded_at", "temperatures_c"),
            "user_id = ? AND device_id = ? AND log_type = ? " +
                "AND temperatures_c IS NOT NULL AND TRIM(temperatures_c) <> ''",
            arrayOf(userId, deviceId, "activity"),
            null,
            null,
            "recorded_at DESC",
        )
        cursor.use {
            while (it.moveToNext()) {
                val recordedAt = it.getLong(0)
                val samples = it.getString(1).split(';')
                for (index in samples.indices.reversed()) {
                    val temperature = samples[index].trim().toDoubleOrNull()
                    if (temperature != null && temperature.isFinite()) {
                        Log.d(TAG, "Ring temperature query: device=$deviceId, recordedAt=$recordedAt")
                        return mapOf(
                            "temperature_c" to temperature,
                            "recorded_at" to recordedAt,
                        )
                    }
                }
            }
        }
        Log.d(TAG, "Ring temperature query: device=$deviceId, no samples")
        return null
    }

    private fun deleteVitalReadings(args: Map<String, Any?>): Int {
        val where = StringBuilder("user_id = ? AND source = ?")
        val whereArgs = mutableListOf(
            args.requiredString("userId"),
            args.requiredString("source"),
        )
        args.string("rawDataContains")?.let {
            where.append(" AND raw_data LIKE ?")
            whereArgs += "%$it%"
        }
        val deleted = writableDatabase.delete("vital_readings", where.toString(), whereArgs.toTypedArray())
        Log.i(TAG, "Vital reading delete: source=${args.requiredString("source")}, count=$deleted")
        return deleted
    }

    private fun saveHealthIntervention(args: Map<String, Any?>) {
        val userId = args.requiredString("userId")
        val database = writableDatabase
        ensureUser(database, userId)
        database.insertWithOnConflict("health_interventions", null, ContentValues().apply {
            put("user_id", userId)
            put("action_id", args.requiredString("actionId"))
            put("day", args.requiredLong("day"))
            put("completed", if (args.boolean("completed")) 1 else 0)
            put("updated_at", System.currentTimeMillis())
        }, SQLiteDatabase.CONFLICT_REPLACE)
    }

    private fun loadHealthInterventions(args: Map<String, Any?>): List<Map<String, Any?>> = readableDatabase.query(
        "health_interventions", null, "user_id = ? AND day = ?",
        arrayOf(args.requiredString("userId"), args.requiredLong("day").toString()), null, null, "updated_at DESC"
    ).use(::rows)

    private fun saveWomenHealthRecord(args: Map<String, Any?>): Long {
        val userId = DEFAULT_USER_ID; ensureUser(writableDatabase, userId)
        return writableDatabase.insertOrThrow("women_health_records", null, ContentValues().apply {
            put("user_id", userId); put("record_type", args.requiredString("recordType")); put("recorded_at", args.requiredLong("recordedAt")); put("payload", args.requiredString("payload")); put("created_at", System.currentTimeMillis())
        })
    }

    private fun loadWomenHealthRecords(args: Map<String, Any?>): List<Map<String, Any?>> = readableDatabase.query(
        "women_health_records", null, "user_id = ?", arrayOf(DEFAULT_USER_ID), null, null, "recorded_at DESC"
    ).use(::rows)

    private fun saveMealRecord(args: Map<String, Any?>): Long {
        val userId = DEFAULT_USER_ID; ensureUser(writableDatabase, userId)
        return writableDatabase.insertOrThrow("meal_records", null, ContentValues().apply {
            put("user_id", userId); put("recorded_at", args.requiredLong("recordedAt")); put("photo_path", args.requiredString("photoPath")); put("payload", args.requiredString("payload")); put("is_demo", if (args.boolean("isDemo", true)) 1 else 0); put("created_at", System.currentTimeMillis())
        })
    }

    private fun loadMealRecords(args: Map<String, Any?>): List<Map<String, Any?>> = readableDatabase.query(
        "meal_records", null, "user_id = ? AND recorded_at >= ?", arrayOf(DEFAULT_USER_ID, args.requiredLong("start").toString()), null, null, "recorded_at DESC"
    ).use(::rows)

    private fun cleanupExpiredMealRecords(args: Map<String, Any?>): List<String> {
        val before = args.requiredLong("before")
        val paths = readableDatabase.query("meal_records", arrayOf("photo_path"), "user_id = ? AND recorded_at < ?", arrayOf(DEFAULT_USER_ID, before.toString()), null, null, null).use { cursor ->
            val result = mutableListOf<String>()
            while (cursor.moveToNext()) result += cursor.getString(0)
            result
        }
        writableDatabase.delete("meal_records", "user_id = ? AND recorded_at < ?", arrayOf(DEFAULT_USER_ID, before.toString()))
        return paths
    }

    private fun debugStatus(): Map<String, Any> {
        val database = readableDatabase
        val counts = listOf(
            "users",
            "devices",
            "vital_readings",
            "ring_measurement_results",
            "ring_daily_log",
            "health_interventions",
            "women_health_records",
            "meal_records",
        ).associateWith { table ->
            DatabaseUtils.longForQuery(database, "SELECT COUNT(*) FROM $table", null)
        }
        val status = linkedMapOf<String, Any>(
            "path" to database.path,
            "version" to database.version,
            "tables" to counts,
        )
        Log.i(TAG, "Database status: $status")
        return status
    }

    private val analysisStore: LocalAnalysisStore
        get() = LocalAnalysisStore(writableDatabase)

    private fun ensureUser(database: SQLiteDatabase, userId: String) {
        val values = ContentValues().apply {
            put("id", userId)
            put("username", userId)
            put("display_name", "Local user")
            put("created_at", System.currentTimeMillis())
        }
        database.insertWithOnConflict("users", null, values, SQLiteDatabase.CONFLICT_IGNORE)
    }

    private fun rows(cursor: Cursor): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        while (cursor.moveToNext()) {
            val row = linkedMapOf<String, Any?>()
            cursor.columnNames.forEachIndexed { index, name ->
                row[name] = when (cursor.getType(index)) {
                    Cursor.FIELD_TYPE_NULL -> null
                    Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(index)
                    Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(index)
                    Cursor.FIELD_TYPE_STRING -> cursor.getString(index)
                    Cursor.FIELD_TYPE_BLOB -> cursor.getBlob(index)
                    else -> null
                }
            }
            result += row
        }
        return result
    }

    private fun MethodCall.localArguments(): Map<String, Any?> {
        val raw = arguments as? Map<*, *> ?: return emptyMap()
        return raw.entries.associate { (key, value) -> key.toString() to value }
    }

    private fun Map<String, Any?>.requiredString(name: String): String =
        string(name) ?: error("Missing $name")

    private fun Map<String, Any?>.string(name: String): String? = this[name] as? String

    private fun Map<String, Any?>.requiredLong(name: String): Long =
        long(name) ?: error("Missing $name")

    private fun Map<String, Any?>.long(name: String): Long? = (this[name] as? Number)?.toLong()

    private fun Map<String, Any?>.double(name: String): Double? =
        (this[name] as? Number)?.toDouble()?.takeIf { it.isFinite() }

    private fun Map<String, Any?>.boolean(name: String, fallback: Boolean = false): Boolean = when (val value = this[name]) {
        null -> fallback
        is Boolean -> value
        is Number -> value.toInt() != 0
        else -> fallback
    }

    private fun ContentValues.putNullableText(name: String, value: String?) {
        if (value == null) putNull(name) else put(name, value)
    }

    private fun ContentValues.putNullableLong(name: String, value: Long?) {
        if (value == null) putNull(name) else put(name, value)
    }

    private fun ContentValues.putNullableDouble(name: String, value: Double?) {
        if (value == null) putNull(name) else put(name, value)
    }

    private fun boundedPercent(value: Any?): Int? =
        (value as? Number)?.toInt()?.coerceIn(0, 100)

    private fun normalizedRatio(value: Double?): Double? {
        if (value == null) return null
        return (if (value > 1.0) value / 100.0 else value).coerceIn(0.0, 1.0)
    }

    private fun tableExists(database: SQLiteDatabase, table: String): Boolean =
        DatabaseUtils.longForQuery(
            database,
            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?",
            arrayOf(table),
        ) == 1L

    private fun addVitalSyncColumns(database: SQLiteDatabase) {
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN coverage_ratio REAL")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN quality_flag TEXT")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN wear_state TEXT")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN clock_offset_ms REAL")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN packet_loss_ratio REAL")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN client_event_id TEXT")
        database.execSQL("ALTER TABLE vital_readings ADD COLUMN data_origin TEXT NOT NULL DEFAULT 'REAL'")
        database.execSQL(
            "UPDATE vital_readings SET data_origin = 'DEBUG_MOCK' " +
                "WHERE raw_data LIKE '%\"isMock\":true%' OR raw_data LIKE '%\"origin\":\"debugMock\"%'",
        )
        database.query(
            "vital_readings",
            arrayOf("id", "user_id", "source", "device_id", "recorded_at", "raw_data"),
            "client_event_id IS NULL",
            null,
            null,
            null,
            "id",
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val eventId = stableVitalEventId(
                    userId = cursor.getString(1),
                    source = cursor.getString(2),
                    deviceId = cursor.getString(3),
                    recordedAt = cursor.getLong(4),
                    rawData = "${cursor.getString(5)}|legacy-row:${cursor.getLong(0)}",
                )
                database.execSQL(
                    "UPDATE vital_readings SET client_event_id = ? WHERE id = ?",
                    arrayOf<Any>(eventId, cursor.getLong(0)),
                )
            }
        }
        database.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_vital_readings_client_event " +
                "ON vital_readings(user_id, client_event_id)",
        )
        database.execSQL(
            "CREATE INDEX IF NOT EXISTS idx_vital_readings_pending_real " +
                "ON vital_readings(user_id, data_origin, cloud_synced_at, recorded_at)",
        )
    }

    private fun stableVitalEventId(
        userId: String,
        source: String,
        deviceId: String?,
        recordedAt: Long,
        rawData: String,
    ): String = UUID.nameUUIDFromBytes(
        "$userId|$source|${deviceId.orEmpty()}|$recordedAt|$rawData"
            .toByteArray(StandardCharsets.UTF_8),
    ).toString()

    companion object {
        private const val DATABASE_NAME = "alloop_health.db"
        private const val DATABASE_VERSION = 6
        private const val DEFAULT_USER_ID = "local-user"
        private const val TAG = "LocalHealthDatabase"
    }
}
