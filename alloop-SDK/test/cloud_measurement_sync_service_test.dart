import 'dart:convert';

import 'package:alloop/features/cloud_sync/data/cloud_measurement_sync_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('alloop/local_health_database');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'dashboard sync analyzes first, drains pages, and excludes mock rows',
    () async {
      final order = <String>[];
      final rawParams = <Map<String, Object?>>[];
      final cloudBundleSizes = <int>[];
      final readQueries = <Map<String, Object?>>[];
      final markedIds = <int>[];
      var outboxLoads = 0;
      var acknowledged = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments is Map
                ? Map<String, Object?>.from(call.arguments as Map)
                : <String, Object?>{};
            switch (call.method) {
              case 'initialize':
                return null;
              case 'loadVitalReadings':
                readQueries.add(args);
                if (args['beforeLocalId'] == null) {
                  return <Object?>[
                    _reading(3, eventId: 'event-3'),
                    _reading(2, eventId: 'event-2', mock: true),
                  ];
                }
                return <Object?>[
                  _reading(1, eventId: 'event-1', noDevice: true),
                ];
              case 'markVitalReadingSynced':
                markedIds.add((args['localId'] as num).toInt());
                return null;
              case 'loadPendingSyncBundle':
                outboxLoads++;
                if (outboxLoads > 1) return <String, Object?>{'items': []};
                return <String, Object?>{
                  'items': [
                    {
                      'id': 10,
                      'entity_type': 'ANALYSIS_RUN',
                      'local_id': '93000000-0000-4000-8000-000000000010',
                      'payload_hash': List.filled(64, 'a').join(),
                      'payload_json': jsonEncode({
                        'data_origin': 'REAL',
                        'model_version': 'river-health-stream-dart-v1',
                      }),
                    },
                    {
                      'id': 11,
                      'entity_type': 'ANALYSIS_RUN',
                      'local_id': '93000000-0000-4000-8000-000000000011',
                      'payload_hash': List.filled(64, 'b').join(),
                      'payload_json': jsonEncode({
                        'data_origin': 'SIMULATION_ONLY',
                        'model_version': 'river-health-stream-dart-v1',
                      }),
                    },
                  ],
                };
              case 'acknowledgeSyncBundle':
                acknowledged += (args['acks'] as List).length;
                return acknowledged;
              case 'saveRecommendationContext':
                return null;
              case 'countPendingRealVitalReadings':
                return 0;
              case 'debugAnalysisStatus':
                return <String, Object?>{'pendingOutbox': 0};
            }
            return null;
          });

      final service = CloudMeasurementSyncService.forTest(
        memberId: '93000000-0000-4000-8000-000000000001',
        analysisRunner: () async => order.add('analysis'),
        rpc: (name, params) async {
          order.add(name);
          switch (name) {
            case 'sync_vital_reading':
              rawParams.add(params);
              return '94000000-0000-4000-8000-000000000001';
            case 'sync_phone_analysis_bundle':
              final bundle = Map<String, Object?>.from(
                params['p_bundle'] as Map,
              );
              cloudBundleSizes.add((bundle['items'] as List).length);
              return {
                'acks': [
                  {
                    'outbox_id': 10,
                    'entity_type': 'ANALYSIS_RUN',
                    'local_id': '93000000-0000-4000-8000-000000000010',
                    'cloud_id': '94000000-0000-4000-8000-000000000010',
                    'status': 'VALID',
                    'reason': null,
                  },
                ],
              };
            case 'run_observatory_analysis':
              return {'status': 'COMPLETED'};
            case 'get_phone_analysis_context':
              return {
                'context_version': 'context-v1',
                'expires_at': '2026-08-05T00:00:00Z',
                'catalog_items': <Object?>[],
                'consent_scopes': <Object?>[],
              };
          }
          throw StateError('Unexpected RPC $name');
        },
      );

      final result = await service.syncDashboardData(batchSize: 2);

      expect(order.first, 'analysis');
      expect(rawParams, hasLength(2));
      expect(markedIds, [3, 1]);
      expect(readQueries, hasLength(2));
      expect(readQueries.first['onlyReal'], isTrue);
      expect(readQueries.last['beforeLocalId'], 2);
      expect(rawParams.first['p_client_event_id'], 'event-3');
      expect(rawParams.first['p_coverage_ratio'], 0.95);
      expect(rawParams.first['p_quality_flag'], 'good');
      expect(rawParams.first['p_wear_state'], 'WORN_GOOD');
      expect(rawParams.first['p_clock_offset_ms'], 12);
      expect(rawParams.first['p_packet_loss_ratio'], 0.01);
      expect(rawParams.last['p_device_identifier'], 'alloop_ring_unidentified');
      expect(
        (rawParams.last['p_raw_data'] as Map)['deviceIdentifierFallback'],
        isTrue,
      );
      expect(cloudBundleSizes, [1]);
      expect(acknowledged, 2);
      expect(outboxLoads, 2);
      expect(result.considered, 3);
      expect(result.synced, 2);
      expect(result.skipped, 2);
      expect(result.artifacts, 1);
      expect(result.analysisPromoted, isTrue);
      expect(result.contextRefreshed, isTrue);
      expect(result.remainingReadings, 0);
      expect(result.remainingArtifacts, 0);
    },
  );
}

Map<String, Object?> _reading(
  int id, {
  required String eventId,
  bool mock = false,
  bool noDevice = false,
}) => {
  'id': id,
  'source': 'alloop_ring',
  'device_id': noDevice ? null : 'ring-1',
  'recorded_at': DateTime.utc(2026, 8, 4, 7, id).millisecondsSinceEpoch,
  'client_event_id': eventId,
  'data_origin': 'REAL',
  'heart_rate': 70 + id,
  'signal_quality': 0.9,
  'confidence': 0.8,
  'coverage_ratio': 0.95,
  'quality_flag': 'good',
  'wear_state': 'WORN_GOOD',
  'clock_offset_ms': 12,
  'packet_loss_ratio': 0.01,
  'is_valid': 1,
  'is_abnormal': 0,
  'raw_data': jsonEncode({
    'isMock': mock,
    'provenance': {'origin': mock ? 'debugMock' : 'realDevice'},
  }),
};
