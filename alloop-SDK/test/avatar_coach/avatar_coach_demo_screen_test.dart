import 'package:alloop/features/avatar_coach/domain/models/mock_avatar_coach_scenario.dart';
import 'package:alloop/features/avatar_coach/presentation/controllers/avatar_coach_controller.dart';
import 'package:alloop/features/avatar_coach/presentation/pages/avatar_coach_demo_screen.dart';
import 'package:alloop/foundations/ui/vvewell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('debug preview exposes all eight independent scenarios', (
    tester,
  ) async {
    final controller = AvatarCoachController();
    addTearDown(controller.onClose);
    await tester.pumpWidget(
      MaterialApp(
        theme: vvewellTheme(),
        home: AvatarCoachDemoScreen(controller: controller),
      ),
    );

    expect(find.byKey(const Key('mock-scenario-switcher')), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<MockScenarioId>>(
      find.byType(DropdownButton<MockScenarioId>),
    );
    expect(dropdown.items, hasLength(8));

    for (final scenario in MockScenarioId.values) {
      controller.switchScenario(scenario);
      await tester.pump();
      expect(controller.viewModel.value.scenarioId, scenario.wireName);
      expect(
        find.byKey(const Key('panda-avatar-stable-frame')),
        findsOneWidget,
      );
    }
  });
}
