import 'dart:convert';

/// A single health data record from the AIZORING ring.
class AizoHealthData {
  /// Unix timestamp in seconds.
  final int timestamp;

  /// Heart rate in bpm.
  final int? heartRate;

  /// Blood oxygen in %.
  final int? bloodOxygen;

  /// Step count.
  final int? steps;

  /// Body temperature in Celsius.
  final double? bodyTemp;

  /// Environmental temperature in Celsius.
  final double? envTemp;

  /// Calories burned in kcal.
  final int? calories;

  /// Distance in meters.
  final int? distance;

  const AizoHealthData({
    this.timestamp = 0,
    this.heartRate,
    this.bloodOxygen,
    this.steps,
    this.bodyTemp,
    this.envTemp,
    this.calories,
    this.distance,
  });

  factory AizoHealthData.fromMap(Map<dynamic, dynamic> map) {
    return AizoHealthData(
      // Accept both camelCase Dart keys and raw fastjson keys from native
      timestamp: _toInt(map['timestamp'] ?? map['time']) ?? 0,
      heartRate: _toInt(map['heartRate'] ?? map['heartrate']),
      bloodOxygen: _toInt(map['bloodOxygen'] ?? map['bloodoxygen']),
      steps: _toInt(map['steps'] ?? map['step']),
      bodyTemp: _toDouble(map['bodyTemp'] ?? map['bodytemp']),
      envTemp: _toDouble(map['envTemp'] ?? map['envtemp']),
      calories: _toInt(map['calories'] ?? map['cal']),
      distance: _toInt(map['distance']),
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

  /// Convert to CSV row values.
  List<String> toCsvRow() {
    return [
      timestamp.toString(),
      heartRate?.toString() ?? '',
      bloodOxygen?.toString() ?? '',
      steps?.toString() ?? '',
      bodyTemp?.toString() ?? '',
      envTemp?.toString() ?? '',
      calories?.toString() ?? '',
      distance?.toString() ?? '',
    ];
  }

  /// Parse from a JSON string (used when native side passes raw JSON).
  static List<AizoHealthData> fromJsonString(String json) {
    final List<dynamic> decoded = jsonDecode(json);
    return decoded
        .map((e) => AizoHealthData.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static List<String> csvHeader() {
    return [
      'timestamp',
      'heartRate',
      'bloodOxygen',
      'steps',
      'bodyTemp',
      'envTemp',
      'calories',
      'distance',
    ];
  }

  @override
  String toString() =>
      'AizoHealthData(ts: $timestamp, hr: $heartRate, spo2: $bloodOxygen, steps: $steps)';
}
