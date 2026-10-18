import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../../family/presentation/controllers/family_profile_controller.dart';
import '../domain/nutrition_models.dart';
import 'nutrition_capture_sheet.dart';
import 'nutrition_demo_controller.dart';

class NutritionCenterPage extends StatefulWidget {
  const NutritionCenterPage({
    super.key,
    required this.controller,
    required this.familyProfileController,
    this.initialTab = 0,
  });

  final NutritionDemoController controller;
  final FamilyProfileController familyProfileController;
  final int initialTab;

  @override
  State<NutritionCenterPage> createState() => _NutritionCenterPageState();
}

class _NutritionCenterPageState extends State<NutritionCenterPage> {
  late int _tabIndex = widget.initialTab;
  String _shopCategory = '查看全部';
  final _questionController = TextEditingController();
  final List<_NutritionMessage> _messages = <_NutritionMessage>[];

  static const _tabs = <(String, IconData)>[
    ('评估', Icons.apple_outlined),
    ('AI 问诊', Icons.medication_outlined),
    ('追踪', Icons.trending_up_outlined),
    ('商城', Icons.shopping_cart_outlined),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _sendNutritionQuestion([String? suggestion]) {
    final question = suggestion ?? _questionController.text.trim();
    if (question.isEmpty) return;
    setState(() {
      _messages.add(_NutritionMessage(question, true));
      _messages.add(
        _NutritionMessage(
          '结合当前饮食记录与睡眠风险标签，建议先确认最近 3 天饮食、用药和过敏信息，再判断是否需要补剂。优先通过食物补充；涉及药物相互作用时请让医生或药师复核。'
              .tr,
          false,
        ),
      );
      _questionController.clear();
    });
  }

  Future<void> _captureMeal() async {
    final result = await showNutritionCaptureSheet(
      context,
      controller: widget.controller,
    );
    if (result != null && mounted) {
      _notice(
        '已将@meal记录到饮食摄入：@summary'.trParams({
          'meal': result.mealType.tr,
          'summary': '@calories kcal · 蛋白 @protein g'.trParams({
            'calories': '${result.totals.kcal.round()}',
            'protein': result.totals.protein.toStringAsFixed(1),
          }),
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.familyProfileController.activeMember;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('营养中心'.tr),
            Text(
              '@member · 个性化营养评估与补剂追踪'.trParams({'member': member.name}),
              style: const TextStyle(
                color: VvewellColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => IconButton(
              tooltip: '购物车，共 @count 件'.trParams({
                'count': '${widget.controller.cartCount}',
              }),
              onPressed: () => _notice(
                widget.controller.cartCount == 0
                    ? '购物车暂无商品'.tr
                    : '购物车已有 @count 件候选补剂'.trParams({
                        'count': '${widget.controller.cartCount}',
                      }),
              ),
              icon: Badge(
                isLabelVisible: widget.controller.cartCount > 0,
                label: Text('${widget.controller.cartCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            decoration: const BoxDecoration(
              color: VvewellColors.surface,
              border: Border(bottom: BorderSide(color: VvewellColors.border)),
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final selected = _tabIndex == index;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: selected
                          ? VvewellColors.softTeal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        key: Key('nutrition-tab-$index'),
                        onTap: () => setState(() => _tabIndex = index),
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 58,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tab.$2,
                                size: 19,
                                color: selected
                                    ? VvewellColors.primaryDark
                                    : VvewellColors.muted,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tab.$1.tr,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? VvewellColors.foreground
                                      : VvewellColors.muted,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_tabIndex) {
                0 => _buildAssessment(member.name),
                1 => _buildAiConsult(member.name),
                2 => _buildTracking(),
                _ => _buildShop(),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessment(String memberName) {
    return AnimatedBuilder(
      key: const ValueKey('nutrition-assessment'),
      animation: widget.controller,
      builder: (context, _) {
        final pending =
            widget.controller.purchasedCount -
            widget.controller.completedPurchasedCount;
        return ListView(
          key: const Key('nutrition-assessment-scroll'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (pending > 0)
              _NoticeBanner(
                icon: Icons.notifications_none_rounded,
                color: VvewellColors.warning,
                title: '今天还有 @count 种补剂未打卡'.trParams({'count': '$pending'}),
                subtitle: '按个人方案记录，不要因漏服自行加倍剂量',
                action: '去打卡',
                onTap: () => setState(() => _tabIndex = 2),
              ),
            if (pending > 0) const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: .72,
                              strokeWidth: 11,
                              backgroundColor: VvewellColors.border,
                              color: VvewellColors.primary,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '72',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '营养完成度'.tr,
                                style: TextStyle(
                                  color: VvewellColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '@member 的今日营养概况'.trParams({'member': memberName}),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.controller.intakes.isEmpty
                          ? '尚未记录餐食，完成一次图片识别后可获得更贴合的建议。'.tr
                          : '已记录 @count 餐，共 @calories kcal。'.trParams({
                              'count': '${widget.controller.intakes.length}',
                              'calories': '${widget.controller.todayCalories}',
                            }),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _captureMeal,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text('记录一餐'.tr),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _NutritionSectionTitle(
              title: '针对睡眠风险的补剂候选',
              subtitle: '根据“睡眠呼吸风险：中等”和近期睡眠不足生成，须结合用药及禁忌复核。',
            ),
            const SizedBox(height: 10),
            ...NutritionDemoController.supplements
                .where(
                  (item) => const <String>{
                    'melatonin',
                    'magnesium',
                    'b6',
                    'theanine',
                    'd3',
                  }.contains(item.id),
                )
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RecommendationRow(item: item),
                  ),
                ),
            const SizedBox(height: 8),
            const _SupplementSafetyNotice(),
          ],
        );
      },
    );
  }

  Widget _buildAiConsult(String memberName) {
    const suggestions = <String>[
      '结合我最近的睡眠状况，补剂应该怎么排时间？',
      '我今天的蛋白质和膳食纤维够吗？',
      '鱼油和正在使用的药物会冲突吗？',
      '如何优先通过食物改善营养，而不是直接买补剂？',
    ];
    return ListView(
      key: const Key('nutrition-ai-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ContextCard(
          title: '已读取 @member 的基础信息'.trParams({'member': memberName}),
          lines: const [
            '睡眠：昨晚 6 小时 30 分钟，睡眠呼吸风险为中等',
            '心血管：血压近 7 天稳定，建议 30 天内完成年度复查',
            '饮食：以今天已确认的餐食记录为准，不推断未记录内容',
          ],
        ),
        const SizedBox(height: 16),
        if (_messages.isEmpty) ...[
          const _NutritionSectionTitle(
            title: 'AI 营养顾问',
            subtitle: '可先从一个具体问题开始；回答会标明假设和需要人工复核的部分。',
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => _sendNutritionQuestion(suggestion.tr),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
                child: Text(suggestion.tr),
              ),
            ),
          ),
        ] else
          ..._messages.map((message) => _NutritionBubble(message: message)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _questionController,
                onSubmitted: (_) => _sendNutritionQuestion(),
                decoration: InputDecoration(hintText: '输入营养或补剂问题'.tr),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '发送问题'.tr,
              onPressed: _sendNutritionQuestion,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SupplementSafetyNotice(),
      ],
    );
  }

  Widget _buildTracking() {
    return AnimatedBuilder(
      key: const ValueKey('nutrition-tracking'),
      animation: widget.controller,
      builder: (context, _) => ListView(
        key: const Key('nutrition-tracking-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '今日补剂概览'.tr,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${widget.controller.completedPurchasedCount} / ${widget.controller.purchasedCount}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value:
                        widget.controller.completedPurchasedCount /
                        widget.controller.purchasedCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: VvewellColors.border,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SymptomTrackingGroup(
            title: '睡眠支持',
            subtitle: '改善睡眠规律，记录入睡与晨起感受',
            progress: .6,
            items: NutritionDemoController.supplements
                .where(
                  (item) => const <String>{
                    'melatonin',
                    'magnesium',
                    'b6',
                    'theanine',
                  }.contains(item.id),
                )
                .toList(),
            controller: widget.controller,
          ),
          const SizedBox(height: 10),
          const _CollapsedTrackingGroup(
            title: '免疫力支持',
            subtitle: '2 / 4 已完成',
            progress: .5,
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 10),
          const _CollapsedTrackingGroup(
            title: '疲劳管理',
            subtitle: '1 / 4 已完成',
            progress: .25,
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: _NutritionSectionTitle(
                  title: '全部补剂清单',
                  subtitle: '仅显示个人已购方案，可逐项记录。',
                ),
              ),
              Text(
                '${widget.controller.completedPurchasedCount} / ${widget.controller.purchasedCount}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...NutritionDemoController.supplements
              .where((item) => item.purchased)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SupplementCheckRow(
                    item: item,
                    checked: widget.controller.completedSupplementIds.contains(
                      item.id,
                    ),
                    onChanged: () =>
                        widget.controller.toggleSupplement(item.id),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            key: const Key('complete-all-supplements'),
            onPressed:
                widget.controller.completedPurchasedCount ==
                    widget.controller.purchasedCount
                ? null
                : () {
                    widget.controller.completeAllPurchased();
                    _notice('今天的已购补剂已全部打卡'.tr);
                  },
            icon: const Icon(Icons.check_circle_outline),
            label: Text('全部打卡'.tr),
          ),
          const SizedBox(height: 24),
          _NutritionSectionTitle(
            title: '今日饮食摄入',
            subtitle: widget.controller.intakes.isEmpty
                ? '还没有餐食记录'
                : '共 @count 餐 · @calories kcal'.trParams({
                    'count': '${widget.controller.intakes.length}',
                    'calories': '${widget.controller.todayCalories}',
                  }),
          ),
          const SizedBox(height: 10),
          if (widget.controller.intakes.isEmpty)
            OutlinedButton.icon(
              onPressed: _captureMeal,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text('上传第一餐'.tr),
            )
          else ...[
            ...widget.controller.intakes.map(
              (intake) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MealIntakeRow(intake: intake),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _captureMeal,
              icon: const Icon(Icons.add),
              label: Text('继续记录餐食'.tr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShop() {
    final products = NutritionDemoController.supplements.where((item) {
      return _shopCategory == '查看全部' || item.category == _shopCategory;
    }).toList();
    return AnimatedBuilder(
      key: const ValueKey('nutrition-shop'),
      animation: widget.controller,
      builder: (context, _) => ListView(
        key: const Key('nutrition-shop-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _NutritionSectionTitle(
            title: '补剂商城',
            subtitle: '候选商品不等于医疗建议；购买前核对成分、剂量、用药和禁忌。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <String>['查看全部', '维生素', '镁', '睡眠', 'Omega-3', '抗氧化']
                  .map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.tr),
                        selected: _shopCategory == category,
                        onSelected: (_) =>
                            setState(() => _shopCategory = category),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VvewellColors.softMint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: VvewellColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '展示批次、成分与第三方检测信息 · Mock 商品不产生真实订单'.tr,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final useSingleColumn = constraints.maxWidth < 340;
              final width = useSingleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: products
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _ProductCard(
                          item: item,
                          onAdd: () {
                            widget.controller.addToCart(item.id);
                            _notice(
                              '@item 已加入候选购物车'.trParams({'item': item.name.tr}),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NutritionSectionTitle extends StatelessWidget {
  const _NutritionSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle.tr,
          style: const TextStyle(
            color: VvewellColors.muted,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.tr,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onTap, child: Text(action.tr)),
        ],
      ),
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.item});

  final SupplementItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VvewellColors.softTeal,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 20,
              color: VvewellColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.name.tr}  ${item.dose.tr}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.timing.tr} · ${item.purpose.tr}',
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                    height: 1.4,
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

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_search_outlined,
                color: Color(0xFF3A8DD9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '· ${line.tr}',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionMessage {
  const _NutritionMessage(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class _NutritionBubble extends StatelessWidget {
  const _NutritionBubble({required this.message});

  final _NutritionMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: message.isUser ? VvewellColors.primary : VvewellColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: message.isUser
              ? null
              : Border.all(color: VvewellColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : VvewellColors.foreground,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _SymptomTrackingGroup extends StatelessWidget {
  const _SymptomTrackingGroup({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.items,
    required this.controller,
  });

  final String title;
  final String subtitle;
  final double progress;
  final List<SupplementItem> items;
  final NutritionDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  color: VvewellColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle.tr,
                        style: const TextStyle(
                          color: VvewellColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text('${(progress * 5).round()}/5'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: VvewellColors.border,
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: controller.completedSupplementIds.contains(item.id),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('${item.name.tr}  ${item.dose.tr}'),
                subtitle: Text(item.timing.tr),
                onChanged: (_) => controller.toggleSupplement(item.id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedTrackingGroup extends StatelessWidget {
  const _CollapsedTrackingGroup({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: VvewellColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                  backgroundColor: VvewellColors.border,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            subtitle.tr,
            style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SupplementCheckRow extends StatelessWidget {
  const _SupplementCheckRow({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  final SupplementItem item;
  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VvewellColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: VvewellColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: checked,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('${item.name.tr}  ${item.dose.tr}'),
        subtitle: Text(item.timing.tr),
        secondary: checked
            ? const Icon(
                Icons.check_circle_outline,
                color: VvewellColors.success,
              )
            : null,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _MealIntakeRow extends StatelessWidget {
  const _MealIntakeRow({required this.intake});

  final NutritionIntakeRecord intake;

  @override
  Widget build(BuildContext context) {
    final hour = intake.recordedAt.hour.toString().padLeft(2, '0');
    final minute = intake.recordedAt.minute.toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant_outlined, color: VvewellColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intake.mealType.tr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  intake.foods.map((food) => food.name.tr).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${'@calories kcal · 蛋白 @protein g'.trParams({'calories': '${intake.totals.kcal.round()}', 'protein': intake.totals.protein.toStringAsFixed(1)})}\n$hour:$minute',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.onAdd});

  final SupplementItem item;
  final VoidCallback onAdd;

  static const _tones = <Color>[
    Color(0xFFBDE3F4),
    Color(0xFFBDEDE6),
    Color(0xFFC9EEDC),
    Color(0xFFF5E4B7),
    Color(0xFFDCD0F2),
    Color(0xFFF3D7A8),
    Color(0xFFCFE6E3),
    Color(0xFFF3CCCC),
    Color(0xFFEBD9B9),
    Color(0xFFF1C5B8),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: VvewellColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VvewellColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: ColoredBox(
              color: _tones[item.tone % _tones.length],
              child: const Center(
                child: Icon(
                  Icons.medication_outlined,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (item.badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: VvewellColors.softTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.badge.tr,
                          style: const TextStyle(
                            color: VvewellColors.primaryDark,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Vvewell · ${item.dose}',
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¥${item.price}',
                            style: const TextStyle(
                              color: VvewellColors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '¥${item.originalPrice}',
                            style: const TextStyle(
                              color: VvewellColors.muted,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      key: Key('add-to-cart-${item.id}'),
                      tooltip: '加入购物车'.tr,
                      onPressed: onAdd,
                      constraints: const BoxConstraints.tightFor(
                        width: 42,
                        height: 42,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplementSafetyNotice extends StatelessWidget {
  const _SupplementSafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VvewellColors.softOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: VvewellColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '补剂推荐是健康管理候选，不用于诊断或治疗。孕期、慢病、肝肾功能异常、手术前或正在用药时，应先由医生或药师复核。'.tr,
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
