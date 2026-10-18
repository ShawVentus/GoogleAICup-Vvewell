import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../../family/domain/family_member.dart';
import '../../health_analysis/domain/canonical_contract.dart';
import '../data/local_recommendation_repository.dart';
import '../domain/recommendation_models.dart';

class RecommendationSection extends StatefulWidget {
  const RecommendationSection({
    super.key,
    this.repository,
    this.healthTags = const [],
  });

  final RecommendationRepository? repository;
  final List<FamilyHealthTag> healthTags;

  @override
  State<RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<RecommendationSection> {
  late final RecommendationRepository _repository =
      widget.repository ?? const LocalRecommendationRepository();
  RecommendationPlan? _plan;
  Object? _error;
  bool _loading = true;
  final Set<String> _updatingTasks = {};
  late final String _displaySessionId = deterministicUuid(
    'recommendation-display:${DateTime.now().toUtc().microsecondsSinceEpoch}:$hashCode',
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _repository.load();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
      if (plan != null) {
        for (var index = 0; index < plan.items.length; index++) {
          unawaited(
            _repository.recordImpression(
              plan.decisionId,
              plan.items[index],
              sessionId: _displaySessionId,
              displayedRank: index + 1,
            ),
          );
        }
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _advanceTask(RecommendationItem item, int displayedRank) async {
    final taskId = item.taskId;
    if (taskId == null || _updatingTasks.contains(taskId)) return;
    final next = item.taskStatus == 'pending' ? 'started' : 'completed';
    setState(() => _updatingTasks.add(taskId));
    try {
      await _repository.updateTask(
        item,
        next,
        sessionId: _displaySessionId,
        displayedRank: displayedRank,
      );
      if (mounted) setState(() => item.taskStatus = next);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
      }
    } finally {
      if (mounted) setState(() => _updatingTasks.remove(taskId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return _StatusRow(
        icon: Icons.error_outline,
        text: "Local analysis is temporarily unavailable",
        action: _load,
      );
    }
    final plan = _plan;
    if (plan?.status == 'CARE_ESCALATION') {
      return _StatusRow(
        icon: Icons.health_and_safety_outlined,
        text: "Review your care reminders first",
        action: _load,
      );
    }
    if (plan?.status == 'ABSTAINED') {
      return _StatusRow(
        icon: Icons.fact_check_outlined,
        text: "No suitable actions to recommend yet",
        action: _load,
      );
    }
    if (plan == null || plan.items.isEmpty) {
      return _FallbackReadingList(healthTags: widget.healthTags);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < plan.items.length; index++) ...[
          _RecommendationRow(
            item: plan.items[index],
            personalizationTags: _tagsFor(plan.items[index], widget.healthTags),
            updating:
                plan.items[index].taskId != null &&
                _updatingTasks.contains(plan.items[index].taskId),
            onTaskAction: () => _advanceTask(plan.items[index], index + 1),
          ),
          if (index != plan.items.length - 1) const SizedBox(height: 9),
        ],
        if (plan.analyzedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            plan.cloudSyncedAt == null
                ? 'Local analysis ${_shortTime(plan.analyzedAt!)} · Not synced'
                : 'Local analysis ${_shortTime(plan.analyzedAt!)} · Cloud sync ${_shortTime(plan.cloudSyncedAt!)}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, color: VvewellColors.muted),
          ),
        ],
      ],
    );
  }

  static String _shortTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  static List<String> _tagsFor(
    RecommendationItem item,
    List<FamilyHealthTag> healthTags,
  ) {
    final visible = healthTags
        .where((tag) => !tag.hiddenFromPersonalization)
        .toList(growable: false);
    if (visible.isEmpty) return const ['日常健康', '个性化'];
    final haystack = '${item.title}${item.description}'.toLowerCase();
    final matched = visible.where((tag) {
      final label = tag.label.toLowerCase();
      return haystack.contains(label) ||
          label
              .split(RegExp(r'[与和、\s]'))
              .any((token) => token.length >= 2 && haystack.contains(token));
    });
    final ordered = <FamilyHealthTag>[...matched];
    for (final tag in visible) {
      if (!ordered.contains(tag)) ordered.add(tag);
    }
    return ordered.take(3).map((tag) => tag.label).toList(growable: false);
  }
}

class _FallbackReadingList extends StatelessWidget {
  const _FallbackReadingList({required this.healthTags});

  final List<FamilyHealthTag> healthTags;

  @override
  Widget build(BuildContext context) {
    final visible = healthTags
        .where((tag) => !tag.hiddenFromPersonalization)
        .map((tag) => tag.label)
        .toList(growable: false);
    List<String> tags(int offset) {
      if (visible.isEmpty) return const ['日常健康', '个性化'];
      return List.generate(
        visible.length.clamp(1, 3),
        (index) => visible[(index + offset) % visible.length],
      );
    }

    return Column(
      children: [
        _ReadingCard(
          icon: Icons.bedtime_outlined,
          title: '把睡眠趋势读懂：比单晚时长更重要的三个信号',
          description: '结合近期睡眠与呼吸变化，了解哪些波动值得持续关注。',
          tags: tags(0),
        ),
        const SizedBox(height: 9),
        _ReadingCard(
          icon: Icons.favorite_border,
          title: '家庭心血管复查前，健康档案应该准备什么',
          description: '用一份清单整理设备趋势、既往报告和当前用药。',
          tags: tags(1),
        ),
        const SizedBox(height: 9),
        _ReadingCard(
          icon: Icons.shield_outlined,
          title: '看懂门诊保障：额度、免赔与网络范围',
          description: '从家庭当前保障缺口出发，梳理常见保单字段。',
          tags: tags(2),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tags,
  });
  final IconData icon;
  final String title;
  final String description;
  final List<String> tags;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: VvewellColors.surface,
      border: Border.all(color: VvewellColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: VvewellColors.softTeal,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: VvewellColors.primary, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              _PersonalizedTagWrap(tags: tags),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: VvewellColors.muted, size: 20),
      ],
    ),
  );
}

class _PersonalizedTagWrap extends StatelessWidget {
  const _PersonalizedTagWrap({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 5,
    runSpacing: 5,
    children: [
      for (final tag in tags)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: VvewellColors.softTeal,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag.tr,
            style: const TextStyle(
              color: VvewellColors.primaryDark,
              fontSize: 9,
            ),
          ),
        ),
    ],
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.text,
    required this.action,
  });
  final IconData icon;
  final String text;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 72),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: VvewellColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: VvewellColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: VvewellColors.muted)),
        ),
        IconButton(
          onPressed: action,
          icon: const Icon(Icons.refresh),
          tooltip: '重试'.tr,
        ),
      ],
    ),
  );
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({
    required this.item,
    required this.personalizationTags,
    required this.updating,
    required this.onTaskAction,
  });
  final RecommendationItem item;
  final List<String> personalizationTags;
  final bool updating;
  final VoidCallback onTaskAction;

  IconData get _icon => switch (item.itemKind) {
    'TASK' => Icons.flag_outlined,
    'GOODS' => Icons.shopping_bag_outlined,
    'SERVICE' => Icons.medical_services_outlined,
    _ => Icons.lightbulb_outline,
  };

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: VvewellColors.surface,
      border: Border.all(color: VvewellColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: VvewellColors.softTeal,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(_icon, color: VvewellColors.primary, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: VvewellColors.muted,
                ),
              ),
              if (item.commercialDisclosure != null) ...[
                const SizedBox(height: 5),
                Text(
                  item.commercialDisclosure!,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    color: VvewellColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              _PersonalizedTagWrap(tags: personalizationTags),
            ],
          ),
        ),
        if (item.itemKind == 'TASK' && item.taskId != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 38,
            child: IconButton.filledTonal(
              onPressed: updating || item.taskStatus == 'completed'
                  ? null
                  : onTaskAction,
              icon: updating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      item.taskStatus == 'pending'
                          ? Icons.play_arrow
                          : Icons.check,
                    ),
              tooltip: item.taskStatus == 'pending'
                  ? "Start task"
                  : item.taskStatus == 'completed'
                  ? '已完成'.tr
                  : "Complete task",
            ),
          ),
        ],
      ],
    ),
  );
}
