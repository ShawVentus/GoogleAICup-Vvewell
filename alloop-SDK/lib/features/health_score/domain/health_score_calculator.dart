import 'dart:math' as math;

/// A local wellness reference score. It is not a medical score or diagnosis.
/// Raw device signals and voluntary action contributions remain separate.
class HealthScoreSnapshot {
  const HealthScoreSnapshot({
    required this.score,
    required this.bodyScore,
    required this.actionContribution,
    required this.weekDelta,
    required this.trend,
  });

  final int? score;
  final int? bodyScore;
  final int actionContribution;
  final int? weekDelta;
  final List<HealthScorePoint> trend;

  bool get hasDeviceData => bodyScore != null;
}

class HealthScorePoint {
  const HealthScorePoint({required this.day, this.score});

  final DateTime day;
  final int? score;
}

class HealthIntervention {
  const HealthIntervention({
    required this.id,
    required this.title,
    required this.detail,
    required this.estimatedContribution,
  });

  final String id;
  final String title;
  final String detail;
  final int estimatedContribution;
}

abstract final class HealthScoreCalculator {
  static const interventions = <HealthIntervention>[
    HealthIntervention(
      id: 'sleep_routine',
      title: '固定今晚的入睡时间',
      detail: '睡前 30 分钟减少屏幕使用',
      estimatedContribution: 2,
    ),
    HealthIntervention(
      id: 'walk_break',
      title: '完成 10 分钟轻松步行',
      detail: '久坐后起身活动，量力而行',
      estimatedContribution: 2,
    ),
    HealthIntervention(
      id: 'calm_break',
      title: '进行 3 分钟放松练习',
      detail: '呼吸或短暂休息都可以',
      estimatedContribution: 2,
    ),
  ];

  static HealthScoreSnapshot calculate({
    required List<Map<String, Object?>> readings,
    required Set<String> completedInterventions,
    DateTime? now,
  }) {
    final today = _day(now ?? DateTime.now());
    final days = List<DateTime>.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    final grouped = <DateTime, List<Map<String, Object?>>>{
      for (final day in days) day: <Map<String, Object?>>[],
    };

    for (final row in readings) {
      if (_asInt(row['is_valid']) == 0) continue;
      final timestamp = _asInt(row['recorded_at']);
      if (timestamp == null) continue;
      final day = _day(
        DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal(),
      );
      grouped[day]?.add(row);
    }

    final daily = <DateTime, _DailyScore>{
      for (final day in days) day: _scoreDay(grouped[day]!),
    };
    final scoredDays = days
        .map((day) => daily[day]!)
        .where((value) => value.score != null)
        .toList();
    final latest = scoredDays.isEmpty ? null : scoredDays.last;
    final previous = scoredDays.length < 2
        ? null
        : scoredDays[scoredDays.length - 2];
    final contribution = interventions
        .where((item) => completedInterventions.contains(item.id))
        .fold<int>(0, (total, item) => total + item.estimatedContribution)
        .clamp(0, 6);
    final bodyScore = latest?.score;
    final score = bodyScore == null
        ? null
        : math.min(100, bodyScore + contribution);
    final latestIndex = days.lastIndexWhere((day) => daily[day]!.score != null);
    final trend = days.indexed.map((entry) {
      final raw = daily[entry.$2]!.score;
      final adjusted = entry.$1 == latestIndex && raw != null
          ? math.min(100, raw + contribution)
          : raw;
      return HealthScorePoint(day: entry.$2, score: adjusted);
    }).toList();

    return HealthScoreSnapshot(
      score: score,
      bodyScore: bodyScore,
      actionContribution: contribution,
      weekDelta: score == null || previous?.score == null
          ? null
          : score - previous!.score!,
      trend: trend,
    );
  }

  static _DailyScore _scoreDay(List<Map<String, Object?>> rows) {
    double? average(String key) {
      final values = rows.map((row) => _asDouble(row[key])).whereType<double>();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final hrv = average('hrv');
    final stress = average('stress');
    final steps = average('steps');
    final values = <int?>[
      hrv == null ? null : _rangeScore(hrv, low: 15, high: 80),
      stress == null ? null : 100 - _rangeScore(stress, low: 0, high: 100),
      steps == null ? null : _rangeScore(steps, low: 0, high: 8000),
    ].whereType<int>().toList();
    final score = values.isEmpty
        ? null
        : (values.reduce((a, b) => a + b) / values.length).round();
    return _DailyScore(score);
  }

  static int _rangeScore(
    double value, {
    required double low,
    required double high,
  }) => (((value - low) / (high - low)).clamp(0, 1) * 100).round();

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int? _asInt(Object? value) => (value as num?)?.toInt();
  static double? _asDouble(Object? value) => (value as num?)?.toDouble();
}

class _DailyScore {
  const _DailyScore(this.score);

  final int? score;
}
