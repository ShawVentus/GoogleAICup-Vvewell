import '../domain/models/avatar_coach_view_model.dart';
import '../domain/models/mock_avatar_coach_scenario.dart';
import '../domain/models/mock_health_snapshot.dart';
import 'mock_avatar_coach_adapter.dart';

enum AvatarCoachFixture {
  greenNormal,
  yellowSleepy,
  redWarning,
  completedBoost,
  loading,
  error,
  empty,
  fallback,
}

class MockAvatarCoachService {
  MockAvatarCoachService({DateTime Function()? now})
    : now = now ?? DateTime.now,
      _adapter = MockAvatarCoachAdapter(now: now ?? DateTime.now);

  static const String defaultSleepyMessage = '你看小熊猫好像睡眠有点不足，休息个二十分钟吧。';

  final DateTime Function() now;
  final MockAvatarCoachAdapter _adapter;

  Iterable<MockAvatarCoachScenario> get scenarios => _scenarios.values;

  MockAvatarCoachScenario scenario(MockScenarioId id) => _scenarios[id]!;

  MockScenarioId nextScenarioAfter(MockScenarioId current) {
    const cycle = [
      MockScenarioId.normal,
      MockScenarioId.happy,
      MockScenarioId.sleepy,
      MockScenarioId.stressed,
      MockScenarioId.inactive,
      MockScenarioId.recovery,
      MockScenarioId.warning,
    ];
    final currentIndex = cycle.indexOf(current);
    return cycle[(currentIndex + 1) % cycle.length];
  }

  MockHealthSnapshot initialSnapshot(MockScenarioId id) =>
      scenario(id).initialSnapshot;

  AvatarCoachViewModel getScenarioFixture(MockScenarioId id) {
    final config = scenario(id);
    final model = _adapter.adapt(
      config.initialSnapshot,
      config,
      presentationState: id == MockScenarioId.completedBoost
          ? AvatarState.completedBoost
          : null,
      coachMessage: id == MockScenarioId.completedBoost
          ? '任务已完成。稍后会加载 Mock 复测结果。'
          : null,
      coachSeverityLabel: id == MockScenarioId.completedBoost ? '任务完成' : null,
    );
    return id == MockScenarioId.completedBoost
        ? model.copyWith(upstreamStateBeforeBoost: AvatarState.sleepy)
        : model;
  }

  AvatarCoachViewModel viewModelForSnapshot(
    MockHealthSnapshot snapshot,
    MockAvatarCoachScenario config, {
    Map<HealthMetricType, int> visibleDeltas = const {},
    String? coachMessage,
    String? coachSeverityLabel,
    MockTaskStatus taskStatus = MockTaskStatus.offered,
    AvatarState? presentationState,
  }) => _adapter.adapt(
    snapshot,
    config,
    visibleDeltas: visibleDeltas,
    coachMessage: coachMessage,
    coachSeverityLabel: coachSeverityLabel,
    taskStatus: taskStatus,
    presentationState: presentationState,
  );

  AvatarState mapAvatarState(MockHealthSnapshot snapshot) =>
      _adapter.mapAvatarState(snapshot);

  AvatarCoachViewModel getFixture(AvatarCoachFixture fixture) {
    return switch (fixture) {
      AvatarCoachFixture.greenNormal => getScenarioFixture(
        MockScenarioId.normal,
      ),
      AvatarCoachFixture.yellowSleepy => getScenarioFixture(
        MockScenarioId.sleepy,
      ),
      AvatarCoachFixture.redWarning => getScenarioFixture(
        MockScenarioId.warning,
      ),
      AvatarCoachFixture.completedBoost => getScenarioFixture(
        MockScenarioId.completedBoost,
      ),
      AvatarCoachFixture.loading => _statusFixture(
        AvatarCoachDataStatus.loading,
        '正在加载今日状态',
      ),
      AvatarCoachFixture.error => _statusFixture(
        AvatarCoachDataStatus.error,
        '暂时无法加载今日状态',
      ),
      AvatarCoachFixture.empty => _statusFixture(
        AvatarCoachDataStatus.empty,
        '今天还没有可展示的数据',
      ),
      AvatarCoachFixture.fallback => _statusFixture(
        AvatarCoachDataStatus.fallback,
        '数据暂不完整，先展示普通状态',
      ),
    };
  }

  AvatarCoachViewModel fixtureForAvatarState(AvatarState state) {
    final id = switch (state) {
      AvatarState.normal => MockScenarioId.normal,
      AvatarState.happy => MockScenarioId.happy,
      AvatarState.sleepy => MockScenarioId.sleepy,
      AvatarState.stressed => MockScenarioId.stressed,
      AvatarState.inactive => MockScenarioId.inactive,
      AvatarState.recovery => MockScenarioId.recovery,
      AvatarState.warning => MockScenarioId.warning,
      AvatarState.completedBoost => MockScenarioId.completedBoost,
    };
    return getScenarioFixture(id);
  }

  AvatarCoachViewModel completedBoostFrom(AvatarCoachViewModel upstream) {
    return upstream.copyWith(
      avatarState: AvatarState.completedBoost,
      avatarVariant: 'completed_boost_stars',
      animationState: AnimationState.transitioning,
      coachSeverity: CoachSeverity.green,
      coachSeverityLabel: '任务完成',
      coachMessage: '任务已完成。稍后会加载 Mock 复测结果。',
      upstreamStateBeforeBoost: upstream.avatarState,
      renderedAt: now(),
      taskStatus: MockTaskStatus.completed,
    );
  }

  AvatarCoachViewModel _statusFixture(
    AvatarCoachDataStatus status,
    String message,
  ) {
    return AvatarCoachViewModel(
      scenarioId: 'mock_status_${status.name}',
      taskId: '',
      taskTitle: '',
      targetMetrics: const {},
      avatarState: AvatarState.normal,
      avatarVariant: 'normal_breathe_blink',
      animationState: AnimationState.idle,
      coachSeverity: CoachSeverity.green,
      coachSeverityLabel: '状态提示',
      coachMessage: '',
      healthScore: null,
      healthIndices: const [],
      systemStatuses: const [],
      basicHealthMetrics: const [],
      riskDisplay: const RiskDisplay.hidden(),
      primaryAction: null,
      secondaryActions: const [],
      dataStatus: status,
      statusMessage: message,
      renderedAt: now(),
    );
  }

  static const Map<MockScenarioId, MockAvatarCoachScenario> _scenarios = {
    MockScenarioId.normal: MockAvatarCoachScenario(
      id: MockScenarioId.normal,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_normal',
        health: 82,
        vitality: 80,
        mental: 78,
        stateTags: {'no_major_issue'},
        movementRating: MovementRating.sufficient,
        movementRawValue: 84,
      ),
      taskId: 'task_mock_normal_hydration',
      taskTitle: '轻量活动或补水',
      coachSeverity: CoachSeverity.green,
      coachSeverityLabel: '日常建议',
      coachMessage: '今天状态平稳，可以做一点轻量活动或补充水分。',
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 7,
        HealthMetricType.vitality: 9,
        HealthMetricType.mental: 6,
      },
      missedDelta: {},
      completedStateTags: {'positive_state'},
      missedStateTags: {'no_major_issue'},
      completionFeedback: '任务已完成。Mock 复测显示三个状态条有变化，请继续按自己的节奏。',
    ),
    MockScenarioId.happy: MockAvatarCoachScenario(
      id: MockScenarioId.happy,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_happy',
        health: 94,
        vitality: 92,
        mental: 90,
        stateTags: {'positive_state'},
        movementRating: MovementRating.sufficient,
        movementRawValue: 92,
      ),
      taskId: 'task_mock_happy_maintain',
      taskTitle: '保持当前节奏',
      coachSeverity: CoachSeverity.green,
      coachSeverityLabel: '状态良好',
      coachMessage: '今天整体状态不错，保持现在舒适的节奏就好。',
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 3,
        HealthMetricType.vitality: 4,
        HealthMetricType.mental: 3,
      },
      missedDelta: {},
      completedStateTags: {'positive_state'},
      missedStateTags: {'positive_state'},
      completionFeedback: '任务已完成。保持适合自己的节奏即可。',
    ),
    MockScenarioId.sleepy: MockAvatarCoachScenario(
      id: MockScenarioId.sleepy,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_sleepy',
        health: 68,
        vitality: 52,
        mental: 72,
        stateTags: {'sleep_deprivation'},
        movementRating: MovementRating.average,
        movementRawValue: 66,
      ),
      taskId: 'task_mock_sleepy_rest',
      taskTitle: '休息二十分钟',
      coachSeverity: CoachSeverity.yellow,
      coachSeverityLabel: '需要关注',
      coachMessage: defaultSleepyMessage,
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 8,
        HealthMetricType.vitality: 18,
        HealthMetricType.mental: 5,
      },
      missedDelta: {
        HealthMetricType.health: -4,
        HealthMetricType.vitality: -10,
      },
      completedStateTags: {'no_major_issue'},
      missedStateTags: {'sleep_deprivation'},
      completionFeedback: '休息任务已完成。Mock 复测已返回，稍后也可以继续关注身体感受。',
    ),
    MockScenarioId.stressed: MockAvatarCoachScenario(
      id: MockScenarioId.stressed,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_stressed',
        health: 66,
        vitality: 70,
        mental: 48,
        stateTags: {'high_stress'},
        movementRating: MovementRating.average,
        movementRawValue: 64,
      ),
      taskId: 'task_mock_stressed_breathe',
      taskTitle: '呼吸放松三分钟',
      coachSeverity: CoachSeverity.yellow,
      coachSeverityLabel: '需要关注',
      coachMessage: '现在可能有些紧绷，可以尝试三分钟呼吸放松。',
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 8,
        HealthMetricType.vitality: 3,
        HealthMetricType.mental: 20,
      },
      missedDelta: {HealthMetricType.health: -4, HealthMetricType.mental: -12},
      completedStateTags: {'no_major_issue'},
      missedStateTags: {'high_stress'},
      completionFeedback: '呼吸任务已完成。Mock 复测已返回，不代表生理指标已经改善。',
    ),
    MockScenarioId.inactive: MockAvatarCoachScenario(
      id: MockScenarioId.inactive,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_inactive',
        health: 70,
        vitality: 50,
        mental: 70,
        stateTags: {'sedentary_too_long'},
        movementRating: MovementRating.insufficient,
        movementRawValue: 42,
      ),
      taskId: 'task_mock_inactive_stretch',
      taskTitle: '拉伸活动五分钟',
      coachSeverity: CoachSeverity.yellow,
      coachSeverityLabel: '需要活动',
      coachMessage: '坐得有些久了，可以用五分钟做一组轻柔拉伸。',
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 7,
        HealthMetricType.vitality: 17,
        HealthMetricType.mental: 4,
      },
      missedDelta: {HealthMetricType.health: -3, HealthMetricType.vitality: -9},
      completedStateTags: {'no_major_issue'},
      missedStateTags: {'sedentary_too_long'},
      completionFeedback: '拉伸任务已完成。Mock 复测已返回，可以留意接下来的身体感受。',
    ),
    MockScenarioId.recovery: MockAvatarCoachScenario(
      id: MockScenarioId.recovery,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_recovery',
        health: 56,
        vitality: 46,
        mental: 64,
        stateTags: {'low_readiness'},
        movementRating: MovementRating.average,
        movementRawValue: 58,
      ),
      taskId: 'task_mock_recovery_rest',
      taskTitle: '降低强度并休息',
      coachSeverity: CoachSeverity.yellow,
      coachSeverityLabel: '恢复优先',
      coachMessage: '今天更适合降低活动强度，给身体留一点恢复时间。',
      targetMetrics: {
        HealthMetricType.health,
        HealthMetricType.vitality,
        HealthMetricType.mental,
      },
      completedDelta: {
        HealthMetricType.health: 10,
        HealthMetricType.vitality: 16,
        HealthMetricType.mental: 6,
      },
      missedDelta: {
        HealthMetricType.health: -6,
        HealthMetricType.vitality: -10,
        HealthMetricType.mental: -2,
      },
      completedStateTags: {'no_major_issue'},
      missedStateTags: {'low_readiness'},
      completionFeedback: '恢复任务已完成。Mock 复测已返回，完成本身不代表生理状态已恢复。',
    ),
    MockScenarioId.warning: MockAvatarCoachScenario(
      id: MockScenarioId.warning,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_warning',
        health: 42,
        vitality: 48,
        mental: 58,
        stateTags: {'temperature_signal_unusual'},
        movementRating: MovementRating.average,
        movementRawValue: 60,
      ),
      taskId: 'task_mock_warning_recheck',
      taskTitle: '人工复测',
      coachSeverity: CoachSeverity.red,
      coachSeverityLabel: '风险提示',
      coachMessage: '体温信号与平时不同，建议使用可靠设备进行人工测量。',
      targetMetrics: {},
      completedDelta: {},
      missedDelta: {},
      completedStateTags: {'temperature_signal_unusual'},
      missedStateTags: {'temperature_signal_unusual'},
      completionFeedback: '已记录操作。风险提示会保留，直到 Mock 人工复测结果正常。',
      warning: true,
    ),
    MockScenarioId.completedBoost: MockAvatarCoachScenario(
      id: MockScenarioId.completedBoost,
      initialSnapshot: MockHealthSnapshot(
        scenarioId: 'mock_completed_boost',
        health: 68,
        vitality: 52,
        mental: 72,
        stateTags: {'sleep_deprivation'},
        movementRating: MovementRating.average,
        movementRawValue: 66,
      ),
      taskId: 'task_mock_completed_preview',
      taskTitle: '已完成任务',
      coachSeverity: CoachSeverity.green,
      coachSeverityLabel: '任务完成',
      coachMessage: '任务已完成。稍后会加载 Mock 复测结果。',
      targetMetrics: {},
      completedDelta: {},
      missedDelta: {},
      completedStateTags: {'no_major_issue'},
      missedStateTags: {'sleep_deprivation'},
      completionFeedback: '任务已完成。',
    ),
  };
}
