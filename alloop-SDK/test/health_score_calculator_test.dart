import 'package:alloop/features/health_score/domain/health_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses local trends and separates voluntary action contribution', () {
    final now = DateTime(2026, 8, 3, 12);
    final previous = now.subtract(const Duration(days: 1));
    final readings = <Map<String, Object?>>[
      {
        'recorded_at': previous.millisecondsSinceEpoch,
        'is_valid': 1,
        'hrv': 45.0,
        'stress': 45.0,
        'steps': 4000,
      },
      {
        'recorded_at': now.millisecondsSinceEpoch,
        'is_valid': 1,
        'hrv': 50.0,
        'stress': 30.0,
        'steps': 6400,
      },
    ];

    final snapshot = HealthScoreCalculator.calculate(
      readings: readings,
      completedInterventions: {'sleep_routine', 'walk_break'},
      now: now,
    );

    expect(snapshot.bodyScore, 68);
    expect(snapshot.actionContribution, 4);
    expect(snapshot.score, 72);
    expect(snapshot.weekDelta, greaterThan(0));
    expect(snapshot.trend.where((point) => point.score != null), hasLength(2));
  });

  test('caps voluntary action contribution at six points', () {
    final now = DateTime(2026, 8, 3, 12);
    final snapshot = HealthScoreCalculator.calculate(
      readings: [
        {
          'recorded_at': now.millisecondsSinceEpoch,
          'is_valid': 1,
          'hrv': 80.0,
          'stress': 0.0,
          'steps': 8000,
        },
      ],
      completedInterventions: {
        'sleep_routine',
        'walk_break',
        'calm_break',
        'unknown_action',
      },
      now: now,
    );

    expect(snapshot.bodyScore, 100);
    expect(snapshot.actionContribution, 6);
    expect(snapshot.score, 100);
  });

  test('does not invent a score without local device readings', () {
    final snapshot = HealthScoreCalculator.calculate(
      readings: const [],
      completedInterventions: {'sleep_routine'},
      now: DateTime(2026, 8, 3),
    );

    expect(snapshot.hasDeviceData, isFalse);
    expect(snapshot.bodyScore, isNull);
    expect(snapshot.score, isNull);
    expect(snapshot.actionContribution, 2);
  });
}
