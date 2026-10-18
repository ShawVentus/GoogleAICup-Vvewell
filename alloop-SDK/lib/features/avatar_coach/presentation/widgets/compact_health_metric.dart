import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/models/avatar_coach_view_model.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import 'severity_style.dart';

class CompactHealthMetric extends StatelessWidget {
  const CompactHealthMetric({super.key, required this.metric});

  final BasicHealthMetric metric;

  @override
  Widget build(BuildContext context) {
    final color = AvatarSeverityStyle.color(metric.severity);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_metricIcon(metric.label), size: 24, color: color),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  text: metric.value.tr,
                  style: const TextStyle(
                    color: VvewellColors.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    if (metric.unit case final unit?)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metric.label.tr,
              maxLines: 1,
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 7),
            Icon(Icons.circle, size: 9, color: color),
          ],
        ),
      ),
    );
  }
}

IconData _metricIcon(String label) => switch (label) {
  '心率' => Icons.favorite_border_rounded,
  '血氧' => Icons.air_rounded,
  '压力' => Icons.psychology_outlined,
  '精力' => Icons.bolt_rounded,
  '睡眠' => Icons.nightlight_round,
  _ => Icons.monitor_heart_outlined,
};
