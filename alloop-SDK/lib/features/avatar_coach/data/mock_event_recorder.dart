import '../domain/models/avatar_coach_view_model.dart';

enum MockAvatarCoachEventType {
  coachMessageShown,
  taskCompleted,
  taskSnoozed,
  taskMissed,
  taskDeclined,
  mockFollowUpReceived,
  avatarStateChanged,
}

class MockAvatarCoachEvent {
  const MockAvatarCoachEvent({
    required this.type,
    required this.scenarioId,
    required this.taskId,
    required this.avatarState,
    required this.affectedMetrics,
    required this.occurredAt,
  });

  final MockAvatarCoachEventType type;
  final String scenarioId;
  final String taskId;
  final AvatarState avatarState;
  final Set<HealthMetricType> affectedMetrics;
  final DateTime occurredAt;
}

class MockEventRecorder {
  final List<MockAvatarCoachEvent> _events = [];

  List<MockAvatarCoachEvent> get events => List.unmodifiable(_events);

  void record(MockAvatarCoachEvent event) => _events.add(event);

  int count(MockAvatarCoachEventType type) =>
      _events.where((event) => event.type == type).length;

  void clear() => _events.clear();
}
