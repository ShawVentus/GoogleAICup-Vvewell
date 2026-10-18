import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:alloop/features/avatar_coach/data/mock_avatar_coach_service.dart';
import 'package:alloop/features/avatar_coach/data/mock_event_recorder.dart';
import 'package:alloop/features/avatar_coach/domain/models/avatar_coach_view_model.dart';
import 'package:alloop/features/avatar_coach/domain/models/mock_avatar_coach_scenario.dart';
import 'package:alloop/features/avatar_coach/presentation/controllers/avatar_coach_controller.dart';

void main() {
  late _ManualTimerFactory timerFactory;
  late MockEventRecorder recorder;
  late AvatarCoachController controller;

  setUp(() {
    timerFactory = _ManualTimerFactory();
    recorder = MockEventRecorder();
    controller = AvatarCoachController(
      eventRecorder: recorder,
      timerFactory: timerFactory.call,
      completedBoostDuration: const Duration(milliseconds: 50),
      snoozeReminderDuration: const Duration(milliseconds: 25),
    );
  });

  tearDown(() {
    controller.onClose();
  });

  List<int> values() => controller.viewModel.value.healthIndices
      .map((index) => index.value)
      .toList();

  test('starts from the unified sleepy snapshot with expanded coach', () {
    expect(controller.currentScenario.id, MockScenarioId.sleepy);
    expect(controller.viewModel.value.avatarState, AvatarState.sleepy);
    expect(values(), [68, 52, 72]);
    expect(
      controller.viewModel.value.coachMessage,
      MockAvatarCoachService.defaultSleepyMessage,
    );
    expect(controller.isCoachExpanded.value, isTrue);
    expect(recorder.count(MockAvatarCoachEventType.coachMessageShown), 1);
  });

  test('completed task shows boost then applies targeted follow-up once', () {
    expect(controller.completeTask(), isTrue);
    expect(controller.viewModel.value.avatarState, AvatarState.completedBoost);
    expect(values(), [68, 52, 72]);
    expect(controller.completeTask(), isFalse);
    expect(timerFactory.lastDuration, const Duration(milliseconds: 50));

    timerFactory.fireNext();

    expect(controller.viewModel.value.avatarState, AvatarState.normal);
    expect(values(), [76, 70, 77]);
    expect(
      controller.viewModel.value.healthIndices.map((index) => index.delta),
      [8, 18, 5],
    );
    expect(recorder.count(MockAvatarCoachEventType.taskCompleted), 1);
    expect(recorder.count(MockAvatarCoachEventType.mockFollowUpReceived), 1);
  });

  test('completed feedback automatically opens the next mock task', () {
    controller.completeTask();
    timerFactory.fireNext();
    expect(controller.currentScenario.id, MockScenarioId.sleepy);
    expect(controller.viewModel.value.taskStatus, MockTaskStatus.completed);

    timerFactory.fireNext();

    expect(controller.currentScenario.id, MockScenarioId.stressed);
    expect(controller.viewModel.value.avatarState, AvatarState.stressed);
    expect(controller.viewModel.value.taskStatus, MockTaskStatus.offered);
    expect(controller.isCoachExpanded.value, isTrue);
  });

  test(
    'first two snoozes do not mutate values and reminders are injectable',
    () {
      final initial = values();

      expect(controller.snoozeTask(), isTrue);
      expect(controller.isCoachExpanded.value, isFalse);
      expect(values(), initial);
      timerFactory.fireNext();
      expect(controller.isCoachExpanded.value, isTrue);

      expect(controller.snoozeTask(), isTrue);
      expect(values(), initial);
      timerFactory.fireNext();
      expect(controller.isCoachExpanded.value, isTrue);
      expect(recorder.count(MockAvatarCoachEventType.taskSnoozed), 2);
      expect(recorder.count(MockAvatarCoachEventType.taskMissed), 0);
    },
  );

  test('third snooze applies missed snapshot exactly once', () {
    controller.snoozeTask();
    timerFactory.fireNext();
    controller.snoozeTask();
    timerFactory.fireNext();

    expect(controller.snoozeTask(), isTrue);
    expect(values(), [64, 42, 72]);
    expect(controller.snoozeTask(), isFalse);
    expect(values(), [64, 42, 72]);
    expect(recorder.count(MockAvatarCoachEventType.taskMissed), 1);
    expect(recorder.count(MockAvatarCoachEventType.mockFollowUpReceived), 1);
  });

  test('decline applies a targeted missed effect exactly once', () {
    controller.switchScenario(MockScenarioId.stressed);

    expect(controller.declineTask(), isTrue);
    expect(values(), [62, 70, 36]);
    expect(controller.declineTask(), isFalse);
    expect(values(), [62, 70, 36]);
    expect(recorder.count(MockAvatarCoachEventType.taskDeclined), 1);
  });

  test('normal and happy suggestions never deduct values when declined', () {
    for (final scenario in [MockScenarioId.normal, MockScenarioId.happy]) {
      controller.switchScenario(scenario);
      final initial = values();
      expect(controller.declineTask(), isTrue);
      expect(values(), initial);
    }
  });

  test('ordinary task actions cannot clear warning', () {
    controller.switchScenario(MockScenarioId.warning);
    final initial = values();

    expect(controller.completeTask(), isFalse);
    expect(controller.viewModel.value.avatarState, AvatarState.warning);
    expect(controller.declineTask(), isTrue);
    expect(values(), initial);
    expect(controller.viewModel.value.avatarState, AvatarState.warning);
    expect(controller.viewModel.value.riskDisplay.visible, isTrue);
  });

  test('normal manual retest is the only mock flow that clears warning', () {
    controller.switchScenario(MockScenarioId.warning);
    controller.declineTask();

    expect(controller.submitNormalManualRetest(), isTrue);
    expect(controller.viewModel.value.avatarState, AvatarState.normal);
    expect(controller.viewModel.value.riskDisplay.visible, isFalse);
    expect(values(), [72, 70, 74]);
    expect(controller.submitNormalManualRetest(), isFalse);
    expect(recorder.count(MockAvatarCoachEventType.mockFollowUpReceived), 2);

    timerFactory.fireNext();
    expect(controller.currentScenario.id, MockScenarioId.normal);
    expect(controller.viewModel.value.taskStatus, MockTaskStatus.offered);
  });

  test('loading a changed snapshot reruns deterministic state mapping', () {
    controller.switchScenario(MockScenarioId.normal);
    final stressed = controller.currentSnapshot.copyWith(
      mental: 45,
      stateTags: const {'high_stress'},
    );

    controller.loadSnapshot(stressed);

    expect(controller.viewModel.value.avatarState, AvatarState.stressed);
    expect(controller.viewModel.value.healthIndices.last.value, 45);
    expect(recorder.count(MockAvatarCoachEventType.avatarStateChanged), 1);
  });

  test('development boost preview restores the exact upstream model', () {
    controller.switchScenario(MockScenarioId.warning);
    final upstream = controller.viewModel.value;

    controller.showCompletedBoost();
    expect(controller.viewModel.value.avatarState, AvatarState.completedBoost);
    timerFactory.fireNext();

    expect(controller.viewModel.value, same(upstream));
    expect(controller.viewModel.value.avatarState, AvatarState.warning);
  });
}

class _ManualTimerFactory {
  final List<_ManualTimerEntry> _entries = [];

  Duration? get lastDuration =>
      _entries.isEmpty ? null : _entries.last.duration;

  Timer call(Duration duration, void Function() action) {
    final timer = _ManualTimer();
    _entries.add(_ManualTimerEntry(duration, action, timer));
    return timer;
  }

  void fireNext() {
    final entry = _entries.firstWhere((entry) => entry.timer.isActive);
    entry.timer.markFired();
    entry.action();
  }
}

class _ManualTimerEntry {
  const _ManualTimerEntry(this.duration, this.action, this.timer);

  final Duration duration;
  final void Function() action;
  final _ManualTimer timer;
}

class _ManualTimer implements Timer {
  bool _isActive = true;
  int _tick = 0;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _isActive = false;
  }

  void markFired() {
    _isActive = false;
    _tick = 1;
  }
}
