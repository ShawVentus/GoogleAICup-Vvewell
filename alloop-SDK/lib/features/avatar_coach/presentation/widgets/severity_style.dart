import 'package:flutter/material.dart';

import '../../../avatar_coach/domain/models/avatar_coach_view_model.dart';
import '../../../../foundations/ui/vvewell_theme.dart';

abstract final class AvatarSeverityStyle {
  static Color color(CoachSeverity severity) => switch (severity) {
    CoachSeverity.green => VvewellColors.success,
    CoachSeverity.yellow => VvewellColors.warning,
    CoachSeverity.red => VvewellColors.error,
  };

  static Color softColor(CoachSeverity severity) => switch (severity) {
    CoachSeverity.green => VvewellColors.softMint,
    CoachSeverity.yellow => VvewellColors.softOrange,
    CoachSeverity.red => VvewellColors.softRed,
  };

  static IconData icon(CoachSeverity severity) => switch (severity) {
    CoachSeverity.green => Icons.check_circle_outline_rounded,
    CoachSeverity.yellow => Icons.info_outline_rounded,
    CoachSeverity.red => Icons.warning_amber_rounded,
  };
}
