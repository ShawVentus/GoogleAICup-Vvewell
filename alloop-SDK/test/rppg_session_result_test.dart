import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alloop/features/rppg/data/rppg_platform_client.dart';
import 'package:alloop/features/rppg/domain/models/rppg_session_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('alloop/rppg_phone_test');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('parses DTO returned over the platform channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'startMeasurement');
          return _payload();
        });

    final result = await RppgPlatformClient(
      channel: channel,
    ).startMeasurement();

    expect(result.sessionId, 'rppg-1');
    expect(result.source, RppgSessionResult.expectedSource);
    expect(result.demoOnly, isFalse);
    expect(result.completed, isTrue);
    expect(result.estimateSamples, hasLength(2));
    expect(result.summary.heartRate, 72.0);
    expect(result.summary.respiratoryRate, 15.5);
  });

  test('supports unavailable respiratory rate without dropping heart rate', () {
    final result = RppgSessionResult.fromPlatform(
      _payload(
        summary: _summary(respiratoryRate: null, respiratoryRateConfidence: 0),
        samples: [_sample(respiratoryRate: null, respiratoryRateConfidence: 0)],
      ),
    );

    expect(result.summary.heartRate, 72.0);
    expect(result.summary.respiratoryRate, isNull);
    expect(result.summary.respiratoryRateConfidence, 0);
    expect(result.estimateSamples.single.respiratoryRate, isNull);
  });

  test('maps confidence values and aggregate quality as bounded ratios', () {
    final result = RppgSessionResult.fromPlatform(_payload());

    expect(result.summary.heartRateConfidence, 0.82);
    expect(result.summary.respiratoryRateConfidence, 0.61);
    expect(result.summary.aggregateQuality, 0.61);
    expect(
      () => RppgSessionResult.fromPlatform(
        _payload(summary: _summary(aggregateQuality: 1.1)),
      ),
      throwsFormatException,
    );
  });

  test('enforces rppg_phone source provenance', () {
    expect(
      () => RppgSessionResult.fromPlatform(_payload(source: 'mmwave_radar')),
      throwsFormatException,
    );
    final result = RppgSessionResult.fromPlatform(_payload());
    expect(result.source, 'rppg_phone');
    expect(result.deviceId, 'phone_camera');
    expect(result.schemaVersion, 1);
  });

  test('parses completed cancelled and error states', () {
    expect(
      RppgSessionResult.fromPlatform(_payload(reason: 'completed')).completed,
      isTrue,
    );
    expect(
      RppgSessionResult.fromPlatform(_payload(reason: 'cancelled')).cancelled,
      isTrue,
    );
    expect(
      RppgSessionResult.fromPlatform(_payload(reason: 'error')).error,
      isTrue,
    );
  });

  test('rejects synthetic demo payloads as real DTOs', () {
    expect(
      () => RppgSessionResult.fromPlatform(_payload(demoOnly: true)),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _payload({
  String source = 'rppg_phone',
  String reason = 'completed',
  bool demoOnly = false,
  Map<String, Object?>? summary,
  List<Map<String, Object?>>? samples,
}) {
  return {
    'sessionId': 'rppg-1',
    'startedAt': 1700000000000,
    'completedAt': 1700000020000,
    'source': source,
    'deviceId': 'phone_camera',
    'schemaVersion': 1,
    'completionReason': reason,
    'demoOnly': demoOnly,
    'estimateSamples':
        samples ??
        [
          _sample(timestamp: 1700000010000, scheduledSecond: 10),
          _sample(timestamp: 1700000020000, scheduledSecond: 20),
        ],
    'summary': summary ?? _summary(),
  };
}

Map<String, Object?> _sample({
  int timestamp = 1700000010000,
  double? heartRate = 72,
  double heartRateConfidence = 0.82,
  double? respiratoryRate = 15.5,
  double respiratoryRateConfidence = 0.61,
  double aggregateQuality = 0.61,
  int scheduledSecond = 10,
}) {
  return {
    'timestamp': timestamp,
    'heartRate': heartRate,
    'heartRateConfidence': heartRateConfidence,
    'respiratoryRate': respiratoryRate,
    'respiratoryRateConfidence': respiratoryRateConfidence,
    'aggregateQuality': aggregateQuality,
    'scheduledSecond': scheduledSecond,
  };
}

Map<String, Object?> _summary({
  double? heartRate = 72,
  double heartRateConfidence = 0.82,
  double? respiratoryRate = 15.5,
  double respiratoryRateConfidence = 0.61,
  double aggregateQuality = 0.61,
}) {
  return {
    'heartRate': heartRate,
    'heartRateConfidence': heartRateConfidence,
    'respiratoryRate': respiratoryRate,
    'respiratoryRateConfidence': respiratoryRateConfidence,
    'aggregateQuality': aggregateQuality,
  };
}
