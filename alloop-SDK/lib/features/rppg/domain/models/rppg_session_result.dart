class RppgEstimateSample {
  const RppgEstimateSample({
    required this.timestamp,
    required this.heartRate,
    required this.heartRateConfidence,
    required this.respiratoryRate,
    required this.respiratoryRateConfidence,
    required this.aggregateQuality,
    this.scheduledSecond,
  });

  final DateTime timestamp;
  final double? heartRate;
  final double heartRateConfidence;
  final double? respiratoryRate;
  final double respiratoryRateConfidence;
  final double aggregateQuality;
  final int? scheduledSecond;

  factory RppgEstimateSample.fromPlatform(Object? value) {
    final map = _stringKeyMap(value, 'estimate sample');
    return RppgEstimateSample(
      timestamp: _dateTime(map['timestamp'], 'timestamp'),
      heartRate: _nullableDouble(map['heartRate'], 'heartRate'),
      heartRateConfidence: _ratio(
        map['heartRateConfidence'],
        'heartRateConfidence',
      ),
      respiratoryRate: _nullableDouble(
        map['respiratoryRate'],
        'respiratoryRate',
      ),
      respiratoryRateConfidence: _ratio(
        map['respiratoryRateConfidence'],
        'respiratoryRateConfidence',
      ),
      aggregateQuality: _ratio(map['aggregateQuality'], 'aggregateQuality'),
      scheduledSecond: _nullableInt(map['scheduledSecond'], 'scheduledSecond'),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toUtc().toIso8601String(),
    'heartRate': heartRate,
    'heartRateConfidence': heartRateConfidence,
    'respiratoryRate': respiratoryRate,
    'respiratoryRateConfidence': respiratoryRateConfidence,
    'aggregateQuality': aggregateQuality,
    'scheduledSecond': scheduledSecond,
  };
}

class RppgEstimateSummary {
  const RppgEstimateSummary({
    required this.heartRate,
    required this.heartRateConfidence,
    required this.respiratoryRate,
    required this.respiratoryRateConfidence,
    required this.aggregateQuality,
  });

  final double? heartRate;
  final double heartRateConfidence;
  final double? respiratoryRate;
  final double respiratoryRateConfidence;
  final double aggregateQuality;

  factory RppgEstimateSummary.fromPlatform(Object? value) {
    final map = _stringKeyMap(value, 'estimate summary');
    return RppgEstimateSummary(
      heartRate: _nullableDouble(map['heartRate'], 'heartRate'),
      heartRateConfidence: _ratio(
        map['heartRateConfidence'],
        'heartRateConfidence',
      ),
      respiratoryRate: _nullableDouble(
        map['respiratoryRate'],
        'respiratoryRate',
      ),
      respiratoryRateConfidence: _ratio(
        map['respiratoryRateConfidence'],
        'respiratoryRateConfidence',
      ),
      aggregateQuality: _ratio(map['aggregateQuality'], 'aggregateQuality'),
    );
  }

  Map<String, dynamic> toJson() => {
    'heartRate': heartRate,
    'heartRateConfidence': heartRateConfidence,
    'respiratoryRate': respiratoryRate,
    'respiratoryRateConfidence': respiratoryRateConfidence,
    'aggregateQuality': aggregateQuality,
  };
}

class RppgSessionResult {
  const RppgSessionResult({
    required this.sessionId,
    required this.startedAt,
    required this.completedAt,
    required this.source,
    required this.deviceId,
    required this.schemaVersion,
    required this.completionReason,
    required this.demoOnly,
    required this.estimateSamples,
    required this.summary,
    this.message,
  });

  static const String expectedSource = 'rppg_phone';

  final String sessionId;
  final DateTime startedAt;
  final DateTime completedAt;
  final String source;
  final String deviceId;
  final int schemaVersion;
  final String completionReason;
  final bool demoOnly;
  final List<RppgEstimateSample> estimateSamples;
  final RppgEstimateSummary summary;
  final String? message;

  bool get completed => completionReason == 'completed';
  bool get cancelled => completionReason == 'cancelled';
  bool get error => completionReason == 'error';

  factory RppgSessionResult.fromPlatform(Object? value) {
    final map = _stringKeyMap(value, 'rPPG session result');
    final source = _requiredString(map['source'], 'source');
    final demoOnly = map['demoOnly'] == true;
    if (source != expectedSource) {
      throw FormatException('Unexpected rPPG source: $source');
    }
    if (demoOnly) {
      throw const FormatException(
        'Demo rPPG payloads are not real session DTOs',
      );
    }
    final samples = (map['estimateSamples'] as List? ?? const <Object?>[])
        .map(RppgEstimateSample.fromPlatform)
        .toList(growable: false);
    return RppgSessionResult(
      sessionId: _requiredString(map['sessionId'], 'sessionId'),
      startedAt: _dateTime(map['startedAt'], 'startedAt'),
      completedAt: _dateTime(map['completedAt'], 'completedAt'),
      source: source,
      deviceId: _requiredString(map['deviceId'], 'deviceId'),
      schemaVersion: _requiredInt(map['schemaVersion'], 'schemaVersion'),
      completionReason: _requiredString(
        map['completionReason'],
        'completionReason',
      ),
      demoOnly: demoOnly,
      estimateSamples: samples,
      summary: RppgEstimateSummary.fromPlatform(map['summary']),
      message: map['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'source': source,
    'deviceId': deviceId,
    'schemaVersion': schemaVersion,
    'completionReason': completionReason,
    'demoOnly': demoOnly,
    'estimateSamples': estimateSamples
        .map((sample) => sample.toJson())
        .toList(),
    'summary': summary.toJson(),
    'message': message,
  };
}

Map<String, Object?> _stringKeyMap(Object? value, String label) {
  if (value is! Map) throw FormatException('Expected $label map');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredString(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Missing $field');
}

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Missing $field');
}

int? _nullableInt(Object? value, String field) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Invalid $field');
}

double? _nullableDouble(Object? value, String field) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('Invalid $field');
}

double _ratio(Object? value, String field) {
  final parsed = _nullableDouble(value, field) ?? 0.0;
  if (parsed < 0 || parsed > 1) {
    throw FormatException('$field must be in [0, 1]');
  }
  return parsed;
}

DateTime _dateTime(Object? value, String field) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  throw FormatException('Missing $field');
}
