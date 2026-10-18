package com.alloop.blue.test

import android.content.ContentValues
import android.database.Cursor
import android.database.DatabaseUtils
import android.database.sqlite.SQLiteDatabase

object LocalAnalysisSchema {
    val tableNames = listOf(
        "l0_fused_metrics",
        "analysis_runs",
        "analysis_metric_state",
        "health_tags",
        "recommendation_context_cache",
        "recommendation_decisions",
        "health_tasks",
        "recommendation_feedback",
        "sync_outbox",
    )

    fun create(database: SQLiteDatabase) {
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS l0_fused_metrics (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              metric_type TEXT NOT NULL,
              window_start INTEGER NOT NULL,
              window_end INTEGER NOT NULL,
              status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'INTERVAL', 'ABSTAINED')),
              value REAL,
              interval_lower REAL,
              interval_upper REAL,
              unit TEXT NOT NULL,
              confidence REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
              signal_quality REAL NOT NULL CHECK (signal_quality BETWEEN 0 AND 1),
              coverage_ratio REAL NOT NULL CHECK (coverage_ratio BETWEEN 0 AND 1),
              quality_flag TEXT NOT NULL,
              conflict_flag INTEGER NOT NULL CHECK (conflict_flag IN (0, 1)),
              coverage_mask_json TEXT NOT NULL,
              contributors_json TEXT NOT NULL,
              evidence_json TEXT NOT NULL,
              wear_state TEXT,
              abstain_reason TEXT,
              algorithm_version TEXT NOT NULL,
              input_fingerprint TEXT NOT NULL,
              data_origin TEXT NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, input_fingerprint),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS analysis_runs (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              as_of INTEGER NOT NULL,
              input_count INTEGER NOT NULL,
              accepted_count INTEGER NOT NULL,
              model_version TEXT NOT NULL,
              policy_version TEXT NOT NULL,
              input_fingerprint TEXT NOT NULL,
              status TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, input_fingerprint, model_version, policy_version),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS analysis_metric_state (
              run_id TEXT NOT NULL,
              metric_type TEXT NOT NULL,
              sample_count INTEGER NOT NULL,
              first_at INTEGER,
              latest_at INTEGER,
              mean_value REAL NOT NULL,
              m2 REAL NOT NULL,
              ew_mean REAL,
              ew_variance REAL,
              adwin_state_json TEXT NOT NULL,
              elevated_run INTEGER NOT NULL,
              suppressed_run INTEGER NOT NULL,
              payload_json TEXT NOT NULL,
              PRIMARY KEY (run_id, metric_type),
              FOREIGN KEY (run_id) REFERENCES analysis_runs(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS health_tags (
              id TEXT PRIMARY KEY,
              run_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              tag_key TEXT NOT NULL,
              tag_type TEXT NOT NULL,
              tag_value_json TEXT NOT NULL,
              evidence_json TEXT NOT NULL,
              weight REAL NOT NULL CHECK (weight BETWEEN 0 AND 1),
              confidence REAL NOT NULL CHECK (confidence BETWEEN 0 AND 1),
              valid_from INTEGER NOT NULL,
              valid_to INTEGER,
              model_version TEXT NOT NULL,
              policy_version TEXT NOT NULL,
              input_fingerprint TEXT NOT NULL,
              demo_baseline INTEGER NOT NULL CHECK (demo_baseline IN (0, 1)),
              data_origin TEXT NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, tag_key, input_fingerprint, policy_version),
              FOREIGN KEY (run_id) REFERENCES analysis_runs(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS recommendation_context_cache (
              user_id TEXT PRIMARY KEY,
              context_json TEXT NOT NULL,
              catalog_json TEXT NOT NULL,
              context_version TEXT NOT NULL,
              fetched_at INTEGER NOT NULL,
              expires_at INTEGER NOT NULL,
              data_origin TEXT NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS recommendation_decisions (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              client_request_id TEXT NOT NULL,
              decided_at INTEGER NOT NULL,
              expires_at INTEGER NOT NULL,
              surface TEXT NOT NULL,
              status TEXT NOT NULL,
              context_snapshot_json TEXT NOT NULL,
              health_tag_snapshot_json TEXT NOT NULL,
              candidate_snapshot_json TEXT NOT NULL,
              final_plan_json TEXT NOT NULL,
              feature_schema_version TEXT NOT NULL,
              matrix_version TEXT NOT NULL,
              registry_version TEXT NOT NULL,
              policy_version TEXT NOT NULL,
              safety_version TEXT NOT NULL,
              data_origin TEXT NOT NULL CHECK (data_origin IN ('REAL', 'SIMULATION_ONLY')),
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, client_request_id),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS health_tasks (
              id TEXT PRIMARY KEY,
              decision_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              catalog_item_id TEXT NOT NULL,
              title_snapshot TEXT NOT NULL,
              goal_snapshot_json TEXT NOT NULL,
              due_at INTEGER NOT NULL,
              status TEXT NOT NULL CHECK (status IN ('pending', 'started', 'completed', 'dismissed', 'expired', 'cancelled')),
              progress REAL NOT NULL CHECK (progress BETWEEN 0 AND 1),
              completed_at INTEGER,
              client_task_id TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              UNIQUE (user_id, client_task_id),
              FOREIGN KEY (decision_id) REFERENCES recommendation_decisions(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS recommendation_feedback (
              id TEXT PRIMARY KEY,
              decision_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              catalog_item_id TEXT NOT NULL,
              event_type TEXT NOT NULL CHECK (event_type IN ('IMPRESSION', 'OPEN', 'START', 'COMPLETE', 'DISMISS')),
              occurred_at INTEGER NOT NULL,
              client_event_id TEXT NOT NULL,
              source TEXT NOT NULL,
              metadata_json TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              cloud_synced_at INTEGER,
              cloud_id TEXT,
              created_at INTEGER NOT NULL,
              UNIQUE (user_id, client_event_id),
              FOREIGN KEY (decision_id) REFERENCES recommendation_decisions(id) ON DELETE CASCADE,
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL(
            """
            CREATE TABLE IF NOT EXISTS sync_outbox (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              user_id TEXT NOT NULL,
              entity_type TEXT NOT NULL,
              local_id TEXT NOT NULL,
              operation TEXT NOT NULL DEFAULT 'UPSERT',
              payload_hash TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_flight', 'acknowledged', 'rejected')),
              last_error TEXT,
              created_at INTEGER NOT NULL,
              acknowledged_at INTEGER,
              UNIQUE (entity_type, local_id, payload_hash),
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_local_fused_window ON l0_fused_metrics(user_id, window_start, metric_type)")
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_local_tags_active ON health_tags(user_id, valid_from, valid_to)")
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_local_decision_latest ON recommendation_decisions(user_id, decided_at DESC)")
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_local_tasks_decision ON health_tasks(decision_id, created_at)")
        database.execSQL("CREATE INDEX IF NOT EXISTS idx_local_outbox_pending ON sync_outbox(user_id, status, id)")
    }
}

class LocalAnalysisStore(private val database: SQLiteDatabase) {
    fun saveAnalysisBundle(args: Map<String, Any?>): Map<String, Int> {
        val userId = args.requiredString("userId")
        val now = System.currentTimeMillis()
        val counts = linkedMapOf("fused" to 0, "runs" to 0, "states" to 0, "tags" to 0, "decisions" to 0, "tasks" to 0, "outbox" to 0)
        database.beginTransaction()
        try {
            for (item in args.mapList("fusedMetrics")) counts.increment("fused", insertFused(userId, item, now))
            args.map("analysisRun")?.let { counts.increment("runs", insertRun(userId, it, now)) }
            for (item in args.mapList("metricStates")) counts.increment("states", insertState(item))
            for (item in args.mapList("healthTags")) counts.increment("tags", insertTag(userId, item, now))
            args.map("decision")?.let { counts.increment("decisions", insertDecision(userId, it, now)) }
            for (item in args.mapList("tasks")) counts.increment("tasks", insertTask(userId, item, now))
            for (item in args.mapList("outbox")) counts.increment("outbox", insertOutbox(userId, item, now))
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
        return counts
    }

    fun loadAnalysisInputs(args: Map<String, Any?>): Map<String, Any> {
        val userId = args.requiredString("userId")
        val start = args.long("start") ?: 0L
        val end = args.long("end") ?: Long.MAX_VALUE
        val fused = query("l0_fused_metrics", "user_id = ? AND window_end <= ?", arrayOf(userId, end.toString()), "window_start, metric_type, id")
        val context = query("recommendation_context_cache", "user_id = ?", arrayOf(userId), null).firstOrNull()
        val analysisRun = query("analysis_runs", "user_id = ?", arrayOf(userId), "created_at DESC, id DESC", "1").firstOrNull()
        return mapOf(
            "fusedMetrics" to fused,
            "context" to (context ?: emptyMap<String, Any?>()),
            "analysisRun" to (analysisRun ?: emptyMap<String, Any?>()),
            "start" to start,
            "end" to end,
        )
    }

    fun loadLatestRecommendation(args: Map<String, Any?>): Map<String, Any?> {
        val userId = args.requiredString("userId")
        val decision = query("recommendation_decisions", "user_id = ?", arrayOf(userId), "decided_at DESC", "1").firstOrNull()
            ?: return emptyMap()
        val tasks = query("health_tasks", "decision_id = ?", arrayOf(decision["id"].toString()), "created_at, id")
        return mapOf("decision" to decision, "tasks" to tasks)
    }

    fun loadActiveHealthTags(args: Map<String, Any?>): List<Map<String, Any?>> {
        val userId = args.requiredString("userId")
        val at = args.requiredLong("at")
        return query("health_tags", "user_id = ? AND valid_from <= ? AND (valid_to IS NULL OR valid_to > ?)", arrayOf(userId, at.toString(), at.toString()), "tag_key, valid_from DESC")
    }

    fun updateLocalTask(args: Map<String, Any?>): Map<String, Any> {
        val userId = args.requiredString("userId")
        val taskId = args.requiredString("taskId")
        val status = args.requiredString("status")
        val progress = args.double("progress") ?: error("Missing progress")
        val occurredAt = args.requiredLong("occurredAt")
        val feedback = args.requiredMap("feedback")
        require(status in setOf("started", "completed", "dismissed", "cancelled")) { "Invalid task status" }
        require(progress in 0.0..1.0) { "Invalid task progress" }
        database.beginTransaction()
        try {
            val current = query("health_tasks", "id = ? AND user_id = ?", arrayOf(taskId, userId), null).singleOrNull()
                ?: error("Local task not found")
            require(current["status"] !in setOf("completed", "dismissed", "expired", "cancelled")) { "Terminal task cannot transition" }
            val values = ContentValues().apply {
                put("status", status)
                put("progress", progress)
                put("updated_at", occurredAt)
                if (status == "completed") put("completed_at", occurredAt) else putNull("completed_at")
                put("payload_json", args.requiredString("payloadJson"))
                putNull("cloud_synced_at")
                putNull("cloud_id")
            }
            check(database.update("health_tasks", values, "id = ? AND user_id = ?", arrayOf(taskId, userId)) == 1)
            insertFeedback(userId, feedback, occurredAt)
            insertOutbox(userId, feedback.requiredMap("outbox"), occurredAt)
            args.map("taskOutbox")?.let { insertOutbox(userId, it, occurredAt) }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
        return mapOf("taskId" to taskId, "status" to status, "progress" to progress)
    }

    fun appendLocalFeedback(args: Map<String, Any?>): String {
        val userId = args.requiredString("userId")
        val feedback = args.requiredMap("feedback")
        val now = args.long("createdAt") ?: System.currentTimeMillis()
        database.beginTransaction()
        try {
            insertFeedback(userId, feedback, now)
            insertOutbox(userId, feedback.requiredMap("outbox"), now)
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
        return feedback.requiredString("id")
    }

    fun loadPendingSyncBundle(args: Map<String, Any?>): Map<String, Any> {
        val userId = args.requiredString("userId")
        val limit = (args.long("limit") ?: 200L).coerceIn(1, 500).toString()
        val items = query("sync_outbox", "user_id = ? AND status IN ('pending', 'in_flight')", arrayOf(userId), "id", limit)
        if (items.isNotEmpty()) {
            val ids = items.map { it["id"].toString() }
            database.execSQL("UPDATE sync_outbox SET status = 'in_flight', attempts = attempts + 1 WHERE id IN (${ids.joinToString(",") { "?" }})", ids.toTypedArray())
        }
        return mapOf("items" to items, "count" to items.size)
    }

    fun acknowledgeSyncBundle(args: Map<String, Any?>): Int {
        val userId = args.requiredString("userId")
        val acknowledgedAt = args.requiredLong("acknowledgedAt")
        var count = 0
        database.beginTransaction()
        try {
            for (ack in args.mapList("acks")) {
                val outboxId = ack.requiredLong("outboxId")
                val status = ack.string("status") ?: "VALID"
                val localId = ack.requiredString("localId")
                val entityType = ack.requiredString("entityType")
                val cloudId = ack.string("cloudId")
                val outboxValues = ContentValues().apply {
                    put("status", if (status == "REJECTED") "rejected" else "acknowledged")
                    put("acknowledged_at", acknowledgedAt)
                    putNullable("last_error", ack.string("reason"))
                }
                count += database.update("sync_outbox", outboxValues, "id = ? AND user_id = ?", arrayOf(outboxId.toString(), userId))
                if (status != "REJECTED") entityTable(entityType)?.let { table ->
                    val values = ContentValues().apply {
                        put("cloud_synced_at", acknowledgedAt)
                        putNullable("cloud_id", cloudId)
                    }
                    database.update(table, values, "id = ? AND user_id = ?", arrayOf(localId, userId))
                }
            }
            database.setTransactionSuccessful()
        } finally {
            database.endTransaction()
        }
        return count
    }

    fun saveRecommendationContext(args: Map<String, Any?>) {
        val values = ContentValues().apply {
            put("user_id", args.requiredString("userId"))
            put("context_json", args.requiredString("contextJson"))
            put("catalog_json", args.requiredString("catalogJson"))
            put("context_version", args.requiredString("contextVersion"))
            put("fetched_at", args.requiredLong("fetchedAt"))
            put("expires_at", args.requiredLong("expiresAt"))
            put("data_origin", args.requiredString("dataOrigin"))
        }
        database.insertWithOnConflict("recommendation_context_cache", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun debugStatus(): Map<String, Any> = mapOf(
        "tables" to LocalAnalysisSchema.tableNames.associateWith { table -> DatabaseUtils.longForQuery(database, "SELECT COUNT(*) FROM $table", null) },
        "pendingOutbox" to DatabaseUtils.longForQuery(database, "SELECT COUNT(*) FROM sync_outbox WHERE status IN ('pending', 'in_flight')", null),
    )

    private fun insertFused(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("l0_fused_metrics", ContentValues().apply {
        put("id", item.requiredString("id")); put("user_id", userId); put("metric_type", item.requiredString("metric_type")); put("window_start", item.requiredLong("window_start")); put("window_end", item.requiredLong("window_end")); put("status", item.requiredString("status")); putNullable("value", item.double("value")); putNullable("interval_lower", item.double("interval_lower")); putNullable("interval_upper", item.double("interval_upper")); put("unit", item.requiredString("unit")); put("confidence", item.requiredDouble("confidence")); put("signal_quality", item.requiredDouble("signal_quality")); put("coverage_ratio", item.requiredDouble("coverage_ratio")); put("quality_flag", item.requiredString("quality_flag")); put("conflict_flag", item.booleanInt("conflict_flag")); put("coverage_mask_json", item.requiredString("coverage_mask_json")); put("contributors_json", item.requiredString("contributors_json")); put("evidence_json", item.requiredString("evidence_json")); putNullable("wear_state", item.string("wear_state")); putNullable("abstain_reason", item.string("abstain_reason")); put("algorithm_version", item.requiredString("algorithm_version")); put("input_fingerprint", item.requiredString("input_fingerprint")); put("data_origin", item.requiredString("data_origin")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertRun(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("analysis_runs", ContentValues().apply {
        put("id", item.requiredString("id")); put("user_id", userId); put("as_of", item.requiredLong("as_of")); put("input_count", item.requiredLong("input_count")); put("accepted_count", item.requiredLong("accepted_count")); put("model_version", item.requiredString("model_version")); put("policy_version", item.requiredString("policy_version")); put("input_fingerprint", item.requiredString("input_fingerprint")); put("status", item.requiredString("status")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertState(item: Map<String, Any?>): Int = insertReplace("analysis_metric_state", ContentValues().apply {
        put("run_id", item.requiredString("run_id")); put("metric_type", item.requiredString("metric_type")); put("sample_count", item.requiredLong("sample_count")); putNullable("first_at", item.long("first_at")); putNullable("latest_at", item.long("latest_at")); put("mean_value", item.requiredDouble("mean_value")); put("m2", item.requiredDouble("m2")); putNullable("ew_mean", item.double("ew_mean")); putNullable("ew_variance", item.double("ew_variance")); put("adwin_state_json", item.requiredString("adwin_state_json")); put("elevated_run", item.requiredLong("elevated_run")); put("suppressed_run", item.requiredLong("suppressed_run")); put("payload_json", item.requiredString("payload_json"))
    })

    private fun insertTag(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("health_tags", ContentValues().apply {
        put("id", item.requiredString("id")); put("run_id", item.requiredString("run_id")); put("user_id", userId); put("tag_key", item.requiredString("tag_key")); put("tag_type", item.requiredString("tag_type")); put("tag_value_json", item.requiredString("tag_value_json")); put("evidence_json", item.requiredString("evidence_json")); put("weight", item.requiredDouble("weight")); put("confidence", item.requiredDouble("confidence")); put("valid_from", item.requiredLong("valid_from")); putNullable("valid_to", item.long("valid_to")); put("model_version", item.requiredString("model_version")); put("policy_version", item.requiredString("policy_version")); put("input_fingerprint", item.requiredString("input_fingerprint")); put("demo_baseline", item.booleanInt("demo_baseline")); put("data_origin", item.requiredString("data_origin")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertDecision(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("recommendation_decisions", ContentValues().apply {
        put("id", item.requiredString("id")); put("user_id", userId); put("client_request_id", item.requiredString("client_request_id")); put("decided_at", item.requiredLong("decided_at")); put("expires_at", item.requiredLong("expires_at")); put("surface", item.requiredString("surface")); put("status", item.requiredString("status")); put("context_snapshot_json", item.requiredString("context_snapshot_json")); put("health_tag_snapshot_json", item.requiredString("health_tag_snapshot_json")); put("candidate_snapshot_json", item.requiredString("candidate_snapshot_json")); put("final_plan_json", item.requiredString("final_plan_json")); put("feature_schema_version", item.requiredString("feature_schema_version")); put("matrix_version", item.requiredString("matrix_version")); put("registry_version", item.requiredString("registry_version")); put("policy_version", item.requiredString("policy_version")); put("safety_version", item.requiredString("safety_version")); put("data_origin", item.requiredString("data_origin")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertTask(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("health_tasks", ContentValues().apply {
        put("id", item.requiredString("id")); put("decision_id", item.requiredString("decision_id")); put("user_id", userId); put("catalog_item_id", item.requiredString("catalog_item_id")); put("title_snapshot", item.requiredString("title_snapshot")); put("goal_snapshot_json", item.requiredString("goal_snapshot_json")); put("due_at", item.requiredLong("due_at")); put("status", item.string("status") ?: "pending"); put("progress", item.double("progress") ?: 0.0); putNullable("completed_at", item.long("completed_at")); put("client_task_id", item.requiredString("client_task_id")); put("payload_json", item.requiredString("payload_json")); put("created_at", now); put("updated_at", now)
    })

    private fun insertFeedback(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("recommendation_feedback", ContentValues().apply {
        put("id", item.requiredString("id")); put("decision_id", item.requiredString("decision_id")); put("user_id", userId); put("catalog_item_id", item.requiredString("catalog_item_id")); put("event_type", item.requiredString("event_type")); put("occurred_at", item.requiredLong("occurred_at")); put("client_event_id", item.requiredString("client_event_id")); put("source", item.requiredString("source")); put("metadata_json", item.requiredString("metadata_json")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertOutbox(userId: String, item: Map<String, Any?>, now: Long): Int = insertIgnore("sync_outbox", ContentValues().apply {
        put("user_id", userId); put("entity_type", item.requiredString("entity_type")); put("local_id", item.requiredString("local_id")); put("operation", item.string("operation") ?: "UPSERT"); put("payload_hash", item.requiredString("payload_hash")); put("payload_json", item.requiredString("payload_json")); put("created_at", now)
    })

    private fun insertIgnore(table: String, values: ContentValues): Int = if (database.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_IGNORE) == -1L) 0 else 1
    private fun insertReplace(table: String, values: ContentValues): Int = if (database.insertWithOnConflict(table, null, values, SQLiteDatabase.CONFLICT_REPLACE) == -1L) 0 else 1
    private fun MutableMap<String, Int>.increment(key: String, amount: Int) { this[key] = getValue(key) + amount }

    private fun query(table: String, selection: String?, args: Array<String>?, order: String?, limit: String? = null): List<Map<String, Any?>> =
        database.query(table, null, selection, args, null, null, order, limit).use(::rows)

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

    private fun entityTable(type: String): String? = when (type) {
        "FUSED_METRIC" -> "l0_fused_metrics"
        "ANALYSIS_RUN" -> "analysis_runs"
        "HEALTH_TAG" -> "health_tags"
        "DECISION" -> "recommendation_decisions"
        "TASK" -> "health_tasks"
        "FEEDBACK" -> "recommendation_feedback"
        else -> null
    }
}

private fun Map<String, Any?>.string(name: String): String? = this[name] as? String
private fun Map<String, Any?>.requiredString(name: String): String = string(name)?.takeIf { it.isNotBlank() } ?: error("Missing $name")
private fun Map<String, Any?>.long(name: String): Long? = (this[name] as? Number)?.toLong()
private fun Map<String, Any?>.requiredLong(name: String): Long = long(name) ?: error("Missing $name")
private fun Map<String, Any?>.double(name: String): Double? = (this[name] as? Number)?.toDouble()?.takeIf { it.isFinite() }
private fun Map<String, Any?>.requiredDouble(name: String): Double = double(name) ?: error("Missing $name")
private fun Map<String, Any?>.booleanInt(name: String): Int = when (val value = this[name]) { is Boolean -> if (value) 1 else 0; is Number -> if (value.toInt() == 0) 0 else 1; else -> 0 }
private fun Map<String, Any?>.map(name: String): Map<String, Any?>? = (this[name] as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value }
private fun Map<String, Any?>.requiredMap(name: String): Map<String, Any?> = map(name) ?: error("Missing $name")
private fun Map<String, Any?>.mapList(name: String): List<Map<String, Any?>> = (this[name] as? List<*>)?.mapNotNull { raw -> (raw as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value } } ?: emptyList()
private fun ContentValues.putNullable(name: String, value: String?) { if (value == null) putNull(name) else put(name, value) }
private fun ContentValues.putNullable(name: String, value: Long?) { if (value == null) putNull(name) else put(name, value) }
private fun ContentValues.putNullable(name: String, value: Double?) { if (value == null) putNull(name) else put(name, value) }
