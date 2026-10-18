import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/models/avatar_coach_view_model.dart';
import '../../../../foundations/ui/vvewell_theme.dart';
import 'severity_style.dart';

class CoachBubbleWidget extends StatelessWidget {
  const CoachBubbleWidget({
    super.key,
    required this.severity,
    required this.severityLabel,
    required this.message,
    required this.expanded,
    this.showActions = false,
    this.completionEnabled = true,
    this.onCompleted,
    this.onSnooze,
    this.onDecline,
  });

  final CoachSeverity severity;
  final String severityLabel;
  final String message;
  final bool expanded;
  final bool showActions;
  final bool completionEnabled;
  final VoidCallback? onCompleted;
  final VoidCallback? onSnooze;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topLeft,
      child: expanded
          ? Semantics(
              liveRegion: true,
              label: '${severityLabel.tr}, ${message.tr}',
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 7),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      key: const Key('coach-bubble-expanded'),
                      constraints: const BoxConstraints(maxWidth: 330),
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: VvewellColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: VvewellColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1617312E),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: AvatarSeverityStyle.color(severity),
                              child: const SizedBox(width: 5),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 12, 16, 13),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AvatarSeverityStyle.icon(severity),
                                      size: 17,
                                      color: AvatarSeverityStyle.color(
                                        severity,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        severityLabel.tr,
                                        key: Key(
                                          'coach-severity-${severity.name}',
                                        ),
                                        style: TextStyle(
                                          color: AvatarSeverityStyle.color(
                                            severity,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  message.tr,
                                  style: const TextStyle(
                                    color: VvewellColors.foreground,
                                    fontSize: 15,
                                    height: 1.55,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (showActions) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CoachActionButton(
                                          key: const Key(
                                            'coach-action-completed',
                                          ),
                                          icon: Icons.check_rounded,
                                          label: '已完成',
                                          onPressed: completionEnabled
                                              ? onCompleted
                                              : null,
                                          primary: true,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: _CoachActionButton(
                                          key: const Key('coach-action-snooze'),
                                          icon: Icons.schedule_rounded,
                                          label: '过一会',
                                          onPressed: onSnooze,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: _CoachActionButton(
                                          key: const Key(
                                            'coach-action-decline',
                                          ),
                                          icon: Icons.close_rounded,
                                          label: '退下',
                                          onPressed: onDecline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 32,
                      top: 0,
                      child: CustomPaint(
                        size: Size(22, 10),
                        painter: _CoachBubbleTailPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: Key('coach-bubble-collapsed')),
    );
  }
}

class _CoachActionButton extends StatelessWidget {
  const _CoachActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 3),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label.tr,
              maxLines: 1,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 3, vertical: 7),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : TextButton(onPressed: onPressed, style: style, child: child);
  }
}

class _CoachBubbleTailPainter extends CustomPainter {
  const _CoachBubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = VvewellColors.surface;
    final stroke = Paint()
      ..color = VvewellColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
