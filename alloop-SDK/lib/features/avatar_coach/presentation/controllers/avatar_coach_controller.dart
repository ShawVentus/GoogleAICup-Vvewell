import 'dart:async';

import 'package:get/get.dart';

import '../../data/mock_avatar_coach_service.dart';
import '../../data/mock_event_recorder.dart';
import '../../domain/models/avatar_coach_view_model.dart';
import '../../domain/models/mock_avatar_coach_scenario.dart';
import '../../domain/models/mock_health_snapshot.dart';

typedef TimerFactory =
    Timer Function(Duration duration, void Function() action);

class AvatarCoachController extends GetxController {
  AvatarCoachController({
    MockAvatarCoachService? service,
    MockEventRecorder? eventRecorder,
    TimerFactory timerFactory = _defaultTimerFactory,
    this.completedBoostDuration = const Duration(seconds: 3),
    this.snoozeReminderDuration = const Duration(seconds: 5),
    this.nextScenarioDelay = const Duration(seconds: 2),
  }) : _service = service ?? MockAvatarCoachService(),
       eventRecorder = eventRecorder ?? MockEventRecorder(),
       _timerFactory = timerFactory {
    _currentScenario = _service.scenario(MockScenarioId.sleepy);
    _currentSnapshot = _currentScenario.initialSnapshot;
    viewModel = _service.getScenarioFixture(MockScenarioId.sleepy).obs;
    _record(MockAvatarCoachEventType.coachMessageShown);
  }

  final MockAvatarCoachService _service;
  final MockEventRecorder eventRecorder;
  final TimerFactory _timerFactory;
  final Duration completedBoostDuration;
  final Duration snoozeReminderDuration;
  final Duration nextScenarioDelay;

  late final Rx<AvatarCoachViewModel> viewModel;
  final RxBool isCoachExpanded = true.obs;
  final RxInt snoozeCount = 0.obs;

  late MockAvatarCoachScenario _currentScenario;
  late MockHealthSnapshot _currentSnapshot;
  Timer? _completedBoostTimer;
  Timer? _snoozeTimer;
  Timer? _nextScenarioTimer;
  AvatarCoachViewModel? _viewModelBeforePreviewBoost;
  final Set<String> _terminalTaskIds = {};
  bool _warningRetestApplied = false;

  MockHealthSnapshot get currentSnapshot => _currentSnapshot;
  MockAvatarCoachScenario get currentScenario => _currentScenario;

  void toggleCoach() {
    isCoachExpanded.toggle();
    if (isCoachExpanded.value) {
      _record(MockAvatarCoachEventType.coachMessageShown);
    }
  }

  void switchScenario(MockScenarioId id, {bool expandCoach = true}) {
    _cancelTimers();
    _loadScenario(id, recordExposure: expandCoach);
    isCoachExpanded.value = expandCoach;
  }

  void switchFixture(AvatarCoachFixture fixture, {bool expandCoach = true}) {
    final scenarioId = switch (fixture) {
      AvatarCoachFixture.greenNormal => MockScenarioId.normal,
      AvatarCoachFixture.yellowSleepy => MockScenarioId.sleepy,
      AvatarCoachFixture.redWarning => MockScenarioId.warning,
      AvatarCoachFixture.completedBoost => MockScenarioId.completedBoost,
      _ => null,
    };
    if (scenarioId != null) {
      switchScenario(scenarioId, expandCoach: expandCoach);
      if (scenarioId == MockScenarioId.completedBoost) {
        _completedBoostTimer = _timerFactory(
          completedBoostDuration,
          () => switchScenario(MockScenarioId.sleepy),
        );
      }
      return;
    }

    _cancelTimers();
    viewModel.value = _service.getFixture(fixture);
    isCoachExpanded.value = expandCoach;
  }

  bool completeTask() {
    if (_currentScenario.warning || !_claimTerminalTask()) return false;

    _cancelSnooze();
    _record(
      MockAvatarCoachEventType.taskCompleted,
      affectedMetrics: _currentScenario.completedDelta.nonZeroMetrics,
    );
    final previousState = viewModel.value.avatarState;
    viewModel.value = _service.completedBoostFrom(viewModel.value);
    isCoachExpanded.value = true;
    if (previousState != AvatarState.completedBoost) {
      _record(MockAvatarCoachEventType.avatarStateChanged);
    }
    _completedBoostTimer = _timerFactory(
      completedBoostDuration,
      _applyCompletedFollowUp,
    );
    return true;
  }

  bool snoozeTask() {
    if (_isTerminal ||
        viewModel.value.avatarState == AvatarState.completedBoost) {
      return false;
    }

    snoozeCount.value += 1;
    _record(MockAvatarCoachEventType.taskSnoozed);
    isCoachExpanded.value = false;
    _cancelSnooze();

    if (snoozeCount.value < 3) {
      _snoozeTimer = _timerFactory(snoozeReminderDuration, () {
        _snoozeTimer = null;
        if (!_isTerminal) {
          isCoachExpanded.value = true;
          _record(MockAvatarCoachEventType.coachMessageShown);
        }
      });
      return true;
    }

    if (_claimTerminalTask()) {
      _applyMissedFollowUp(
        taskStatus: MockTaskStatus.missed,
        terminalEvent: MockAvatarCoachEventType.taskMissed,
      );
    }
    return true;
  }

  bool declineTask() {
    if (!_claimTerminalTask()) return false;

    _cancelSnooze();
    isCoachExpanded.value = false;
    _applyMissedFollowUp(
      taskStatus: MockTaskStatus.declined,
      terminalEvent: MockAvatarCoachEventType.taskDeclined,
    );
    return true;
  }

  bool submitNormalManualRetest() {
    if (!_currentScenario.warning || _warningRetestApplied) return false;
    _warningRetestApplied = true;
    _terminalTaskIds.add(_currentScenario.taskId);

    final previousState = viewModel.value.avatarState;
    final next = _currentSnapshot.copyWith(
      health: 72,
      vitality: 70,
      mental: 74,
      stateTags: const {'no_major_issue'},
    );
    final deltas = _deltasBetween(_currentSnapshot, next);
    _currentSnapshot = next;
    viewModel.value = _service.viewModelForSnapshot(
      next,
      _currentScenario,
      visibleDeltas: deltas,
      coachMessage: 'Mock 人工复测结果正常，风险提示已解除。请继续关注身体感受。',
      coachSeverityLabel: '复测完成',
      taskStatus: MockTaskStatus.completed,
    );
    isCoachExpanded.value = true;
    _record(
      MockAvatarCoachEventType.mockFollowUpReceived,
      affectedMetrics: deltas.nonZeroMetrics,
    );
    if (previousState != viewModel.value.avatarState) {
      _record(
        MockAvatarCoachEventType.avatarStateChanged,
        affectedMetrics: deltas.nonZeroMetrics,
      );
    }
    _record(MockAvatarCoachEventType.coachMessageShown);
    _scheduleNextScenario();
    return true;
  }

  /// Development-only animation preview. It never mutates the snapshot.
  void showCompletedBoost() {
    _cancelCompletedBoost();
    _viewModelBeforePreviewBoost = viewModel.value;
    viewModel.value = _service.completedBoostFrom(viewModel.value);
    isCoachExpanded.value = true;
    _completedBoostTimer = _timerFactory(completedBoostDuration, () {
      final previous = _viewModelBeforePreviewBoost;
      if (previous != null) viewModel.value = previous;
      _viewModelBeforePreviewBoost = null;
      _completedBoostTimer = null;
    });
  }

  void loadSnapshot(MockHealthSnapshot snapshot) {
    final previousState = viewModel.value.avatarState;
    _currentSnapshot = snapshot;
    viewModel.value = _service.viewModelForSnapshot(snapshot, _currentScenario);
    if (previousState != viewModel.value.avatarState) {
      _record(MockAvatarCoachEventType.avatarStateChanged);
    }
  }

  void _loadScenario(MockScenarioId id, {required bool recordExposure}) {
    _currentScenario = _service.scenario(id);
    _currentSnapshot = _currentScenario.initialSnapshot;
    _terminalTaskIds.remove(_currentScenario.taskId);
    _warningRetestApplied = false;
    snoozeCount.value = 0;
    viewModel.value = _service.getScenarioFixture(id);
    if (recordExposure) _record(MockAvatarCoachEventType.coachMessageShown);
  }

  void _applyCompletedFollowUp() {
    _completedBoostTimer = null;
    final previousState = viewModel.value.avatarState;
    _currentSnapshot = _currentScenario.completedSnapshot(_currentSnapshot);
    viewModel.value = _service.viewModelForSnapshot(
      _currentSnapshot,
      _currentScenario,
      visibleDeltas: _currentScenario.completedDelta,
      coachMessage: _currentScenario.completionFeedback,
      coachSeverityLabel: '完成反馈',
      taskStatus: MockTaskStatus.completed,
    );
    isCoachExpanded.value = true;
    _record(
      MockAvatarCoachEventType.mockFollowUpReceived,
      affectedMetrics: _currentScenario.completedDelta.nonZeroMetrics,
    );
    if (previousState != viewModel.value.avatarState) {
      _record(
        MockAvatarCoachEventType.avatarStateChanged,
        affectedMetrics: _currentScenario.completedDelta.nonZeroMetrics,
      );
    }
    _record(MockAvatarCoachEventType.coachMessageShown);
    _scheduleNextScenario();
  }

  void _applyMissedFollowUp({
    required MockTaskStatus taskStatus,
    required MockAvatarCoachEventType terminalEvent,
  }) {
    final previousState = viewModel.value.avatarState;
    _currentSnapshot = _currentScenario.missedSnapshot(_currentSnapshot);
    final deltas = _currentScenario.missedDelta;
    viewModel.value = _service.viewModelForSnapshot(
      _currentSnapshot,
      _currentScenario,
      visibleDeltas: deltas,
      coachMessage: _currentScenario.warning
          ? '已收起 Coach。体温信号提示仍会保留，建议按需进行人工测量。'
          : deltas.nonZeroMetrics.isEmpty
          ? '已记录，这次不调整状态值。需要时可以再打开 Coach。'
          : '已记录本次未完成。Mock 后续状态已更新，需要时可以再查看建议。',
      taskStatus: taskStatus,
    );
    _record(terminalEvent, affectedMetrics: deltas.nonZeroMetrics);
    _record(
      MockAvatarCoachEventType.mockFollowUpReceived,
      affectedMetrics: deltas.nonZeroMetrics,
    );
    if (previousState != viewModel.value.avatarState) {
      _record(
        MockAvatarCoachEventType.avatarStateChanged,
        affectedMetrics: deltas.nonZeroMetrics,
      );
    }
    if (!_currentScenario.warning) {
      _scheduleNextScenario();
    }
  }

  bool _claimTerminalTask() {
    if (_isTerminal) return false;
    _terminalTaskIds.add(_currentScenario.taskId);
    return true;
  }

  bool get _isTerminal => _terminalTaskIds.contains(_currentScenario.taskId);

  void _scheduleNextScenario() {
    _nextScenarioTimer?.cancel();
    _nextScenarioTimer = _timerFactory(nextScenarioDelay, () {
      _nextScenarioTimer = null;
      switchScenario(_service.nextScenarioAfter(_currentScenario.id));
    });
  }

  void _record(
    MockAvatarCoachEventType type, {
    Set<HealthMetricType> affectedMetrics = const {},
  }) {
    eventRecorder.record(
      MockAvatarCoachEvent(
        type: type,
        scenarioId: _currentScenario.id.wireName,
        taskId: _currentScenario.taskId,
        avatarState: viewModel.value.avatarState,
        affectedMetrics: affectedMetrics,
        occurredAt: _service.now(),
      ),
    );
  }

  Map<HealthMetricType, int> _deltasBetween(
    MockHealthSnapshot before,
    MockHealthSnapshot after,
  ) => {
    for (final metric in HealthMetricType.values)
      metric: after.valueFor(metric) - before.valueFor(metric),
  };

  void _cancelCompletedBoost() {
    _completedBoostTimer?.cancel();
    _completedBoostTimer = null;
    _viewModelBeforePreviewBoost = null;
  }

  void _cancelSnooze() {
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
  }

  void _cancelTimers() {
    _cancelCompletedBoost();
    _cancelSnooze();
    _nextScenarioTimer?.cancel();
    _nextScenarioTimer = null;
  }

  @override
  void onClose() {
    _cancelTimers();
    super.onClose();
  }

  static Timer _defaultTimerFactory(
    Duration duration,
    void Function() action,
  ) => Timer(duration, action);
}

extension on Map<HealthMetricType, int> {
  Set<HealthMetricType> get nonZeroMetrics => entries
      .where((entry) => entry.value != 0)
      .map((entry) => entry.key)
      .toSet();
}
