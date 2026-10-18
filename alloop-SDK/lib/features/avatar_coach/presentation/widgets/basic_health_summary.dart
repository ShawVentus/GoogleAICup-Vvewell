import 'package:flutter/material.dart';

import '../../domain/models/avatar_coach_view_model.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import 'compact_health_metric.dart';

class BasicHealthSummary extends StatelessWidget {
  const BasicHealthSummary({super.key, required this.metrics});

  final List<BasicHealthMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    CompactHealthMetric(metric: metrics[index]),
                    if (index != metrics.length - 1)
                      const VerticalDivider(
                        width: 1,
                        color: VvewellColors.border,
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
