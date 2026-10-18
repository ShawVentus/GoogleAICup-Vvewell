import 'package:alloop/features/avatar_coach/data/mock_avatar_coach_service.dart';
import 'package:alloop/features/avatar_coach/domain/models/avatar_coach_view_model.dart';
import 'package:alloop/features/avatar_coach/presentation/widgets/coach_bubble_widget.dart';
import 'package:alloop/features/avatar_coach/presentation/widgets/panda_avatar_widget.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: vvewellTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('unknown variant keeps a stable frame and uses state GIF', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const PandaAvatarWidget(
          state: AvatarState.sleepy,
          variant: 'unknown_variant',
          animationState: AnimationState.idle,
          size: 144,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('panda-avatar-stable-frame')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('panda-avatar-stable-frame'))),
      const Size.square(144),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('panda-avatar-fallback')), findsNothing);
  });

  testWidgets('asset load failure renders a safe fallback', (tester) async {
    await tester.pumpWidget(
      host(
        DefaultAssetBundle(
          bundle: _FailingAssetBundle(),
          child: const PandaAvatarWidget(
            state: AvatarState.warning,
            variant: 'warning_cooling_patch_thermometer',
            animationState: AnimationState.idle,
            size: 144,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('panda-avatar-stable-frame')), findsOneWidget);
    expect(find.byKey(const Key('panda-avatar-fallback')), findsOneWidget);
  });

  testWidgets('coach severity is conveyed by label and icon', (tester) async {
    const fixtures = <CoachSeverity, String>{
      CoachSeverity.green: '日常建议',
      CoachSeverity.yellow: '需要关注',
      CoachSeverity.red: '风险提示',
    };

    for (final entry in fixtures.entries) {
      await tester.pumpWidget(
        host(
          CoachBubbleWidget(
            severity: entry.key,
            severityLabel: entry.value,
            message: '测试建议',
            expanded: true,
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(Icon), findsWidgets);
      expect(
        find.byKey(Key('coach-severity-${entry.key.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('collapsed coach does not expose message', (tester) async {
    await tester.pumpWidget(
      host(
        const CoachBubbleWidget(
          severity: CoachSeverity.yellow,
          severityLabel: '需要关注',
          message: MockAvatarCoachService.defaultSleepyMessage,
          expanded: false,
        ),
      ),
    );

    expect(find.byKey(const Key('coach-bubble-collapsed')), findsOneWidget);
    expect(
      find.text(MockAvatarCoachService.defaultSleepyMessage),
      findsNothing,
    );
  });

  testWidgets('coach exposes complete, snooze and decline actions', (
    tester,
  ) async {
    var completed = 0;
    var snoozed = 0;
    var declined = 0;
    await tester.pumpWidget(
      host(
        CoachBubbleWidget(
          severity: CoachSeverity.yellow,
          severityLabel: '需要关注',
          message: '测试建议',
          expanded: true,
          showActions: true,
          onCompleted: () => completed++,
          onSnooze: () => snoozed++,
          onDecline: () => declined++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coach-action-completed')));
    await tester.tap(find.byKey(const Key('coach-action-snooze')));
    await tester.tap(find.byKey(const Key('coach-action-decline')));

    expect((completed, snoozed, declined), (1, 1, 1));
  });
}

class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(StateError('Simulated asset load failure: $key'));
}
