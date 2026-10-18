import 'dart:convert';

import 'package:alloop/features/cloud_sync/domain/l0_fusion_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 8, 3, 10);

  test('fuses aligned real sources deterministically', () {
    final rows = [
      _row(1, 'aizo_ring', start, heartRate: 72, temperature: 34),
      _row(
        2,
        'rppg_phone',
        start.add(const Duration(seconds: 15)),
        heartRate: 74,
      ),
    ];

    final first = const L0FusionEngine().process(rows);
    final replay = const L0FusionEngine().process(rows.reversed.toList());
    final output = first.outputs.singleWhere(
      (item) => item.metricType == 'heart_rate',
    );
    final replayOutput = replay.outputs.singleWhere(
      (item) => item.metricType == 'heart_rate',
    );

    expect(output.status, L0OutputStatus.available);
    expect(output.value, inInclusiveRange(72, 74));
    expect(output.coverageRatio, 1);
    expect(output.sourceLocalIds, [1, 2]);
    expect(output.inputFingerprint, replayOutput.inputFingerprint);
  });

  test('emits an interval and conflict evidence for divergent sources', () {
    final result = const L0FusionEngine().process([
      _row(1, 'aizo_ring', start, heartRate: 60, temperature: 34),
      _row(
        2,
        'rppg_phone',
        start.add(const Duration(seconds: 5)),
        heartRate: 100,
      ),
    ]);
    final output = result.outputs.singleWhere(
      (item) => item.metricType == 'heart_rate',
    );

    expect(output.status, L0OutputStatus.interval);
    expect(output.value, isNull);
    expect(output.conflictFlag, isTrue);
    expect(output.abstainReason, 'SOURCE_CONFLICT');
    expect(output.intervalLower, 60);
    expect(output.intervalUpper, 100);
  });

  test(
    'abstains below forty percent source coverage without interpolation',
    () {
      final result = const L0FusionEngine().process([
        _row(1, 'aizo_ring', start, heartRate: 70, temperature: 34),
        _row(2, 'rppg_phone', start, heartRate: 71),
        _row(3, 'mmwave_radar', start, heartRate: 72),
        _row(
          4,
          'rppg_phone',
          start.add(const Duration(minutes: 1)),
          heartRate: 73,
        ),
      ]);
      final output = result.outputs.singleWhere(
        (item) =>
            item.metricType == 'heart_rate' &&
            item.windowStart == start.add(const Duration(minutes: 1)),
      );

      expect(output.status, L0OutputStatus.abstained);
      expect(output.abstainReason, 'INSUFFICIENT_COVERAGE');
      expect(output.coverageRatio, closeTo(1 / 3, 0.00001));
      expect(output.evidence['interpolationUsed'], isFalse);
      expect(output.sourceLocalIds, [4]);
    },
  );

  test('invalidates off-wrist ring measurements', () {
    final result = const L0FusionEngine().process([
      _row(1, 'alloop_ring', start, heartRate: 72, temperature: 25),
    ]);
    final output = result.outputs.singleWhere(
      (item) => item.metricType == 'heart_rate',
    );

    expect(output.status, L0OutputStatus.abstained);
    expect(output.abstainReason, 'NOT_WORN');
    expect(output.wearState, 'OFF');
    expect(result.rowAssessments[1]?.wearState, 'OFF');
  });

  test('uses child wear threshold and aligns a known device clock offset', () {
    final childResult = const L0FusionEngine(
      ageGroup: 'child',
    ).process([_row(1, 'aizo_ring', start, heartRate: 72, temperature: 27)]);
    final adultResult = const L0FusionEngine().process([
      _row(1, 'aizo_ring', start, heartRate: 72, temperature: 27),
    ]);
    final aligned = const L0FusionEngine().process([
      _row(
        2,
        'rppg_phone',
        start.add(const Duration(minutes: 1, seconds: 20)),
        heartRate: 72,
        raw: {'clockOffsetMs': 30000},
      ),
    ]);

    expect(childResult.rowAssessments[1]?.wearState, 'WORN_GOOD');
    expect(adultResult.rowAssessments[1]?.wearState, 'OFF');
    expect(aligned.outputs.single.windowStart, start);
  });

  test('rejects poor radar target quality and excludes mock rows', () {
    final result = const L0FusionEngine().process([
      _row(
        1,
        'mmwave_radar',
        start,
        heartRate: 72,
        raw: {'targetCount': 2, 'snrDb': 3},
      ),
      _row(
        2,
        'rppg_phone',
        start,
        heartRate: 72,
        raw: {
          'provenance': {'isMock': true},
        },
      ),
    ]);
    final output = result.outputs.singleWhere(
      (item) => item.metricType == 'heart_rate',
    );

    expect(output.status, L0OutputStatus.abstained);
    expect(output.abstainReason, 'LOW_SQI');
    expect(result.ignoredRowIds, {2});
  });
}

Map<String, Object?> _row(
  int id,
  String source,
  DateTime recordedAt, {
  double? heartRate,
  double? temperature,
  Map<String, Object?> raw = const {},
}) => {
  'id': id,
  'source': source,
  'device_id': '$source-device',
  'recorded_at': recordedAt.millisecondsSinceEpoch,
  'heart_rate': heartRate,
  'temperature': temperature,
  'signal_quality': 0.9,
  'confidence': 0.9,
  'is_valid': 1,
  'raw_data': jsonEncode(raw),
};
