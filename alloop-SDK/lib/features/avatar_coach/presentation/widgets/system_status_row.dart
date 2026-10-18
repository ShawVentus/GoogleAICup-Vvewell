import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/models/avatar_coach_view_model.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import 'severity_style.dart';

class SystemStatusRow extends StatelessWidget {
  const SystemStatusRow({super.key, required this.statuses});

  final List<SystemStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 340 ? 72.0 : 80.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var index = 0; index < statuses.length; index++) ...[
                  SizedBox(
                    width: itemWidth,
                    child: _SystemStatusItem(status: statuses[index]),
                  ),
                  if (index != statuses.length - 1)
                    const SizedBox(
                      height: 75,
                      child: VerticalDivider(
                        width: 1,
                        color: VvewellColors.border,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SystemStatusItem extends StatelessWidget {
  const _SystemStatusItem({required this.status});

  final SystemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AvatarSeverityStyle.color(status.severity);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status.label), color: color, size: 25),
          const SizedBox(height: 4),
          Text(
            (status.displayValue ?? '${status.value}%').tr,
            key: Key('system-status-value-${status.label}'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            status.label.tr,
            maxLines: 1,
            style: const TextStyle(fontSize: 11, color: VvewellColors.muted),
          ),
          const SizedBox(height: 5),
          Container(
            width: 31,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _statusIcon(String label) => switch (label) {
  '心血管' => Icons.favorite_border_rounded,
  '呼吸' => Icons.air_rounded,
  '运动' => Icons.directions_run_rounded,
  '睡眠' => Icons.nightlight_round,
  _ => Icons.health_and_safety_outlined,
};
