import 'avatar_coach_view_model.dart';
import 'mock_health_snapshot.dart';

enum MockScenarioId {
  normal,
  happy,
  sleepy,
  stressed,
  inactive,
  recovery,
  warning,
  completedBoost,
}

extension MockScenarioIdWireName on MockScenarioId {
  String get wireName => switch (this) {
    MockScenarioId.completedBoost => 'mock_completed_boost',
    _ => 'mock_$name',
  };
}

class MockAvatarCoachScenario {
  const MockAvatarCoachScenario({
    required this.id,
    required this.initialSnapshot,
    required this.taskId,
    required this.taskTitle,
    required this.coachSeverity,
    required this.coachSeverityLabel,
    required this.coachMessage,
    required this.targetMetrics,
    required this.completedDelta,
    required this.missedDelta,
    required this.completedStateTags,
    required this.missedStateTags,
    required this.completionFeedback,
    this.warning = false,
  });

  final MockScenarioId id;
  final MockHealthSnapshot initialSnapshot;
  final String taskId;
  final String taskTitle;
  final CoachSeverity coachSeverity;
  final String coachSeverityLabel;
  final String coachMessage;
  final Set<HealthMetricType> targetMetrics;
  final Map<HealthMetricType, int> completedDelta;
  final Map<HealthMetricType, int> missedDelta;
  final Set<String> completedStateTags;
  final Set<String> missedStateTags;
  final String completionFeedback;
  final bool warning;

  MockHealthSnapshot completedSnapshot(MockHealthSnapshot source) =>
      source.applyDeltas(completedDelta, nextStateTags: completedStateTags);

  MockHealthSnapshot missedSnapshot(MockHealthSnapshot source) =>
      source.applyDeltas(missedDelta, nextStateTags: missedStateTags);
}
