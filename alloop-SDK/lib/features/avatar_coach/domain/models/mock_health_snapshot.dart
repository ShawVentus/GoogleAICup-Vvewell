import 'avatar_coach_view_model.dart';

class MockHealthSnapshot {
  const MockHealthSnapshot({
    required this.scenarioId,
    required this.health,
    required this.vitality,
    required this.mental,
    required this.stateTags,
    required this.movementRating,
    required this.movementRawValue,
  });

  final String scenarioId;
  final int health;
  final int vitality;
  final int mental;
  final Set<String> stateTags;
  final MovementRating movementRating;
  final int movementRawValue;

  int valueFor(HealthMetricType metric) => switch (metric) {
    HealthMetricType.health => health,
    HealthMetricType.vitality => vitality,
    HealthMetricType.mental => mental,
  };

  MockHealthSnapshot applyDeltas(
    Map<HealthMetricType, int> deltas, {
    required Set<String> nextStateTags,
  }) {
    int next(HealthMetricType metric) =>
        (valueFor(metric) + (deltas[metric] ?? 0)).clamp(0, 100);

    return MockHealthSnapshot(
      scenarioId: scenarioId,
      health: next(HealthMetricType.health),
      vitality: next(HealthMetricType.vitality),
      mental: next(HealthMetricType.mental),
      stateTags: nextStateTags,
      movementRating: movementRating,
      movementRawValue: movementRawValue,
    );
  }

  MockHealthSnapshot copyWith({
    String? scenarioId,
    int? health,
    int? vitality,
    int? mental,
    Set<String>? stateTags,
    MovementRating? movementRating,
    int? movementRawValue,
  }) {
    return MockHealthSnapshot(
      scenarioId: scenarioId ?? this.scenarioId,
      health: health ?? this.health,
      vitality: vitality ?? this.vitality,
      mental: mental ?? this.mental,
      stateTags: stateTags ?? this.stateTags,
      movementRating: movementRating ?? this.movementRating,
      movementRawValue: movementRawValue ?? this.movementRawValue,
    );
  }
}
