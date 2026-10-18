import 'dart:convert';
import 'dart:math' as math;

import '../../cloud_sync/domain/l0_fusion_engine.dart';
import 'canonical_contract.dart';

const phoneHealthModelVersion = 'river-health-stream-dart-v1';
const phoneHealthPolicyVersion = 'health-tag-policy-v1';

class PhoneFusedMetric {
  const PhoneFusedMetric({
    required this.id,
    required this.metricType,
    required this.windowStart,
    required this.windowEnd,
    required this.status,
    required this.value,
    required this.unit,
    required this.confidence,
    required this.signalQuality,
    required this.coverageRatio,
    required this.qualityFlag,
    required this.conflictFlag,
    required this.abstainReason,
    required this.algorithmVersion,
    required this.inputFingerprint,
    required this.dataOrigin,
    required this.payload,
  });

  final String id;
  final String metricType;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String status;
  final double? value;
  final String unit;
  final double confidence;
  final double signalQuality;
  final double coverageRatio;
  final String qualityFlag;
  final bool conflictFlag;
  final String? abstainReason;
  final String algorithmVersion;
  final String inputFingerprint;
  final String dataOrigin;
  final Map<String, Object?> payload;

  factory PhoneFusedMetric.fromL0(
    L0FusedMetric metric, {
    String dataOrigin = 'REAL',
  }) {
    final id = deterministicUuid('l0:${metric.inputFingerprint}');
    final payload = <String, Object?>{
      'id': id,
      'metric_type': metric.metricType,
      'window_start': pythonIso(metric.windowStart),
      'window_end': pythonIso(metric.windowEnd),
      'status': metric.status.name.toUpperCase(),
      'value': metric.value,
      'unit': metric.unit,
      'confidence': metric.confidence,
      'signal_quality': metric.signalQuality,
      'coverage_ratio': metric.coverageRatio,
      'coverage_mask': metric.coverageMask,
      'quality_flag': metric.qualityFlag,
      'conflict_flag': metric.conflictFlag,
      'interval_lower': metric.intervalLower,
      'interval_upper': metric.intervalUpper,
      'contributing_sources': metric.contributingSources,
      'wear_state': metric.wearState,
      'abstain_reason': metric.abstainReason,
      'algorithm_version': L0FusedMetric.algorithmVersion,
      'input_fingerprint': metric.inputFingerprint,
      'evidence': metric.evidence,
      'data_origin': dataOrigin,
    };
    return PhoneFusedMetric(
      id: id,
      metricType: metric.metricType,
      windowStart: metric.windowStart.toUtc(),
      windowEnd: metric.windowEnd.toUtc(),
      status: metric.status.name.toUpperCase(),
      value: metric.value,
      unit: metric.unit,
      confidence: metric.confidence,
      signalQuality: metric.signalQuality,
      coverageRatio: metric.coverageRatio,
      qualityFlag: metric.qualityFlag,
      conflictFlag: metric.conflictFlag,
      abstainReason: metric.abstainReason,
      algorithmVersion: L0FusedMetric.algorithmVersion,
      inputFingerprint: metric.inputFingerprint,
      dataOrigin: dataOrigin,
      payload: payload,
    );
  }

  factory PhoneFusedMetric.fromMap(Map<String, Object?> row) {
    final payload =
        _decodeMap(row['payload_json']) ?? Map<String, Object?>.from(row);
    DateTime time(String key) {
      final value = row[key] ?? payload[key];
      if (value is num)
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      return DateTime.parse(value.toString()).toUtc();
    }

    return PhoneFusedMetric(
      id: (row['id'] ?? payload['id']).toString(),
      metricType: (row['metric_type'] ?? payload['metric_type']).toString(),
      windowStart: time('window_start'),
      windowEnd: time('window_end'),
      status: (row['status'] ?? payload['status']).toString(),
      value: _finite(row['value'] ?? payload['value']),
      unit: (row['unit'] ?? payload['unit']).toString(),
      confidence: _finite(row['confidence'] ?? payload['confidence']) ?? 0,
      signalQuality:
          _finite(row['signal_quality'] ?? payload['signal_quality']) ?? 0,
      coverageRatio:
          _finite(row['coverage_ratio'] ?? payload['coverage_ratio']) ?? 0,
      qualityFlag: (row['quality_flag'] ?? payload['quality_flag']).toString(),
      conflictFlag: _bool(row['conflict_flag'] ?? payload['conflict_flag']),
      abstainReason: (row['abstain_reason'] ?? payload['abstain_reason'])
          ?.toString(),
      algorithmVersion:
          (row['algorithm_version'] ?? payload['algorithm_version']).toString(),
      inputFingerprint:
          (row['input_fingerprint'] ?? payload['input_fingerprint']).toString(),
      dataOrigin: (row['data_origin'] ?? payload['data_origin'] ?? 'REAL')
          .toString(),
      payload: payload,
    );
  }

  Map<String, Object?> toLocalMap() => {
    'id': id,
    'metric_type': metricType,
    'window_start': windowStart.millisecondsSinceEpoch,
    'window_end': windowEnd.millisecondsSinceEpoch,
    'status': status,
    'value': value,
    'interval_lower': payload['interval_lower'],
    'interval_upper': payload['interval_upper'],
    'unit': unit,
    'confidence': confidence,
    'signal_quality': signalQuality,
    'coverage_ratio': coverageRatio,
    'quality_flag': qualityFlag,
    'conflict_flag': conflictFlag,
    'coverage_mask_json': canonicalJson(payload['coverage_mask'] ?? const {}),
    'contributors_json': canonicalJson(
      payload['contributing_sources'] ?? const [],
    ),
    'evidence_json': canonicalJson(payload['evidence'] ?? const {}),
    'wear_state': payload['wear_state'],
    'abstain_reason': abstainReason,
    'algorithm_version': algorithmVersion,
    'input_fingerprint': inputFingerprint,
    'data_origin': dataOrigin,
    'payload_json': canonicalJson(payload),
  };
}

class PhoneHealthTag {
  const PhoneHealthTag({
    required this.tagType,
    required this.tagKey,
    required this.tagValue,
    required this.weight,
    required this.confidence,
    required this.validFrom,
    required this.validTo,
    required this.evidence,
    required this.inputFingerprint,
    required this.demoBaseline,
    required this.dataOrigin,
  });

  final String tagType;
  final String tagKey;
  final Map<String, Object?> tagValue;
  final double weight;
  final double confidence;
  final DateTime validFrom;
  final DateTime? validTo;
  final Map<String, Object?> evidence;
  final String inputFingerprint;
  final bool demoBaseline;
  final String dataOrigin;

  Map<String, Object?> toPayload() => {
    'tag_type': tagType,
    'tag_key': tagKey,
    'tag_value': tagValue,
    'weight': weight,
    'confidence': confidence,
    'source': phoneHealthModelVersion,
    'valid_from': pythonIso(validFrom),
    'valid_to': validTo == null ? null : pythonIso(validTo!),
    'evidence': evidence,
    'input_fingerprint': inputFingerprint,
    'demo_baseline': demoBaseline,
    'data_origin': dataOrigin,
  };

  Map<String, Object?> toLocalMap(String runId) {
    final payload = toPayload();
    return {
      'id': deterministicUuid('tag:$inputFingerprint'),
      'run_id': runId,
      'tag_key': tagKey,
      'tag_type': tagType,
      'tag_value_json': canonicalJson(tagValue),
      'evidence_json': canonicalJson(evidence),
      'weight': weight,
      'confidence': confidence,
      'valid_from': validFrom.millisecondsSinceEpoch,
      'valid_to': validTo?.millisecondsSinceEpoch,
      'model_version': phoneHealthModelVersion,
      'policy_version': phoneHealthPolicyVersion,
      'input_fingerprint': inputFingerprint,
      'demo_baseline': demoBaseline,
      'data_origin': dataOrigin,
      'payload_json': canonicalJson(payload),
    };
  }
}

class PhoneMetricState {
  PhoneMetricState({this.metricType = ''});

  final String metricType;
  int count = 0;
  DateTime? firstAt;
  DateTime? latestAt;
  double mean = 0;
  double m2 = 0;
  double? ewMean;
  double? ewSquareMean;
  int elevatedRun = 0;
  int suppressedRun = 0;
  final AdaptiveWindowDetector detector = AdaptiveWindowDetector();

  double? deviationBeforeUpdate(double value) {
    if (count < 2) return null;
    final variance = m2 / (count - 1);
    if (variance <= 0 || !variance.isFinite) return null;
    return (value - mean) / math.sqrt(variance);
  }

  void observeDirection(double? deviation, {double threshold = 1.5}) {
    if (deviation != null && deviation >= threshold) {
      elevatedRun += 1;
      suppressedRun = 0;
    } else if (deviation != null && deviation <= -threshold) {
      suppressedRun += 1;
      elevatedRun = 0;
    } else {
      elevatedRun = 0;
      suppressedRun = 0;
    }
  }

  bool update(double value, DateTime at) {
    firstAt ??= at;
    latestAt = at;
    count += 1;
    final delta = value - mean;
    mean += delta / count;
    m2 += delta * (value - mean);
    ewMean = ewMean == null ? value : 0.25 * value + 0.75 * ewMean!;
    ewSquareMean = ewSquareMean == null
        ? value * value
        : 0.25 * value * value + 0.75 * ewSquareMean!;
    return detector.update(value);
  }

  double? get ewVariance {
    if (ewMean == null || ewSquareMean == null) return null;
    return math.max(0, ewSquareMean! - ewMean! * ewMean!);
  }

  Map<String, Object?> toLocalMap(String runId) {
    final payload = <String, Object?>{
      'metric_type': metricType,
      'count': count,
      'first_at': firstAt == null ? null : pythonIso(firstAt!),
      'latest_at': latestAt == null ? null : pythonIso(latestAt!),
      'mean': mean,
      'm2': m2,
      'ew_mean': ewMean,
      'ew_variance': ewVariance,
      'adwin': detector.toJson(),
      'elevated_run': elevatedRun,
      'suppressed_run': suppressedRun,
    };
    return {
      'run_id': runId,
      'metric_type': metricType,
      'sample_count': count,
      'first_at': firstAt?.millisecondsSinceEpoch,
      'latest_at': latestAt?.millisecondsSinceEpoch,
      'mean_value': mean,
      'm2': m2,
      'ew_mean': ewMean,
      'ew_variance': ewVariance,
      'adwin_state_json': canonicalJson(detector.toJson()),
      'elevated_run': elevatedRun,
      'suppressed_run': suppressedRun,
      'payload_json': canonicalJson(payload),
    };
  }
}

class AdaptiveWindowDetector {
  AdaptiveWindowDetector({
    this.delta = 0.002,
    this.clock = 32,
    this.minWindowLength = 5,
    this.gracePeriod = 30,
  });

  final double delta;
  final int clock;
  final int minWindowLength;
  final int gracePeriod;
  final List<double> _window = [];
  int detections = 0;
  int updates = 0;
  bool _driftDetected = false;

  int get width => _window.length;

  bool update(double value) {
    // River resets ADWIN on the update immediately following a detection.
    if (_driftDetected) {
      _window.clear();
      _driftDetected = false;
    }
    _window.add(value);
    updates += 1;
    if (_window.length < gracePeriod || updates % clock != 0) return false;
    var detected = false;
    while (_window.length >= minWindowLength * 2) {
      final variance = _variance(_window);
      var cut = -1;
      for (
        var index = minWindowLength;
        index <= _window.length - minWindowLength;
        index++
      ) {
        final left = _window.sublist(0, index);
        final right = _window.sublist(index);
        final m =
            1 / (left.length - minWindowLength + 1) +
            1 / (right.length - minWindowLength + 1);
        final logWidth = math.log(math.max(2, _window.length));
        final dd = math.log(2 * math.log(math.max(math.e, logWidth)) / delta);
        final epsilon = math.sqrt(2 * m * variance * dd) + 2 * dd * m / 3;
        if ((_mean(left) - _mean(right)).abs() > epsilon) {
          cut = index;
          break;
        }
      }
      if (cut < 0) break;
      _window.removeRange(0, cut);
      detected = true;
      detections += 1;
    }
    _driftDetected = detected;
    return detected;
  }

  Map<String, Object?> toJson() => {
    'delta': delta,
    'clock': clock,
    'min_window_length': minWindowLength,
    'grace_period': gracePeriod,
    'width': width,
    'detections': detections,
    'updates': updates,
    'drift_detected': _driftDetected,
    'window': _window,
  };

  static double _mean(List<double> values) =>
      values.fold<double>(0, (sum, value) => sum + value) / values.length;

  static double _variance(List<double> values) {
    if (values.length < 2) return 0;
    final mean = _mean(values);
    return values.fold<double>(
          0,
          (sum, value) => sum + math.pow(value - mean, 2),
        ) /
        (values.length - 1);
  }
}

class PhoneAnalysisResult {
  const PhoneAnalysisResult({
    required this.analysisId,
    required this.memberId,
    required this.asOf,
    required this.inputCount,
    required this.acceptedCount,
    required this.tags,
    required this.states,
    required this.inputFingerprint,
    required this.dataOrigin,
  });

  final String analysisId;
  final String memberId;
  final DateTime asOf;
  final int inputCount;
  final int acceptedCount;
  final List<PhoneHealthTag> tags;
  final List<PhoneMetricState> states;
  final String inputFingerprint;
  final String dataOrigin;

  Map<String, Object?> toPayload() => {
    'analysis_id': analysisId,
    'member_id': memberId,
    'model_version': phoneHealthModelVersion,
    'policy_version': phoneHealthPolicyVersion,
    'as_of': pythonIso(asOf),
    'input_count': inputCount,
    'accepted_count': acceptedCount,
    'tags': tags.map((item) => item.toPayload()).toList(),
    'input_fingerprint': inputFingerprint,
    'data_origin': dataOrigin,
  };

  Map<String, Object?> toLocalRun() {
    final payload = toPayload();
    return {
      'id': analysisId,
      'as_of': asOf.millisecondsSinceEpoch,
      'input_count': inputCount,
      'accepted_count': acceptedCount,
      'model_version': phoneHealthModelVersion,
      'policy_version': phoneHealthPolicyVersion,
      'input_fingerprint': inputFingerprint,
      'status': tags.any((tag) => tag.tagKey == 'data_insufficient')
          ? 'INSUFFICIENT'
          : 'READY',
      'payload_json': canonicalJson(payload),
    };
  }
}

class PhoneHealthAnalyzer {
  const PhoneHealthAnalyzer();

  static const _units = {
    'heart_rate': 'bpm',
    'hrv': 'ms',
    'respiratory_rate': 'breaths/min',
  };
  static const _directionTags = {
    'heart_rate:elevated': 'relative_hr_elevated',
    'heart_rate:suppressed': 'relative_hr_suppressed',
    'respiratory_rate:elevated': 'relative_resp_rate_elevated',
    'hrv:suppressed': 'relative_hrv_suppressed',
  };

  PhoneAnalysisResult analyze(
    String memberId,
    DateTime asOf,
    List<PhoneFusedMetric> rows,
  ) {
    final utcAsOf = asOf.toUtc();
    final ordered =
        rows.where((row) => !row.windowEnd.isAfter(utcAsOf)).toList()
          ..sort((left, right) {
            final time = left.windowStart.compareTo(right.windowStart);
            if (time != 0) return time;
            final metric = left.metricType.compareTo(right.metricType);
            return metric != 0 ? metric : left.id.compareTo(right.id);
          });
    final states = <String, PhoneMetricState>{};
    final tags = <String, PhoneHealthTag>{};
    final conflicts = <String>[];
    var accepted = 0;
    var rejected = 0;
    DateTime? latestEnd;
    var origin = ordered.isEmpty ? 'SIMULATION_ONLY' : 'REAL';

    for (final row in ordered) {
      if (row.dataOrigin == 'SIMULATION_ONLY') origin = 'SIMULATION_ONLY';
      if (latestEnd == null || row.windowEnd.isAfter(latestEnd))
        latestEnd = row.windowEnd;
      final reasons = qualityReasons(row);
      if (reasons.isNotEmpty) {
        rejected += 1;
        if (reasons.contains('SOURCE_CONFLICT')) conflicts.add(row.id);
        continue;
      }
      accepted += 1;
      final value = row.value!;
      final state = states.putIfAbsent(
        row.metricType,
        () => PhoneMetricState(metricType: row.metricType),
      );
      final span = state.firstAt == null
          ? Duration.zero
          : row.windowStart.difference(state.firstAt!);
      final baselineReady =
          state.count >= 12 && span >= const Duration(hours: 2);
      final demoBaseline =
          baselineReady &&
          !(state.count >= 30 && span >= const Duration(hours: 24));
      final deviation = baselineReady
          ? state.deviationBeforeUpdate(value)
          : null;
      state.observeDirection(deviation);
      final confidence = math.min(
        row.confidence,
        math.min(row.signalQuality, row.coverageRatio),
      );
      String? direction;
      var persistence = 0;
      if (state.elevatedRun >= 3) {
        direction = 'elevated';
        persistence = state.elevatedRun;
      } else if (state.suppressedRun >= 3) {
        direction = 'suppressed';
        persistence = state.suppressedRun;
      }
      final tagKey = direction == null
          ? null
          : _directionTags['${row.metricType}:$direction'];
      if (tagKey != null && deviation != null) {
        tags[tagKey] = _tag(
          key: tagKey,
          category: 'state',
          value: {
            'active': true,
            'deviation': _round6(deviation),
            'persistence': persistence,
          },
          confidence: confidence,
          at: row.windowEnd,
          validFor: Duration(hours: row.metricType == 'hrv' ? 4 : 2),
          evidence: {
            'l0_ids': [row.id],
            'metric_type': row.metricType,
            'quality_policy': 'l0-quality-v1',
            'baseline_count': state.count,
          },
          demoBaseline: demoBaseline,
          dataOrigin: origin,
        );
      }
      final drift = state.update(value, row.windowStart);
      if (drift && state.count >= 30) {
        tags['distribution_shift_observed'] = _tag(
          key: 'distribution_shift_observed',
          category: 'causal_response',
          value: {'active': true, 'metric_type': row.metricType},
          confidence: confidence,
          at: row.windowEnd,
          validFor: const Duration(hours: 4),
          evidence: {
            'l0_ids': [row.id],
            'detector': 'ADWIN',
            'width': state.detector.width,
          },
          dataOrigin: origin,
        );
      }
    }

    final anyReady = states.values.any(
      (state) =>
          state.count >= 12 &&
          state.firstAt != null &&
          latestEnd != null &&
          latestEnd!.difference(state.firstAt!) >= const Duration(hours: 2),
    );
    if (!anyReady) {
      tags['data_insufficient'] = _tag(
        key: 'data_insufficient',
        category: 'state',
        value: {
          'active': true,
          'accepted_count': accepted,
          'required_count': 12,
        },
        confidence: 1,
        at: utcAsOf,
        evidence: {'input_count': ordered.length, 'accepted_count': accepted},
        dataOrigin: origin,
      );
    }
    if (ordered.isNotEmpty && rejected / ordered.length >= 0.40) {
      tags['low_data_coverage'] = _tag(
        key: 'low_data_coverage',
        category: 'state',
        value: {
          'active': true,
          'rejected_ratio': _round6(rejected / ordered.length),
        },
        confidence: math.min(1, rejected / ordered.length),
        at: utcAsOf,
        validFor: const Duration(hours: 2),
        evidence: {'input_count': ordered.length, 'rejected_count': rejected},
        dataOrigin: origin,
      );
    }
    if (conflicts.isNotEmpty) {
      tags['source_conflict_observed'] = _tag(
        key: 'source_conflict_observed',
        category: 'state',
        value: {'active': true, 'count': conflicts.length},
        confidence: 1,
        at: utcAsOf,
        validFor: const Duration(hours: 2),
        evidence: {'l0_ids': conflicts},
        dataOrigin: origin,
      );
    }
    if (latestEnd == null ||
        utcAsOf.difference(latestEnd!) > const Duration(hours: 2)) {
      tags['measurement_stale'] = _tag(
        key: 'measurement_stale',
        category: 'state',
        value: {'active': true},
        confidence: 1,
        at: utcAsOf,
        validFor: const Duration(hours: 2),
        evidence: {
          'latest_window_end': latestEnd == null ? null : pythonIso(latestEnd!),
        },
        dataOrigin: origin,
      );
    }
    final inputFingerprint = sha256Hex(
      ordered
          .map(
            (row) => {
              'id': row.id,
              'input_fingerprint': row.inputFingerprint,
              'window_start': pythonIso(row.windowStart),
            },
          )
          .toList(),
    );
    final analysisId = deterministicUuid(
      '$memberId:${pythonIso(utcAsOf)}:$inputFingerprint',
    );
    final sortedTags = tags.values.toList()
      ..sort((left, right) => left.tagKey.compareTo(right.tagKey));
    final sortedStates = states.values.toList()
      ..sort((left, right) => left.metricType.compareTo(right.metricType));
    return PhoneAnalysisResult(
      analysisId: analysisId,
      memberId: memberId,
      asOf: utcAsOf,
      inputCount: ordered.length,
      acceptedCount: accepted,
      tags: sortedTags,
      states: sortedStates,
      inputFingerprint: inputFingerprint,
      dataOrigin: origin,
    );
  }

  List<String> qualityReasons(PhoneFusedMetric row) {
    final reasons = <String>[];
    if (row.status != 'AVAILABLE') reasons.add('STATUS_NOT_AVAILABLE');
    if (row.value == null || !row.value!.isFinite)
      reasons.add('VALUE_NOT_FINITE');
    if (!{'good', 'degraded'}.contains(row.qualityFlag))
      reasons.add('QUALITY_POOR');
    if (row.confidence < 0.60 || row.confidence > 1)
      reasons.add('CONFIDENCE_LOW');
    if (row.signalQuality < 0.50 || row.signalQuality > 1)
      reasons.add('SIGNAL_QUALITY_LOW');
    if (row.coverageRatio < 0.60 || row.coverageRatio > 1)
      reasons.add('COVERAGE_LOW');
    if (row.conflictFlag) reasons.add('SOURCE_CONFLICT');
    if (_units[row.metricType] != row.unit) reasons.add('UNIT_UNSUPPORTED');
    return reasons;
  }

  PhoneHealthTag _tag({
    required String key,
    required String category,
    required Map<String, Object?> value,
    required double confidence,
    required DateTime at,
    Duration? validFor,
    required Map<String, Object?> evidence,
    bool demoBaseline = false,
    required String dataOrigin,
  }) {
    final payload = {
      'key': key,
      'value': value,
      'at': pythonIso(at),
      'evidence': evidence,
      'policy': phoneHealthPolicyVersion,
    };
    final bounded = confidence.clamp(0.0, 1.0).toDouble();
    return PhoneHealthTag(
      tagType: category,
      tagKey: key,
      tagValue: value,
      weight: bounded,
      confidence: bounded,
      validFrom: at.toUtc(),
      validTo: validFor == null ? null : at.toUtc().add(validFor),
      evidence: evidence,
      inputFingerprint: sha256Hex(payload),
      demoBaseline: demoBaseline,
      dataOrigin: dataOrigin,
    );
  }
}

double? _finite(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return number?.isFinite == true ? number : null;
}

bool _bool(Object? value) => value == true || (value is num && value != 0);
double _round6(double value) => double.parse(value.toStringAsFixed(6));

Map<String, Object?>? _decodeMap(Object? value) {
  if (value is Map)
    return value.map((key, item) => MapEntry(key.toString(), item));
  if (value is! String || value.isEmpty) return null;
  final decoded = jsonDecode(value);
  return decoded is Map
      ? decoded.map((key, item) => MapEntry(key.toString(), item))
      : null;
}
