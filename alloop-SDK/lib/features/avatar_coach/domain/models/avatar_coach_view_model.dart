enum AvatarState {
  normal,
  happy,
  sleepy,
  stressed,
  inactive,
  recovery,
  warning,
  completedBoost,
}

enum AnimationState { idle, transitioning }

enum CoachSeverity { green, yellow, red }

enum AvatarCoachDataStatus { ready, loading, empty, error, fallback }

enum HealthMetricType { health, vitality, mental }

enum MovementRating { insufficient, average, sufficient, excessive }

enum MockTaskStatus { offered, snoozed, completed, missed, declined }

enum AvatarActionType {
  startTask,
  completeTask,
  snooze,
  swapTask,
  decline,
  dismiss,
  seekProfessionalHelp,
}

class HealthIndex {
  const HealthIndex({
    required this.metric,
    required this.label,
    required this.value,
    this.delta = 0,
  });

  final HealthMetricType metric;
  final String label;
  final int value;
  final int delta;
}

class SystemStatus {
  const SystemStatus({
    required this.label,
    required this.value,
    required this.severity,
    this.displayValue,
  });

  final String label;
  final int value;
  final CoachSeverity severity;
  final String? displayValue;
}

class BasicHealthMetric {
  const BasicHealthMetric({
    required this.label,
    required this.value,
    required this.severity,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final CoachSeverity severity;
}

class RiskDisplay {
  const RiskDisplay({
    required this.visible,
    required this.severity,
    required this.label,
    required this.message,
  });

  const RiskDisplay.hidden()
    : visible = false,
      severity = CoachSeverity.green,
      label = '',
      message = '';

  final bool visible;
  final CoachSeverity severity;
  final String label;
  final String message;
}

class AvatarAction {
  const AvatarAction({required this.type, required this.label});

  final AvatarActionType type;
  final String label;
}

class AvatarCoachViewModel {
  const AvatarCoachViewModel({
    required this.scenarioId,
    required this.taskId,
    required this.taskTitle,
    required this.targetMetrics,
    required this.avatarState,
    required this.avatarVariant,
    required this.animationState,
    required this.coachSeverity,
    required this.coachSeverityLabel,
    required this.coachMessage,
    required this.healthScore,
    required this.healthIndices,
    required this.systemStatuses,
    required this.basicHealthMetrics,
    required this.riskDisplay,
    required this.primaryAction,
    required this.secondaryActions,
    required this.dataStatus,
    required this.renderedAt,
    this.taskStatus = MockTaskStatus.offered,
    this.upstreamStateBeforeBoost,
    this.statusMessage,
  });

  final String scenarioId;
  final String taskId;
  final String taskTitle;
  final Set<HealthMetricType> targetMetrics;
  final AvatarState avatarState;
  final String avatarVariant;
  final AnimationState animationState;
  final CoachSeverity coachSeverity;
  final String coachSeverityLabel;
  final String coachMessage;
  final int? healthScore;
  final List<HealthIndex> healthIndices;
  final List<SystemStatus> systemStatuses;
  final List<BasicHealthMetric> basicHealthMetrics;
  final RiskDisplay riskDisplay;
  final AvatarAction? primaryAction;
  final List<AvatarAction> secondaryActions;
  final AvatarState? upstreamStateBeforeBoost;
  final AvatarCoachDataStatus dataStatus;
  final String? statusMessage;
  final DateTime renderedAt;
  final MockTaskStatus taskStatus;

  AvatarCoachViewModel copyWith({
    String? scenarioId,
    String? taskId,
    String? taskTitle,
    Set<HealthMetricType>? targetMetrics,
    AvatarState? avatarState,
    String? avatarVariant,
    AnimationState? animationState,
    CoachSeverity? coachSeverity,
    String? coachSeverityLabel,
    String? coachMessage,
    int? healthScore,
    List<HealthIndex>? healthIndices,
    List<SystemStatus>? systemStatuses,
    List<BasicHealthMetric>? basicHealthMetrics,
    RiskDisplay? riskDisplay,
    AvatarAction? primaryAction,
    List<AvatarAction>? secondaryActions,
    AvatarState? upstreamStateBeforeBoost,
    AvatarCoachDataStatus? dataStatus,
    String? statusMessage,
    DateTime? renderedAt,
    MockTaskStatus? taskStatus,
  }) {
    return AvatarCoachViewModel(
      scenarioId: scenarioId ?? this.scenarioId,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      targetMetrics: targetMetrics ?? this.targetMetrics,
      avatarState: avatarState ?? this.avatarState,
      avatarVariant: avatarVariant ?? this.avatarVariant,
      animationState: animationState ?? this.animationState,
      coachSeverity: coachSeverity ?? this.coachSeverity,
      coachSeverityLabel: coachSeverityLabel ?? this.coachSeverityLabel,
      coachMessage: coachMessage ?? this.coachMessage,
      healthScore: healthScore ?? this.healthScore,
      healthIndices: healthIndices ?? this.healthIndices,
      systemStatuses: systemStatuses ?? this.systemStatuses,
      basicHealthMetrics: basicHealthMetrics ?? this.basicHealthMetrics,
      riskDisplay: riskDisplay ?? this.riskDisplay,
      primaryAction: primaryAction ?? this.primaryAction,
      secondaryActions: secondaryActions ?? this.secondaryActions,
      upstreamStateBeforeBoost:
          upstreamStateBeforeBoost ?? this.upstreamStateBeforeBoost,
      dataStatus: dataStatus ?? this.dataStatus,
      statusMessage: statusMessage ?? this.statusMessage,
      renderedAt: renderedAt ?? this.renderedAt,
      taskStatus: taskStatus ?? this.taskStatus,
    );
  }
}
