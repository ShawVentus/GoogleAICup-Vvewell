import 'dart:convert';
import 'dart:io';

import 'package:alloop/features/health_analysis/data/phone_analysis_coordinator.dart';
import 'package:alloop/features/health_analysis/domain/canonical_contract.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty offline pipeline creates a measurement retry decision', () async {
    var networkCalls = 0;
    final summary = await HttpOverrides.runZoned(
      () => PhoneAnalysisCoordinator.instance.runNow(
        asOf: DateTime.utc(2026, 8, 3, 10),
      ),
      createHttpClient: (_) {
        networkCalls++;
        throw StateError('Phone analysis must not create an HTTP client.');
      },
    );

    expect(networkCalls, 0);
    expect(summary.status, 'READY');
    expect(summary.itemCount, 1);
    expect(summary.analysisId, isNotEmpty);
    expect(summary.decisionId, isNotEmpty);
  });

  test(
    'unchanged durable input does not enqueue another sync bundle',
    () async {
      const channel = MethodChannel('alloop/local_health_database');
      var bundleWrites = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'loadVitalReadings':
                return <Object?>[];
              case 'loadAnalysisInputs':
                return <String, Object?>{
                  'fusedMetrics': <Object?>[],
                  'context': <String, Object?>{},
                  'analysisRun': <String, Object?>{
                    'input_fingerprint': sha256Hex(const <Object?>[]),
                  },
                };
              case 'saveAnalysisBundle':
                bundleWrites++;
                return <String, int>{};
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await PhoneAnalysisCoordinator.instance.runNow(
        asOf: DateTime.utc(2026, 8, 3, 11),
      );

      expect(bundleWrites, 0);
    },
  );

  test('mock-only readings remain local and create no cloud outbox', () async {
    const channel = MethodChannel('alloop/local_health_database');
    Map<String, Object?>? savedBundle;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'initialize':
              return null;
            case 'loadVitalReadings':
              return <Object?>[
                <String, Object?>{
                  'id': 1,
                  'source': 'rppg_phone',
                  'device_id': 'phone_camera',
                  'recorded_at': DateTime.utc(
                    2026,
                    8,
                    3,
                    9,
                  ).millisecondsSinceEpoch,
                  'heart_rate': 70,
                  'signal_quality': 0.9,
                  'confidence': 0.9,
                  'is_valid': 1,
                  'raw_data':
                      '{"provenance":{"origin":"debugMock","isMock":true}}',
                },
              ];
            case 'loadAnalysisInputs':
              return <String, Object?>{
                'fusedMetrics': <Object?>[],
                'context': <String, Object?>{},
                'analysisRun': <String, Object?>{},
              };
            case 'saveAnalysisBundle':
              savedBundle = Map<String, Object?>.from(call.arguments as Map);
              return <String, int>{};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await PhoneAnalysisCoordinator.instance.runNow(
      asOf: DateTime.utc(2026, 8, 3, 10),
    );

    expect(savedBundle?['outbox'], isEmpty);
    final run = Map<String, Object?>.from(savedBundle?['analysisRun'] as Map);
    final payload = jsonDecode(run['payload_json'].toString()) as Map;
    expect(payload['data_origin'], 'SIMULATION_ONLY');
  });
}
