import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

enum L0OutputStatus { available, interval, abstained }

class L0RowAssessment {
  const L0RowAssessment({
    required this.signalQuality,
    required this.confidence,
    required this.coverageRatio,
    required this.qualityFlag,
    required this.wearState,
    required this.clockOffsetMs,
    required this.packetLossRatio,
  });

  final double signalQuality;
  final double confidence;
  final double coverageRatio;
  final String qualityFlag;
  final String? wearState;
  final double clockOffsetMs;
  final double packetLossRatio;
}

class L0Conflict {
  const L0Conflict({
    required this.sourceA,
    required this.sourceB,
    required this.valueA,
    required this.valueB,
    required this.tolerance,
  });

  final String sourceA;
  final String sourceB;
  final double valueA;
  final double valueB;
  final double tolerance;
}

class L0FusedMetric {
  const L0FusedMetric({
    required this.metricType,
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    required this.value,
    required this.unit,
    required this.confidence,
    required this.signalQuality,
    required this.coverageRatio,
    required this.coverageMask,
    required this.qualityFlag,
    required this.conflictFlag,
    required this.intervalLower,
    required this.intervalUpper,
    required this.contributingSources,
    required this.wearState,
    required this.abstainReason,
    required this.inputFingerprint,
    required this.evidence,
    this.conflict,
  });

  static const algorithmVersion = 'l0-adaptive-kalman-v1';

  final String metricType;
  final DateTime windowStart;
  final DateTime windowEnd;
  final L0OutputStatus status;
  final double? value;
  final String unit;
  final double confidence;
  final double signalQuality;
  final double coverageRatio;
  final Map<String, bool> coverageMask;
  final String qualityFlag;
  final bool conflictFlag;
  final double? intervalLower;
  final double? intervalUpper;
  final List<String> contributingSources;
  final String? wearState;
  final String? abstainReason;
  final String inputFingerprint;
  final Map<String, dynamic> evidence;
  final L0Conflict? conflict;

  List<int> get sourceLocalIds =>
      (evidence['sourceLocalIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false);

  Map<String, dynamic> toRpcParams(String memberId) => {
    'p_member_id': memberId,
    'p_metric_type': metricType,
    'p_window_start': windowStart.toIso8601String(),
    'p_window_end': windowEnd.toIso8601String(),
    'p_status': status.name.toUpperCase(),
    'p_value': value,
    'p_unit': unit,
    'p_confidence': confidence,
    'p_signal_quality': signalQuality,
    'p_coverage_ratio': coverageRatio,
    'p_coverage_mask': coverageMask,
    'p_quality_flag': qualityFlag,
    'p_conflict_flag': conflictFlag,
    'p_interval_lower': intervalLower,
    'p_interval_upper': intervalUpper,
    'p_contributing_sources': contributingSources,
    'p_wear_state': wearState,
    'p_abstain_reason': abstainReason,
    'p_algorithm_version': algorithmVersion,
    'p_input_fingerprint': inputFingerprint,
    'p_evidence': evidence,
    'p_conflict_source_a': conflict?.sourceA,
    'p_conflict_source_b': conflict?.sourceB,
    'p_conflict_value_a': conflict?.valueA,
    'p_conflict_value_b': conflict?.valueB,
    'p_conflict_tolerance': conflict?.tolerance,
  };
}

class L0ProcessingResult {
  const L0ProcessingResult({
    required this.outputs,
    required this.rowAssessments,
    required this.ignoredRowIds,
  });

  final List<L0FusedMetric> outputs;
  final Map<int, L0RowAssessment> rowAssessments;
  final Set<int> ignoredRowIds;
}

class L0FusionEngine {
  const L0FusionEngine({this.ageGroup = 'adult'});

  static const minimumCoverage = 0.40;
  static const minimumSignalQuality = 0.35;
  static const _window = Duration(minutes: 1);
  static const _sessionGap = Duration(minutes: 5);

  final String ageGroup;

  L0ProcessingResult process(List<Map<String, Object?>> rows) {
    final observations = <_Observation>[];
    final ignored = <int>{};
    final rawRows = <int, _RawRow>{};

    for (final row in rows) {
      final parsed = _RawRow.fromMap(row);
      if (parsed == null) continue;
      rawRows[parsed.localId] = parsed;
      if (parsed.isMock) {
        ignored.add(parsed.localId);
        continue;
      }
      observations.addAll(_observationsFor(parsed));
    }

    final outputs = <L0FusedMetric>[];
    final byMetric = <String, List<_Observation>>{};
    for (final observation in observations) {
      byMetric.putIfAbsent(observation.metricType, () => []).add(observation);
    }
    for (final entry in byMetric.entries) {
      entry.value.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      for (final session in _sessions(entry.value)) {
        outputs.addAll(_processSession(entry.key, session));
      }
    }

    final assessmentInputs = <int, List<_Observation>>{};
    for (final observation in observations) {
      assessmentInputs
          .putIfAbsent(observation.localId, () => [])
          .add(observation);
    }
    final outputByMetricWindow = <String, L0FusedMetric>{
      for (final output in outputs)
        _metricWindowKey(output.metricType, output.windowStart): output,
    };
    final assessments = <int, L0RowAssessment>{};
    for (final entry in assessmentInputs.entries) {
      final items = entry.value;
      final row = rawRows[entry.key]!;
      final quality = items.map((item) => item.signalQuality).reduce(math.min);
      final confidence = items.map((item) => item.confidence).reduce(math.min);
      final coverage = items
          .map(
            (item) =>
                outputByMetricWindow[_metricWindowKey(
                      item.metricType,
                      _floorMinute(item.recordedAt),
                    )]
                    ?.coverageRatio ??
                0,
          )
          .reduce(math.min);
      assessments[entry.key] = L0RowAssessment(
        signalQuality: quality,
        confidence: confidence,
        coverageRatio: coverage,
        qualityFlag: _qualityFlag(quality),
        wearState: row.wearState(ageGroup),
        clockOffsetMs: row.clockOffsetMs,
        packetLossRatio: row.packetLossRatio,
      );
    }

    outputs.sort((a, b) {
      final byTime = a.windowStart.compareTo(b.windowStart);
      return byTime != 0 ? byTime : a.metricType.compareTo(b.metricType);
    });
    return L0ProcessingResult(
      outputs: outputs,
      rowAssessments: assessments,
      ignoredRowIds: ignored,
    );
  }

  List<_Observation> _observationsFor(_RawRow row) {
    final result = <_Observation>[];
    for (final definition in _metrics) {
      if (!definition.sourceVariances.containsKey(row.source)) continue;
      final value = _finite(row.values[definition.column]);
      if (value == null) continue;
      final wearState = row.wearState(ageGroup);
      final plausibility = definition.isPlausible(value, ageGroup) ? 1.0 : 0.0;
      final sourceQuality = row.metricQuality(definition.metricType);
      final wearFactor = switch (wearState) {
        'WORN_GOOD' => 1.0,
        'WORN_POOR' => 0.5,
        'CHARGING' || 'OFF' => 0.0,
        _ => 1.0,
      };
      final quality =
          (sourceQuality *
                  plausibility *
                  (1 - row.packetLossRatio) *
                  wearFactor *
                  (row.valid ? 1.0 : 0.0))
              .clamp(0.0, 1.0);
      result.add(
        _Observation(
          localId: row.localId,
          source: row.source,
          deviceId: row.deviceId,
          recordedAt: row.recordedAt.subtract(
            Duration(microseconds: (row.clockOffsetMs * 1000).round()),
          ),
          metricType: definition.metricType,
          value: value,
          unit: definition.unit,
          signalQuality: quality,
          confidence: math.min(
            row.metricConfidence(definition.metricType),
            quality,
          ),
          valid: row.valid && plausibility > 0,
          wearState: wearState,
        ),
      );
    }
    return result;
  }

  Iterable<List<_Observation>> _sessions(
    List<_Observation> observations,
  ) sync* {
    var current = <_Observation>[];
    DateTime? previous;
    for (final observation in observations) {
      if (previous != null &&
          observation.recordedAt.difference(previous) > _sessionGap) {
        yield current;
        current = <_Observation>[];
      }
      current.add(observation);
      previous = observation.recordedAt;
    }
    if (current.isNotEmpty) yield current;
  }

  List<L0FusedMetric> _processSession(
    String metricType,
    List<_Observation> session,
  ) {
    final definition = _metrics.singleWhere(
      (item) => item.metricType == metricType,
    );
    final activeSources = session.map((item) => item.source).toSet().toList()
      ..sort();
    final sessionLocalIds = session.map((item) => item.localId).toSet().toList()
      ..sort();
    final firstWindow = _floorMinute(session.first.recordedAt);
    final lastWindow = _floorMinute(session.last.recordedAt);
    final result = <L0FusedMetric>[];
    for (
      var start = firstWindow;
      !start.isAfter(lastWindow);
      start = start.add(_window)
    ) {
      final end = start.add(_window);
      final windowItems = session
          .where(
            (item) =>
                !item.recordedAt.isBefore(start) &&
                item.recordedAt.isBefore(end),
          )
          .toList();
      result.add(
        _fuseWindow(
          definition,
          start,
          end,
          activeSources,
          windowItems,
          sessionLocalIds,
        ),
      );
    }
    return result;
  }

  L0FusedMetric _fuseWindow(
    _MetricDefinition definition,
    DateTime start,
    DateTime end,
    List<String> activeSources,
    List<_Observation> items,
    List<int> sessionLocalIds,
  ) {
    final observedSources = items.map((item) => item.source).toSet();
    final coverageMask = {
      for (final source in activeSources)
        source: observedSources.contains(source),
    };
    final coverage = activeSources.isEmpty
        ? 0.0
        : observedSources.length / activeSources.length;
    final contributing = items.map((item) => item.source).toSet().toList()
      ..sort();
    final sourceLocalIds = items.isEmpty
        ? sessionLocalIds
        : (items.map((item) => item.localId).toSet().toList()..sort());
    final fingerprint = _fingerprint(
      definition.metricType,
      start,
      items,
      activeSources,
    );
    final evidence = <String, dynamic>{
      'policy': definition.policy,
      'windowSeconds': 60,
      'interpolationUsed': false,
      'sourceCount': observedSources.length,
      'expectedSourceCount': activeSources.length,
      'qualityThreshold': minimumSignalQuality,
      'coverageThreshold': minimumCoverage,
      'sourceLocalIds': sourceLocalIds,
    };

    if (coverage < minimumCoverage) {
      return _abstained(
        definition,
        start,
        end,
        coverageMask,
        contributing,
        coverage,
        'INSUFFICIENT_COVERAGE',
        fingerprint,
        evidence,
      );
    }
    if (items.isNotEmpty &&
        items.every(
          (item) => item.wearState == 'OFF' || item.wearState == 'CHARGING',
        )) {
      return _abstained(
        definition,
        start,
        end,
        coverageMask,
        contributing,
        coverage,
        'NOT_WORN',
        fingerprint,
        evidence,
        wearState: items.first.wearState,
      );
    }

    final usable = items
        .where(
          (item) => item.valid && item.signalQuality >= minimumSignalQuality,
        )
        .toList();
    if (usable.isEmpty) {
      return _abstained(
        definition,
        start,
        end,
        coverageMask,
        contributing,
        coverage,
        'LOW_SQI',
        fingerprint,
        evidence,
        wearState: _combinedWearState(items),
      );
    }

    final conflict = _worstConflict(definition, usable);
    final quality = _weightedQuality(definition, usable);
    if (conflict != null) {
      return L0FusedMetric(
        metricType: definition.metricType,
        windowStart: start,
        windowEnd: end,
        status: L0OutputStatus.interval,
        value: null,
        unit: definition.unit,
        confidence: (quality * 0.75).clamp(0.0, 1.0),
        signalQuality: quality,
        coverageRatio: coverage.clamp(0.0, 1.0),
        coverageMask: coverageMask,
        qualityFlag: 'degraded',
        conflictFlag: true,
        intervalLower: usable.map((item) => item.value).reduce(math.min),
        intervalUpper: usable.map((item) => item.value).reduce(math.max),
        contributingSources: usable.map((item) => item.source).toSet().toList()
          ..sort(),
        wearState: _combinedWearState(usable),
        abstainReason: 'SOURCE_CONFLICT',
        inputFingerprint: fingerprint,
        evidence: {...evidence, 'resolution': 'interval'},
        conflict: conflict,
      );
    }

    final estimate = _kalman(definition, usable);
    final standardDeviation = math.sqrt(estimate.variance);
    final confidence = (quality * coverage).clamp(0.0, 1.0);
    return L0FusedMetric(
      metricType: definition.metricType,
      windowStart: start,
      windowEnd: end,
      status: L0OutputStatus.available,
      value: estimate.value,
      unit: definition.unit,
      confidence: confidence,
      signalQuality: quality,
      coverageRatio: coverage.clamp(0.0, 1.0),
      coverageMask: coverageMask,
      qualityFlag: _qualityFlag(quality),
      conflictFlag: false,
      intervalLower: estimate.value - 1.96 * standardDeviation,
      intervalUpper: estimate.value + 1.96 * standardDeviation,
      contributingSources: usable.map((item) => item.source).toSet().toList()
        ..sort(),
      wearState: _combinedWearState(usable),
      abstainReason: null,
      inputFingerprint: fingerprint,
      evidence: {...evidence, 'posteriorVariance': estimate.variance},
    );
  }

  L0FusedMetric _abstained(
    _MetricDefinition definition,
    DateTime start,
    DateTime end,
    Map<String, bool> coverageMask,
    List<String> contributing,
    double coverage,
    String reason,
    String fingerprint,
    Map<String, dynamic> evidence, {
    String? wearState,
  }) => L0FusedMetric(
    metricType: definition.metricType,
    windowStart: start,
    windowEnd: end,
    status: L0OutputStatus.abstained,
    value: null,
    unit: definition.unit,
    confidence: 0,
    signalQuality: 0,
    coverageRatio: coverage.clamp(0.0, 1.0),
    coverageMask: coverageMask,
    qualityFlag: 'poor',
    conflictFlag: false,
    intervalLower: null,
    intervalUpper: null,
    contributingSources: contributing,
    wearState: wearState,
    abstainReason: reason,
    inputFingerprint: fingerprint,
    evidence: evidence,
  );

  _KalmanEstimate _kalman(
    _MetricDefinition definition,
    List<_Observation> observations,
  ) {
    final ordered = [...observations]
      ..sort(
        (a, b) => definition
            .sourceVariance(a.source)
            .compareTo(definition.sourceVariance(b.source)),
      );
    var value = ordered.first.value;
    var variance = _observationVariance(definition, ordered.first);
    for (final observation in ordered.skip(1)) {
      final observationVariance = _observationVariance(definition, observation);
      final gain = variance / (variance + observationVariance);
      value += gain * (observation.value - value);
      variance = math.max(1e-9, (1 - gain) * variance);
    }
    return _KalmanEstimate(value, variance);
  }

  double _observationVariance(
    _MetricDefinition definition,
    _Observation observation,
  ) =>
      definition.sourceVariance(observation.source) /
      math.pow(math.max(observation.signalQuality, 0.05), 2).toDouble();

  double _weightedQuality(
    _MetricDefinition definition,
    List<_Observation> observations,
  ) {
    var numerator = 0.0;
    var denominator = 0.0;
    for (final observation in observations) {
      final weight = 1 / _observationVariance(definition, observation);
      numerator += weight * observation.signalQuality;
      denominator += weight;
    }
    return denominator == 0 ? 0 : (numerator / denominator).clamp(0.0, 1.0);
  }

  L0Conflict? _worstConflict(
    _MetricDefinition definition,
    List<_Observation> observations,
  ) {
    L0Conflict? worst;
    var worstExcess = 0.0;
    for (var left = 0; left < observations.length; left++) {
      for (var right = left + 1; right < observations.length; right++) {
        final a = observations[left];
        final b = observations[right];
        if (a.source == b.source) continue;
        final tolerance = definition.tolerance(a.value, b.value);
        final excess = (a.value - b.value).abs() - tolerance;
        if (excess > worstExcess) {
          worstExcess = excess;
          worst = L0Conflict(
            sourceA: a.source,
            sourceB: b.source,
            valueA: a.value,
            valueB: b.value,
            tolerance: tolerance,
          );
        }
      }
    }
    return worst;
  }

  static String? _combinedWearState(List<_Observation> observations) {
    final states = observations
        .map((item) => item.wearState)
        .whereType<String>()
        .toSet();
    if (states.contains('WORN_GOOD')) return 'WORN_GOOD';
    if (states.contains('WORN_POOR')) return 'WORN_POOR';
    if (states.contains('CHARGING')) return 'CHARGING';
    if (states.contains('OFF')) return 'OFF';
    return null;
  }

  static String _fingerprint(
    String metricType,
    DateTime start,
    List<_Observation> observations,
    List<String> activeSources,
  ) {
    final canonical = <String>[
      metricType,
      start.toUtc().toIso8601String(),
      activeSources.join(','),
      ...observations
          .map(
            (item) =>
                '${item.localId}|${item.source}|${item.deviceId}|'
                '${item.recordedAt.toUtc().microsecondsSinceEpoch}|${item.value}|'
                '${item.signalQuality}',
          )
          .toList()
        ..sort(),
    ].join('\n');
    final bytes = SHA256Digest().process(
      Uint8List.fromList(utf8.encode(canonical)),
    );
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static DateTime _floorMinute(DateTime value) {
    final utc = value.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  static String _metricWindowKey(String metric, DateTime start) =>
      '$metric|${start.toUtc().microsecondsSinceEpoch}';

  static String _qualityFlag(double quality) => switch (quality) {
    >= 0.65 => 'good',
    >= 0.40 => 'degraded',
    _ => 'poor',
  };
}

class _RawRow {
  const _RawRow({
    required this.localId,
    required this.source,
    required this.deviceId,
    required this.recordedAt,
    required this.values,
    required this.signalQuality,
    required this.confidence,
    required this.valid,
    required this.rawData,
    required this.isMock,
    required this.clockOffsetMs,
    required this.packetLossRatio,
  });

  final int localId;
  final String source;
  final String deviceId;
  final DateTime recordedAt;
  final Map<String, Object?> values;
  final double? signalQuality;
  final double? confidence;
  final bool valid;
  final Map<String, dynamic> rawData;
  final bool isMock;
  final double clockOffsetMs;
  final double packetLossRatio;

  static _RawRow? fromMap(Map<String, Object?> row) {
    final localId = _integer(row['id']);
    final source = row['source']?.toString();
    final deviceId = row['device_id']?.toString();
    final milliseconds = _integer(row['recorded_at']);
    if (localId == null ||
        source == null ||
        source.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty ||
        milliseconds == null) {
      return null;
    }
    final rawData = _decodeMap(row['raw_data']);
    final provenance = _map(rawData['provenance']);
    return _RawRow(
      localId: localId,
      source: source,
      deviceId: deviceId,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ),
      values: row,
      signalQuality: _ratio(row['signal_quality']),
      confidence: _ratio(row['confidence']),
      valid: _boolean(row['is_valid'], fallback: true),
      rawData: rawData,
      isMock: rawData['isMock'] == true || provenance['isMock'] == true,
      clockOffsetMs:
          _finite(rawData['clockOffsetMs'] ?? provenance['clockOffsetMs']) ?? 0,
      packetLossRatio:
          (_ratio(
                    rawData['packetLossRatio'] ?? provenance['packetLossRatio'],
                  ) ??
                  0)
              .clamp(0.0, 1.0),
    );
  }

  String? wearState(String ageGroup) {
    if (source != 'aizo_ring' && source != 'alloop_ring') return null;
    final state = (rawData['batteryState'] ?? rawData['wearState'])
        ?.toString()
        .toUpperCase();
    if (rawData['charging'] == true ||
        rawData['isCharging'] == true ||
        state == 'CHARGING') {
      return 'CHARGING';
    }
    if (state == 'OFF' || state == 'WORN_POOR' || state == 'WORN_GOOD') {
      return state;
    }
    final temperature = _finite(
      values['temperature'] ?? rawData['bodyTemp'] ?? rawData['temperature'],
    );
    final offThreshold = ageGroup == 'child' ? 26.0 : 28.0;
    if (temperature != null && temperature < offThreshold) return 'OFF';
    if (!valid) return 'WORN_POOR';
    if (temperature != null) return 'WORN_GOOD';
    return null;
  }

  double metricQuality(String metricType) {
    final provenance = _map(rawData['provenance']);
    final session = _map(rawData['rppgSession']);
    final summary = _map(session['summary']);
    final sourceSpecific = switch (metricType) {
      'heart_rate' =>
        rawData['heartConfidence'] ??
            provenance['hrConfidence'] ??
            summary['heartRateConfidence'],
      'respiratory_rate' =>
        rawData['breathingConfidence'] ??
            provenance['rrConfidence'] ??
            summary['respiratoryRateConfidence'],
      _ => null,
    };
    var quality =
        _ratio(sourceSpecific) ??
        signalQuality ??
        _ratio(provenance['aggregateQuality']) ??
        confidence ??
        0.55;
    if (source == 'mmwave_radar') {
      final targetCount = _integer(rawData['targetCount']);
      if (targetCount != null && targetCount != 1) quality *= 0.25;
      final snr = _finite(rawData['snrDb']);
      if (snr != null && snr < 6) quality *= 0.5;
    }
    final motion = _finite(
      rawData['accelerationMagnitude'] ?? rawData['motionMagnitude'],
    );
    if ((source == 'aizo_ring' || source == 'alloop_ring') &&
        motion != null &&
        motion > 1.5) {
      quality *= 0.5;
    }
    return quality.clamp(0.0, 1.0);
  }

  double metricConfidence(String metricType) =>
      (_ratio(confidence) ?? metricQuality(metricType)).clamp(0.0, 1.0);
}

class _Observation {
  const _Observation({
    required this.localId,
    required this.source,
    required this.deviceId,
    required this.recordedAt,
    required this.metricType,
    required this.value,
    required this.unit,
    required this.signalQuality,
    required this.confidence,
    required this.valid,
    required this.wearState,
  });

  final int localId;
  final String source;
  final String deviceId;
  final DateTime recordedAt;
  final String metricType;
  final double value;
  final String unit;
  final double signalQuality;
  final double confidence;
  final bool valid;
  final String? wearState;
}

class _MetricDefinition {
  const _MetricDefinition({
    required this.metricType,
    required this.column,
    required this.unit,
    required this.absoluteTolerance,
    required this.relativeTolerance,
    required this.defaultVariance,
    required this.sourceVariances,
    required this.policy,
    required this.adultRange,
    required this.childRange,
    required this.elderRange,
  });

  final String metricType;
  final String column;
  final String unit;
  final double absoluteTolerance;
  final double relativeTolerance;
  final double defaultVariance;
  final Map<String, double> sourceVariances;
  final String policy;
  final (double, double) adultRange;
  final (double, double) childRange;
  final (double, double) elderRange;

  bool isPlausible(double value, String ageGroup) {
    final range = switch (ageGroup) {
      'child' => childRange,
      'elder' => elderRange,
      _ => adultRange,
    };
    return value >= range.$1 && value <= range.$2;
  }

  double sourceVariance(String source) =>
      sourceVariances[source] ?? defaultVariance;

  double tolerance(double a, double b) => math.max(
    absoluteTolerance,
    relativeTolerance * math.max(a.abs(), b.abs()),
  );
}

class _KalmanEstimate {
  const _KalmanEstimate(this.value, this.variance);

  final double value;
  final double variance;
}

const _metrics = <_MetricDefinition>[
  _MetricDefinition(
    metricType: 'heart_rate',
    column: 'heart_rate',
    unit: 'bpm',
    absoluteTolerance: 10,
    relativeTolerance: 0.15,
    defaultVariance: 16,
    sourceVariances: {
      'aizo_ring': 4,
      'alloop_ring': 4,
      'rppg_phone': 9,
      'mmwave_radar': 16,
    },
    policy: 'ring_primary_rppg_crosscheck_radar_fallback',
    adultRange: (30, 220),
    childRange: (35, 240),
    elderRange: (30, 220),
  ),
  _MetricDefinition(
    metricType: 'respiratory_rate',
    column: 'respiratory_rate',
    unit: 'breaths/min',
    absoluteTolerance: 4,
    relativeTolerance: 0.20,
    defaultVariance: 12,
    sourceVariances: {
      'mmwave_radar': 4,
      'rppg_phone': 9,
      'aizo_ring': 12,
      'alloop_ring': 12,
    },
    policy: 'radar_primary_ppg_fallback',
    adultRange: (4, 60),
    childRange: (5, 80),
    elderRange: (4, 60),
  ),
  _MetricDefinition(
    metricType: 'spo2',
    column: 'spo2',
    unit: '%',
    absoluteTolerance: 3,
    relativeTolerance: 0.03,
    defaultVariance: 4,
    sourceVariances: {'aizo_ring': 2, 'alloop_ring': 2},
    policy: 'ring_only_motion_gated',
    adultRange: (70, 100),
    childRange: (70, 100),
    elderRange: (70, 100),
  ),
  _MetricDefinition(
    metricType: 'hrv',
    column: 'hrv',
    unit: 'ms',
    absoluteTolerance: 25,
    relativeTolerance: 0.35,
    defaultVariance: 64,
    sourceVariances: {'aizo_ring': 36, 'alloop_ring': 36},
    policy: 'ring_prv',
    adultRange: (0, 500),
    childRange: (0, 500),
    elderRange: (0, 500),
  ),
  _MetricDefinition(
    metricType: 'temperature',
    column: 'temperature',
    unit: 'C',
    absoluteTolerance: 1.5,
    relativeTolerance: 0.05,
    defaultVariance: 1,
    sourceVariances: {'aizo_ring': 0.5, 'alloop_ring': 0.5},
    policy: 'skin_temperature_only',
    adultRange: (20, 42),
    childRange: (20, 42),
    elderRange: (20, 42),
  ),
];

Map<String, dynamic> _decodeMap(Object? value) {
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
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : <String, dynamic>{};

double? _finite(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

double? _ratio(Object? value) {
  final parsed = _finite(value);
  if (parsed == null) return null;
  return (parsed > 1 ? parsed / 100 : parsed).clamp(0.0, 1.0);
}

int? _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

bool _boolean(Object? value, {bool fallback = false}) => switch (value) {
  bool item => item,
  num item => item != 0,
  String item => item == '1' || item.toLowerCase() == 'true',
  _ => fallback,
};
