import 'dart:convert';

/// A sleep stage within a sleep record.
class SleepStage {
  /// Unix timestamp of this stage transition.
  final int time;

  /// Stage type: 1=awake, 2=light, 3=REM, 5=deep.
  final int stageType;

  const SleepStage({required this.time, required this.stageType});

  factory SleepStage.fromMap(Map<dynamic, dynamic> map) {
    return SleepStage(
      time: map['time'] as int? ?? 0,
      stageType: map['stageType'] as int? ?? 0,
    );
  }

  /// Human-readable label for this stage.
  String get label {
    switch (stageType) {
      case 1:
        return 'Awake';
      case 2:
        return 'Light';
      case 3:
        return 'REM';
      case 5:
        return 'Deep';
      default:
        return 'Unknown';
    }
  }
}

/// A complete sleep record from the AIZORING ring.
class AizoSleepRecord {
  /// Unique sleep record ID.
  final int sleepId;

  /// Start time in unix seconds.
  final int startTime;

  /// End time in unix seconds.
  final int endTime;

  /// Total sleep duration in minutes.
  final int totalDuration;

  /// Deep sleep duration in minutes.
  final int deepDuration;

  /// Light sleep duration in minutes.
  final int lightDuration;

  /// REM sleep duration in minutes.
  final int remDuration;

  /// Awake duration in minutes.
  final int awakeDuration;

  /// Number of times awake.
  final int awakeTimes;

  /// Detailed sleep stages.
  final List<SleepStage> stages;

  const AizoSleepRecord({
    this.sleepId = 0,
    this.startTime = 0,
    this.endTime = 0,
    this.totalDuration = 0,
    this.deepDuration = 0,
    this.lightDuration = 0,
    this.remDuration = 0,
    this.awakeDuration = 0,
    this.awakeTimes = 0,
    this.stages = const [],
  });

  factory AizoSleepRecord.fromMap(Map<dynamic, dynamic> map) {
    final stagesList = map['stages'] as List<dynamic>? ?? [];
    return AizoSleepRecord(
      sleepId: map['sleepId'] as int? ?? 0,
      startTime: map['startTime'] as int? ?? 0,
      endTime: map['endTime'] as int? ?? 0,
      totalDuration: map['totalDuration'] as int? ?? 0,
      deepDuration: map['deepDuration'] as int? ?? 0,
      lightDuration: map['lightDuration'] as int? ?? 0,
      remDuration: map['remDuration'] as int? ?? 0,
      awakeDuration: map['awakeDuration'] as int? ?? 0,
      awakeTimes: map['awakeTimes'] as int? ?? 0,
      stages: stagesList
          .map((e) => SleepStage.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  /// Parse from a JSON string (used when native side passes raw JSON).
  static List<AizoSleepRecord> fromJsonString(String json) {
    final List<dynamic> decoded = jsonDecode(json);
    return decoded
        .map((e) => AizoSleepRecord.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() =>
      'AizoSleepRecord(start: $startTime, total: ${totalDuration}min, deep: ${deepDuration}min)';
}
