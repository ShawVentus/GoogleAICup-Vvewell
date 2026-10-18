import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/local_health_database.dart';
import '../../health_analysis/data/phone_analysis_coordinator.dart';
import 'embedded_demo_cloud_credentials.dart';

typedef CloudRpcOverride =
    Future<Object?> Function(String functionName, Map<String, Object?> params);

class CloudSyncConfigurationException implements Exception {
  const CloudSyncConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudSyncAuthRequiredException implements Exception {
  const CloudSyncAuthRequiredException();

  @override
  String toString() => 'A Supabase user session is required before syncing.';
}

class CloudSyncResult {
  const CloudSyncResult({
    required this.considered,
    required this.synced,
    required this.skipped,
    required this.failed,
    required this.fused,
    required this.conflicts,
    required this.abstained,
    required this.artifacts,
    required this.rejected,
    required this.contextRefreshed,
    required this.analysisPromoted,
    required this.remainingReadings,
    required this.remainingArtifacts,
    this.lastError,
  });

  final int considered;
  final int synced;
  final int skipped;
  final int failed;
  final int fused;
  final int conflicts;
  final int abstained;
  final int artifacts;
  final int rejected;
  final bool contextRefreshed;
  final bool analysisPromoted;
  final int remainingReadings;
  final int remainingArtifacts;
  final String? lastError;

  String get summary {
    final error = lastError == null ? '' : ' Last error: $lastError';
    final context = contextRefreshed ? ' context refreshed;' : '';
    final analysis = analysisPromoted ? ' cloud analysis refreshed;' : '';
    final remaining = remainingReadings + remainingArtifacts > 0
        ? ' $remainingReadings readings and $remainingArtifacts artifacts remain queued;'
        : '';
    return 'Cloud sync complete: $synced readings, $artifacts analysis artifacts;'
        '$context$analysis$remaining $rejected rejected, $skipped skipped, $failed failed.$error';
  }
}

/// Uploads normalized local vital readings only after an explicit user action.
///
/// DIRTY_DEMO_EMBEDDED_CREDENTIALS_REMOVE_BEFORE_RELEASE
///
/// This hackathon build silently establishes a dedicated demo Auth session from
/// the encrypted APK asset. Never replace it with a service-role credential.
class CloudMeasurementSyncService {
  CloudMeasurementSyncService._() : _rpcOverride = null, _analysisRunner = null;

  @visibleForTesting
  CloudMeasurementSyncService.forTest({
    required String memberId,
    required CloudRpcOverride rpc,
    Future<void> Function()? analysisRunner,
  }) : _memberId = memberId,
       _rpcOverride = rpc,
       _analysisRunner = analysisRunner,
       _initialized = true;

  static final CloudMeasurementSyncService instance =
      CloudMeasurementSyncService._();

  SupabaseClient? _client;
  String? _memberId;
  String? _demoEmail;
  String? _demoPassword;
  bool _initialized = false;
  final CloudRpcOverride? _rpcOverride;
  final Future<void> Function()? _analysisRunner;

  bool get isConfigured => _client != null && _memberId != null;
  String? get configuredMemberId => _memberId;
  String? get currentAccessToken => _client?.auth.currentSession?.accessToken;

  Future<void> initializeForEmbeddedDemo() async {
    if (_initialized) return;
    _initialized = true;

    final credentials = await EmbeddedDemoCloudCredentials.load();
    _memberId = credentials.memberId;
    _demoEmail = credentials.email;
    _demoPassword = credentials.password;

    await Supabase.initialize(
      url: credentials.url,
      publishableKey: credentials.publishableKey,
      debug: kDebugMode,
    );
    _client = Supabase.instance.client;
  }

  Future<void> ensureDemoSession() async {
    final client = _requireClient();
    final email = _demoEmail;
    final password = _demoPassword;
    if (email == null || password == null) {
      throw const CloudSyncConfigurationException(
        'Cloud demo session is not configured.',
      );
    }
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<CloudSyncResult> syncDashboardData({int batchSize = 200}) async {
    final analysisRunner = _analysisRunner;
    if (analysisRunner == null) {
      await PhoneAnalysisCoordinator.instance.runNow();
    } else {
      await analysisRunner();
    }
    return syncPendingVitalReadings(limit: batchSize);
  }

  Future<CloudSyncResult> syncPendingVitalReadings({int limit = 500}) async {
    final client = _rpcOverride == null ? _requireClient() : null;
    if (_rpcOverride == null && client?.auth.currentSession == null) {
      throw const CloudSyncAuthRequiredException();
    }
    final memberId = _memberId;
    if (memberId == null) {
      throw const CloudSyncConfigurationException(
        'Cloud measurement sync is not configured.',
      );
    }

    final database = LocalHealthDatabase.instance;
    final rawBatchSize = limit.clamp(1, 500);
    final artifactBatchSize = limit.clamp(1, 200);
    var considered = 0;
    var synced = 0;
    var skipped = 0;
    var failed = 0;
    var fused = 0;
    var conflicts = 0;
    var abstained = 0;
    var artifacts = 0;
    var rejected = 0;
    var contextRefreshed = false;
    var analysisPromoted = false;
    var remainingReadings = 0;
    var remainingArtifacts = 0;
    String? lastError;

    int? beforeLocalId;
    while (true) {
      final pendingRows = await database.loadVitalReadings(
        onlyUnsynced: true,
        onlyReal: true,
        beforeLocalId: beforeLocalId,
        limit: rawBatchSize,
      );
      if (pendingRows.isEmpty) break;
      considered += pendingRows.length;
      for (final row in pendingRows) {
        final localId = _intValue(row['id']);
        final source = row['source']?.toString();
        final clientEventId = row['client_event_id']?.toString();
        final rawData = _decodeRawData(row['raw_data']);
        final provenance = _stringMap(rawData['provenance']);
        final storedDeviceId = row['device_id']?.toString();
        final provenanceDeviceId = provenance['deviceId']?.toString();
        final deviceId = storedDeviceId?.isNotEmpty == true
            ? storedDeviceId
            : provenanceDeviceId?.isNotEmpty == true
            ? provenanceDeviceId
            : source == null
            ? null
            : '${source}_unidentified';
        if (_isMock(row, rawData, provenance)) {
          skipped++;
          continue;
        }
        if (localId == null ||
            source == null ||
            deviceId == null ||
            deviceId.isEmpty ||
            clientEventId == null ||
            clientEventId.isEmpty) {
          skipped++;
          continue;
        }
        try {
          final cloudId = await _rpc<String>(
            'sync_vital_reading',
            params: {
              'p_member_id': memberId,
              'p_device_identifier': deviceId,
              'p_source': source,
              'p_recorded_at': _recordedAt(
                row['recorded_at'],
              ).toIso8601String(),
              'p_client_event_id': clientEventId,
              'p_heart_rate': row['heart_rate'],
              'p_spo2': row['spo2'],
              'p_hrv': row['hrv'],
              'p_respiratory_rate': row['respiratory_rate'],
              'p_temperature': row['temperature'],
              'p_stress': row['stress'],
              'p_steps': row['steps'],
              'p_signal_quality': _ratio(row['signal_quality']),
              'p_confidence': _ratio(row['confidence']),
              'p_is_valid': _boolValue(row['is_valid'], fallback: true),
              'p_is_abnormal': _boolValue(row['is_abnormal']),
              'p_raw_data': {
                ...rawData,
                if (storedDeviceId?.isNotEmpty != true &&
                    provenanceDeviceId?.isNotEmpty != true)
                  'deviceIdentifierFallback': true,
              },
              'p_coverage_ratio': _ratio(
                row['coverage_ratio'] ?? provenance['coverageRatio'],
              ),
              'p_quality_flag':
                  row['quality_flag'] ?? provenance['qualityFlag'],
              'p_wear_state':
                  row['wear_state'] ??
                  rawData['wearState'] ??
                  provenance['wearState'],
              'p_clock_offset_ms':
                  row['clock_offset_ms'] ??
                  rawData['clockOffsetMs'] ??
                  provenance['clockOffsetMs'],
              'p_packet_loss_ratio': _ratio(
                row['packet_loss_ratio'] ??
                    rawData['packetLossRatio'] ??
                    provenance['packetLossRatio'],
              ),
            },
          );
          await database.markVitalReadingSynced(
            localId: localId,
            cloudReadingId: cloudId,
          );
          synced++;
        } on Object catch (error) {
          failed++;
          lastError = _friendlyError(error);
        }
      }
      beforeLocalId = pendingRows
          .map((row) => _intValue(row['id']))
          .whereType<int>()
          .fold<int?>(
            null,
            (lowest, id) => lowest == null || id < lowest ? id : lowest,
          );
      if (beforeLocalId == null || pendingRows.length < rawBatchSize) break;
    }

    while (true) {
      try {
        final pending = await database.loadPendingSyncBundle(
          limit: artifactBatchSize,
        );
        final localItems = (pending['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .toList(growable: false);
        if (localItems.isEmpty) break;
        final bundleItems = localItems
            .map((item) {
              final decoded = jsonDecode(item['payload_json'].toString());
              return {
                'outbox_id': item['id'],
                'entity_type': item['entity_type'],
                'local_id': item['local_id'],
                'payload_hash': item['payload_hash'],
                'payload': decoded,
              };
            })
            .toList(growable: false);
        final localOnly = bundleItems
            .where((item) => _artifactIsMock(item['payload']))
            .map(
              (item) => <String, Object?>{
                'outboxId': item['outbox_id'],
                'entityType': item['entity_type'],
                'localId': item['local_id'],
                'cloudId': null,
                'status': 'REJECTED',
                'reason': 'LOCAL_ONLY_MOCK_DATA',
              },
            )
            .toList(growable: false);
        if (localOnly.isNotEmpty) {
          skipped += localOnly.length;
          await database.acknowledgeSyncBundle(acknowledgements: localOnly);
        }
        final cloudBundleItems = bundleItems
            .where((item) => !_artifactIsMock(item['payload']))
            .toList(growable: false);
        if (cloudBundleItems.isEmpty) continue;
        final response = await _rpc<dynamic>(
          'sync_phone_analysis_bundle',
          params: {
            'p_member_id': memberId,
            'p_bundle': {'items': cloudBundleItems},
          },
        );
        final result = response is Map
            ? Map<String, dynamic>.from(response)
            : const <String, dynamic>{};
        final acknowledgements = (result['acks'] as List? ?? const [])
            .whereType<Map>()
            .map((raw) {
              final ack = Map<String, Object?>.from(raw);
              final status = ack['status']?.toString() ?? 'REJECTED';
              if (status == 'REJECTED') rejected++;
              if (ack['entity_type'] == 'FUSED_METRIC' &&
                  status != 'REJECTED') {
                fused++;
              }
              return <String, Object?>{
                'outboxId': ack['outbox_id'],
                'entityType': ack['entity_type'],
                'localId': ack['local_id'],
                'cloudId': ack['cloud_id'],
                'status': status,
                'reason': ack['reason'],
              };
            })
            .toList(growable: false);
        artifacts +=
            acknowledgements.length -
            acknowledgements.where((ack) => ack['status'] == 'REJECTED').length;
        await database.acknowledgeSyncBundle(
          acknowledgements: acknowledgements,
        );
        if (acknowledgements.length != cloudBundleItems.length) {
          failed++;
          lastError = 'Cloud returned incomplete bundle acknowledgements.';
          break;
        }
      } on Object catch (error) {
        failed++;
        lastError = _friendlyError(error);
        break;
      }
    }

    try {
      final response = await _rpc<dynamic>(
        'run_observatory_analysis',
        params: {
          'p_member_id': memberId,
          'p_as_of': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (response is Map) {
        analysisPromoted = response['status']?.toString() == 'COMPLETED';
      }
    } on Object catch (error) {
      failed++;
      lastError = _friendlyError(error);
    }

    try {
      final response = await _rpc<dynamic>(
        'get_phone_analysis_context',
        params: {
          'p_member_id': memberId,
          'p_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (response is Map) {
        final snapshot = Map<String, Object?>.from(response);
        final catalog = (snapshot.remove('catalog_items') as List? ?? const [])
            .cast<Object?>();
        final expiresAt = DateTime.parse(
          snapshot.remove('expires_at').toString(),
        ).toUtc();
        final contextVersion = snapshot.remove('context_version').toString();
        await database.saveRecommendationContext(
          context: snapshot,
          catalog: catalog,
          contextVersion: contextVersion,
          fetchedAt: DateTime.now().toUtc(),
          expiresAt: expiresAt,
          dataOrigin: 'REAL',
        );
        contextRefreshed = true;
      }
    } on Object catch (error) {
      failed++;
      lastError = _friendlyError(error);
    }

    try {
      remainingReadings = await database.countPendingRealVitalReadings();
      final status = await database.getAnalysisDebugStatus();
      remainingArtifacts = _intValue(status['pendingOutbox']) ?? 0;
    } on Object {
      // Sync success must not depend on optional diagnostics.
    }

    return CloudSyncResult(
      considered: considered,
      synced: synced,
      skipped: skipped,
      failed: failed,
      fused: fused,
      conflicts: conflicts,
      abstained: abstained,
      artifacts: artifacts,
      rejected: rejected,
      contextRefreshed: contextRefreshed,
      analysisPromoted: analysisPromoted,
      remainingReadings: remainingReadings,
      remainingArtifacts: remainingArtifacts,
      lastError: lastError,
    );
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const CloudSyncConfigurationException(
        'Cloud measurement sync is not configured.',
      );
    }
    return client;
  }

  Future<T> _rpc<T>(
    String functionName, {
    required Map<String, Object?> params,
  }) async {
    final override = _rpcOverride;
    if (override != null) {
      return await override(functionName, params) as T;
    }
    return _requireClient().rpc<T>(functionName, params: params);
  }

  static DateTime _recordedAt(Object? value) {
    final milliseconds = _intValue(value);
    if (milliseconds == null) {
      throw const FormatException('Local vital reading has no timestamp.');
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  static Map<String, dynamic> _decodeRawData(Object? value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, item) => MapEntry(key.toString(), item));
        }
      } on FormatException {
        // Preserve the normalized reading even when an optional payload is bad.
      }
    }
    return <String, dynamic>{};
  }

  static Map<String, Object?> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static bool _isMock(
    Map<String, Object?> row,
    Map<String, dynamic> rawData,
    Map<String, Object?> provenance,
  ) =>
      row['data_origin'] == 'DEBUG_MOCK' ||
      rawData['isMock'] == true ||
      provenance['isMock'] == true ||
      provenance['origin'] == 'debugMock';

  static bool _artifactIsMock(Object? value) {
    final payload = _stringMap(value);
    final evidence = _stringMap(payload['evidence']);
    return payload['data_origin'] == 'SIMULATION_ONLY' ||
        payload['data_origin'] == 'DEBUG_MOCK' ||
        evidence['mock'] == true;
  }

  static int? _intValue(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static bool _boolValue(Object? value, {bool fallback = false}) =>
      switch (value) {
        bool value => value,
        num value => value != 0,
        String value => value == '1' || value.toLowerCase() == 'true',
        _ => fallback,
      };

  static double? _ratio(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (number == null || !number.isFinite) return null;
    return (number > 1 ? number / 100 : number).clamp(0.0, 1.0);
  }

  static String _friendlyError(Object error) {
    if (error is PostgrestException) return error.message;
    if (error is AuthException) return error.message;
    return error.toString();
  }
}
