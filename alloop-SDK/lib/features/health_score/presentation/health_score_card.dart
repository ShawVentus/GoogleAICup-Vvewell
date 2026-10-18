import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../data/health_score_repository.dart';
import '../domain/health_score_calculator.dart';

/// Local wellness feedback: device trends form the reference score and
/// voluntary actions add a bounded, clearly separated contribution.
class HealthScoreCard extends StatefulWidget {
  const HealthScoreCard({super.key, this.actualAge = 38});

  final int actualAge;

  @override
  State<HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<HealthScoreCard>
    with SingleTickerProviderStateMixin {
  final _repository = HealthScoreRepository();
  List<Map<String, Object?>> _readings = const [];
  Set<String> _completed = <String>{};
  bool _loading = true;
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _load();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait<Object>([
      _repository.loadRecentReadings(),
      _repository.loadCompletedInterventions(),
    ]);
    if (!mounted) return;
    setState(() {
      _readings = values[0] as List<Map<String, Object?>>;
      _completed = values[1] as Set<String>;
      _loading = false;
    });
  }

  Future<void> _toggle(HealthIntervention intervention) async {
    final wasCompleted = _completed.contains(intervention.id);
    setState(() {
      _completed = {..._completed};
      wasCompleted
          ? _completed.remove(intervention.id)
          : _completed.add(intervention.id);
    });
    try {
      await _repository.setInterventionCompleted(
        intervention.id,
        !wasCompleted,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completed = {..._completed};
        wasCompleted
            ? _completed.add(intervention.id)
            : _completed.remove(intervention.id);
      });
    }
  }

  int get _validReadingDays {
    final days = <String>{};
    for (final row in _readings) {
      if ((row['is_valid'] as num?)?.toInt() == 0) continue;
      final timestamp = (row['recorded_at'] as num?)?.toInt();
      if (timestamp == null) continue;
      final day = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
      days.add('${day.year}-${day.month}-${day.day}');
    }
    return days.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _ScoreSurface(
        child: SizedBox(
          height: 240,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final snapshot = HealthScoreCalculator.calculate(
      readings: _readings,
      completedInterventions: _completed,
    );
    return _ScoreSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '今日健康参考分'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _AgingBadge(validDays: _validReadingDays),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '今日行动改变参考分，持续趋势形成 Aging 方向'.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          _SolarScoreHero(
            snapshot: snapshot,
            motion: _motion,
            completed: _completed,
            onToggle: _toggle,
          ),
          const SizedBox(height: 8),
          _AgeFusionPanel(actualAge: widget.actualAge, snapshot: snapshot),
        ],
      ),
    );
  }
}

class _AgeFusionPanel extends StatelessWidget {
  const _AgeFusionPanel({required this.actualAge, required this.snapshot});

  final int actualAge;
  final HealthScoreSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final score = snapshot.score;
    final weekDelta = snapshot.weekDelta ?? 0;
    final biologicalAge = score == null
        ? null
        : (actualAge + (68 - score) * .12 - weekDelta * .08).clamp(
            actualAge - 8,
            actualAge + 12,
          );
    final agingPace = score == null
        ? null
        : (1 + (62 - score) / 180 - weekDelta / 300).clamp(.72, 1.28);
    return Container(
      key: const Key('health-age-fusion-panel'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: VvewellColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AgeMetric(
              label: '实际年龄'.tr,
              value: actualAge.toDouble(),
              suffix: '岁'.tr,
              decimals: 0,
            ),
          ),
          const _AgeDivider(),
          Expanded(
            child: _AgeMetric(
              label: '生理年龄'.tr,
              value: biologicalAge?.toDouble(),
              suffix: '岁'.tr,
              decimals: 1,
            ),
          ),
          const _AgeDivider(),
          Expanded(
            child: _AgeMetric(
              label: '衰老速度'.tr,
              value: agingPace?.toDouble(),
              suffix: 'x',
              decimals: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgeMetric extends StatelessWidget {
  const _AgeMetric({
    required this.label,
    required this.value,
    required this.suffix,
    required this.decimals,
  });

  final String label;
  final double? value;
  final String suffix;
  final int decimals;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        maxLines: 1,
        style: const TextStyle(color: VvewellColors.muted, fontSize: 10),
      ),
      const SizedBox(height: 4),
      if (value == null)
        const Text(
          '--',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        )
      else
        TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 550),
          builder: (context, animatedValue, _) => Text(
            '${animatedValue.toStringAsFixed(decimals)} $suffix',
            maxLines: 1,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
    ],
  );
}

class _AgeDivider extends StatelessWidget {
  const _AgeDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 30,
    child: VerticalDivider(width: 1, color: VvewellColors.border),
  );
}

class _SolarScoreHero extends StatelessWidget {
  const _SolarScoreHero({
    required this.snapshot,
    required this.motion,
    required this.completed,
    required this.onToggle,
  });

  final HealthScoreSnapshot snapshot;
  final Animation<double> motion;
  final Set<String> completed;
  final ValueChanged<HealthIntervention> onToggle;

  @override
  Widget build(BuildContext context) {
    final score = snapshot.score;
    final actionCount = completed.length.clamp(0, 3);
    final scoreColor = score == null
        ? VvewellColors.muted
        : score >= 67
        ? VvewellColors.success
        : score >= 45
        ? VvewellColors.warning
        : VvewellColors.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VvewellColors.surface, VvewellColors.softTeal],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 212,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final center = Offset(width / 2, 94);
                return AnimatedBuilder(
                  animation: motion,
                  builder: (context, _) {
                    final angle = motion.value * math.pi * 2;
                    final positions = <Offset>[
                      Offset(
                        49 + math.sin(angle) * 5,
                        40 + math.cos(angle) * 3,
                      ),
                      Offset(
                        width - 49 + math.sin(angle + 2.1) * 5,
                        40 + math.cos(angle + 2.1) * 3,
                      ),
                      Offset(
                        width / 2 + math.sin(angle + 4.2) * 7,
                        184 + math.cos(angle + 4.2) * 3,
                      ),
                    ];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ActionOrbitPainter(
                              center: center,
                              taskPositions: positions,
                              phase: motion.value,
                              completed: completed,
                              scoreColor: scoreColor,
                              actionCount: actionCount,
                            ),
                          ),
                        ),
                        Positioned(
                          left: center.dx - 55,
                          top: center.dy - 55,
                          width: 110,
                          height: 110,
                          child: _ScoreCore(
                            score: score,
                            scoreColor: scoreColor,
                            actionCount: actionCount,
                          ),
                        ),
                        for (final entry
                            in HealthScoreCalculator.interventions.indexed)
                          Positioned(
                            left: positions[entry.$1].dx - 38,
                            top: positions[entry.$1].dy - 28,
                            width: 76,
                            height: 56,
                            child: _OrbitTaskNode(
                              intervention: entry.$2,
                              completed: completed.contains(entry.$2.id),
                              onPressed: () => onToggle(entry.$2),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              actionCount == 0
                  ? '点击行动星球，向今日健康分注入能量'.tr
                  : '已完成 @count 项行动 · 今日贡献 +@score'.trParams({
                      'count': '$actionCount',
                      'score': '${snapshot.actionContribution}',
                    }),
              key: ValueKey(actionCount),
              style: TextStyle(
                fontSize: 9.5,
                color: actionCount == 0 ? VvewellColors.muted : scoreColor,
                fontWeight: actionCount == 0
                    ? FontWeight.w400
                    : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCore extends StatelessWidget {
  const _ScoreCore({
    required this.score,
    required this.scoreColor,
    required this.actionCount,
  });

  final int? score;
  final Color scoreColor;
  final int actionCount;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-.18, -.22),
          radius: .84,
          colors: [VvewellColors.surface, VvewellColors.softTeal],
        ),
        border: Border.all(
          color: scoreColor.withValues(alpha: actionCount == 0 ? .28 : .58),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: actionCount == 0 ? .08 : .18),
            blurRadius: actionCount == 0 ? 14 : 24,
            spreadRadius: actionCount == 0 ? 1 : 3,
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween<double>(begin: .78, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            score?.toString() ?? '—',
            key: ValueKey(score),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Arial',
              fontFamilyFallback: ['Roboto', 'sans-serif'],
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 50,
              height: 1,
              letterSpacing: -2.2,
              fontWeight: FontWeight.w400,
              color: VvewellColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionOrbitPainter extends CustomPainter {
  const _ActionOrbitPainter({
    required this.center,
    required this.taskPositions,
    required this.phase,
    required this.completed,
    required this.scoreColor,
    required this.actionCount,
  });

  final Offset center;
  final List<Offset> taskPositions;
  final double phase;
  final Set<String> completed;
  final Color scoreColor;
  final int actionCount;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = .5 + math.sin(phase * math.pi * 2) * .5;
    canvas.drawCircle(
      center,
      60 + pulse * 4 + actionCount,
      Paint()..color = scoreColor.withValues(alpha: .03 + actionCount * .015),
    );
    final rayPaint = Paint()
      ..color = scoreColor.withValues(alpha: .13 + actionCount * .02)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 16; index++) {
      final angle = index / 16 * math.pi * 2 + phase * .18;
      final outer = 60 + pulse * 3 + (index.isEven ? 2 : 0);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * 57,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        rayPaint,
      );
    }

    final orbitRect = Rect.fromCenter(
      center: Offset(center.dx, 104),
      width: math.max(190, size.width - 44),
      height: 170,
    );
    canvas.drawOval(
      orbitRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..shader = SweepGradient(
          transform: GradientRotation(phase * math.pi * 2),
          colors: [
            VvewellColors.border.withValues(alpha: .2),
            VvewellColors.primary.withValues(alpha: .65),
            VvewellColors.border.withValues(alpha: .2),
            VvewellColors.primaryDark.withValues(alpha: .42),
            VvewellColors.border.withValues(alpha: .2),
          ],
        ).createShader(orbitRect),
    );
    final movingAngle = phase * math.pi * 2 - math.pi / 2;
    final orbitDot = Offset(
      orbitRect.center.dx + math.cos(movingAngle) * orbitRect.width / 2,
      orbitRect.center.dy + math.sin(movingAngle) * orbitRect.height / 2,
    );
    canvas.drawCircle(
      orbitDot,
      4.8,
      Paint()..color = VvewellColors.primary.withValues(alpha: .12),
    );
    canvas.drawCircle(orbitDot, 2.1, Paint()..color = VvewellColors.primary);

    final interventions = HealthScoreCalculator.interventions;
    for (var index = 0; index < taskPositions.length; index++) {
      final done = completed.contains(interventions[index].id);
      final start = taskPositions[index];
      canvas.drawCircle(
        start,
        25,
        Paint()
          ..color = VvewellColors.border.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      final moonAngle = phase * math.pi * 2 * (1.08 + index * .14) + index;
      final moon =
          start + Offset(math.cos(moonAngle), math.sin(moonAngle)) * 25;
      canvas.drawCircle(
        moon,
        done ? 2.8 : 2.1,
        Paint()
          ..color = done
              ? VvewellColors.primaryDark
              : VvewellColors.muted.withValues(alpha: .45),
      );
      final direction = center - start;
      final distance = direction.distance;
      if (distance == 0) continue;
      final unit = direction / distance;
      final connectorStart = start + unit * 22;
      final connectorEnd = center - unit * 57;
      canvas.drawLine(
        connectorStart,
        connectorEnd,
        Paint()
          ..color = done
              ? VvewellColors.primary.withValues(alpha: .5)
              : VvewellColors.border.withValues(alpha: .6)
          ..strokeWidth = done ? 1.3 : .8
          ..strokeCap = StrokeCap.round,
      );
      if (!done) continue;
      final travel = (phase + index * .23) % 1;
      final particle = Offset.lerp(connectorStart, connectorEnd, travel)!;
      canvas.drawCircle(
        particle,
        5.5,
        Paint()..color = VvewellColors.primary.withValues(alpha: .12),
      );
      canvas.drawCircle(particle, 2.4, Paint()..color = VvewellColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _ActionOrbitPainter old) =>
      old.phase != phase ||
      old.completed != completed ||
      old.scoreColor != scoreColor ||
      old.actionCount != actionCount ||
      old.center != center;
}

class _OrbitTaskNode extends StatelessWidget {
  const _OrbitTaskNode({
    required this.intervention,
    required this.completed,
    required this.onPressed,
  });

  final HealthIntervention intervention;
  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final details = switch (intervention.id) {
      'sleep_routine' => (Icons.bedtime_outlined, '准时睡'),
      'walk_break' => (Icons.directions_walk_outlined, '轻松走'),
      _ => (Icons.self_improvement_outlined, '放松'),
    };
    return Semantics(
      button: true,
      selected: completed,
      label: '${details.$2.tr}, ${completed ? '已完成'.tr : '未完成'.tr}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-.28, -.32),
                    colors: completed
                        ? [VvewellColors.primary, VvewellColors.primaryDark]
                        : [VvewellColors.surface, VvewellColors.softTeal],
                  ),
                  border: Border.all(
                    color: completed
                        ? VvewellColors.primaryDark
                        : VvewellColors.border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VvewellColors.primary.withValues(
                        alpha: completed ? .25 : .08,
                      ),
                      blurRadius: completed ? 14 : 7,
                      spreadRadius: completed ? 2 : 0,
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Icon(
                    completed ? Icons.check_rounded : details.$1,
                    key: ValueKey(completed),
                    size: 19,
                    color: completed
                        ? VvewellColors.surface
                        : VvewellColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                completed ? '${details.$2.tr} · ${'已完成'.tr}' : details.$2.tr,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 8.6,
                  fontWeight: FontWeight.w700,
                  color: VvewellColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSurface extends StatelessWidget {
  const _ScoreSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: VvewellColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: VvewellColors.border),
    ),
    child: child,
  );
}

class _AgingBadge extends StatelessWidget {
  const _AgingBadge({required this.validDays});

  final int validDays;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: VvewellColors.softTeal,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VvewellColors.border),
    ),
    child: Text(
      'AGING ${validDays.clamp(0, 21)}/21',
      style: const TextStyle(
        color: VvewellColors.primaryDark,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
