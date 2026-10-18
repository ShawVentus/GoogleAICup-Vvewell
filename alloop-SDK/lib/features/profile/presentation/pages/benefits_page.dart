import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../foundations/ui/vvewell_theme.dart';

class BenefitsPage extends StatelessWidget {
  const BenefitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('我的权益'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: const [
          _MemberHero(),
          SizedBox(height: 16),
          _BenefitsGrid(),
          SizedBox(height: 16),
          _DailyTasks(),
          SizedBox(height: 16),
          _PointsHistory(),
        ],
      ),
    );
  }
}

class _MemberHero extends StatelessWidget {
  const _MemberHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: VvewellColors.primaryDark,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium, color: Color(0xFFF9D66D)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '高级会员'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Lv.5', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '2,380',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '会员积分'.tr,
                  style: const TextStyle(
                    color: Color(0xFFB9E5DF),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '距离下一等级'.tr,
                style: const TextStyle(color: Color(0xFFB9E5DF), fontSize: 11),
              ),
            ),
            Text(
              '620 积分'.tr,
              style: const TextStyle(color: Color(0xFFB9E5DF), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const LinearProgressIndicator(
          value: .72,
          minHeight: 5,
          color: Color(0xFF55D1C1),
          backgroundColor: Color(0xFF397C75),
        ),
        const SizedBox(height: 12),
        Text(
          '已连续签到 7 天'.tr,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid();

  static const _items = [
    (Icons.medical_services_outlined, 'AI 健康咨询', '24 小时 AI 健康顾问', true),
    (Icons.smart_toy_outlined, '营养顾问', '个性化营养建议', true),
    (Icons.shield_outlined, '深度报告', '每月健康深度分析', true),
    (Icons.event_available_outlined, '优先预约', '专家问诊优先通道', true),
    (Icons.card_giftcard_outlined, '生日礼遇', '专属生日福利', true),
    (Icons.family_restroom_outlined, '家庭共享+', '升级后支持家人共享', false),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final useSingleColumn = constraints.maxWidth < 330;
      return _SectionCard(
        title: '我的权益'.tr,
        trailing: '5 / 6 已解锁'.tr,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: useSingleColumn ? 1 : 2,
            mainAxisExtent: useSingleColumn ? 136 : 150,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = _items[index];
            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: item.$4
                    ? VvewellColors.surface
                    : VvewellColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: VvewellColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.$1,
                    color: item.$4
                        ? VvewellColors.primary
                        : VvewellColors.muted,
                    size: 22,
                  ),
                  const Spacer(),
                  Text(
                    item.$2.tr,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$3.tr,
                    maxLines: 2,
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

class _DailyTasks extends StatefulWidget {
  const _DailyTasks();

  @override
  State<_DailyTasks> createState() => _DailyTasksState();
}

class _DailyTasksState extends State<_DailyTasks> {
  final completed = <int>{0, 1};

  @override
  Widget build(BuildContext context) {
    const tasks = [('每日签到', 10), ('佩戴戒指', 20), ('完成健康评估', 30), ('阅读文章', 5)];
    return _SectionCard(
      title: '每日任务'.tr,
      trailing: '${completed.length}/${tasks.length}',
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: completed.contains(index),
              onChanged: (_) => setState(() {
                completed.contains(index)
                    ? completed.remove(index)
                    : completed.add(index);
              }),
              title: Text(
                tasks[index].$1.tr,
                style: const TextStyle(fontSize: 13),
              ),
              secondary: Text(
                '+${tasks[index].$2}',
                style: const TextStyle(color: VvewellColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointsHistory extends StatelessWidget {
  const _PointsHistory();

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: '积分记录'.tr,
    trailing: '查看全部'.tr,
    child: const Column(
      children: [
        _PointRow('每日签到', '2026-08-04', '+10', VvewellColors.success),
        _PointRow('佩戴戒指', '2026-08-03', '+20', VvewellColors.success),
        _PointRow('营养评估', '2026-08-02', '+30', VvewellColors.success),
        _PointRow('兑换礼品', '2026-07-30', '-200', VvewellColors.error),
      ],
    ),
  );
}

class _PointRow extends StatelessWidget {
  const _PointRow(this.title, this.date, this.points, this.color);
  final String title;
  final String date;
  final String points;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.tr, style: const TextStyle(fontSize: 13)),
              Text(
                date,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          points,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.trailing,
    required this.child,
  });
  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: VvewellColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: VvewellColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
