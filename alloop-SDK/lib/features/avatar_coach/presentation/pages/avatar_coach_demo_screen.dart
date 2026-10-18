import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/models/avatar_coach_view_model.dart';
import '../../domain/models/mock_avatar_coach_scenario.dart';
import '../controllers/avatar_coach_controller.dart';
import '../widgets/coach_bubble_widget.dart';
import '../widgets/panda_avatar_widget.dart';
import '../widgets/system_status_row.dart';

/// Standalone development preview. It is intentionally not registered in the
/// production route table and does not add debug controls to the home page.
class AvatarCoachDemoScreen extends StatefulWidget {
  const AvatarCoachDemoScreen({super.key, this.controller});

  final AvatarCoachController? controller;

  @override
  State<AvatarCoachDemoScreen> createState() => _AvatarCoachDemoScreenState();
}

class _AvatarCoachDemoScreenState extends State<AvatarCoachDemoScreen> {
  late final AvatarCoachController _controller =
      widget.controller ?? AvatarCoachController();
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _controller.onClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avatar + Coach Mock Preview')),
      body: Obx(() {
        final model = _controller.viewModel.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<MockScenarioId>(
              key: const Key('mock-scenario-switcher'),
              initialValue: _controller.currentScenario.id,
              decoration: const InputDecoration(labelText: "Demo scenario"),
              items: [
                for (final scenario in MockScenarioId.values)
                  DropdownMenuItem(
                    value: scenario,
                    child: Text(scenario.wireName),
                  ),
              ],
              onChanged: (scenario) {
                if (scenario != null) _controller.switchScenario(scenario);
              },
            ),
            const SizedBox(height: 12),
            CoachBubbleWidget(
              severity: model.coachSeverity,
              severityLabel: model.coachSeverityLabel,
              message: model.coachMessage,
              expanded: _controller.isCoachExpanded.value,
              showActions:
                  model.taskStatus == MockTaskStatus.offered ||
                  model.taskStatus == MockTaskStatus.snoozed,
              completionEnabled: !model.riskDisplay.visible,
              onCompleted: _controller.completeTask,
              onSnooze: _controller.snoozeTask,
              onDecline: _controller.declineTask,
            ),
            const SizedBox(height: 12),
            Center(
              child: PandaAvatarWidget(
                state: model.avatarState,
                variant: model.avatarVariant,
                animationState: model.animationState,
                size: 210,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final index in model.healthIndices)
                  Chip(label: Text('${index.label} ${index.value}')),
              ],
            ),
            const SizedBox(height: 12),
            SystemStatusRow(statuses: model.systemStatuses),
            if (model.riskDisplay.visible) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('demo-warning-retest'),
                onPressed: _controller.submitNormalManualRetest,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Mock 人工复测正常'.tr),
              ),
            ],
          ],
        );
      }),
    );
  }
}
