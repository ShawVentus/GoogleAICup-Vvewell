import '../domain/models/avatar_coach_view_model.dart';
import '../domain/models/mock_avatar_coach_scenario.dart';
import '../domain/models/mock_health_snapshot.dart';

class MockAvatarCoachAdapter {
  const MockAvatarCoachAdapter({this.now = DateTime.now});

  final DateTime Function() now;

  AvatarState mapAvatarState(MockHealthSnapshot snapshot) {
    final tags = snapshot.stateTags;
    if (tags.contains('temperature_signal_unusual')) {
      return AvatarState.warning;
    }
    if (tags.contains('low_readiness')) return AvatarState.recovery;
    if (tags.contains('sleep_deprivation') ||
        tags.contains('poor_sleep_quality')) {
      return AvatarState.sleepy;
    }
    if (tags.contains('high_stress')) return AvatarState.stressed;
    if (tags.contains('sedentary_too_long')) return AvatarState.inactive;
    if (tags.contains('positive_state')) return AvatarState.happy;
    return AvatarState.normal;
  }

  AvatarCoachViewModel adapt(
    MockHealthSnapshot snapshot,
    MockAvatarCoachScenario scenario, {
    Map<HealthMetricType, int> visibleDeltas = const {},
    String? coachMessage,
    String? coachSeverityLabel,
    MockTaskStatus taskStatus = MockTaskStatus.offered,
    AvatarState? presentationState,
  }) {
    final avatarState = presentationState ?? mapAvatarState(snapshot);
    final warning = avatarState == AvatarState.warning;
    return AvatarCoachViewModel(
      scenarioId: scenario.id.wireName,
      taskId: scenario.taskId,
      taskTitle: scenario.taskTitle,
      targetMetrics: scenario.targetMetrics,
      avatarState: avatarState,
      avatarVariant: _variantFor(avatarState),
      animationState: avatarState == AvatarState.completedBoost
          ? AnimationState.transitioning
          : AnimationState.idle,
      coachSeverity: warning ? CoachSeverity.red : scenario.coachSeverity,
      coachSeverityLabel:
          coachSeverityLabel ??
          (warning ? '风险提示' : scenario.coachSeverityLabel),
      coachMessage: coachMessage ?? scenario.coachMessage,
      healthScore: snapshot.health,
      healthIndices: [
        HealthIndex(
          metric: HealthMetricType.health,
          label: '健康指数',
          value: snapshot.health,
          delta: visibleDeltas[HealthMetricType.health] ?? 0,
        ),
        HealthIndex(
          metric: HealthMetricType.vitality,
          label: '身体活力',
          value: snapshot.vitality,
          delta: visibleDeltas[HealthMetricType.vitality] ?? 0,
        ),
        HealthIndex(
          metric: HealthMetricType.mental,
          label: '心理状态',
          value: snapshot.mental,
          delta: visibleDeltas[HealthMetricType.mental] ?? 0,
        ),
      ],
      systemStatuses: [
        const SystemStatus(
          label: '心血管',
          value: 92,
          severity: CoachSeverity.green,
        ),
        const SystemStatus(
          label: '呼吸',
          value: 88,
          severity: CoachSeverity.green,
        ),
        SystemStatus(
          label: '运动',
          value: snapshot.movementRawValue,
          displayValue: movementLabel(snapshot.movementRating),
          severity: _movementSeverity(snapshot.movementRating),
        ),
        SystemStatus(
          label: '睡眠',
          value: warning ? 58 : 62,
          severity: warning ? CoachSeverity.yellow : CoachSeverity.red,
        ),
      ],
      basicHealthMetrics: _basicHealthMetrics,
      riskDisplay: warning
          ? const RiskDisplay(
              visible: true,
              severity: CoachSeverity.red,
              label: '需要专业关注',
              message: '体温信号与平时不同，必要时请人工测量或寻求专业帮助。',
            )
          : const RiskDisplay.hidden(),
      primaryAction: AvatarAction(
        type: warning
            ? AvatarActionType.seekProfessionalHelp
            : AvatarActionType.completeTask,
        label: warning ? '人工复测' : '已完成',
      ),
      secondaryActions: const [
        AvatarAction(type: AvatarActionType.snooze, label: '过一会'),
        AvatarAction(type: AvatarActionType.dismiss, label: '退下'),
      ],
      dataStatus: AvatarCoachDataStatus.ready,
      taskStatus: taskStatus,
      renderedAt: now(),
    );
  }

  String movementLabel(MovementRating rating) => switch (rating) {
    MovementRating.insufficient => '不足',
    MovementRating.average => '平均',
    MovementRating.sufficient => '充足',
    MovementRating.excessive => '过量',
  };

  static String _variantFor(AvatarState state) => switch (state) {
    AvatarState.normal => 'normal_breathe_blink',
    AvatarState.happy => 'happy_wave',
    AvatarState.sleepy => 'sleepy_yawn_pillow',
    AvatarState.stressed => 'stressed_tense_breathe',
    AvatarState.inactive => 'inactive_neck_stretch',
    AvatarState.recovery => 'recovery_blanket_breathe',
    AvatarState.warning => 'warning_cooling_patch_thermometer',
    AvatarState.completedBoost => 'completed_boost_stars',
  };

  static CoachSeverity _movementSeverity(MovementRating rating) =>
      switch (rating) {
        MovementRating.insufficient => CoachSeverity.red,
        MovementRating.average => CoachSeverity.yellow,
        MovementRating.sufficient => CoachSeverity.green,
        MovementRating.excessive => CoachSeverity.yellow,
      };

  static const List<BasicHealthMetric> _basicHealthMetrics = [
    BasicHealthMetric(
      label: '心率',
      value: '72',
      unit: 'bpm',
      severity: CoachSeverity.green,
    ),
    BasicHealthMetric(
      label: '血氧',
      value: '98',
      unit: '%',
      severity: CoachSeverity.green,
    ),
    BasicHealthMetric(label: '压力', value: '中等', severity: CoachSeverity.yellow),
    BasicHealthMetric(label: '精力', value: '偏低', severity: CoachSeverity.yellow),
    BasicHealthMetric(label: '睡眠', value: '不足', severity: CoachSeverity.red),
  ];
}
