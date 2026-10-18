package com.alloop.blue.test

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LocalHealthDatabaseMigrationTest {
    @Test
    fun additiveV5UpgradeCreatesWellnessTablesForExistingV4Database() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val name = "local-health-v5-${System.nanoTime()}.db"
        context.deleteDatabase(name)
        try {
            context.openOrCreateDatabase(name, 0, null).use { database ->
                database.execSQL(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, auth_uid TEXT, username TEXT NOT NULL, display_name TEXT, created_at INTEGER NOT NULL)",
                )
                database.execSQL("INSERT INTO users(id,username,created_at) VALUES ('local-user','local-user',1)")
                database.version = 4
            }

            LocalHealthDatabaseBridge(context, name).use { bridge ->
                bridge.handle(MethodCall("initialize", emptyMap<String, Any?>()))
                assertEquals(6, bridge.readableDatabase.version)
                for (table in listOf("women_health_records", "meal_records", "health_interventions")) {
                    assertEquals(
                        1L,
                        android.database.DatabaseUtils.longForQuery(
                            bridge.readableDatabase,
                            "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?",
                            arrayOf(table),
                        ),
                    )
                }
                assertEquals(
                    1L,
                    android.database.DatabaseUtils.longForQuery(
                        bridge.readableDatabase,
                        "SELECT count(*) FROM users WHERE id='local-user'",
                        null,
                    ),
                )
            }
        } finally {
            context.deleteDatabase(name)
        }
    }

    @Test
    fun additiveV6UpgradeBackfillsStableIdentityAndMockOrigin() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val name = "local-health-v6-${System.nanoTime()}.db"
        context.deleteDatabase(name)
        try {
            context.openOrCreateDatabase(name, 0, null).use { database ->
                database.execSQL(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, auth_uid TEXT UNIQUE, username TEXT NOT NULL UNIQUE, display_name TEXT, created_at INTEGER NOT NULL)",
                )
                database.execSQL(
                    "CREATE TABLE vital_readings (" +
                        "id INTEGER PRIMARY KEY, user_id TEXT NOT NULL, device_id TEXT, source TEXT NOT NULL, " +
                        "recorded_at INTEGER NOT NULL, raw_data TEXT NOT NULL, cloud_synced_at INTEGER, " +
                        "FOREIGN KEY(user_id) REFERENCES users(id))",
                )
                database.execSQL(
                    "INSERT INTO users(id,username,created_at) VALUES ('local-user','local-user',1)",
                )
                database.execSQL(
                    "INSERT INTO vital_readings(id,user_id,device_id,source,recorded_at,raw_data) VALUES " +
                        "(1,'local-user','ring-1','alloop_ring',1000,'{\"isMock\":false}')," +
                        "(2,'local-user','ring-1','alloop_ring',2000,'{\"provenance\":{\"origin\":\"debugMock\",\"isMock\":true}}')",
                )
                database.version = 5
            }

            LocalHealthDatabaseBridge(context, name).use { bridge ->
                bridge.handle(MethodCall("initialize", emptyMap<String, Any?>()))
                val database = bridge.readableDatabase
                assertEquals(6, database.version)
                assertEquals(
                    "REAL",
                    android.database.DatabaseUtils.stringForQuery(
                        database,
                        "SELECT data_origin FROM vital_readings WHERE id=1",
                        null,
                    ),
                )
                assertEquals(
                    "DEBUG_MOCK",
                    android.database.DatabaseUtils.stringForQuery(
                        database,
                        "SELECT data_origin FROM vital_readings WHERE id=2",
                        null,
                    ),
                )
                val eventId = android.database.DatabaseUtils.stringForQuery(
                    database,
                    "SELECT client_event_id FROM vital_readings WHERE id=1",
                    null,
                )
                assertTrue(
                    Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
                        .matches(eventId),
                )
            }
        } finally {
            context.deleteDatabase(name)
        }
    }

    @Test
    fun writeOnlyBridgeMethodPersistsContextAndReturnsCodecSafeNull() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val name = "local-health-channel-${System.nanoTime()}.db"
        context.deleteDatabase(name)
        val bridge = LocalHealthDatabaseBridge(context, name)
        try {
            bridge.handle(MethodCall("initialize", emptyMap<String, Any?>()))
            val result = bridge.handle(
                MethodCall(
                    "saveRecommendationContext",
                    mapOf(
                        "userId" to "local-user",
                        "contextJson" to "{}",
                        "catalogJson" to "[]",
                        "contextVersion" to "context-v1",
                        "fetchedAt" to 1L,
                        "expiresAt" to 2L,
                        "dataOrigin" to "REAL",
                    ),
                ),
            )

            assertNull(result)
            assertEquals(
                1L,
                android.database.DatabaseUtils.longForQuery(
                    bridge.readableDatabase,
                    "SELECT count(*) FROM recommendation_context_cache WHERE user_id = 'local-user'",
                    null,
                ),
            )
        } finally {
            bridge.close()
            context.deleteDatabase(name)
        }
    }

    @Test
    fun additiveV3SchemaPreservesV2ReadingAndAnalysisBundleAcrossReopen() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val name = "local-health-migration-${System.nanoTime()}.db"
        context.deleteDatabase(name)
        try {
            context.openOrCreateDatabase(name, 0, null).use { database ->
                database.execSQL("PRAGMA foreign_keys = ON")
                database.execSQL("CREATE TABLE users (id TEXT PRIMARY KEY)")
                database.execSQL(
                    "CREATE TABLE vital_readings (id INTEGER PRIMARY KEY, user_id TEXT NOT NULL, raw_data TEXT NOT NULL, FOREIGN KEY(user_id) REFERENCES users(id))",
                )
                database.execSQL("INSERT INTO users(id) VALUES ('local-user')")
                database.execSQL("INSERT INTO vital_readings(id,user_id,raw_data) VALUES (1,'local-user','{\"before\":true}')")
                database.version = 2
                database.beginTransaction()
                try {
                    LocalAnalysisSchema.create(database)
                    LocalAnalysisStore(database).saveAnalysisBundle(
                        mapOf(
                            "userId" to "local-user",
                            "analysisRun" to mapOf(
                                "id" to "94000000-0000-4000-8000-000000000001",
                                "as_of" to 1L,
                                "input_count" to 0,
                                "accepted_count" to 0,
                                "model_version" to "river-health-stream-dart-v1",
                                "policy_version" to "health-tag-policy-v1",
                                "input_fingerprint" to "a".repeat(64),
                                "status" to "INSUFFICIENT",
                                "payload_json" to "{}",
                            ),
                        ),
                    )
                    database.version = 3
                    database.setTransactionSuccessful()
                } finally {
                    database.endTransaction()
                }
                assertEquals(1L, android.database.DatabaseUtils.longForQuery(database, "SELECT count(*) FROM vital_readings", null))
                assertEquals("{\"before\":true}", android.database.DatabaseUtils.stringForQuery(database, "SELECT raw_data FROM vital_readings WHERE id=1", null))
            }

            context.openOrCreateDatabase(name, 0, null).use { reopened ->
                assertEquals(3, reopened.version)
                assertEquals(1L, android.database.DatabaseUtils.longForQuery(reopened, "SELECT count(*) FROM analysis_runs", null))
                val inputs = LocalAnalysisStore(reopened).loadAnalysisInputs(
                    mapOf("userId" to "local-user", "start" to 0L, "end" to Long.MAX_VALUE),
                )
                @Suppress("UNCHECKED_CAST")
                val latestRun = inputs["analysisRun"] as Map<String, Any?>
                assertEquals("a".repeat(64), latestRun["input_fingerprint"])
                assertTrue(LocalAnalysisSchema.tableNames.all { table ->
                    android.database.DatabaseUtils.longForQuery(
                        reopened,
                        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?",
                        arrayOf(table),
                    ) == 1L
                })
            }
        } finally {
            context.deleteDatabase(name)
        }
    }
}
