import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';
import '../../domain/family_member.dart';
import '../controllers/family_profile_controller.dart';
import 'family_members_page.dart';

class HealthRecordPage extends StatelessWidget {
  const HealthRecordPage({super.key, required this.controller});

  final FamilyProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('健康档案'.tr)),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final member = controller.activeMember;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _RecordHeader(
                member: member,
                onSwitch: () => showFamilyMemberSwitcher(context, controller),
              ),
              const SizedBox(height: 20),
              _RecordSummary(member: member),
              const SizedBox(height: 24),
              Text(
                '动态健康标签'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (member.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                _HealthTagLegend(tags: member.tags),
              ],
              const SizedBox(height: 8),
              Text(
                '事实、预测与推断分开显示。预测结果不是诊断。'.tr,
                style: const TextStyle(color: VvewellColors.muted),
              ),
              const SizedBox(height: 12),
              if (member.tags.isEmpty)
                const _EmptyRecord()
              else
                ...member.tags.map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HealthTagCard(
                      tag: tag,
                      onConfirm: tag.status == HealthTagStatus.confirmed
                          ? null
                          : () => controller.confirmTag(tag.id),
                      onToggleHidden: () => controller.setTagHidden(
                        tag.id,
                        hidden: !tag.hiddenFromPersonalization,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                color: VvewellColors.softBlue,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: VvewellColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '社区行为不会用于保险销售、个体精算、核保、费率、拒保或拒赔。所有跨用途访问都需要单独授权。'.tr,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({required this.member, required this.onSwitch});

  final FamilyMember member;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VvewellColors.softTeal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_outline,
                color: VvewellColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@relationship · @gender · @year 年'.trParams({
                      'relationship': member.relationship.tr,
                      'gender': member.gender.tr,
                      'year': '${member.birthYear}',
                    }),
                    style: const TextStyle(color: VvewellColors.muted),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              key: const Key('health-record-switch-member'),
              onPressed: onSwitch,
              icon: const Icon(Icons.swap_horiz),
              label: Text('切换'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordSummary extends StatelessWidget {
  const _RecordSummary({required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final confirmed = member.tags
        .where((tag) => tag.status == HealthTagStatus.confirmed)
        .length;
    final predictions = member.tags
        .where((tag) => tag.status == HealthTagStatus.predicted)
        .length;
    return Row(
      children: [
        Expanded(
          child: _SummaryMetric(
            label: '健康评分'.tr,
            value: member.healthScore == 0 ? '待完善'.tr : '${member.healthScore}',
            icon: Icons.monitor_heart_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: '已确认事实'.tr,
            value: '@count 项'.trParams({'count': '$confirmed'}),
            icon: Icons.verified_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetric(
            label: '风险预测'.tr,
            value: '@count 项'.trParams({'count': '$predictions'}),
            icon: Icons.insights_outlined,
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: VvewellColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HealthTagLegend extends StatelessWidget {
  const _HealthTagLegend({required this.tags});

  final List<FamilyHealthTag> tags;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '动态健康标签'.tr,
      child: Wrap(
        key: const Key('health-tag-legend'),
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (tag) => _HealthTagLegendItem(
                key: Key('health-tag-legend-${tag.id}'),
                tag: tag,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _HealthTagLegendItem extends StatelessWidget {
  const _HealthTagLegendItem({super.key, required this.tag});

  final FamilyHealthTag tag;

  @override
  Widget build(BuildContext context) {
    final status = _healthTagStatusStyle(tag.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: status.$2.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.$2.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: status.$2, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag.label.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  status.$1.tr,
                  style: TextStyle(
                    color: status.$2,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(String, Color) _healthTagStatusStyle(HealthTagStatus status) =>
    switch (status) {
      HealthTagStatus.confirmed => ('已确认', VvewellColors.success),
      HealthTagStatus.predicted => ('风险预测', VvewellColors.warning),
      HealthTagStatus.inferred => ('系统推断', const Color(0xFF3A8DD9)),
      HealthTagStatus.unknown => ('待补充', VvewellColors.muted),
    };

class _HealthTagCard extends StatelessWidget {
  const _HealthTagCard({
    required this.tag,
    required this.onConfirm,
    required this.onToggleHidden,
  });

  final FamilyHealthTag tag;
  final VoidCallback? onConfirm;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final status = _healthTagStatusStyle(tag.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag.category.tr,
                        style: const TextStyle(
                          color: VvewellColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tag.label.tr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.$2.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.$1.tr,
                    style: TextStyle(
                      color: status.$2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tag.value.tr,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              (tag.confidence == null
                      ? '来源：@source\n用途：@purpose'
                      : '来源：@source\n用途：@purpose\n置信度：@confidence%')
                  .trParams({
                    'source': tag.source.tr,
                    'purpose': tag.purpose.tr,
                    'confidence': '${(tag.confidence ?? 0) * 100}'
                        .split('.')
                        .first,
                  }),
              style: const TextStyle(
                color: VvewellColors.muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (onConfirm != null)
                  TextButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('确认信息'.tr),
                  ),
                TextButton.icon(
                  onPressed: onToggleHidden,
                  icon: Icon(
                    tag.hiddenFromPersonalization
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  label: Text(
                    (tag.hiddenFromPersonalization ? '恢复个性化使用' : '停止个性化使用').tr,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecord extends StatelessWidget {
  const _EmptyRecord();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 36,
              color: VvewellColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              '档案尚未完善'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '完成基础资料与授权后，健康事实和服务建议会显示在这里。'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VvewellColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () {}, child: Text('完善基础资料'.tr)),
          ],
        ),
      ),
    );
  }
}
