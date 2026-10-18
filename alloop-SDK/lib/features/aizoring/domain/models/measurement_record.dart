import 'package:aizoring_blue_lite/aizoring_blue_lite.dart';

/// A locally saved measurement record with a timestamp.
class MeasurementRecord {
  /// Local save time (milliseconds since epoch).
  final int savedAt;

  /// The measurement result from the ring.
  final AizoMeasureResult result;

  const MeasurementRecord({required this.savedAt, required this.result});

  Map<String, dynamic> toMap() {
    return {
      'savedAt': savedAt,
      'type': result.type,
      'resultCode': result.result,
      'timestamp': result.timestamp,
      'heartRate': result.heartRate,
      'bloodOxygen': result.bloodOxygen,
      'bodyTemp': result.bodyTemp,
      'envTemp': result.envTemp,
      'stress': result.stress,
      'uvi': result.uvi,
    };
  }

  factory MeasurementRecord.fromMap(Map<dynamic, dynamic> map) {
    return MeasurementRecord(
      savedAt: map['savedAt'] as int? ?? 0,
      result: AizoMeasureResult(
        type: map['type'] as int? ?? 0,
        result: map['resultCode'] as int? ?? 0,
        timestamp: map['timestamp'] as int? ?? 0,
        heartRate: map['heartRate'] as int?,
        bloodOxygen: map['bloodOxygen'] as int?,
        bodyTemp: (map['bodyTemp'] as num?)?.toDouble(),
        envTemp: (map['envTemp'] as num?)?.toDouble(),
        stress: map['stress'] as int?,
        uvi: map['uvi'] as int?,
      ),
    );
  }

  /// Human-readable label for the measurement type.
  String get typeLabel {
    switch (result.type) {
      case AizoInstantMeasurementType.heartRate:
        return 'Heart Rate';
      case AizoInstantMeasurementType.bloodOxygen:
        return 'Blood Oxygen';
      case AizoInstantMeasurementType.temperature:
        return 'Temperature';
      default:
        return 'Unknown';
    }
  }

  /// Primary display value for this measurement type.
  String get displayValue {
    switch (result.type) {
      case AizoInstantMeasurementType.heartRate:
        return '${result.heartRate ?? '--'} bpm';
      case AizoInstantMeasurementType.bloodOxygen:
        return '${result.bloodOxygen ?? '--'} %';
      case AizoInstantMeasurementType.temperature:
        return '${result.bodyTemp?.toStringAsFixed(1) ?? '--'} °C';
      default:
        return '--';
    }
  }
}
