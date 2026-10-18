import 'package:flutter_test/flutter_test.dart';

import 'package:alloop/features/avatar_coach/data/mock_avatar_coach_service.dart';
import 'package:alloop/features/avatar_coach/domain/models/avatar_coach_view_model.dart';
import 'package:alloop/features/avatar_coach/domain/models/mock_avatar_coach_scenario.dart';

void main() {
  final renderedAt = DateTime.utc(2026, 8, 3);
  late MockAvatarCoachService service;

  setUp(() {
    service = MockAvatarCoachService(now: () => renderedAt);
  });

  test('default fixture is the exact approved yellow sleepy scenario', () {
    final fixture = service.getFixture(AvatarCoachFixture.yellowSleepy);

    expect(fixture.avatarState, AvatarState.sleepy);
    expect(fixture.avatarVariant, 'sleepy_yawn_pillow');
    expect(fixture.coachSeverity, CoachSeverity.yellow);
    expect(fixture.coachSeverityLabel, '需要关注');
    expect(fixture.coachMessage, '你看小熊猫好像睡眠有点不足，休息个二十分钟吧。');
    expect(fixture.renderedAt, renderedAt);
  });

  test(
    'all eight scenarios expose exact state, variant and initial values',
    () {
      const expected = {
        MockScenarioId.normal: (
          AvatarState.normal,
          'normal_breathe_blink',
          [82, 80, 78],
        ),
        MockScenarioId.happy: (AvatarState.happy, 'happy_wave', [94, 92, 90]),
        MockScenarioId.sleepy: (
          AvatarState.sleepy,
          'sleepy_yawn_pillow',
          [68, 52, 72],
        ),
        MockScenarioId.stressed: (
          AvatarState.stressed,
          'stressed_tense_breathe',
          [66, 70, 48],
        ),
        MockScenarioId.inactive: (
          AvatarState.inactive,
          'inactive_neck_stretch',
          [70, 50, 70],
        ),
        MockScenarioId.recovery: (
          AvatarState.recovery,
          'recovery_blanket_breathe',
          [56, 46, 64],
        ),
        MockScenarioId.warning: (
          AvatarState.warning,
          'warning_cooling_patch_thermometer',
          [42, 48, 58],
        ),
        MockScenarioId.completedBoost: (
          AvatarState.completedBoost,
          'completed_boost_stars',
          [68, 52, 72],
        ),
      };

      for (final entry in expected.entries) {
        final model = service.getScenarioFixture(entry.key);
        expect(model.scenarioId, entry.key.wireName);
        expect(model.avatarState, entry.value.$1);
        expect(model.avatarVariant, entry.value.$2);
        expect(model.healthIndices.map((index) => index.value), entry.value.$3);
      }
    },
  );

  test('mapping is deterministic and warning keeps highest priority', () {
    final base = service.initialSnapshot(MockScenarioId.normal);
    final warningAndHappy = base.copyWith(
      stateTags: const {'positive_state', 'temperature_signal_unusual'},
    );

    expect(service.mapAvatarState(warningAndHappy), AvatarState.warning);
    expect(service.mapAvatarState(warningAndHappy), AvatarState.warning);
  });

  test('demo task sequence advances through seven scenarios and loops', () {
    const expected = [
      MockScenarioId.normal,
      MockScenarioId.happy,
      MockScenarioId.sleepy,
      MockScenarioId.stressed,
      MockScenarioId.inactive,
      MockScenarioId.recovery,
      MockScenarioId.warning,
      MockScenarioId.normal,
    ];
    var current = MockScenarioId.warning;

    for (final next in expected) {
      current = service.nextScenarioAfter(current);
      expect(current, next);
    }
  });

  test('scenario deltas only mutate metrics declared by each outcome', () {
    final stressed = service.scenario(MockScenarioId.stressed);
    final missed = stressed.missedSnapshot(stressed.initialSnapshot);

    expect(missed.health, 62);
    expect(missed.vitality, stressed.initialSnapshot.vitality);
    expect(missed.mental, 36);
    expect(stressed.missedDelta.keys, {
      HealthMetricType.health,
      HealthMetricType.mental,
    });
  });

  test('combined completed advice changes all configured metrics', () {
    final sleepy = service.scenario(MockScenarioId.sleepy);
    final completed = sleepy.completedSnapshot(sleepy.initialSnapshot);

    expect(
      [completed.health, completed.vitality, completed.mental],
      [76, 70, 77],
    );
    expect(service.mapAvatarState(completed), AvatarState.normal);
  });

  test('movement uses typed labels and never renders its raw percentage', () {
    const expected = {
      MovementRating.insufficient: '不足',
      MovementRating.average: '平均',
      MovementRating.sufficient: '充足',
      MovementRating.excessive: '过量',
    };
    final config = service.scenario(MockScenarioId.normal);

    for (final entry in expected.entries) {
      final snapshot = config.initialSnapshot.copyWith(
        movementRating: entry.key,
        movementRawValue: 76,
      );
      final model = service.viewModelForSnapshot(snapshot, config);
      final movement = model.systemStatuses.singleWhere(
        (status) => status.label == '运动',
      );
      expect(movement.displayValue, entry.value);
      expect(movement.value, 76);
    }

    expect(
      service
          .getScenarioFixture(MockScenarioId.inactive)
          .systemStatuses
          .singleWhere((status) => status.label == '运动')
          .displayValue,
      '不足',
    );
  });

  test('fixtures expose green, yellow, and red severity labels', () {
    final green = service.getFixture(AvatarCoachFixture.greenNormal);
    final yellow = service.getFixture(AvatarCoachFixture.yellowSleepy);
    final red = service.getFixture(AvatarCoachFixture.redWarning);

    expect(green.coachSeverity, CoachSeverity.green);
    expect(green.coachSeverityLabel, isNotEmpty);
    expect(yellow.coachSeverity, CoachSeverity.yellow);
    expect(yellow.coachSeverityLabel, isNotEmpty);
    expect(red.coachSeverity, CoachSeverity.red);
    expect(red.coachSeverityLabel, isNotEmpty);
    expect(red.riskDisplay.visible, isTrue);
  });

  test('system status uses movement and never the retired neural label', () {
    final fixture = service.getFixture(AvatarCoachFixture.yellowSleepy);
    final labels = fixture.systemStatuses.map((status) => status.label);

    expect(labels, ['心血管', '呼吸', '运动', '睡眠']);
  });

  test('loading error empty and fallback remain explicit render states', () {
    const expected = {
      AvatarCoachFixture.loading: AvatarCoachDataStatus.loading,
      AvatarCoachFixture.error: AvatarCoachDataStatus.error,
      AvatarCoachFixture.empty: AvatarCoachDataStatus.empty,
      AvatarCoachFixture.fallback: AvatarCoachDataStatus.fallback,
    };

    for (final entry in expected.entries) {
      final fixture = service.getFixture(entry.key);
      expect(fixture.dataStatus, entry.value);
      expect(fixture.statusMessage, isNotEmpty);
      expect(fixture.healthScore, isNull);
    }
  });

  test('warning copy is conservative and does not diagnose illness', () {
    final warning = service.getFixture(AvatarCoachFixture.redWarning);
    final copy = '${warning.coachMessage}${warning.riskDisplay.message}';

    expect(copy, contains('体温信号与平时不同'));
    expect(copy, isNot(contains('你发烧了')));
    expect(copy, isNot(contains('你生病了')));
    expect(copy, isNot(contains('患有')));
  });

  test(
    'completed boost acknowledges behavior without claiming improvement',
    () {
      final completed = service.getFixture(AvatarCoachFixture.completedBoost);

      expect(completed.avatarState, AvatarState.completedBoost);
      expect(completed.upstreamStateBeforeBoost, AvatarState.sleepy);
      expect(completed.coachMessage, contains('任务已完成'));
      expect(completed.coachMessage, isNot(contains('指标已改善')));
      expect(completed.coachMessage, isNot(contains('身体已经变好')));
      expect(completed.coachMessage, isNot(contains('恢复正常')));
    },
  );

  test('coach content avoids diagnosis, threats, shame and guilt', () {
    const forbidden = ['你发烧了', '你生病了', '患有', '必须', '否则', '越来越难受', '都是你的错'];

    for (final scenario in service.scenarios) {
      final copy = '${scenario.coachMessage}${scenario.completionFeedback}';
      for (final phrase in forbidden) {
        expect(copy, isNot(contains(phrase)), reason: scenario.id.wireName);
      }
    }
  });
}
