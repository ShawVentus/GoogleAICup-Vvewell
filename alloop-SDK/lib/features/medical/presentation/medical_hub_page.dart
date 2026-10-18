import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../../family/presentation/controllers/family_profile_controller.dart';
import '../../family/presentation/pages/health_record_page.dart';
import 'medical_flow_sheets.dart';

class MedicalHubPage extends StatefulWidget {
  const MedicalHubPage({
    super.key,
    required this.familyProfileController,
    required this.header,
  });

  final FamilyProfileController familyProfileController;
  final Widget header;

  @override
  State<MedicalHubPage> createState() => _MedicalHubPageState();
}

class _MedicalHubPageState extends State<MedicalHubPage> {
  int _tabIndex = 0;
  int _selectedService = 0;
  ReferralIntakeResult? _referral;
  bool _quoteConfirmed = false;
  InsuranceNeedsResult? _insuranceNeeds;
  ClaimDraftResult? _claimDraft;
  String _communityQuery = '';
  final TextEditingController _communitySearchController =
      TextEditingController();
  String _communityTopic = '推荐';
  final Set<String> _joinedCommunities = <String>{
    'diabetes',
    'mental-wellness',
  };
  final Set<String> _bookmarkedPosts = <String>{};
  final List<CommunityPostDraft> _newPosts = <CommunityPostDraft>[];
  bool _eventRegistered = false;
  String _providerLocation = '北京';
  String _providerDepartment = '心内科';

  @override
  void dispose() {
    _communitySearchController.dispose();
    super.dispose();
  }

  static const _services = <_MedicalService>[
    _MedicalService(
      title: '专家问诊',
      subtitle: '专科医师及全球医学专家意见，适用于复杂病症',
      price: '¥500 - ¥5,000',
      icon: Icons.medical_services_outlined,
      includes: ['全球专家匹配', '视频问诊协调', '多语言支持', '第二诊疗意见整理'],
      excludes: '医生或医院另收的挂号诊金、检查费和药品费',
    ),
    _MedicalService(
      title: '专项检查',
      subtitle: '精密诊断检测与专科医学检查的预约协调',
      price: '¥2,000 - ¥8,000',
      icon: Icons.document_scanner_outlined,
      includes: ['MRI / CT 协调', '基因检测协调', '专科化验协调', '结果归档'],
      excludes: '医院检查费、造影剂、麻醉、耗材和复诊诊金另付医院',
    ),
    _MedicalService(
      title: '全球转诊',
      subtitle: '跨境医疗转诊全流程协调与支持',
      price: '¥2,000 - ¥10,000',
      icon: Icons.public,
      includes: ['国际医院准入', '医疗签证材料', '行程协调', '专属个案经理'],
      excludes: '医院诊疗、签证规费、机票、酒店和交通不包含',
    ),
  ];

  static const _plans = <_InsurancePlan>[
    _InsurancePlan(
      name: 'Premium Health Shield',
      provider: '平安健康险',
      match: 95,
      price: '¥4,200 / 年',
      coverage: '¥1,000,000',
      p50: '¥4,800',
      p90: '¥12,000',
      p95: '¥18,000',
      deductible: '¥10,000',
      waiting: '90 天',
      fit: '住院医疗缺口覆盖较高，常用医院网络匹配',
      limit: '既往症和等待期以正式条款与核保结果为准',
    ),
    _InsurancePlan(
      name: 'Family Care Plus',
      provider: '太平洋健康险',
      match: 87,
      price: '¥2,800 / 年',
      coverage: '¥500,000',
      p50: '¥3,200',
      p90: '¥8,000',
      p95: '¥14,000',
      deductible: '¥5,000',
      waiting: '30 天',
      fit: '门诊与意外保障均衡，年度预算压力较低',
      limit: '部分专科医院为网络外，预计自付区间更宽',
    ),
    _InsurancePlan(
      name: 'Critical Illness Guard',
      provider: '中国人寿',
      match: 82,
      price: '¥1,800 / 年',
      coverage: '¥300,000',
      p50: '¥1,800',
      p90: '¥5,000',
      p95: '¥8,000',
      deductible: '无',
      waiting: '180 天',
      fit: '补充重大疾病一次性给付，降低家庭收入责任缺口',
      limit: '不替代医疗险；健康告知需由持牌机构正式审核',
    ),
  ];

  static const _communities = <_Community>[
    _Community(
      id: 'breast-cancer',
      name: '乳腺癌康友社区',
      description: '围绕治疗经验、康复随访、用药副作用和心理支持的私密交流空间',
      members: '2,340',
      posts: '892',
      topic: '肿瘤康复',
      verified: true,
    ),
    _Community(
      id: 'diabetes',
      name: '糖尿病管理',
      description: '分享饮食、运动、用药依从和日常管理经验',
      members: '5,120',
      posts: '3,201',
      topic: '慢病管理',
      verified: true,
    ),
    _Community(
      id: 'heart-health',
      name: '心脏健康',
      description: '心血管疾病预防、复诊和康复支持',
      members: '1,890',
      posts: '654',
      topic: '心血管',
      verified: true,
    ),
    _Community(
      id: 'mental-wellness',
      name: '心理与生活',
      description: '情绪支持、家庭沟通、工作与生活适应',
      members: '8,760',
      posts: '12,450',
      topic: '心理支持',
      verified: true,
    ),
    _Community(
      id: 'rare-disease',
      name: '罕见病互助网络',
      description: '与相似经历的人交流就医信息、资源和照护经验',
      members: '890',
      posts: '234',
      topic: '罕见病',
      verified: true,
    ),
  ];

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.tr)));
  }

  Future<void> _requestAdvisor(String productName) async {
    final result = await showAdvisorContactSheet(
      context,
      memberName: widget.familyProfileController.activeMember.name.tr,
      productName: productName,
    );
    if (result == null || !mounted) return;
    _notice(
      '${result.name} 的回访申请已提交，顾问将按“${result.preferredTime}”通过${result.contactChannel}联系',
    );
  }

  List<_ProviderRecommendation> get _providerRecommendations {
    final hospitals = switch (_providerLocation) {
      '上海' => const ['上海交通大学医学院附属瑞金医院', '复旦大学附属中山医院'],
      '新加坡' => const ['Singapore General Hospital', 'Mount Elizabeth Hospital'],
      '美国' => const ['Mayo Clinic', 'Cleveland Clinic'],
      _ => const ['北京协和医院', '中国医学科学院阜外医院'],
    };
    final waits = switch (_providerLocation) {
      '上海' => const ['预计 5 天可约', '预计 8 天可约'],
      '新加坡' => const ['预计 9 天可约', '预计 7 天可约'],
      '美国' => const ['预计 12 天可约', '预计 15 天可约'],
      _ => const ['预计 6 天可约', '预计 4 天可约'],
    };
    final reasons = switch (_providerDepartment) {
      '呼吸与睡眠' => const ['睡眠呼吸亚专科匹配；可承接睡眠监测与多学科评估', '呼吸睡眠联合门诊；便于从风险筛查进入专业诊断'],
      '内分泌科' => const ['代谢与营养风险联合评估；可结合检验与连续监测', '糖脂代谢专科能力匹配；支持长期随访计划'],
      '肿瘤科' => const ['复杂病例多学科讨论；支持病理与影像复核', '诊疗连续性较高；支持第二诊疗意见整理'],
      _ => const ['与年度心血管复查标签高度匹配；支持复杂心血管评估', '心血管专科能力突出；可承接进一步分层检查与长期随访'],
    };
    return List.generate(
      2,
      (index) => _ProviderRecommendation(
        name: '${hospitals[index].tr} · ${_providerDepartment.tr}',
        location: '${_providerLocation.tr} · ${waits[index].tr}',
        reason: reasons[index].tr,
        evidence: index == 0
            ? '档案标签匹配 96% · 报告闭环率 94% · 网络状态待核验'.tr
            : '档案标签匹配 88% · 号源更新于 15 分钟前 · 预计自付待评估'.tr,
        score: index == 0 ? 96 : 88,
      ),
    );
  }

  Future<void> _startReferral({String initialChannel = '线下门诊'}) async {
    final result = await showReferralIntakeSheet(
      context,
      memberName: widget.familyProfileController.activeMember.name.tr,
      initialChannel: initialChannel,
    );
    if (result == null || !mounted) return;
    setState(() {
      _referral = result;
      _quoteConfirmed = false;
    });
    _notice('送诊资料已提交，将在 1 个工作日内完成初审');
  }

  Future<void> _confirmQuote() async {
    final service = _services[_selectedService];
    final confirmed = await showQuoteConfirmationSheet(
      context,
      serviceName: service.title,
      serviceFee: service.price,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _quoteConfirmed = true);
    _notice('费用边界已确认，下一步为协议签署；当前未发起真实支付');
  }

  Future<void> _planInsurance() async {
    final result = await showInsuranceNeedsSheet(
      context,
      memberName: widget.familyProfileController.activeMember.name.tr,
    );
    if (result == null || !mounted) return;
    setState(() => _insuranceNeeds = result);
    _notice('保障需求已更新，候选方案将交由持牌顾问复核');
  }

  Future<void> _createClaim() async {
    final result = await showClaimDraftSheet(
      context,
      memberName: widget.familyProfileController.activeMember.name.tr,
    );
    if (result == null || !mounted) return;
    setState(() => _claimDraft = result);
    _notice('理赔草稿已保存，提交前请继续核对材料与抽取字段');
  }

  Future<void> _createPost() async {
    final community = _communities.firstWhere(
      (item) => _joinedCommunities.contains(item.id),
      orElse: () => _communities.first,
    );
    if (!_joinedCommunities.contains(community.id)) {
      _notice('请先加入一个社区再发布内容');
      return;
    }
    final result = await showCommunityPostSheet(
      context,
      communityName: community.name.tr,
    );
    if (result == null || !mounted) return;
    setState(() => _newPosts.insert(0, result));
    _notice('内容已通过基础隐私检查并发布');
  }

  Future<void> _toggleCommunity(_Community community) async {
    if (_joinedCommunities.contains(community.id)) {
      setState(() => _joinedCommunities.remove(community.id));
      _notice(
        '已退出@community，社区通知同时关闭'.trParams({'community': community.name.tr}),
      );
      return;
    }
    final confirmed = await _showCommunityJoinConsent(context, community);
    if (confirmed != true || !mounted) return;
    setState(() => _joinedCommunities.add(community.id));
    _notice('已使用匿名别名加入@community'.trParams({'community': community.name.tr}));
  }

  void _resetCommunitySearch() {
    _communitySearchController.clear();
    setState(() => _communityQuery = '');
  }

  Future<void> _shareNeutralCommunityLink() async {
    await Clipboard.setData(
      const ClipboardData(text: 'https://vvewell.example/community/invite'),
    );
    if (!mounted) return;
    _notice('已复制不包含病种名称的站内邀请链接');
  }

  Future<void> _replyToCommunityPost() async {
    final reply = await _showCommunityReplySheet(context);
    if (reply == null || !mounted) return;
    _notice('回复已使用匿名别名发布');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('medical-hub-scroll-view'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        widget.header,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _MemberContextCard(controller: widget.familyProfileController),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _HubTabs(
            index: _tabIndex,
            onChanged: (value) => setState(() => _tabIndex = value),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_tabIndex) {
            0 => _buildReferralTab(),
            1 => _buildInsuranceTab(),
            _ => _buildCommunityTab(),
          },
        ),
      ],
    );
  }

  Widget _buildReferralTab() {
    final selectedService = _services[_selectedService];
    return Padding(
      key: const ValueKey('referral-tab'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionGrid(
            onEmergency: () => _showEmergencyDialog(context),
            onSupport: () => _notice('专属顾问将在服务时段内联系你'),
            onReferral: _startReferral,
            onGlobal: () => _startReferral(initialChannel: '跨境医疗'),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: '推荐服务',
            subtitle: '基于当前档案给出方向性建议，临床安全与资质硬门不会因价格或偏好放宽。',
          ),
          const SizedBox(height: 10),
          _RecommendationCard(
            memberName: widget.familyProfileController.activeMember.name.tr,
            onTap: _startReferral,
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: '选择一个主服务',
            subtitle: '每个服务单只能选择一个主服务。医院与第三方费用始终独立。',
          ),
          const SizedBox(height: 10),
          ...List.generate(
            _services.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceCard(
                service: _services[index],
                selected: _selectedService == index,
                onSelected: () => setState(() => _selectedService = index),
                onStart: () => _startReferral(
                  initialChannel: index == 2 ? '跨境医疗' : '线下门诊',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ReferralJourneyCard(
            referral: _referral,
            quoteConfirmed: _quoteConfirmed,
            service: selectedService,
            onStart: _startReferral,
            onQuote: _confirmQuote,
            onHospitalCosts: () => _showHospitalCostSheet(context),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: '候选医疗资源',
            subtitle: '已根据健康标签预选地点与科室，可修改后重新排序。候选卡展示适配理由、时限、证据和未知项。',
          ),
          const SizedBox(height: 10),
          _ProviderFilters(
            location: _providerLocation,
            department: _providerDepartment,
            onLocationChanged: (value) =>
                setState(() => _providerLocation = value),
            onDepartmentChanged: (value) =>
                setState(() => _providerDepartment = value),
          ),
          const SizedBox(height: 10),
          ..._providerRecommendations.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProviderCard(
                name: entry.value.name,
                location: entry.value.location,
                reason: entry.value.reason,
                evidence: entry.value.evidence,
                matchScore: entry.value.score,
                recommended: entry.key == 0,
                onTap: () => _showProviderDetails(context, entry.value.name),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const _MedicalSafetyFooter(),
        ],
      ),
    );
  }

  Widget _buildInsuranceTab() {
    return Padding(
      key: const ValueKey('insurance-tab'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsuranceHero(
            memberName: widget.familyProfileController.activeMember.name.tr,
            needs: _insuranceNeeds,
            onPlan: _planInsurance,
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: '保障缺口分析',
            subtitle: '目标、已有保障和缺口按责任类型分开显示，不以单一综合分替代。',
          ),
          const SizedBox(height: 10),
          _CoverageGapCard(
            title: '重大疾病',
            current: '¥100,000',
            target: '¥500,000',
            gap: '¥400,000',
            progress: .2,
            risk: '高',
            color: VvewellColors.error,
          ),
          const SizedBox(height: 10),
          _CoverageGapCard(
            title: '医疗险',
            current: '¥50,000',
            target: '¥200,000',
            gap: '¥150,000',
            progress: .25,
            risk: '中',
            color: VvewellColors.warning,
          ),
          const SizedBox(height: 10),
          _CoverageGapCard(
            title: '意外险',
            current: '¥200,000',
            target: '¥300,000',
            gap: '¥100,000',
            progress: .67,
            risk: '低',
            color: VvewellColors.success,
          ),
          const SizedBox(height: 24),
          const _SectionHeading(
            title: '推荐保障方案',
            subtitle: '仅展示通过资格与适当性初筛的候选；匹配度不会替代具体理由。',
          ),
          const SizedBox(height: 10),
          ..._plans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanCard(
                plan: plan,
                onDetails: () => _showPlanDetails(
                  context,
                  plan,
                  memberName:
                      widget.familyProfileController.activeMember.name.tr,
                  onSubmitted: (result) => _notice(
                    '${result.name} 的回访申请已提交，顾问将通过${result.contactChannel}联系',
                  ),
                ),
                onAdvisor: () => _requestAdvisor(plan.name),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PolicyServiceCard(
            claim: _claimDraft,
            onCreateClaim: _createClaim,
            onPreauthorization: () async {
              final result = await showClaimDraftSheet(
                context,
                memberName: widget.familyProfileController.activeMember.name.tr,
                initialType: '预授权申请',
              );
              if (result != null && mounted) {
                setState(() => _claimDraft = result);
              }
            },
          ),
          const SizedBox(height: 14),
          const _InsuranceBoundaryNotice(),
        ],
      ),
    );
  }

  Widget _buildCommunityTab() {
    final query = _communityQuery.trim().toLowerCase();
    final communities = _communities.where((community) {
      if (query.isEmpty) return true;
      return community.name.tr.toLowerCase().contains(query) ||
          community.name.toLowerCase().contains(query) ||
          community.topic.tr.toLowerCase().contains(query) ||
          community.topic.toLowerCase().contains(query) ||
          community.description.tr.toLowerCase().contains(query) ||
          community.description.toLowerCase().contains(query);
    }).toList();
    return Padding(
      key: const ValueKey('community-tab'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: '康友社区'.tr,
            subtitle: '安全、私密的经验交流空间。社区不是诊疗场所，不提供个体诊断或处方。'.tr,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('community-search'),
            controller: _communitySearchController,
            onChanged: (value) => setState(() => _communityQuery = value),
            decoration: InputDecoration(
              hintText: '搜索社区、病种或主题'.tr,
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  ['推荐', '最新', '治疗经验', '康复随访', '用药副作用', '心理生活', '问答', '活动']
                      .map(
                        (topic) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(topic.tr),
                            selected: _communityTopic == topic,
                            onSelected: (_) =>
                                setState(() => _communityTopic = topic),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (communities.isEmpty)
            _CommunityEmptyState(onReset: _resetCommunitySearch)
          else
            ...communities.map(
              (community) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CommunityCard(
                  community: community,
                  joined: _joinedCommunities.contains(community.id),
                  onJoin: () => _toggleCommunity(community),
                  onDetails: () => _showCommunityRules(context, community),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SectionHeading(
                  title: '社区动态'.tr,
                  subtitle: '优先有帮助的回应、内容质量与成员安全。'.tr,
                ),
              ),
              IconButton.filled(
                key: const Key('create-community-post'),
                tooltip: '发布内容'.tr,
                onPressed: _createPost,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._newPosts.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommunityPostCard(
                id: 'new-${entry.key}',
                author: '晨光 27',
                type: entry.value.type,
                content: entry.value.content,
                bookmarked: _bookmarkedPosts.contains('new-${entry.key}'),
                onBookmark: () => setState(() {
                  final id = 'new-${entry.key}';
                  _bookmarkedPosts.contains(id)
                      ? _bookmarkedPosts.remove(id)
                      : _bookmarkedPosts.add(id);
                }),
                onReport: () => _showReportDialog(context),
                onReply: _replyToCommunityPost,
                onShare: _shareNeutralCommunityLink,
              ),
            ),
          ),
          _CommunityPostCard(
            id: 'featured-1',
            author: '小满 · 认证康友',
            type: _communityTopic == '推荐' ? '康复与随访' : _communityTopic,
            content: '治疗结束后的第一次复查，我把医生要求的资料、检查顺序和当天的准备事项整理成了清单，希望能帮到正在准备的朋友。',
            translateContent: true,
            bookmarked: _bookmarkedPosts.contains('featured-1'),
            onBookmark: () => setState(() {
              _bookmarkedPosts.contains('featured-1')
                  ? _bookmarkedPosts.remove('featured-1')
                  : _bookmarkedPosts.add('featured-1');
            }),
            onReport: () => _showReportDialog(context),
            onReply: _replyToCommunityPost,
            onShare: _shareNeutralCommunityLink,
          ),
          const SizedBox(height: 16),
          _CommunityEventCard(
            registered: _eventRegistered,
            onToggle: () =>
                setState(() => _eventRegistered = !_eventRegistered),
          ),
          const SizedBox(height: 14),
          const _CommunityPrivacyNotice(),
        ],
      ),
    );
  }
}

class _MemberContextCard extends StatelessWidget {
  const _MemberContextCard({required this.controller});

  final FamilyProfileController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final member = controller.activeMember;
        return Material(
          color: VvewellColors.softTeal,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => HealthRecordPage(controller: controller),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_outline,
                      color: VvewellColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前服务档案'.tr,
                          style: const TextStyle(
                            color: VvewellColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${member.name.tr} · ${member.relationship.tr}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '查看档案'.tr,
                    style: const TextStyle(
                      color: VvewellColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: VvewellColors.primaryDark,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HubTabs extends StatelessWidget {
  const _HubTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <(String, IconData)>[
      ('送诊服务', Icons.medical_services_outlined),
      ('保险服务', Icons.shield_outlined),
      ('康友社区', Icons.groups_outlined),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(items.length, (itemIndex) {
          final selected = index == itemIndex;
          return Expanded(
            child: Material(
              color: selected ? VvewellColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                key: Key('medical-hub-tab-$itemIndex'),
                onTap: () => onChanged(itemIndex),
                borderRadius: BorderRadius.circular(9),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[itemIndex].$2,
                        size: 19,
                        color: selected
                            ? VvewellColors.primaryDark
                            : VvewellColors.muted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[itemIndex].$1.tr,
                        style: TextStyle(
                          color: selected
                              ? VvewellColors.foreground
                              : VvewellColors.muted,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onEmergency,
    required this.onSupport,
    required this.onReferral,
    required this.onGlobal,
  });

  final VoidCallback onEmergency;
  final VoidCallback onSupport;
  final VoidCallback onReferral;
  final VoidCallback onGlobal;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.25,
      children: [
        _ActionTile(
          label: '紧急帮助',
          icon: Icons.warning_amber_rounded,
          color: VvewellColors.error,
          onTap: onEmergency,
        ),
        _ActionTile(
          label: '在线客服',
          icon: Icons.support_agent_outlined,
          color: const Color(0xFF3A8DD9),
          onTap: onSupport,
        ),
        _ActionTile(
          key: const Key('start-referral'),
          label: '发起送诊',
          icon: Icons.assignment_outlined,
          color: VvewellColors.primary,
          onTap: onReferral,
        ),
        _ActionTile(
          label: '跨境医疗',
          icon: Icons.public,
          color: VvewellColors.success,
          onTap: onGlobal,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: .1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: .2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.memberName, required this.onTap});

  final String memberName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VvewellColors.softTeal,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _StatusLabel(
                    label: '档案建议',
                    color: VvewellColors.primary,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.medical_services_outlined,
                    color: VvewellColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '先完成计划性专科评估'.tr,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '@member 的健康档案显示年度心血管复查即将到期。建议 30 天内评估；若出现胸痛、严重呼吸困难或意识改变，请立即升级处理。'
                    .trParams({'member': memberName}),
                style: const TextStyle(
                  color: VvewellColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatusLabel(label: 'A3 计划就诊'),
                  _StatusLabel(label: '有效期 30 天'),
                  _StatusLabel(label: '可人工复核'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.selected,
    required this.onSelected,
    required this.onStart,
  });

  final _MedicalService service;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? VvewellColors.softTeal : VvewellColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? VvewellColors.primary : VvewellColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBox(icon: service.icon, color: VvewellColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                service.title.tr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (selected)
                              const _StatusLabel(
                                label: '已选择',
                                color: VvewellColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.subtitle.tr,
                          style: const TextStyle(
                            color: VvewellColors.muted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.price.tr,
                          style: const TextStyle(
                            color: VvewellColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: service.includes
                    .map((item) => _StatusLabel(label: item))
                    .toList(),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: VvewellColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      service.excludes.tr,
                      style: const TextStyle(
                        color: VvewellColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSelected,
                      child: Text((selected ? '当前选择' : '选择服务').tr),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onStart,
                      child: Text('开始评估'.tr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferralJourneyCard extends StatelessWidget {
  const _ReferralJourneyCard({
    required this.referral,
    required this.quoteConfirmed,
    required this.service,
    required this.onStart,
    required this.onQuote,
    required this.onHospitalCosts,
  });

  final ReferralIntakeResult? referral;
  final bool quoteConfirmed;
  final _MedicalService service;
  final VoidCallback onStart;
  final VoidCallback onQuote;
  final VoidCallback onHospitalCosts;

  @override
  Widget build(BuildContext context) {
    if (referral == null) {
      return _EmptyActionCard(
        icon: Icons.route_outlined,
        title: '我的就诊进度',
        description: '完成建档与初筛后，可在这里查看平台、医院直付和资料三类待办。',
        actionLabel: '发起送诊',
        onAction: onStart,
      );
    }
    final progress = quoteConfirmed ? .35 : .18;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的就诊进度',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusLabel(
                  label: quoteConfirmed ? '待签协议' : '资料初审',
                  color: VvewellColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: VvewellColors.border,
            ),
            const SizedBox(height: 8),
            Text(
              quoteConfirmed
                  ? '费用边界已确认 · 等待协议签署'
                  : '${referral!.urgency} · ${referral!.channel} · 顾问将在 1 个工作日内初审',
              style: const TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _TaskRow(
              icon: Icons.assignment_outlined,
              title: '资料待办',
              detail: referral!.hasRecords ? '上传病历资料包' : '补充既往诊疗资料（如有）',
              status: '待完成',
            ),
            const Divider(height: 24),
            _TaskRow(
              icon: Icons.support_agent_outlined,
              title: '平台服务待办',
              detail: quoteConfirmed
                  ? '专属顾问：林顾问 · 预计今天 18:00 前'
                  : '确认 ${service.title} 服务方案与单笔报价',
              status: quoteConfirmed ? '处理中' : '待确认',
            ),
            const Divider(height: 24),
            const _TaskRow(
              icon: Icons.account_balance_outlined,
              title: '医院直付待办',
              detail: '医院尚未回传预算或正式付款指引',
              status: '暂无预算',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onHospitalCosts,
                    child: const Text('医院费用中心'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: quoteConfirmed ? null : onQuote,
                    child: Text(quoteConfirmed ? '已确认费用边界' : '查看服务方案'),
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

class _ProviderFilters extends StatelessWidget {
  const _ProviderFilters({
    required this.location,
    required this.department,
    required this.onLocationChanged,
    required this.onDepartmentChanged,
  });

  final String location;
  final String department;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<String> onDepartmentChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softTeal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VvewellColors.primary.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: VvewellColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已根据“血压趋势稳定”和“30 天内心血管复查”自动预选'.tr,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 330;
              final locationField = DropdownButtonFormField<String>(
                key: const Key('provider-location-filter'),
                initialValue: location,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '地点'.tr,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                items: const ['北京', '上海', '新加坡', '美国']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value.tr)),
                    )
                    .toList(),
                onChanged: (value) => onLocationChanged(value!),
              );
              final departmentField = DropdownButtonFormField<String>(
                key: const Key('provider-department-filter'),
                initialValue: department,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '科室'.tr,
                  prefixIcon: const Icon(Icons.local_hospital_outlined),
                ),
                items: const ['心内科', '呼吸与睡眠', '内分泌科', '肿瘤科']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value.tr)),
                    )
                    .toList(),
                onChanged: (value) => onDepartmentChanged(value!),
              );
              if (narrow) {
                return Column(
                  children: [
                    locationField,
                    const SizedBox(height: 10),
                    departmentField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: locationField),
                  const SizedBox(width: 10),
                  Expanded(child: departmentField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.name,
    required this.location,
    required this.reason,
    required this.evidence,
    required this.matchScore,
    required this.recommended,
    required this.onTap,
  });

  final String name;
  final String location;
  final String reason;
  final String evidence;
  final int matchScore;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recommended) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: VvewellColors.softMint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '最优推荐'.tr,
                        style: const TextStyle(
                          color: VvewellColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '标签匹配 @score%'.trParams({'score': '$matchScore'}),
                      style: const TextStyle(
                        color: VvewellColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  const _IconBox(
                    icon: Icons.local_hospital_outlined,
                    color: VvewellColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          location,
                          style: const TextStyle(
                            color: VvewellColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '为什么适合：@reason'.trParams({'reason': reason}),
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 5),
              Text(
                evidence,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsuranceHero extends StatelessWidget {
  const _InsuranceHero({
    required this.memberName,
    required this.needs,
    required this.onPlan,
  });

  final String memberName;
  final InsuranceNeedsResult? needs;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VvewellColors.softBlue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBox(
                  icon: Icons.health_and_safety_outlined,
                  color: Color(0xFF3A8DD9),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '家庭保障规划'.tr,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              needs == null
                  ? '@member 现有保单、家庭责任及可持续预算概览，可生成保障缺口分析和三项候选方案。'.trParams({
                      'member': memberName,
                    })
                  : '已按“@priority”更新需求，年度预算 ¥@budget。'.trParams({
                      'priority': needs!.priority.tr,
                      'budget': '${needs!.annualBudget}',
                    }),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('start-insurance-planning'),
                onPressed: onPlan,
                icon: const Icon(Icons.calculate_outlined),
                label: Text(needs == null ? '开始保障规划'.tr : '调整预算与优先级'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageGapCard extends StatelessWidget {
  const _CoverageGapCard({
    required this.title,
    required this.current,
    required this.target,
    required this.gap,
    required this.progress,
    required this.risk,
    required this.color,
  });

  final String title;
  final String current;
  final String target;
  final String gap;
  final double progress;
  final String risk;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.tr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusLabel(label: risk, color: color),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
              color: color,
              backgroundColor: VvewellColors.border,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '@label @amount'.trParams({
                      'label': '已有保障'.tr,
                      'amount': current,
                    }),
                    style: const TextStyle(
                      color: VvewellColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '@label @amount'.trParams({
                    'label': '目标'.tr,
                    'amount': target,
                  }),
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '缺口金额：@amount'.trParams({'amount': gap}),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.onDetails,
    required this.onAdvisor,
  });

  final _InsurancePlan plan;
  final VoidCallback onDetails;
  final VoidCallback onAdvisor;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: plan.match >= 90
              ? VvewellColors.primary
              : VvewellColors.border,
          width: plan.match >= 90 ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: VvewellColors.softTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${plan.match}%',
                    style: const TextStyle(
                      color: VvewellColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@provider · @price · 保额 @coverage'.trParams({
                          'provider': plan.provider.tr,
                          'price': plan.price.tr,
                          'coverage': plan.coverage.tr,
                        }),
                        style: const TextStyle(
                          color: VvewellColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (plan.match >= 90)
                  const _StatusLabel(label: '优选', color: VvewellColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '适配：@fit'.trParams({'fit': plan.fit.tr}),
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VvewellColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _CostMetric(label: 'P50', value: plan.p50.tr),
                  ),
                  Expanded(
                    child: _CostMetric(label: 'P90', value: plan.p90.tr),
                  ),
                  Expanded(
                    child: _CostMetric(label: 'P95', value: plan.p95.tr),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '限制：@limit'.trParams({'limit': plan.limit.tr}),
              style: const TextStyle(
                color: VvewellColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetails,
                    child: Text('查看条款与成本'.tr),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    key: Key('advisor-contact-${plan.name}'),
                    onPressed: onAdvisor,
                    child: Text('持牌顾问复核'.tr),
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

class _PolicyServiceCard extends StatelessWidget {
  const _PolicyServiceCard({
    required this.claim,
    required this.onCreateClaim,
    required this.onPreauthorization,
  });

  final ClaimDraftResult? claim;
  final VoidCallback onCreateClaim;
  final VoidCallback onPreauthorization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: '保单与理赔服务',
          subtitle: '合同事实、材料、预授权、进度与申诉入口集中管理。',
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TaskRow(
                  icon: Icons.verified_user_outlined,
                  title: '医疗险 · 保单有效'.tr,
                  detail: '免赔进度 ¥3,500 / ¥10,000 · 等待期已结束'.tr,
                  status: '有效'.tr,
                ),
                const Divider(height: 24),
                _TaskRow(
                  icon: Icons.description_outlined,
                  title: claim?.type.tr ?? '暂无理赔草稿'.tr,
                  detail: claim == null
                      ? '上传材料后可查看完整度、责任人、SLA 和下一步'.tr
                      : '申请金额 ¥@amount · 草稿待核对字段'.trParams({
                          'amount': '${claim!.amount}',
                        }),
                  status: claim == null ? '待创建'.tr : '草稿'.tr,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPreauthorization,
                        child: Text('预授权'.tr),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('create-claim-draft'),
                        onPressed: onCreateClaim,
                        icon: const Icon(Icons.add),
                        label: Text('新建理赔'.tr),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.joined,
    required this.onJoin,
    required this.onDetails,
  });

  final _Community community;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
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
                  child: InkWell(
                    onTap: onDetails,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                community.name.tr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (community.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_outlined,
                                size: 18,
                                color: VvewellColors.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          community.description.tr,
                          style: const TextStyle(
                            color: VvewellColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 42,
                  child: joined
                      ? OutlinedButton(
                          key: Key('join-community-${community.id}'),
                          onPressed: onJoin,
                          child: Text('已加入'.tr),
                        )
                      : ElevatedButton(
                          key: Key('join-community-${community.id}'),
                          onPressed: onJoin,
                          child: Text('加入'.tr),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(
                  '@count 成员'.trParams({'count': community.members}),
                  style: const TextStyle(color: VvewellColors.muted),
                ),
                Text(
                  '@count 帖子'.trParams({'count': community.posts}),
                  style: const TextStyle(color: VvewellColors.muted),
                ),
                _StatusLabel(label: community.topic),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.id,
    required this.author,
    required this.type,
    required this.content,
    this.translateContent = false,
    required this.bookmarked,
    required this.onBookmark,
    required this.onReport,
    required this.onReply,
    required this.onShare,
  });

  final String id;
  final String author;
  final String type;
  final String content;
  final bool translateContent;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onReport;
  final VoidCallback onReply;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: VvewellColors.softTeal,
                  child: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: VvewellColors.primary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.tr,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        type.tr,
                        style: const TextStyle(
                          color: VvewellColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多操作'.tr,
                  onSelected: (value) {
                    if (value == 'report') onReport();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'report', child: Text('举报内容'.tr)),
                    PopupMenuItem(value: 'mute', child: Text('减少此类内容'.tr)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              translateContent ? content.tr : content,
              style: const TextStyle(height: 1.55),
            ),
            const SizedBox(height: 8),
            Text(
              '个人经历，不构成医疗建议'.tr,
              style: TextStyle(color: VvewellColors.warning, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.chat_bubble_outline, size: 19),
                  label: Text('回复'.tr),
                ),
                TextButton.icon(
                  onPressed: onBookmark,
                  icon: Icon(
                    bookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                  ),
                  label: Text(bookmarked ? '已收藏'.tr : '收藏'.tr),
                ),
                IconButton(
                  tooltip: '分享站内链接'.tr,
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_outlined, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityEventCard extends StatelessWidget {
  const _CommunityEventCard({required this.registered, required this.onToggle});

  final bool registered;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VvewellColors.softViolet,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconBox(
                  icon: Icons.event_outlined,
                  color: Color(0xFF8759CF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '线上活动 · 复查前的准备与沟通'.tr,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const _StatusLabel(label: '认证医护'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('8 月 10 日 19:30 · 普通话 · 提供字幕与审核后回放'.tr),
            const SizedBox(height: 4),
            Text(
              '剩余 18 席 · 问题将提前预审 · 报名身份在前台使用别名'.tr,
              style: TextStyle(color: VvewellColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: registered
                  ? OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text('已报名 · 取消报名'.tr),
                    )
                  : ElevatedButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text('报名活动'.tr),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.tr,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle.tr,
          style: const TextStyle(
            color: VvewellColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.label,
    this.color = VvewellColors.primaryDark,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.tr,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: VvewellColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                detail.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _StatusLabel(label: status),
      ],
    );
  }
}

class _CostMetric extends StatelessWidget {
  const _CostMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: VvewellColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _EmptyActionCard extends StatelessWidget {
  const _EmptyActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 36, color: VvewellColors.muted),
            const SizedBox(height: 10),
            Text(title.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
              description.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VvewellColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel.tr)),
          ],
        ),
      ),
    );
  }
}

class _MedicalSafetyFooter extends StatelessWidget {
  const _MedicalSafetyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '安全提示：任何候选都不能替代紧急医疗判断。若症状加重或出现危险信号，请立即联系当地急救或前往适当急诊。'.tr,
        style: const TextStyle(height: 1.45),
      ),
    );
  }
}

class _InsuranceBoundaryNotice extends StatelessWidget {
  const _InsuranceBoundaryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softOrange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '平台结果为需求、条款和成本情景辅助，不是正式报价、承保或赔付承诺。正式费率、除外、反要约和理赔决定以持牌保险机构结果为准，并提供人工复核与申诉。'
            .tr,
        style: TextStyle(height: 1.45),
      ),
    );
  }
}

class _CommunityPrivacyNotice extends StatelessWidget {
  const _CommunityPrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: VvewellColors.primaryDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '成年成员的加入、浏览、发帖和活动记录默认不向家庭管理员展示，也不会进入保险销售、精算、核保、拒保或拒赔。对外分享使用不暴露病种的中性链接。'
                  .tr,
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _EmptyActionCard(
      icon: Icons.search_off_outlined,
      title: '没有匹配的社区'.tr,
      description: '试试搜索更宽泛的病种、康复阶段或支持主题。预测风险不会自动把你加入确诊社区。'.tr,
      actionLabel: '查看全部社区'.tr,
      onAction: onReset,
    );
  }
}

class _ProviderRecommendation {
  const _ProviderRecommendation({
    required this.name,
    required this.location,
    required this.reason,
    required this.evidence,
    required this.score,
  });

  final String name;
  final String location;
  final String reason;
  final String evidence;
  final int score;
}

class _MedicalService {
  const _MedicalService({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.icon,
    required this.includes,
    required this.excludes,
  });

  final String title;
  final String subtitle;
  final String price;
  final IconData icon;
  final List<String> includes;
  final String excludes;
}

class _InsurancePlan {
  const _InsurancePlan({
    required this.name,
    required this.provider,
    required this.match,
    required this.price,
    required this.coverage,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.deductible,
    required this.waiting,
    required this.fit,
    required this.limit,
  });

  final String name;
  final String provider;
  final int match;
  final String price;
  final String coverage;
  final String p50;
  final String p90;
  final String p95;
  final String deductible;
  final String waiting;
  final String fit;
  final String limit;
}

class _Community {
  const _Community({
    required this.id,
    required this.name,
    required this.description,
    required this.members,
    required this.posts,
    required this.topic,
    required this.verified,
  });

  final String id;
  final String name;
  final String description;
  final String members;
  final String posts;
  final String topic;
  final bool verified;
}

Future<void> _showEmergencyDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: VvewellColors.error,
        size: 34,
      ),
      title: const Text('紧急情况请立即求助'),
      content: const Text(
        '如有持续胸痛、严重呼吸困难、意识改变、大出血或其他危及生命的情况，请立即联系当地急救服务或前往最近的适当急诊。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('我知道了'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(dialogContext),
          icon: const Icon(Icons.call_outlined),
          label: const Text('联系当地急救'),
        ),
      ],
    ),
  );
}

Future<void> _showHospitalCostSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '医院费用中心',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '医院预算、正式账单和直付凭证与平台服务订单完全分开。',
              style: TextStyle(color: VvewellColors.muted),
            ),
            const SizedBox(height: 16),
            const _TaskRow(
              icon: Icons.account_balance_outlined,
              title: '接收医院待确认',
              detail: '暂无医院预算 · 正式付款指引待回传',
              status: '暂无预算',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VvewellColors.softOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '医院费用由医院收取，退款请按医院政策办理。平台不提供“立即支付医院费”按钮；官方外链会进行域名白名单校验。',
                style: TextStyle(height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('上传医院付款凭证'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showProviderDetails(BuildContext context, String name) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const _DetailLine(label: '最早可约', value: '6-12 天，号源更新于 15 分钟前'),
            const _DetailLine(label: '适配理由', value: '专科能力、适用人群、设备和连续性符合当前需求'),
            const _DetailLine(label: '费用与权益', value: '网络状态待核验；预计自付区间将在预评估后更新'),
            const _DetailLine(
              label: '质量证据',
              value: '显示风险调整结果、样本量与区间；证据不足时不会隐藏',
            ),
            const _DetailLine(label: '替代方案', value: '可优先更近、更快或更低预计自付的合格候选'),
            const SizedBox(height: 12),
            const _MedicalSafetyFooter(),
          ],
        ),
      ),
    ),
  );
}

Future<void> _showPlanDetails(
  BuildContext context,
  _InsurancePlan plan, {
  required String memberName,
  required ValueChanged<AdvisorContactResult> onSubmitted,
}) async {
  final requestAdvisor = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                '@provider · 条款版本 2026.07 · 网络更新于 2026-08-01'.trParams({
                  'provider': plan.provider.tr,
                }),
                style: const TextStyle(color: VvewellColors.muted),
              ),
              const SizedBox(height: 18),
              _DetailLine(label: '具体适配'.tr, value: plan.fit.tr),
              _DetailLine(
                label: '年保费 / 保额'.tr,
                value: '${plan.price.tr} / ${plan.coverage.tr}',
              ),
              _DetailLine(
                label: '总成本情景'.tr,
                value:
                    'P50 ${plan.p50.tr} · P90 ${plan.p90.tr} · P95 ${plan.p95.tr}',
              ),
              _DetailLine(
                label: '免赔与等待期'.tr,
                value: '${plan.deductible.tr} · ${plan.waiting.tr}',
              ),
              _DetailLine(label: '重要限制'.tr, value: plan.limit.tr),
              _DetailLine(label: '网络与预授权'.tr, value: '常用医院需逐项核验；部分治疗需要事前授权'.tr),
              _DetailLine(
                label: '利益关系'.tr,
                value: '平台可能与合作机构开展服务合作，不以佣金提升不适当产品'.tr,
              ),
              const SizedBox(height: 12),
              const _InsuranceBoundaryNotice(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('advisor-contact-from-details'),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(
                    '申请具名持牌顾问复核'.tr,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (requestAdvisor != true || !context.mounted) return;
  final result = await showAdvisorContactSheet(
    context,
    memberName: memberName,
    productName: plan.name,
  );
  if (result != null && context.mounted) onSubmitted(result);
}

Future<void> _showCommunityRules(BuildContext context, _Community community) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                community.name.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(community.description.tr),
              const SizedBox(height: 18),
              _DetailLine(label: '社区身份'.tr, value: '默认使用匿名别名，真实身份与公开身份分离'.tr),
              _DetailLine(label: '允许内容'.tr, value: '经验、问题、情绪支持、资源和审核后的活动信息'.tr),
              _DetailLine(
                label: '禁止内容'.tr,
                value: '个体诊断、处方指令、药品售卖、保险承诺、诈骗和隐私泄露'.tr,
              ),
              _DetailLine(
                label: '安全升级'.tr,
                value: '急症、自伤、虐待、诈骗与严重错误信息进入人工安全队列'.tr,
              ),
              _DetailLine(label: '通知隐私'.tr, value: '锁屏、短信和邮件主题默认不显示具体病种'.tr),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<bool?> _showCommunityJoinConsent(
  BuildContext context,
  _Community community,
) {
  bool consent = false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        icon: const Icon(Icons.groups_outlined, color: VvewellColors.primary),
        title: Text('加入@community'.trParams({'community': community.name.tr})),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(community.description.tr),
              const SizedBox(height: 12),
              Text(
                '加入后将默认使用匿名别名。成年成员的社区活动不会向家庭管理员展示，也不会用于保险销售、精算、核保或理赔。'.tr,
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: consent,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text('我已阅读社区规则和隐私说明，并同意加入'.tr),
                onChanged: (value) => setDialogState(() => consent = value!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: consent
                ? () => Navigator.pop(dialogContext, true)
                : null,
            child: Text('使用匿名别名加入'.tr),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _showCommunityReplySheet(BuildContext context) async {
  final controller = TextEditingController();
  bool attempted = false;
  try {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, keyboard + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '回复帖子'.tr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '将使用匿名别名“晨光 27”，回复同样经过隐私与医疗安全检查。'.tr,
                    style: TextStyle(color: VvewellColors.muted),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: InputDecoration(
                      labelText: '回复内容'.tr,
                      alignLabelWithHint: true,
                      errorText: attempted && controller.text.trim().length < 2
                          ? '请填写回复内容'.tr
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (controller.text.trim().length < 2) {
                          setSheetState(() => attempted = true);
                          return;
                        }
                        Navigator.pop(sheetContext, controller.text.trim());
                      },
                      child: Text('发布回复'.tr),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _showReportDialog(BuildContext context) {
  String category = '医疗错误信息';
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('举报内容'.tr),
        content: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: category,
          decoration: InputDecoration(labelText: '举报原因'.tr),
          items: ['医疗错误信息', '隐私泄露', '诈骗或售药', '骚扰与攻击', '其他']
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(value.tr)),
              )
              .toList(),
          onChanged: (value) => setDialogState(() => category = value!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('提交举报'.tr),
          ),
        ],
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: VvewellColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}
