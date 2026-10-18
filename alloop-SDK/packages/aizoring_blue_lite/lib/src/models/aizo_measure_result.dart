/// Authoritative instant-measurement codes exposed by the AIZORING SDK.
class AizoInstantMeasurementType {
  AizoInstantMeasurementType._();

  static const int heartRate = 0x01;
  static const int bloodOxygen = 0x02;
  static const int temperature = 0x03;
  static const int stress = 0x04;
  static const int uvIndex = 0x05;
  static const int bloodPressure = 0x06;
}

/// Result from an instant (single-shot) measurement on the AIZORING ring.
class AizoMeasureResult {
  /// Measurement type code (e.g. 0x01 for HR).
  final int type;

  /// Result code from the SDK.
  final int result;

  /// Unix timestamp of the measurement.
  final int timestamp;

  /// Heart rate in bpm.
  final int? heartRate;

  /// Blood oxygen saturation in %.
  final int? bloodOxygen;

  /// Body temperature in Celsius.
  final double? bodyTemp;

  /// Environmental temperature in Celsius.
  final double? envTemp;

  /// Stress/pressure level.
  final int? stress;

  /// UV index.
  final int? uvi;

  /// Blood pressure value (if supported).
  final int? bloodPressure;

  const AizoMeasureResult({
    this.type = 0,
    this.result = 0,
    this.timestamp = 0,
    this.heartRate,
    this.bloodOxygen,
    this.bodyTemp,
    this.envTemp,
    this.stress,
    this.uvi,
    this.bloodPressure,
  });

  factory AizoMeasureResult.fromMap(Map<dynamic, dynamic> map) {
    return AizoMeasureResult(
      type: _toInt(map['type']) ?? 0,
      result: _toInt(map['result']) ?? 0,
      timestamp: _toInt(map['timestamp']) ?? 0,
      heartRate: _toInt(map['heartRate']),
      bloodOxygen: _toInt(map['bloodOxygen']),
      bodyTemp: _toDouble(map['bodyTemp']),
      envTemp: _toDouble(map['envTemp']),
      stress: _toInt(map['stress']),
      uvi: _toInt(map['uvi']),
      bloodPressure: _toInt(map['bloodPressure']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is bool) return v ? 1 : 0;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Human-readable label for the measurement type.
  String get typeLabel {
    switch (type) {
      case AizoInstantMeasurementType.heartRate:
        return 'Heart Rate';
      case AizoInstantMeasurementType.bloodOxygen:
        return 'Blood Oxygen';
      case AizoInstantMeasurementType.temperature:
        return 'Temperature';
      case AizoInstantMeasurementType.stress:
        return 'Stress';
      case AizoInstantMeasurementType.uvIndex:
        return 'UV Index';
      case AizoInstantMeasurementType.bloodPressure:
        return 'Blood Pressure';
      default:
        return 'Unknown (0x${type.toRadixString(16)})';
    }
  }

  @override
  String toString() =>
      'AizoMeasureResult(type: $typeLabel, hr: $heartRate, spo2: $bloodOxygen, temp: $bodyTemp)';
}
