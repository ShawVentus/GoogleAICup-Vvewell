import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../foundations/log/al_logger.dart';
import '../../web/web_cloud.dart';

/// Identifies whether a normalized record came from hardware or debug data.
enum HealthDataOrigin { realDevice, debugMock }

/// A normalized vital-sign row that was successfully written to local storage.
///
/// Consumers use this stream for immediate, in-process reactions to readings
/// (for example, an accessibility or companion-device alert). The database
/// remains the source of truth; this event is deliberately emitted only after
/// the native write succeeds.
class VitalReadingSaved {
  const VitalReadingSaved({
    required this.id,
    required this.source,
    required this.recordedAt,
    required this.isValid,
    required this.isAbnormal,
    required this.origin,
    this.deviceId,
    this.heartRate,
    this.spo2,
  });

  final int id;
  final String source;
  final String? deviceId;
  final DateTime recordedAt;
  final double? heartRate;
  final double? spo2;
  final bool isValid;
  final bool isAbnormal;
  final HealthDataOrigin origin;
}

/// Latest temperature sample stored in an Alloop activity-history row.
class RingTemperatureReading {
  const RingTemperatureReading({
    required this.temperatureC,
    required this.recordedAt,
  });

  final double temperatureC;
  final DateTime recordedAt;

  factory RingTemperatureReading.fromMap(Map<dynamic, dynamic> row) {
    final temperature = row['temperature_c'];
    final recordedAt = row['recorded_at'];
    if (temperature is! num || recordedAt is! num) {
      throw const FormatException('Invalid ring temperature row');
    }
    return RingTemperatureReading(
      temperatureC: temperature.toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        recordedAt.toInt(),
        isUtc: true,
      ),
    );
  }
}

/// Lightweight context stored inside `raw_data` without changing SQLite schema.
///
/// The normalized columns remain the source for medical values; this contract
/// records their session and provenance so different devices and mock data are
/// never conflated by consumers that decode the raw payload.
class VitalReadingProvenance {
  static const int currentSchemaVersion = 1;

  const VitalReadingProvenance({
    this.sessionId,
    required this.source,
    this.deviceId,
    required this.recordedAt,
    this.schemaVersion = currentSchemaVersion,
    this.origin = HealthDataOrigin.realDevice,
    this.hrConfidence,
    this.rrConfidence,
    this.aggregateQuality,
    this.coverageRatio,
    this.qualityFlag,
    this.wearState,
    this.clockOffsetMs,
    this.packetLossRatio,
    this.algorithmVersion,
  });

  final String? sessionId;
  final String source;
  final String? deviceId;
  final DateTime recordedAt;
  final int schemaVersion;
  final HealthDataOrigin origin;
  final double? hrConfidence;
  final double? rrConfidence;
  final double? aggregateQuality;
  final double? coverageRatio;
  final String? qualityFlag;
  final String? wearState;
  final double? clockOffsetMs;
  final double? packetLossRatio;
  final String? algorithmVersion;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'source': source,
    'deviceId': deviceId,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'origin': origin.name,
    'isMock': origin == HealthDataOrigin.debugMock,
    'hrConfidence': hrConfidence,
    'rrConfidence': rrConfidence,
    'aggregateQuality': aggregateQuality,
    'coverageRatio': coverageRatio,
    'qualityFlag': qualityFlag,
    'wearState': wearState,
    'clockOffsetMs': clockOffsetMs,
    'packetLossRatio': packetLossRatio,
    'algorithmVersion': algorithmVersion,
  };
}

/// Local SQLite storage for the app's health sensor data.
///
/// The Android host owns the SQLite implementation, so no third-party Flutter
/// database dependency is required. Timestamps cross the platform channel as
/// UTC milliseconds since the Unix epoch.
class LocalHealthDatabase {
  LocalHealthDatabase._();

  static final LocalHealthDatabase instance = LocalHealthDatabase._();

  static const String defaultUserId = 'local-user';
  static const MethodChannel _channel = MethodChannel(
    'alloop/local_health_database',
  );
  static const String _logTag = 'LOCAL_DB';
  static final Random _confidenceRandom = Random.secure();

  /// Installed by the phone analysis coordinator during app startup.
  /// Keeping the callback here avoids coupling sensor adapters to analysis.
  static Future<void> Function()? onRealVitalReadingSaved;
  static Future<void> Function()? onMeasurementBlockCompleted;

  /// Flushes any queued analysis after an adapter finishes one acquisition
  /// block. Continuous streams can rely on the per-reading callback instead.
  static Future<void> notifyMeasurementBlockCompleted() async {
    final callback = onMeasurementBlockCompleted;
    if (callback != null) await callback();
  }

  static final StreamController<VitalReadingSaved> _vitalReadingController =
      StreamController<VitalReadingSaved>.broadcast();

  /// Emits each successfully persisted normalized vital reading.
  static Stream<VitalReadingSaved> get vitalReadingStream =>
      _vitalReadingController.stream;

  Future<void>? _initialization;

  /// Creates the schema and the offline local user once per process.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _invoke<void>('initialize');
    AlLogger.info('Local database initialization completed', tag: _logTag);
  }

  /// Creates or updates a discovered/connected sensor device.
  Future<void> upsertDevice({
    required String deviceId,
    required String name,
    required String type,
    String? firmwareVersion,
    int? batteryPercent,
    required bool connected,
    DateTime? lastSyncAt,
    String userId = defaultUserId,
  }) async {
    await initialize();
    await _invoke<void>('upsertDevice', {
      'userId': userId,
      'deviceId': deviceId,
      'name': name,
      'type': type,
      'firmwareVersion': firmwareVersion,
      'batteryPercent': batteryPercent,
      'connected': connected,
      'lastSyncAt': lastSyncAt?.toUtc().millisecondsSinceEpoch,
    });
    AlLogger.debug(
      'Device upserted: type=$type, device=$deviceId, connected=$connected',
      tag: _logTag,
    );
  }

  /// Saves one normalized vital-sign record. `source` accepts `aizo_ring`,
  /// `alloop_ring`, `rppg_phone`, and `mmwave_radar`.
  Future<int> saveVitalReading({
    required String source,
    required DateTime recordedAt,
    String? deviceId,
    double? heartRate,
    double? spo2,
    double? hrv,
    double? respiratoryRate,
    double? temperature,
    double? stress,
    int? steps,
    double? signalQuality,
    double? confidence,
    double? coverageRatio,
    String? qualityFlag,
    String? wearState,
    double? clockOffsetMs,
    double? packetLossRatio,
    String? clientEventId,
    bool isValid = true,
    bool isAbnormal = false,
    Map<String, dynamic>? rawData,
    VitalReadingProvenance? provenance,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final normalizedProvenance =
        provenance ??
        VitalReadingProvenance(
          source: source,
          deviceId: deviceId,
          recordedAt: recordedAt,
        );
    final normalizedConfidence =
        confidence ?? 0.6 + 0.3 * _confidenceRandom.nextDouble();
    final id =
        await _invoke<int>('saveVitalReading', {
          'userId': userId,
          'deviceId': deviceId,
          'source': source,
          'recordedAt': recordedAt.toUtc().millisecondsSinceEpoch,
          'heartRate': heartRate,
          'spo2': spo2,
          'hrv': hrv,
          'respiratoryRate': respiratoryRate,
          'temperature': temperature,
          'stress': stress,
          'steps': steps,
          'signalQuality': signalQuality,
          'confidence': normalizedConfidence,
          'coverageRatio': coverageRatio ?? normalizedProvenance.coverageRatio,
          'qualityFlag': qualityFlag ?? normalizedProvenance.qualityFlag,
          'wearState': wearState ?? normalizedProvenance.wearState,
          'clockOffsetMs': clockOffsetMs ?? normalizedProvenance.clockOffsetMs,
          'packetLossRatio':
              packetLossRatio ?? normalizedProvenance.packetLossRatio,
          'clientEventId': clientEventId,
          'dataOrigin':
              normalizedProvenance.origin == HealthDataOrigin.debugMock
              ? 'DEBUG_MOCK'
              : 'REAL',
          'isValid': isValid,
          'isAbnormal': isAbnormal,
          'rawData': _encodeRawData({
            ...?rawData,
            'confidenceImputed': confidence == null,
            if (confidence == null)
              'confidenceImputation': 'uniform_random_0.6_0.9',
            'provenance': normalizedProvenance.toJson(),
          }),
        }) ??
        0;
    AlLogger.debug(
      'Vital reading saved: id=$id, source=$source, device=${deviceId ?? "none"}, '
      'recordedAt=${recordedAt.toUtc().toIso8601String()}',
      tag: _logTag,
    );
    if (id > 0) {
      _vitalReadingController.add(
        VitalReadingSaved(
          id: id,
          source: source,
          deviceId: deviceId,
          recordedAt: recordedAt,
          heartRate: heartRate,
          spo2: spo2,
          isValid: isValid,
          isAbnormal: isAbnormal,
          origin: normalizedProvenance.origin,
        ),
      );
      if (normalizedProvenance.origin == HealthDataOrigin.realDevice) {
        final callback = onRealVitalReadingSaved;
        if (callback != null) unawaited(callback());
      }
    }
    return id;
  }

  /// Saves the SDK/algorithm comparison information from ring verification.
  Future<int> saveRingMeasurementResult({
    required String deviceId,
    required DateTime recordedAt,
    int? sdkHeartRate,
    int? sdkSpo2,
    double? algorithmHeartRate,
    double? algorithmSpo2,
    double? algorithmHrvRmssd,
    double? signalQuality,
    required bool valid,
    Map<String, dynamic>? rawData,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final id =
        await _invoke<int>('saveRingMeasurementResult', {
          'userId': userId,
          'deviceId': deviceId,
          'recordedAt': recordedAt.toUtc().millisecondsSinceEpoch,
          'sdkHeartRate': sdkHeartRate,
          'sdkSpo2': sdkSpo2,
          'algorithmHeartRate': algorithmHeartRate,
          'algorithmSpo2': algorithmSpo2,
          'algorithmHrvRmssd': algorithmHrvRmssd,
          'signalQuality': signalQuality,
          'valid': valid,
          'rawData': _encodeRawData(rawData),
        }) ??
        0;
    AlLogger.debug(
      'Ring comparison saved: id=$id, device=$deviceId, valid=$valid',
      tag: _logTag,
    );
    return id;
  }

  /// Saves or replaces one ring daily sport/activity record.
  Future<int> saveRingDailyLog({
    required String deviceId,
    required DateTime recordedAt,
    required String logType,
    int? heartRate,
    int? steps,
    int? activityCount,
    int? batteryPercent,
    int? activeSeconds,
    List<double>? temperaturesC,
    Map<String, dynamic>? rawData,
    VitalReadingProvenance? provenance,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final normalizedProvenance =
        provenance ??
        VitalReadingProvenance(
          source: 'alloop_ring',
          deviceId: deviceId,
          recordedAt: recordedAt,
        );
    final id =
        await _invoke<int>('saveRingDailyLog', {
          'userId': userId,
          'deviceId': deviceId,
          'recordedAt': recordedAt.toUtc().millisecondsSinceEpoch,
          'logType': logType,
          'heartRate': heartRate,
          'steps': steps,
          'activityCount': activityCount,
          'batteryPercent': batteryPercent,
          'activeSeconds': activeSeconds,
          'temperaturesC': temperaturesC?.join(';'),
          'rawData': _encodeRawData({
            ...?rawData,
            'provenance': normalizedProvenance.toJson(),
          }),
        }) ??
        0;
    AlLogger.debug(
      'Ring daily log saved: id=$id, type=$logType, device=$deviceId',
      tag: _logTag,
    );
    return id;
  }

  /// Reads normalized vital data in reverse chronological order.
  Future<List<Map<String, Object?>>> loadVitalReadings({
    String? source,
    String? deviceId,
    DateTime? start,
    DateTime? end,
    bool onlyUnsynced = false,
    bool onlyReal = false,
    int? beforeLocalId,
    int? limit,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final rows =
        await _invoke<List<dynamic>>('loadVitalReadings', {
          'userId': userId,
          'source': source,
          'deviceId': deviceId,
          'start': start?.toUtc().millisecondsSinceEpoch,
          'end': end?.toUtc().millisecondsSinceEpoch,
          'onlyUnsynced': onlyUnsynced,
          'onlyReal': onlyReal,
          'beforeLocalId': beforeLocalId,
          'limit': limit,
        }) ??
        const <dynamic>[];
    final result = rows
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(Map<String, Object?>.from)
        .toList();
    AlLogger.debug(
      'Vital readings loaded: count=${result.length}, source=${source ?? "all"}, '
      'device=${deviceId ?? "all"}',
      tag: _logTag,
    );
    return result;
  }

  Future<int> countPendingRealVitalReadings({
    String userId = defaultUserId,
  }) async {
    await initialize();
    return await _invoke<int>('countPendingRealVitalReadings', {
          'userId': userId,
        }) ??
        0;
  }

  /// Reads Alloop ring activity/sport logs, including SDK temperature arrays.
  Future<List<Map<String, Object?>>> loadRingDailyLogs({
    required String deviceId,
    DateTime? start,
    DateTime? end,
    int? limit,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final rows =
        await _invoke<List<dynamic>>('loadRingDailyLogs', {
          'userId': userId,
          'deviceId': deviceId,
          'start': start?.toUtc().millisecondsSinceEpoch,
          'end': end?.toUtc().millisecondsSinceEpoch,
          'limit': limit,
        }) ??
        const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(Map<String, Object?>.from)
        .toList(growable: false);
  }

  /// Deletes local Alloop data for one physical device while preserving the
  /// connection record so the ring remains visible in device management.
  Future<Map<String, int>> clearAlloopDeviceData({
    required String deviceId,
    String userId = defaultUserId,
  }) => _manageAlloopDeviceData(
    deviceId: deviceId,
    deleteHealthData: true,
    removeDevice: false,
    userId: userId,
  );

  /// Removes only the app-side device binding. Historical health records are
  /// retained unless the user invokes [clearAlloopDeviceData] separately.
  Future<Map<String, int>> forgetAlloopDevice({
    required String deviceId,
    String userId = defaultUserId,
  }) => _manageAlloopDeviceData(
    deviceId: deviceId,
    deleteHealthData: false,
    removeDevice: true,
    userId: userId,
  );

  Future<Map<String, int>> _manageAlloopDeviceData({
    required String deviceId,
    required bool deleteHealthData,
    required bool removeDevice,
    required String userId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('manageAlloopDeviceData', {
      'userId': userId,
      'deviceId': deviceId,
      'deleteHealthData': deleteHealthData,
      'removeDevice': removeDevice,
    });
    return (raw ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  /// Marks a local vital row after the cloud RPC has accepted it.
  Future<void> markVitalReadingSynced({
    required int localId,
    required String cloudReadingId,
    String userId = defaultUserId,
  }) async {
    await initialize();
    await _invoke<void>('markVitalReadingSynced', {
      'userId': userId,
      'localId': localId,
      'cloudReadingId': cloudReadingId,
      'syncedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
    });
  }

  /// Atomically persists fused metrics, an analysis run, tags, a decision,
  /// tasks, and their pending synchronization records.
  Future<Map<String, int>> saveAnalysisBundle(
    Map<String, Object?> bundle, {
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('saveAnalysisBundle', {
      'userId': userId,
      ...bundle,
    });
    return (raw ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  Future<Map<String, Object?>> loadAnalysisInputs({
    required DateTime start,
    required DateTime end,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('loadAnalysisInputs', {
      'userId': userId,
      'start': start.toUtc().millisecondsSinceEpoch,
      'end': end.toUtc().millisecondsSinceEpoch,
    });
    return _stringMap(raw);
  }

  Future<Map<String, Object?>> loadLatestRecommendation({
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>(
      'loadLatestRecommendation',
      {'userId': userId},
    );
    return _stringMap(raw);
  }

  Future<List<Map<String, Object?>>> loadActiveHealthTags({
    DateTime? at,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<List<dynamic>>('loadActiveHealthTags', {
      'userId': userId,
      'at': (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
    });
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => _stringMap(item))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> updateLocalTask({
    required String taskId,
    required String status,
    required double progress,
    required DateTime occurredAt,
    required String payloadJson,
    required Map<String, Object?> feedback,
    required Map<String, Object?> taskOutbox,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('updateLocalTask', {
      'userId': userId,
      'taskId': taskId,
      'status': status,
      'progress': progress,
      'occurredAt': occurredAt.toUtc().millisecondsSinceEpoch,
      'payloadJson': payloadJson,
      'feedback': feedback,
      'taskOutbox': taskOutbox,
    });
    return _stringMap(raw);
  }

  Future<String?> appendLocalFeedback(
    Map<String, Object?> feedback, {
    DateTime? createdAt,
    String userId = defaultUserId,
  }) async {
    await initialize();
    return _invoke<String>('appendLocalFeedback', {
      'userId': userId,
      'createdAt': (createdAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      'feedback': feedback,
    });
  }

  Future<Map<String, Object?>> loadPendingSyncBundle({
    int limit = 200,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('loadPendingSyncBundle', {
      'userId': userId,
      'limit': limit,
    });
    return _stringMap(raw);
  }

  Future<int> acknowledgeSyncBundle({
    required List<Map<String, Object?>> acknowledgements,
    DateTime? acknowledgedAt,
    String userId = defaultUserId,
  }) async {
    await initialize();
    return await _invoke<int>('acknowledgeSyncBundle', {
          'userId': userId,
          'acknowledgedAt': (acknowledgedAt ?? DateTime.now())
              .toUtc()
              .millisecondsSinceEpoch,
          'acks': acknowledgements,
        }) ??
        0;
  }

  Future<void> saveRecommendationContext({
    required Map<String, Object?> context,
    required List<Object?> catalog,
    required String contextVersion,
    required DateTime fetchedAt,
    required DateTime expiresAt,
    required String dataOrigin,
    String userId = defaultUserId,
  }) async {
    await initialize();
    await _invoke<void>('saveRecommendationContext', {
      'userId': userId,
      'contextJson': canonicalJson(context),
      'catalogJson': canonicalJson(catalog),
      'contextVersion': contextVersion,
      'fetchedAt': fetchedAt.toUtc().millisecondsSinceEpoch,
      'expiresAt': expiresAt.toUtc().millisecondsSinceEpoch,
      'dataOrigin': dataOrigin,
    });
  }

  Future<Map<String, Object?>> getAnalysisDebugStatus() async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('debugAnalysisStatus');
    return _stringMap(raw);
  }

  /// Reads the newest temperature sample from the ring activity-history table.
  ///
  /// An activity row can contain multiple semicolon-separated samples. The
  /// native query walks rows newest-first and returns the last finite sample in
  /// the first row that contains one.
  Future<RingTemperatureReading?> loadLatestRingTemperature({
    required String deviceId,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final row = await _invoke<Map<dynamic, dynamic>>(
      'loadLatestRingTemperature',
      {'userId': userId, 'deviceId': deviceId},
    );
    if (row == null) return null;
    try {
      final reading = RingTemperatureReading.fromMap(row);
      AlLogger.debug(
        'Ring temperature loaded: device=$deviceId, '
        'temperature=${reading.temperatureC}',
        tag: _logTag,
      );
      return reading;
    } on FormatException catch (error, stackTrace) {
      AlLogger.warning(
        'Ignored malformed ring temperature row: $error',
        tag: _logTag,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Deletes readings of one source, optionally limited by a raw JSON marker.
  Future<int> deleteVitalReadings({
    required String source,
    String? rawDataContains,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final deleted =
        await _invoke<int>('deleteVitalReadings', {
          'userId': userId,
          'source': source,
          'rawDataContains': rawDataContains,
        }) ??
        0;
    AlLogger.info(
      'Vital readings deleted: count=$deleted, source=$source',
      tag: _logTag,
    );
    return deleted;
  }

  /// Stores a voluntary, daily wellness action. Completion affects only the
  /// in-app wellness reference score; it never changes raw device readings.
  Future<void> saveHealthIntervention({
    required String actionId,
    required bool completed,
    required DateTime day,
    String userId = defaultUserId,
  }) async {
    await initialize();
    await _invoke<void>('saveHealthIntervention', {
      'userId': userId,
      'actionId': actionId,
      'completed': completed,
      'day': DateTime(
        day.year,
        day.month,
        day.day,
      ).toUtc().millisecondsSinceEpoch,
    });
  }

  /// Returns the action IDs voluntarily marked complete for a local day.
  Future<Set<String>> loadHealthInterventions({
    required DateTime day,
    String userId = defaultUserId,
  }) async {
    await initialize();
    final rows =
        await _invoke<List<dynamic>>('loadHealthInterventions', {
          'userId': userId,
          'day': DateTime(
            day.year,
            day.month,
            day.day,
          ).toUtc().millisecondsSinceEpoch,
        }) ??
        const <dynamic>[];
    return rows
        .whereType<Map>()
        .where((row) => row['completed'] == true || row['completed'] == 1)
        .map((row) => '${row['action_id']}')
        .toSet();
  }

  /// Returns table counts and the native database path for debug screens/logs.
  Future<Map<String, Object?>> getDebugStatus() async {
    await initialize();
    final raw = await _invoke<Map<dynamic, dynamic>>('debugStatus') ?? const {};
    final status = Map<String, Object?>.from(raw);
    AlLogger.info('Database status: $status', tag: _logTag);
    return status;
  }

  Map<String, dynamic> decodeRawData(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final value = jsonDecode(encoded);
      if (value is Map) {
        return value.map((key, item) => MapEntry(key.toString(), item));
      }
    } on FormatException {
      // A malformed extension payload must not make a valid row unreadable.
    }
    return const {};
  }

  static DateTime fromUnixSeconds(int unixSeconds) {
    if (unixSeconds <= 0) return DateTime.now().toUtc();
    return DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true);
  }

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    if (kIsWeb) {
      if (method == 'loadVitalReadings') return WebCloud.instance.localReadings(arguments ?? {}) as T;
      if (method == 'initialize') return null;
      if (method.startsWith('save') || method.startsWith('delete') || method.startsWith('update')) {
        throw UnsupportedError('This record must be updated in the mobile app.');
      }
      return null;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      AlLogger.debug(
        'Skipped $method because this platform has no native SQLite bridge',
        tag: _logTag,
      );
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // Enables widget tests and non-Android development builds without a
      // platform handler. Hardware sensor streams are Android-only.
      AlLogger.warning(
        'Native SQLite bridge is unavailable for $method',
        tag: _logTag,
      );
      return null;
    } on PlatformException catch (error, stackTrace) {
      AlLogger.error(
        'Native SQLite call failed: $method (${error.code})',
        tag: _logTag,
        error: error.message,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static String _encodeRawData(Map<String, dynamic>? rawData) =>
      jsonEncode(_jsonSafe(rawData ?? const {}));

  static String canonicalJson(Object? value) =>
      jsonEncode(_canonicalJsonSafe(value));

  static Map<String, Object?> _stringMap(Map<dynamic, dynamic>? value) =>
      (value ?? const {}).map((key, item) => MapEntry(key.toString(), item));

  static dynamic _canonicalJsonSafe(dynamic value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is double && !value.isFinite) return null;
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in keys)
          key: _canonicalJsonSafe(
            value.entries
                .firstWhere((entry) => entry.key.toString() == key)
                .value,
          ),
      };
    }
    if (value is Iterable) return value.map(_canonicalJsonSafe).toList();
    return value;
  }

  static dynamic _jsonSafe(dynamic value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is double && !value.isFinite) return null;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) return value.map(_jsonSafe).toList();
    return value;
  }
}
