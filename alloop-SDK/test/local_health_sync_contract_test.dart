import 'dart:convert';

import 'package:alloop/core/database/local_health_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('alloop/local_health_database');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('real reading persists cloud identity and dashboard metadata', () async {
    Map<String, Object?>? saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'initialize') return null;
          if (call.method == 'saveVitalReading') {
            saved = Map<String, Object?>.from(call.arguments as Map);
            return 7;
          }
          return null;
        });

    final at = DateTime.utc(2026, 8, 4, 7, 15);
    await LocalHealthDatabase.instance.saveVitalReading(
      source: 'alloop_ring',
      deviceId: 'ring-1',
      recordedAt: at,
      heartRate: 72,
      signalQuality: 0.9,
      confidence: 0.8,
      clientEventId: '93000000-0000-4000-8000-000000000001',
      provenance: VitalReadingProvenance(
        source: 'alloop_ring',
        deviceId: 'ring-1',
        recordedAt: at,
        coverageRatio: 0.95,
        qualityFlag: 'good',
        wearState: 'WORN_GOOD',
        clockOffsetMs: 12,
        packetLossRatio: 0.01,
        algorithmVersion: 'ring-sdk-v1',
      ),
    );

    expect(saved?['dataOrigin'], 'REAL');
    expect(saved?['clientEventId'], '93000000-0000-4000-8000-000000000001');
    expect(saved?['coverageRatio'], 0.95);
    expect(saved?['qualityFlag'], 'good');
    expect(saved?['wearState'], 'WORN_GOOD');
    final raw = jsonDecode(saved?['rawData'] as String) as Map<String, dynamic>;
    expect(raw['provenance']['algorithmVersion'], 'ring-sdk-v1');
    expect(raw['provenance']['isMock'], isFalse);
  });

  test(
    'mock reading is explicitly marked and real paging is requested',
    () async {
      Map<String, Object?>? saved;
      Map<String, Object?>? query;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return null;
            if (call.method == 'saveVitalReading') {
              saved = Map<String, Object?>.from(call.arguments as Map);
              return 8;
            }
            if (call.method == 'loadVitalReadings') {
              query = Map<String, Object?>.from(call.arguments as Map);
              return <Object?>[];
            }
            return null;
          });

      final at = DateTime.utc(2026, 8, 4);
      await LocalHealthDatabase.instance.saveVitalReading(
        source: 'rppg_phone',
        deviceId: 'phone_camera',
        recordedAt: at,
        provenance: VitalReadingProvenance(
          source: 'rppg_phone',
          deviceId: 'phone_camera',
          recordedAt: at,
          origin: HealthDataOrigin.debugMock,
        ),
      );
      await LocalHealthDatabase.instance.loadVitalReadings(
        onlyUnsynced: true,
        onlyReal: true,
        beforeLocalId: 501,
        limit: 200,
      );

      expect(saved?['dataOrigin'], 'DEBUG_MOCK');
      expect(saved?['confidence'], inInclusiveRange(0.6, 0.9));
      final raw =
          jsonDecode(saved?['rawData'] as String) as Map<String, dynamic>;
      expect(raw['provenance']['isMock'], isTrue);
      expect(raw['confidenceImputed'], isTrue);
      expect(raw['confidenceImputation'], 'uniform_random_0.6_0.9');
      expect(query?['onlyReal'], isTrue);
      expect(query?['beforeLocalId'], 501);
      expect(query?['limit'], 200);
    },
  );
}
