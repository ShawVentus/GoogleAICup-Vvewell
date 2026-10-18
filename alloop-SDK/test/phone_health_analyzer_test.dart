import 'package:alloop/features/health_analysis/domain/phone_health_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime.utc(2026, 8, 3);
  const analyzer = PhoneHealthAnalyzer();

  test('matches every inclusive quality boundary', () {
    final accepted = _row(
      0,
      confidence: 0.60,
      signalQuality: 0.50,
      coverageRatio: 0.60,
    );
    expect(analyzer.qualityReasons(accepted), isEmpty);
    expect(
      analyzer.qualityReasons(_row(0, confidence: 0.59)),
      contains('CONFIDENCE_LOW'),
    );
    expect(
      analyzer.qualityReasons(_row(0, signalQuality: 0.49)),
      contains('SIGNAL_QUALITY_LOW'),
    );
    expect(
      analyzer.qualityReasons(_row(0, coverageRatio: 0.59)),
      contains('COVERAGE_LOW'),
    );
    expect(
      analyzer.qualityReasons(_row(0, conflictFlag: true)),
      contains('SOURCE_CONFLICT'),
    );
    expect(
      analyzer.qualityReasons(_row(0, unit: 'hz')),
      contains('UNIT_UNSUPPORTED'),
    );
  });

  test('three rows produce only data insufficiency state', () {
    final result = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 1)),
      List.generate(3, _row),
    );
    expect(result.acceptedCount, 3);
    expect(_keys(result), contains('data_insufficient'));
    expect(_keys(result).where((key) => key.startsWith('relative_')), isEmpty);
  });

  test('requires twelve previous rows and a two hour span', () {
    final eleven = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 3)),
      List.generate(11, _row),
    );
    final twelve = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 3)),
      List.generate(12, _row),
    );
    final thirteen = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 3)),
      List.generate(13, _row),
    );
    expect(_keys(eleven), contains('data_insufficient'));
    expect(_keys(twelve), contains('data_insufficient'));
    expect(_keys(thirteen), isNot(contains('data_insufficient')));
  });

  test('matches Python predict-before-update golden output', () {
    final values = [
      ...[
        69.0,
        70.0,
        71.0,
      ].expand((value) => [value, value, value, value, value]),
    ];
    // Preserve the Python fixture order: [69,70,71] repeated five times.
    final ordered = <double>[
      for (var i = 0; i < 5; i++) ...[69, 70, 71],
      90,
      90,
      90,
    ];
    expect(values.length, 15);
    final rows = [
      for (var index = 0; index < ordered.length; index++)
        _row(index, value: ordered[index]),
    ];
    final result = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 4)),
      rows,
    );
    final tag = result.tags.singleWhere(
      (item) => item.tagKey == 'relative_hr_elevated',
    );
    expect(result.analysisId, '28faa44f-37e3-5871-8d36-099605e4af75');
    expect(
      result.inputFingerprint,
      'a12c8c0aa3431336dd3f6314d56c58dac66a0a629b0c4e203b7c3c81fbbd338f',
    );
    expect(
      tag.inputFingerprint,
      '4aaafca6ff863d88850700602ca7fc57a0ff71c6994bd57b056858e001198b54',
    );
    expect(tag.tagValue['deviation'], 2.638223);
    expect(tag.tagValue['persistence'], 3);
    expect(tag.demoBaseline, isTrue);
  });

  test('replay is deterministic when input order changes', () {
    final rows = List.generate(
      15,
      (index) => _row(index, value: 70 + index % 3),
    );
    final first = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 4)),
      rows,
    );
    final replay = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 4)),
      rows.reversed.toList(),
    );
    expect(first.toPayload(), replay.toPayload());
    expect(
      first.states.map((state) => state.toLocalMap(first.analysisId)).toList(),
      replay.states
          .map((state) => state.toLocalMap(replay.analysisId))
          .toList(),
    );
  });

  test('rejected rows make quality tags without changing baseline', () {
    final rows = [
      for (var index = 0; index < 12; index++)
        _row(index, status: 'ABSTAINED', qualityFlag: 'poor'),
      _row(13, conflictFlag: true),
    ];
    final result = analyzer.analyze(
      'member-1',
      base.add(const Duration(hours: 4)),
      rows,
    );
    expect(result.acceptedCount, 0);
    expect(
      _keys(result),
      containsAll({
        'data_insufficient',
        'low_data_coverage',
        'source_conflict_observed',
      }),
    );
  });

  test('adaptive window matches River drift index golden', () {
    final detector = AdaptiveWindowDetector();
    final detected = <int>[];
    final stream = [...List.filled(64, 0.0), ...List.filled(128, 10.0)];
    for (var index = 0; index < stream.length; index++) {
      if (detector.update(stream[index])) detected.add(index);
    }
    expect(detected.first, 95);
    expect(detected, [95]);
  });
}

Set<String> _keys(PhoneAnalysisResult result) =>
    result.tags.map((tag) => tag.tagKey).toSet();

PhoneFusedMetric _row(
  int index, {
  double value = 70,
  String status = 'AVAILABLE',
  String qualityFlag = 'good',
  double confidence = 0.9,
  double signalQuality = 0.9,
  double coverageRatio = 0.9,
  bool conflictFlag = false,
  String unit = 'bpm',
}) {
  final start = DateTime.utc(2026, 8, 3).add(Duration(minutes: 10 * index));
  final id = '00000000-0000-0000-0000-${index.toString().padLeft(12, '0')}';
  return PhoneFusedMetric(
    id: id,
    metricType: 'heart_rate',
    windowStart: start,
    windowEnd: start.add(const Duration(minutes: 1)),
    status: status,
    value: status == 'AVAILABLE' ? value : null,
    unit: unit,
    confidence: confidence,
    signalQuality: signalQuality,
    coverageRatio: coverageRatio,
    qualityFlag: qualityFlag,
    conflictFlag: conflictFlag,
    abstainReason: status == 'AVAILABLE' ? null : 'LOW_SQI',
    algorithmVersion: 'l0-adaptive-kalman-v1',
    inputFingerprint: index.toRadixString(16).padLeft(64, '0'),
    dataOrigin: 'REAL',
    payload: const {},
  );
}
